import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';
import 'add_condition_screen.dart';
import 'conditions_history_screen.dart';

class ConditionsViewScreen extends StatelessWidget {
  const ConditionsViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F6FA),
        foregroundColor: Colors.black,
        title: const Text(
          "Existing Conditions",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getConditionsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No conditions added yet"),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              return _conditionCard(
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _getConditionsStream() async* {
    final collection =
    await FirestoreService.getMemberCollection('conditions');
    if (collection == null) return;

    yield* collection
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _conditionCard(
      BuildContext context, {
        required String docId,
        required Map<String, dynamic> data,
      }) {
    final timestamp = data['diagnosedDate'] as Timestamp?;
    final date = timestamp?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['conditionName'] ?? "",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Status: ${data['status']}",
            style: const TextStyle(fontSize: 14),
          ),
          if (data['hasMedication'] == true &&
              (data['medication'] ?? "").isNotEmpty)
            Text(
              "Medication: ${data['medication']}",
              style: const TextStyle(fontSize: 14),
            ),
          if (date != null)
            Text(
              "Diagnosed: ${date.day}/${date.month}/${date.year}",
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
                        builder: (_) => AddConditionScreen(
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
                            ConditionsHistoryScreen(
                              conditionName:
                              data['conditionName'],
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
        title: const Text("Delete Condition?"),
        content: const Text(
            "This will permanently remove this condition."),
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
                  .deleteCondition(docId);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}