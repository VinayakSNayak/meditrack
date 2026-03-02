import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../models/prescription_model.dart';
import '../../providers/member_provider.dart';
import 'add_prescription_screen.dart';
import 'prescription_detail_screen.dart'; // detail + medicines

class PrescriptionListScreen extends StatelessWidget {
  const PrescriptionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text('Prescriptions',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddPrescriptionScreen())),
        child: const Icon(Icons.add),
      ),
      body: Consumer<MemberProvider>(
        builder: (context, memberProvider, _) {
          final memberId = memberProvider.activeMemberId;
          if (memberId == null) {
            return const Center(
                child: Text('No profile selected',
                    style: TextStyle(color: Colors.grey)));
          }
          return StreamBuilder<List<PrescriptionModel>>(
            stream: PrescriptionFirestoreService.prescriptionsStream(memberId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _emptyState();
              }
              final prescriptions = snapshot.data!;
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: prescriptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) =>
                    _PrescriptionCard(prescription: prescriptions[i],
                        memberId: memberId),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No prescriptions added',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
          SizedBox(height: 6),
          Text('Tap + to create your first prescription',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final PrescriptionModel prescription;
  final String memberId;
  const _PrescriptionCard(
      {required this.prescription, required this.memberId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final dateStr =
        DateFormat('dd MMM yyyy').format(prescription.visitDate);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrescriptionDetailScreen(
            prescription: prescription,
            memberId: memberId,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail (if available)
            if (prescription.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                child: Image.network(
                  prescription.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.description_outlined,
                        color: Colors.green, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prescription.name.isNotEmpty
                              ? prescription.name
                              : 'Prescription',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        if (prescription.hospitalName.isNotEmpty)
                          Text(
                            prescription.hospitalName,
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                          ),
                        if (prescription.diagnosis.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              prescription.diagnosis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade500),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _pill(Icons.calendar_today_outlined, dateStr,
                                Colors.blue),
                            const SizedBox(width: 8),
                            _pill(
                                Icons.medication_outlined,
                                '${prescription.medicineCount} medicine${prescription.medicineCount != 1 ? 's' : ''}',
                                Colors.green),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // More menu
                  PopupMenuButton<String>(
                    iconColor: Colors.grey,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddPrescriptionScreen(
                              prescriptionId: prescription.id,
                              existingData: prescription,
                              memberId: memberId,
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        await _confirmDelete(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Prescription?'),
        content: const Text(
            'This will delete the prescription and all its medicines. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PrescriptionFirestoreService.deletePrescription(
        memberId: memberId,
        prescriptionId: prescription.id,
      );
    }
  }
}