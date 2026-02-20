import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';
import 'add_prescription_screen.dart';

class PrescriptionListScreen extends StatelessWidget {
  const PrescriptionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF1F4FA),
        foregroundColor: Colors.black,
        title: const Text(
          'Prescriptions',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const AddPrescriptionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<QuerySnapshot>(
          stream:
          FirestoreService.getPrescriptions(),
          builder: (context, snapshot) {
            if (!snapshot.hasData ||
                snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No prescriptions added',
                  style: TextStyle(
                      color: Colors.grey),
                ),
              );
            }

            final docs =
                snapshot.data!.docs;

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder:
                  (context, index) {
                final doc =
                docs[index];
                final data = doc.data()
                as Map<String,
                    dynamic>;

                final name =
                    data['medicineName'] ??
                        '';
                final dosage =
                    data['dosage'] ??
                        '';
                final foodTiming =
                    data['foodTiming'] ??
                        '';
                final timeStamp =
                data['time']
                as Timestamp?;
                final startStamp =
                data['startDate']
                as Timestamp?;
                final endStamp =
                data['endDate']
                as Timestamp?;
                final notificationId =
                    data['notificationId'] ??
                        0;

                final time =
                timeStamp != null
                    ? TimeOfDay
                    .fromDateTime(
                    timeStamp
                        .toDate())
                    .format(
                    context)
                    : '';

                final startDate =
                startStamp != null
                    ? startStamp
                    .toDate()
                    : null;

                final endDate =
                endStamp != null
                    ? endStamp
                    .toDate()
                    : null;

                return _prescriptionCard(
                  context: context,
                  id: doc.id,
                  notificationId:
                  notificationId,
                  data: data,
                  name: name,
                  dosage: dosage,
                  foodTiming:
                  foodTiming,
                  time: time,
                  startDate:
                  startDate,
                  endDate:
                  endDate,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _prescriptionCard({
    required BuildContext context,
    required String id,
    required int notificationId,
    required Map<String, dynamic>
    data,
    required String name,
    required String dosage,
    required String foodTiming,
    required String time,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    return Container(
      margin:
      const EdgeInsets.only(
          bottom: 16),
      padding:
      const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets
                    .all(14),
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                      0xFFEFF5FF),
                  borderRadius:
                  BorderRadius
                      .circular(20),
                ),
                child: const Icon(
                  Icons.medication,
                  color: Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(
                  width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      name,
                      style:
                      const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),
                    const SizedBox(
                        height: 6),
                    Text(
                      [
                        if (dosage
                            .isNotEmpty)
                          dosage,
                        foodTiming,
                        time,
                      ].join(' • '),
                      style:
                      const TextStyle(
                        color:
                        Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder:
                    (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                onSelected:
                    (value) async {
                  if (value ==
                      'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddPrescriptionScreen(
                              prescriptionId:
                              id,
                              existingData:
                              data,
                            ),
                      ),
                    );
                  }

                  if (value ==
                      'delete') {
                    await FirestoreService
                        .deletePrescription(
                      id,
                      notificationId,
                    );
                  }
                },
              )
            ],
          ),
          if (startDate != null ||
              endDate != null)
            Padding(
              padding:
              const EdgeInsets
                  .only(top: 10),
              child: Text(
                [
                  if (startDate !=
                      null)
                    "Start: ${startDate.day}/${startDate.month}/${startDate.year}",
                  if (endDate !=
                      null)
                    "End: ${endDate.day}/${endDate.month}/${endDate.year}",
                ].join("   "),
                style:
                const TextStyle(
                  fontSize: 12,
                  color:
                  Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}