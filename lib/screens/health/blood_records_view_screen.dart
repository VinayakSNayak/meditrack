import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';
import 'add_metric_screen.dart';
import 'blood_history_screen.dart';

class BloodRecordsViewScreen extends StatelessWidget {
  const BloodRecordsViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F6FA),
        foregroundColor: Colors.black,
        title: const Text(
          "Blood Records",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.getBloodMetrics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No blood records added yet",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final Map<String,
              QueryDocumentSnapshot<Map<String, dynamic>>> latestMetrics = {};

          for (var doc in docs) {
            final data = doc.data();
            if (!data.containsKey('type')) continue;

            final type = data['type'];

            if (!latestMetrics.containsKey(type)) {
              latestMetrics[type] = doc;
            }
          }

          final sortedMetrics = latestMetrics.values.toList()
            ..sort((a, b) {
              final aTime =
              (a.data()['recordTime'] ??
                  a.data()['recordDate']) as Timestamp;
              final bTime =
              (b.data()['recordTime'] ??
                  b.data()['recordDate']) as Timestamp;

              return bTime.toDate()
                  .compareTo(aTime.toDate());
            });

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sortedMetrics.length,
            itemBuilder: (context, index) {
              final doc = sortedMetrics[index];
              final data = doc.data();

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['type'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${data['value']} ${data['unit']}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style:
                            OutlinedButton.styleFrom(
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddMetricScreen(
                                        metricType:
                                        data['type'],
                                        category: "blood",
                                        existingData:
                                        data,
                                        docId: doc.id,
                                      ),
                                ),
                              );
                            },
                            child:
                            const Text("Edit"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style:
                            ElevatedButton.styleFrom(
                              backgroundColor:
                              Colors.green
                                  .shade600,
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BloodHistoryScreen(
                                        metricType:
                                        data['type'],
                                      ),
                                ),
                              );
                            },
                            child:
                            const Text("History"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style:
                            ElevatedButton.styleFrom(
                              backgroundColor:
                              Colors.red
                                  .shade400,
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(12),
                              ),
                            ),
                            onPressed: () =>
                                _confirmDelete(
                                    context,
                                    doc.id),
                            child:
                            const Text("Delete"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(16),
        ),
        title: const Text("Delete Record?"),
        content: const Text(
            "This will permanently remove this record."),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
              Colors.red.shade400,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService
                  .deleteBloodMetric(docId);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}