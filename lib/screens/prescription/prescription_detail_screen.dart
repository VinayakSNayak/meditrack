import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../backend/services/prescription_ocr_service.dart';
import '../../models/prescription_model.dart';
import '../../models/medicine_model.dart';
import 'add_medicine_screen.dart'; // add/edit medicine form

class PrescriptionDetailScreen extends StatelessWidget {
  final PrescriptionModel prescription;
  final String memberId;

  const PrescriptionDetailScreen({
    super.key,
    required this.prescription,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: Text(
          prescription.name.isNotEmpty ? prescription.name : 'Prescription',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Scan button for OCR
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan & Add Medicine',
            onPressed: () => _scanAndAdd(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Medicine',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddMedicineScreen(
                  memberId: memberId,
                  prescriptionId: prescription.id,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Prescription info header
          _prescriptionHeader(context, isDark, cardBg),
          const SizedBox(height: 4),
          // Medicines list
          Expanded(
            child: StreamBuilder<List<MedicineModel>>(
              stream: PrescriptionFirestoreService.medicinesStream(
                  memberId, prescription.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyMedicines(context, isDark);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _MedicineCard(
                    medicine: snapshot.data![i],
                    memberId: memberId,
                    prescriptionId: prescription.id,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddMedicineScreen(
              memberId: memberId,
              prescriptionId: prescription.id,
            ),
          ),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medicine',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _prescriptionHeader(
      BuildContext context, bool isDark, Color cardBg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prescription.hospitalName.isNotEmpty)
            Row(children: [
              Icon(Icons.local_hospital_outlined,
                  size: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey),
              const SizedBox(width: 6),
              Text(prescription.hospitalName,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600)),
            ]),
          if (prescription.diagnosis.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.medical_information_outlined,
                  size: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey),
              const SizedBox(width: 6),
              Text(prescription.diagnosis,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600)),
            ]),
          ],
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey),
            const SizedBox(width: 6),
            Text(
                'Visit: ${DateFormat('dd MMM yyyy').format(prescription.visitDate)}',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600)),
          ]),
          // Prescription image
          if (prescription.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                prescription.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyMedicines(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_outlined,
              size: 60,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No medicines added yet',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Tap + to add medicines or scan prescription',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _scanAndAdd(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Scan Prescription',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    // Show loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Scanning…'),
            duration: Duration(seconds: 10),
            behavior: SnackBarBehavior.floating),
      );
    }

    List<OcrMedicineResult> results;
    try {
      results = source == 'camera'
          ? await PrescriptionOCRService.scanFromCamera()
          : await PrescriptionOCRService.scanFromGallery();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.redAccent));
      }
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No medicines detected. Please fill manually.'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // Show preview confirmation sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _OcrPreviewSheet(
        results: results,
        memberId: memberId,
        prescriptionId: prescription.id,
      ),
    );
  }
}

// ====================== MEDICINE CARD ======================

class _MedicineCard extends StatelessWidget {
  final MedicineModel medicine;
  final String memberId;
  final String prescriptionId;

  const _MedicineCard({
    required this.medicine,
    required this.memberId,
    required this.prescriptionId,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build time string from ALL time slots, not just times.first
    final timesStr = medicine.times.isNotEmpty
        ? medicine.times.map((t) {
            final parts = t.split(':');
            final h = int.tryParse(parts[0]) ?? 8;
            final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
            return DateFormat('hh:mm a').format(DateTime(2000, 1, 1, h, m));
          }).join(' · ')
        : DateFormat('hh:mm a').format(medicine.reminderTime);

    final isActive = medicine.isActiveToday(DateTime.now());
    final statusColor = isActive ? Colors.green : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
        border: Border.all(
            color: statusColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.medication, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.medicineName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (medicine.dosage.isNotEmpty) medicine.dosage,
                    if (medicine.frequency.isNotEmpty) medicine.frequency,
                    medicine.foodTiming,
                    timesStr,
                  ].join(' • '),
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600),
                ),
                if (medicine.startDate != null || medicine.endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        if (medicine.startDate != null)
                          'From ${DateFormat('dd MMM').format(medicine.startDate!)}',
                        if (medicine.endDate != null)
                          'To ${DateFormat('dd MMM').format(medicine.endDate!)}',
                      ].join('  '),
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            iconColor: Colors.grey,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                  value: 'delete',
                  child:
                      Text('Delete', style: TextStyle(color: Colors.red))),
            ],
            onSelected: (v) async {
              if (v == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddMedicineScreen(
                      memberId: memberId,
                      prescriptionId: prescriptionId,
                      existingMedicine: medicine,
                    ),
                  ),
                );
              } else if (v == 'delete') {
                await _confirmDelete(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Medicine?'),
        content: Text(
            'Remove "${medicine.medicineName}" and cancel its reminder?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PrescriptionFirestoreService.deleteMedicine(
        memberId: memberId,
        prescriptionId: prescriptionId,
        medicineId: medicine.id,
        times: medicine.times,
        notificationIds: medicine.notificationIds,
      );
    }
  }
}

// ====================== OCR PREVIEW SHEET ======================

class _OcrPreviewSheet extends StatefulWidget {
  final List<OcrMedicineResult> results;
  final String memberId;
  final String prescriptionId;

  const _OcrPreviewSheet({
    required this.results,
    required this.memberId,
    required this.prescriptionId,
  });

  @override
  State<_OcrPreviewSheet> createState() => _OcrPreviewSheetState();
}

class _OcrPreviewSheetState extends State<_OcrPreviewSheet> {
  late List<TextEditingController> _nameControllers;
  late List<TextEditingController> _dosageControllers;
  final Set<int> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameControllers = widget.results
        .map((r) => TextEditingController(text: r.medicineName))
        .toList();
    _dosageControllers = widget.results
        .map((r) => TextEditingController(text: r.dosage))
        .toList();
    // Select all by default
    _selected.addAll(List.generate(widget.results.length, (i) => i));
  }

  @override
  void dispose() {
    for (final c in _nameControllers) c.dispose();
    for (final c in _dosageControllers) c.dispose();
    super.dispose();
  }

  Future<void> _saveSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);

    try {
      for (final i in _selected) {
        final name = _nameControllers[i].text.trim();
        if (name.isEmpty) continue;
        await PrescriptionFirestoreService.addMedicine(
          memberId: widget.memberId,
          prescriptionId: widget.prescriptionId,
          medicineName: name,
          dosage: _dosageControllers[i].text.trim(),
          frequency: widget.results[i].frequency,
          foodTiming: widget.results[i].foodTiming,
          times: const ['08:00'],
          notes: '',
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Detected Medicines — Review & Confirm',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: widget.results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _previewTile(i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _saving ? null : _saveSelected,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Add ${_selected.length} Medicine${_selected.length != 1 ? 's' : ''}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewTile(int i) {
    final isSelected = _selected.contains(i);
    return GestureDetector(
      onTap: () => setState(
          () => isSelected ? _selected.remove(i) : _selected.add(i)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.green.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: Colors.green,
              onChanged: (_) => setState(() =>
                  isSelected ? _selected.remove(i) : _selected.add(i)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameControllers[i],
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Medicine Name',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                  TextField(
                    controller: _dosageControllers[i],
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                    decoration: const InputDecoration(
                      labelText: 'Dosage',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


