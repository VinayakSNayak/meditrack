import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';

class BodyVitalsHistoryScreen extends StatelessWidget {
  final String metricType;

  const BodyVitalsHistoryScreen({
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
        stream: FirestoreService.getBodyVitalMetrics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter by selected metric type
          final filteredDocs = snapshot.data!.docs
              .where((doc) => doc['type'] == metricType)
              .toList();

          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text("No history available"),
            );
          }

          // Sort by recordDate descending
          filteredDocs.sort((a, b) {
            final aDate =
            (a['recordDate'] as Timestamp).toDate();
            final bDate =
            (b['recordDate'] as Timestamp).toDate();
            return bDate.compareTo(aDate);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final data = filteredDocs[index].data();
              final timestamp =
              data['recordDate'] as Timestamp?;
              final date = timestamp?.toDate();

              final isEdited =
                  data['isEdited'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    // DATE + EDIT TAG
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                      children: [
                        Text(
                          date != null
                              ? "${date.day}/${date.month}/${date.year}  •  ${_formatTime(date)}"
                              : "No date",
                          style:
                          const TextStyle(
                            fontSize: 13,
                            color:
                            Colors.black54,
                          ),
                        ),
                        if (isEdited)
                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                            BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  8),
                            ),
                            child: const Text(
                              "Edited",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors
                                    .orange,
                                fontWeight:
                                FontWeight
                                    .w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "${data['value']} ${data['unit']}",
                      style:
                      const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w600,
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
    final hour =
    date.hour > 12 ? date.hour - 12 : date.hour;
    final minute =
    date.minute.toString().padLeft(2, '0');
    final period =
    date.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }
}