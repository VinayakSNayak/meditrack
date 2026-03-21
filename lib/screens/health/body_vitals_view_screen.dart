import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';
import 'add_metric_screen.dart';
import 'body_vitals_history_screen.dart';

class BodyVitalsViewScreen extends StatelessWidget {
  const BodyVitalsViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        title: const Text(
          "Body Vitals",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
      ),
      // Outer: resolve active member id
      body: StreamBuilder<String?>(
        stream: FirestoreService.getActiveMemberId(),
        builder: (context, memberSnap) {
          if (!memberSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final memberId = memberSnap.data;
          if (memberId == null) {
            return const Center(child: Text("No member selected"));
          }

          // Inner: direct Firestore query for this member
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.getBodyVitalsForMember(memberId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No body vitals added yet",
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              // Keep only the latest entry per type (docs already sorted
              // by recordDate descending from Firestore)
              final Map<String,
                  QueryDocumentSnapshot<Map<String, dynamic>>> latestMetrics = {};

              for (var doc in docs) {
                final data = doc.data();
                if (!data.containsKey('type') || !data.containsKey('recordDate')) {
                  continue;
                }
                final type = data['type'] as String;
                if (!latestMetrics.containsKey(type)) {
                  latestMetrics[type] = doc;
                }
              }

              final sortedMetrics = latestMetrics.values.toList()
                ..sort((a, b) {
                  // Sort cards by most-recently created type
                  final aTs = a.data()['createdAt'] as Timestamp?;
                  final bTs = b.data()['createdAt'] as Timestamp?;
                  final aDate = aTs?.toDate() ??
                      (a['recordDate'] as Timestamp).toDate();
                  final bDate = bTs?.toDate() ??
                      (b['recordDate'] as Timestamp).toDate();
                  return bDate.compareTo(aDate);
                });

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: sortedMetrics.length,
                itemBuilder: (context, index) {
                  final doc = sortedMetrics[index];
                  final data = doc.data();

                  return _metricCard(
                    context,
                    type: data['type'] as String,
                    value: data['value'].toString(),
                    unit: data['unit'] as String,
                    docId: doc.id,
                    fullData: data,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _metricCard(
      BuildContext context, {
        required String type,
        required String value,
        required String unit,
        required String docId,
        required Map<String, dynamic> fullData,
      }) {
    final cardBg = Theme.of(context).cardColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text("$value $unit",
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green, width: 1.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddMetricScreen(
                        metricType: type,
                        category: 'bodyVitals',
                        existingData: fullData,
                        docId: docId,
                      ),
                    ),
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BodyVitalsHistoryScreen(metricType: type),
                    ),
                  ),
                  child: const Text('History'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _confirmDelete(context, type),
                  child: const Text('Delete'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Delete Record?"),
        content: const Text(
            "This will permanently remove this record and all its history."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.deleteAllBodyVitalsByType(type);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}