import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../models/prescription_model.dart';
import '../../providers/member_provider.dart';
import 'prescription_detail_screen.dart'; // navigate after creation

class AddPrescriptionScreen extends StatefulWidget {
  final String? prescriptionId;
  final PrescriptionModel? existingData;
  final String? memberId;

  const AddPrescriptionScreen({
    super.key,
    this.prescriptionId,
    this.existingData,
    this.memberId,
  });

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();

  DateTime _visitDate = DateTime.now();
  File? _imageFile;
  bool _removeExistingImage = false;
  bool _isSaving = false;

  bool get _isEditing => widget.prescriptionId != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final d = widget.existingData!;
      _nameCtrl.text = d.name;
      _hospitalCtrl.text = d.hospitalName;
      _diagnosisCtrl.text = d.diagnosis;
      _visitDate = d.visitDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hospitalCtrl.dispose();
    _diagnosisCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile != null) {
      setState(() {
        _imageFile = File(xfile.path);
        _removeExistingImage = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final memberId = widget.memberId ??
          context.read<MemberProvider>().activeMemberId;
      if (memberId == null) {
        _showError('No profile selected');
        return;
      }

      if (_isEditing) {
        await PrescriptionFirestoreService.updatePrescription(
          memberId: memberId,
          prescriptionId: widget.prescriptionId!,
          name: _nameCtrl.text.trim(),
          hospitalName: _hospitalCtrl.text.trim(),
          diagnosis: _diagnosisCtrl.text.trim(),
          visitDate: _visitDate,
          newImageFile: _imageFile,
          removeImage: _removeExistingImage,
        );
        if (mounted) Navigator.pop(context);
      } else {
        // Create prescription envelope, then navigate to detail screen to add medicines
        final prescriptionId =
            await PrescriptionFirestoreService.addPrescription(
          memberId: memberId,
          name: _nameCtrl.text.trim(),
          hospitalName: _hospitalCtrl.text.trim(),
          diagnosis: _diagnosisCtrl.text.trim(),
          visitDate: _visitDate,
          imageFile: _imageFile,
        );

        if (mounted) {
          // Replace with detail screen so user can add medicines immediately
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PrescriptionDetailScreen(
                prescription: PrescriptionModel(
                  id: prescriptionId,
                  name: _nameCtrl.text.trim(),
                  hospitalName: _hospitalCtrl.text.trim(),
                  diagnosis: _diagnosisCtrl.text.trim(),
                  visitDate: _visitDate,
                  medicineCount: 0,
                  createdAt: DateTime.now(),
                ),
                memberId: memberId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

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
          _isEditing ? 'Edit Prescription' : 'New Prescription',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              _imageSection(isDark, cardBg),
              const SizedBox(height: 20),

              // Prescription name
              _card(cardBg,
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prescription Name *',
                      hintText: 'e.g. Diabetic Follow-up',
                      border: InputBorder.none,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  )),
              const SizedBox(height: 12),

              // Hospital name
              _card(cardBg,
                  child: TextFormField(
                    controller: _hospitalCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hospital / Clinic Name',
                      hintText: 'e.g. City Hospital',
                      border: InputBorder.none,
                    ),
                  )),
              const SizedBox(height: 12),

              // Diagnosis
              _card(cardBg,
                  child: TextFormField(
                    controller: _diagnosisCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Diagnosis / Reason',
                      hintText: 'e.g. Type 2 Diabetes',
                      border: InputBorder.none,
                    ),
                  )),
              const SizedBox(height: 12),

              // Visit date
              _card(cardBg,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.calendar_today, color: Colors.green),
                    title: const Text('Visit Date'),
                    subtitle: Text(
                        DateFormat('dd MMM yyyy').format(_visitDate),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _visitDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _visitDate = picked);
                    },
                  )),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _isEditing
                              ? 'Save Changes'
                              : 'Create & Add Medicines',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSection(bool isDark, Color cardBg) {
    final existingUrl = widget.existingData?.imageUrl;
    final hasImage = _imageFile != null ||
        (existingUrl != null && !_removeExistingImage);

    return GestureDetector(
      onTap: () => _showImagePicker(),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Colors.green.withValues(alpha: 0.3), width: 1.5),
        ),
        child: hasImage
            ? Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : Image.network(existingUrl!, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _imageFile = null;
                      _removeExistingImage = true;
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 40,
                      color: isDark ? Colors.grey.shade400 : Colors.grey),
                  const SizedBox(height: 8),
                  Text('Add Prescription Image (Optional)',
                      style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 13)),
                ],
              ),
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Color bg, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: child,
    );
  }
}