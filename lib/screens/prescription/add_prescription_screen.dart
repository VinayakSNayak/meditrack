import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';
import '../../backend/services/ocr_service.dart';

class AddPrescriptionScreen extends StatefulWidget {
  final String? prescriptionId;
  final Map<String, dynamic>? existingData;

  const AddPrescriptionScreen({
    super.key,
    this.prescriptionId,
    this.existingData,
  });

  @override
  State<AddPrescriptionScreen> createState() =>
      _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState
    extends State<AddPrescriptionScreen> {
  final TextEditingController _medicineController =
  TextEditingController();
  final TextEditingController _dosageController =
  TextEditingController();
  final TextEditingController _notesController =
  TextEditingController();

  String _foodTiming = "After Food";
  DateTime? _selectedTime;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final data = widget.existingData!;
      _medicineController.text =
          data['medicineName'] ?? '';
      _dosageController.text =
          data['dosage'] ?? '';
      _notesController.text =
          data['notes'] ?? '';
      _foodTiming =
          data['foodTiming'] ?? "After Food";
      _selectedTime =
          (data['time'] as Timestamp?)
              ?.toDate();
      _startDate =
          (data['startDate'] as Timestamp?)
              ?.toDate();
      _endDate =
          (data['endDate'] as Timestamp?)
              ?.toDate();
    }
  }

  Future<void> _scanPrescription() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              ListTile(
                leading:
                const Icon(Icons.camera_alt),
                title: const Text(
                    "Scan from Camera"),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleScan(
                      OcrService
                          .scanFromCamera);
                },
              ),
              ListTile(
                leading:
                const Icon(Icons.photo),
                title: const Text(
                    "Pick from Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  await _handleScan(
                      OcrService
                          .scanFromGallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleScan(
      Future<String?> Function()
      scanner) async {
    setState(() {
      _isScanning = true;
    });

    final result = await scanner();

    setState(() {
      _isScanning = false;
    });

    if (result != null &&
        result.trim().isNotEmpty) {
      _medicineController.text =
          result.trim();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
                "Could not detect medicine name"),
          ),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final picked =
    await showTimePicker(
      context: context,
      initialTime:
      TimeOfDay.now(),
    );
    if (picked != null) {
      final now =
      DateTime.now();
      setState(() {
        _selectedTime =
            DateTime(
              now.year,
              now.month,
              now.day,
              picked.hour,
              picked.minute,
            );
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked =
    await showDatePicker(
      context: context,
      initialDate:
      DateTime.now(),
      firstDate:
      DateTime(2023),
      lastDate:
      DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked =
    await showDatePicker(
      context: context,
      initialDate:
      DateTime.now(),
      firstDate:
      DateTime(2023),
      lastDate:
      DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_medicineController.text
        .trim()
        .isEmpty ||
        _selectedTime == null) {
      return;
    }

    if (widget.prescriptionId ==
        null) {
      await FirestoreService
          .addPrescription(
        medicineName:
        _medicineController
            .text
            .trim(),
        foodTiming:
        _foodTiming,
        dosage:
        _dosageController
            .text
            .trim(),
        time:
        _selectedTime!,
        notes:
        _notesController
            .text
            .trim(),
        startDate:
        _startDate,
        endDate:
        _endDate,
      );
    } else {
      await FirestoreService
          .updatePrescription(
        prescriptionId:
        widget
            .prescriptionId!,
        medicineName:
        _medicineController
            .text
            .trim(),
        foodTiming:
        _foodTiming,
        dosage:
        _dosageController
            .text
            .trim(),
        time:
        _selectedTime!,
        notes:
        _notesController
            .text
            .trim(),
        startDate:
        _startDate,
        endDate:
        _endDate,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(
      BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF1F4FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
        const Color(0xFFF1F4FA),
        foregroundColor:
        Colors.black,
        title: const Text(
          'Add Prescription',
          style: TextStyle(
              fontWeight:
              FontWeight.w600),
        ),
      ),
      body:
      SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          children: [
            _inputField(
              controller:
              _medicineController,
              label:
              'Medicine Name',
            ),
            const SizedBox(
                height: 12),
            _isScanning
                ? const CircularProgressIndicator()
                : TextButton.icon(
              onPressed:
              _scanPrescription,
              icon: const Icon(
                  Icons.camera_alt),
              label: const Text(
                  "Scan Prescription"),
            ),
            const SizedBox(
                height: 16),
            _foodSelector(),
            const SizedBox(
                height: 16),
            _inputField(
              controller:
              _dosageController,
              label:
              'Dosage (Optional)',
            ),
            const SizedBox(
                height: 16),
            _timePicker(),
            const SizedBox(
                height: 16),
            _datePicker(
              label:
              'Start Date (Optional)',
              value:
              _startDate,
              onTap:
              _pickStartDate,
            ),
            const SizedBox(
                height: 16),
            _datePicker(
              label:
              'End Date (Optional)',
              value:
              _endDate,
              onTap:
              _pickEndDate,
            ),
            const SizedBox(
                height: 16),
            _inputField(
              controller:
              _notesController,
              label:
              'Notes (Optional)',
              maxLines: 3,
            ),
            const SizedBox(
                height: 24),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController
    controller,
    required String label,
    int maxLines = 1,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
          horizontal: 20),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(26),
      ),
      child: TextField(
        controller:
        controller,
        maxLines:
        maxLines,
        decoration:
        InputDecoration(
          labelText:
          label,
          border:
          InputBorder.none,
        ),
      ),
    );
  }

  Widget _foodSelector() {
    return DropdownButtonFormField<
        String>(
      value: _foodTiming,
      items: const [
        DropdownMenuItem(
          value:
          "Before Food",
          child: Text(
              "Before Food"),
        ),
        DropdownMenuItem(
          value:
          "After Food",
          child:
          Text("After Food"),
        ),
      ],
      onChanged:
          (value) {
        setState(() {
          _foodTiming =
          value!;
        });
      },
      decoration:
      const InputDecoration(
        border:
        OutlineInputBorder(
            borderRadius:
            BorderRadius.all(
                Radius.circular(
                    26))),
      ),
    );
  }

  Widget _timePicker() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding:
        const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
          children: [
            Text(
              _selectedTime == null
                  ? "Select Time"
                  : TimeOfDay
                  .fromDateTime(
                  _selectedTime!)
                  .format(context),
            ),
            const Icon(
                Icons.access_time),
          ],
        ),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18),
        decoration:
        BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
          children: [
            Text(value == null
                ? label
                : "${value.day}/${value.month}/${value.year}"),
            const Icon(
                Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return Container(
      width:
      double.infinity,
      height: 52,
      decoration:
      BoxDecoration(
        color: Colors.green,
        borderRadius:
        BorderRadius.circular(26),
      ),
      child: TextButton(
        onPressed: _save,
        child: const Text(
          'Save Prescription',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ),
    );
  }
}