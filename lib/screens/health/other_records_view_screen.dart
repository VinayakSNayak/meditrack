import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';
import 'add_other_record_screen.dart';
import 'other_history_screen.dart';

class OtherRecordsViewScreen extends StatelessWidget {
  const OtherRecordsViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F6FA),
        foregroundColor: Colors.black,
        title: const Text(
          "Other Records",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.getOtherRecords(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No other records added yet"),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              return _recordCard(
                context,
                docId: doc.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }


  Widget _recordCard(
      BuildContext context, {
        required String docId,
        required Map<String, dynamic> data,
      }) {
    final timestamp = data['recordDate'] as Timestamp?;
    final date = timestamp?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['recordName'] ?? "",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data['measurement'] ?? "",
            style: const TextStyle(fontSize: 15),
          ),
          if (date != null)
            Text(
              "${date.day}/${date.month}/${date.year}",
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddOtherRecordScreen(
                          existingData: data,
                          docId: docId,
                        ),
                      ),
                    );
                  },
                  child: const Text("Edit"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.green.shade600,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OtherHistoryScreen(
                              recordName:
                              data['recordName'],
                            ),
                      ),
                    );
                  },
                  child: const Text("History"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.red.shade400,
                  ),
                  onPressed: () =>
                      _confirmDelete(context, docId),
                  child: const Text("Delete"),
                ),
              ),
            ],
          )
        ],
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
                  .deleteOtherRecord(docId);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}