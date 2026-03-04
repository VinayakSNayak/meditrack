import 'package:flutter/material.dart';
import '../../backend/services/firestore_service.dart';

class AddConditionScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AddConditionScreen({
    super.key,
    this.existingData,
    this.docId,
  });

  @override
  State<AddConditionScreen> createState() =>
      _AddConditionScreenState();
}

class _AddConditionScreenState
    extends State<AddConditionScreen> {

  final _formKey = GlobalKey<FormState>();

  final nameController =
  TextEditingController();
  final medicationController =
  TextEditingController();
  final doctorController =
  TextEditingController();
  final notesController =
  TextEditingController();

  DateTime diagnosedDate =
  DateTime.now();

  String selectedStatus = "Active";
  bool hasMedication = false;
  bool isSaving = false;

  bool get isEditing =>
      widget.existingData != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final data = widget.existingData!;

      nameController.text =
          data['conditionName'] ?? "";

      selectedStatus =
          data['status'] ?? "Active";

      hasMedication =
          data['hasMedication'] ?? false;

      medicationController.text =
          data['medication'] ?? "";

      doctorController.text =
          data['doctorName'] ?? "";

      notesController.text =
          data['notes'] ?? "";

      if (data['diagnosedDate'] != null) {
        diagnosedDate =
            data['diagnosedDate'].toDate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF1F4FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
        const Color(0xFFF1F4FA),
        foregroundColor: Colors.black,
        title: Text(
          isEditing
              ? "Edit Condition"
              : "Add Condition",
        ),
      ),
      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              _input(
                controller:
                nameController,
                label:
                "Condition Name",
                required: true,
              ),

              const SizedBox(height: 12),

              _statusDropdown(),

              const SizedBox(height: 12),

              _datePicker(),

              const SizedBox(height: 12),

              SwitchListTile(
                tileColor: Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                      18),
                ),
                title: const Text(
                    "Currently Taking Medication?"),
                value: hasMedication,
                onChanged: (value) {
                  setState(() {
                    hasMedication =
                        value;
                  });
                },
              ),

              const SizedBox(height: 12),

              if (hasMedication)
                _input(
                  controller:
                  medicationController,
                  label:
                  "Current Medication",
                ),

              const SizedBox(height: 12),

              _input(
                controller:
                doctorController,
                label:
                "Doctor Name (optional)",
              ),

              const SizedBox(height: 12),

              _input(
                controller:
                notesController,
                label:
                "Notes (optional)",
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                  isSaving ? null : _save,
                  child: isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      Colors.white,
                    ),
                  )
                      : Text(
                    isEditing
                        ? "Update Condition"
                        : "Save Condition",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController
    controller,
    required String label,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: required
          ? (value) =>
      value == null ||
          value.isEmpty
          ? "Required"
          : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
              18),
          borderSide:
          BorderSide.none,
        ),
      ),
    );
  }

  Widget _statusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedStatus,
      items: const [
        DropdownMenuItem(
            value: "Active",
            child: Text("Active")),
        DropdownMenuItem(
            value: "Controlled",
            child: Text("Controlled")),
        DropdownMenuItem(
            value: "Recovered",
            child: Text("Recovered")),
      ],
      onChanged: (value) {
        setState(() {
          selectedStatus = value!;
        });
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
              18),
          borderSide:
          BorderSide.none,
        ),
      ),
    );
  }

  Widget _datePicker() {
    return ListTile(
      tileColor: Colors.white,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
            18),
      ),
      title: const Text(
          "Diagnosed Date"),
      subtitle: Text(
          "${diagnosedDate.day}/${diagnosedDate.month}/${diagnosedDate.year}"),
      trailing:
      const Icon(Icons.calendar_today),
      onTap: () async {
        final picked =
        await showDatePicker(
          context: context,
          initialDate:
          diagnosedDate,
          firstDate:
          DateTime(2000),
          lastDate:
          DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            diagnosedDate =
                picked;
          });
        }
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!
        .validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      if (isEditing &&
          widget.docId != null) {
        await FirestoreService
            .updateCondition(
          docId: widget.docId!,
          conditionName:
          nameController.text
              .trim(),
          diagnosedDate:
          diagnosedDate,
          status: selectedStatus,
          hasMedication:
          hasMedication,
          medication:
          medicationController
              .text
              .trim(),
          doctorName:
          doctorController
              .text
              .trim(),
          notes:
          notesController
              .text
              .trim(),
        );
      } else {
        await FirestoreService
            .addCondition(
          conditionName:
          nameController.text
              .trim(),
          diagnosedDate:
          diagnosedDate,
          status: selectedStatus,
          hasMedication:
          hasMedication,
          medication:
          medicationController
              .text
              .trim(),
          doctorName:
          doctorController
              .text
              .trim(),
          notes:
          notesController
              .text
              .trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    if (mounted) setState(() => isSaving = false);
  }
}