import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';

class ConditionsHistoryScreen extends StatelessWidget {
  final String conditionName;

  const ConditionsHistoryScreen({
    super.key,
    required this.conditionName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F6FA),
        foregroundColor: Colors.black,
        title: Text(
          "$conditionName History",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<String?>(
        stream: FirestoreService.getActiveMemberId(),
        builder: (context, memberSnapshot) {
          if (!memberSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final memberId = memberSnapshot.data;

          if (memberId == null) {
            return const Center(child: Text("No member selected"));
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirestoreService.uid)
                .collection('members')
                .doc(memberId)
                .collection('conditions')
                .where('conditionName', isEqualTo: conditionName)
                .orderBy('diagnosedDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("No history available"),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final timestamp =
                  data['diagnosedDate'] as Timestamp?;
                  final date = timestamp?.toDate();

                  return Container(
                    margin:
                    const EdgeInsets.only(bottom: 16),
                    padding:
                    const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFFFF3E0),
                      borderRadius:
                      BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        if (date != null)
                          Text(
                            "${date.day}/${date.month}/${date.year}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          "Status: ${data['status']}",
                          style: const TextStyle(
                              fontSize: 14),
                        ),
                        if (data['hasMedication'] ==
                            true &&
                            (data['medication'] ??
                                "")
                                .isNotEmpty)
                          Text(
                            "Medication: ${data['medication']}",
                            style: const TextStyle(
                                fontSize: 14),
                          ),
                        if ((data['doctorName'] ??
                            "")
                            .isNotEmpty)
                          Text(
                            "Doctor: ${data['doctorName']}",
                            style: const TextStyle(
                                fontSize: 14),
                          ),
                        if ((data['notes'] ?? "")
                            .isNotEmpty)
                          Padding(
                            padding:
                            const EdgeInsets.only(
                                top: 6),
                            child: Text(
                              data['notes'],
                              style:
                              const TextStyle(
                                fontSize: 14,
                                color: Colors
                                    .black54,
                              ),
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
}