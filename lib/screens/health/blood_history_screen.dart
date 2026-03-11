import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';

class BloodHistoryScreen extends StatelessWidget {
  final String metricType;

  const BloodHistoryScreen({
    super.key,
    required this.metricType,
  });

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
        title: Text(
          "$metricType History",
          style: const TextStyle(fontWeight: FontWeight.w600),
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
            stream: FirestoreService.getBloodMetricsForMember(memberId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Filter by the selected metric type
              final filteredDocs = snapshot.data!.docs
                  .where((doc) =>
                      doc.data().containsKey('type') &&
                      doc['type'] == metricType)
                  .toList();

              // Sort by createdAt descending — new edits always appear
              // first regardless of what recordDate was chosen.
              filteredDocs.sort((a, b) {
                final aTs = a.data()['createdAt'] as Timestamp?;
                final bTs = b.data()['createdAt'] as Timestamp?;
                // Fall back to recordDate for old documents without createdAt
                final aDate = aTs?.toDate() ??
                    (a['recordDate'] as Timestamp).toDate();
                final bDate = bTs?.toDate() ??
                    (b['recordDate'] as Timestamp).toDate();
                return bDate.compareTo(aDate);
              });

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text("No history available"),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data();
                  final recordDate =
                      (data['recordDate'] as Timestamp?)?.toDate();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recordDate != null
                              ? "${recordDate.day}/${recordDate.month}/${recordDate.year}  •  ${_formatTime(recordDate)}"
                              : "No date",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "${data['value']} ${data['unit']}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime date) {
    int hour = date.hour % 12;
    if (hour == 0) hour = 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }
}