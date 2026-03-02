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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.getBloodMetrics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          // Filter by selected metric type
          final filteredDocs = docs
              .where((doc) =>
          doc.data().containsKey('type') &&
              doc['type'] == metricType)
              .toList();

          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text("No history available"),
            );
          }

          // 🔥 Sort using recordTime if available
          filteredDocs.sort((a, b) {
            final aTime =
            (a.data()['recordTime'] ??
                a.data()['recordDate']) as Timestamp;
            final bTime =
            (b.data()['recordTime'] ??
                b.data()['recordDate']) as Timestamp;

            return bTime.toDate().compareTo(aTime.toDate());
          });

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final data = filteredDocs[index].data();

              final recordDate =
              (data['recordDate'] as Timestamp?)?.toDate();

              final recordTime =
              (data['recordTime'] ??
                  data['recordDate']) as Timestamp?;

              final timeDate = recordTime?.toDate();

              final isEdited = data['isEdited'] == true;

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

                    /// DATE + TIME + EDITED TAG
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          recordDate != null && timeDate != null
                              ? "${recordDate.day}/${recordDate.month}/${recordDate.year}  •  ${_formatTime(timeDate)}"
                              : "No date",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),

                        if (isEdited)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Edited",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// VALUE
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
      ),
    );
  }

  String _formatTime(DateTime date) {
    int hour = date.hour;
    final minute =
    date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? "PM" : "AM";

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return "$hour:$minute $period";
  }
}