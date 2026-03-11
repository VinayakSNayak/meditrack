import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';

class OtherHistoryScreen extends StatelessWidget {
  final String recordName;

  const OtherHistoryScreen({
    super.key,
    required this.recordName,
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
          "$recordName History",
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
                .collection('otherRecords')
                .where('recordName', isEqualTo: recordName)
                .snapshots(),
            builder: (context, snapshot) {
              // Stuck-loading guard: show error if stream fails
              if (snapshot.hasError) {
                return const Center(
                  child: Text("Failed to load history"),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("No history available"),
                );
              }

              // Sort in Dart by createdAt descending (avoids requiring a
              // Firestore composite index on recordName + createdAt).
              final docs = List.of(snapshot.data!.docs);
              docs.sort((a, b) {
                final aTs = a.data()['createdAt'] as Timestamp?;
                final bTs = b.data()['createdAt'] as Timestamp?;
                // Fall back to recordDate for older documents
                final aDate = aTs?.toDate() ??
                    (a.data()['recordDate'] as Timestamp?)?.toDate() ??
                    DateTime(2000);
                final bDate = bTs?.toDate() ??
                    (b.data()['recordDate'] as Timestamp?)?.toDate() ??
                    DateTime(2000);
                return bDate.compareTo(aDate);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final timestamp =
                  data['recordDate'] as Timestamp?;
                  final date = timestamp?.toDate();

                  return Container(
                    margin:
                    const EdgeInsets.only(bottom: 16),
                    padding:
                    const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFE8F5E9),
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
                          data['measurement'] ?? "",
                          style: const TextStyle(
                            fontSize: 16,
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
}