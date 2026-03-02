import 'package:flutter/material.dart';
import '../../backend/services/firestore_service.dart';

class AddMetricScreen extends StatefulWidget {
  final String metricType;
  final String category;
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AddMetricScreen({
    super.key,
    required this.metricType,
    required this.category,
    this.existingData,
    this.docId,
  });

  @override
  State<AddMetricScreen> createState() => _AddMetricScreenState();
}

class _AddMetricScreenState extends State<AddMetricScreen> {
  final _formKey = GlobalKey<FormState>();
  final valueController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  bool isSaving = false;

  bool get isEditing => widget.existingData != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      valueController.text =
          widget.existingData!['value'].toString();

      if (widget.existingData!['recordDate'] != null) {
        selectedDate =
            widget.existingData!['recordDate'].toDate();
      }
    }
  }

  // ================= UNIT =================

  String _getUnit(String type) {
    switch (type) {
      case "Blood Pressure":
        return "mmHg";
      case "Heart Rate":
        return "bpm";
      case "Temperature":
        return "°C";
      case "Respiratory Rate":
        return "rpm";
      case "SpO₂":
        return "%";
      case "Weight":
        return "kg";
      case "Height":
        return "cm";
      case "Hemoglobin":
        return "g/dL";
      case "RBC":
        return "million/µL";
      case "WBC":
        return "cells/µL";
      case "Platelets":
        return "platelets/µL";
      case "FBS":
        return "mg/dL";
      case "HbA1c":
        return "%";
      case "Cholesterol":
      case "LDL":
      case "HDL":
      case "Triglycerides":
        return "mg/dL";
      default:
        return "";
    }
  }

  // ================= PLACEHOLDER =================

  String _getPlaceholder(String type) {
    switch (type) {
      case "Blood Pressure":
        return "120/80";
      case "Heart Rate":
        return "72";
      case "Temperature":
        return "36.5";
      case "Respiratory Rate":
        return "16";
      case "SpO₂":
        return "98";
      case "Weight":
        return "70";
      case "Height":
        return "170";
      case "Hemoglobin":
        return "13.5";
      case "RBC":
        return "4.5";
      case "WBC":
        return "7000";
      case "Platelets":
        return "250000";
      case "FBS":
        return "95";
      case "HbA1c":
        return "5.5";
      case "Cholesterol":
        return "180";
      case "LDL":
        return "100";
      case "HDL":
        return "50";
      case "Triglycerides":
        return "140";
      default:
        return "Enter value";
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = _getUnit(widget.metricType);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final labelColor = isDark ? Colors.white70 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: Text(
          isEditing ? "Edit ${widget.metricType}" : "Add ${widget.metricType}",
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// VALUE FIELD CARD
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: TextFormField(
                  controller: valueController,
                  keyboardType: widget.metricType == "Blood Pressure"
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) =>
                      value == null || value.isEmpty ? "Required" : null,
                  style: TextStyle(
                      fontSize: 18, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: "Value",
                    hintText: "${_getPlaceholder(widget.metricType)} $unit",
                    hintStyle: TextStyle(color: labelColor, fontSize: 16),
                    suffixText: unit,
                    suffixStyle: TextStyle(
                        color: labelColor, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// DATE PICKER CARD
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  title: const Text("Record Date",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                    style: const TextStyle(fontSize: 15),
                  ),
                  trailing:
                      const Icon(Icons.calendar_today, color: Colors.indigo),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
              ),

              const Spacer(),

              /// SAVE BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                  ),
                  onPressed: isSaving ? null : _save,
                  child: isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          isEditing ? "Update" : "Save",
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

  // ================= SAVE =================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    final unit = _getUnit(widget.metricType);

    try {
      if (widget.category == 'bodyVitals' || widget.category == 'body') {
        if (isEditing) {
          await FirestoreService.updateBodyVitalMetric(
            docId: widget.docId!,
            type: widget.metricType,
            value: valueController.text.trim(),
            unit: unit,
            recordDate: selectedDate,
          );
        } else {
          await FirestoreService.addBodyVitalMetric(
            type: widget.metricType,
            value: valueController.text.trim(),
            unit: unit,
            recordDate: selectedDate,
          );
        }
      } else {
        if (isEditing) {
          await FirestoreService.updateBloodMetric(
            docId: widget.docId!,
            type: widget.metricType,
            value: valueController.text.trim(),
            unit: unit,
            recordDate: selectedDate,
          );
        } else {
          await FirestoreService.addBloodMetric(
            type: widget.metricType,
            value: valueController.text.trim(),
            unit: unit,
            recordDate: selectedDate,
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isSaving = false);
  }
}