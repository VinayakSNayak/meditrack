import 'package:flutter/material.dart';
import '../../backend/services/firestore_service.dart';

class AddOtherRecordScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? docId;

  const AddOtherRecordScreen({
    super.key,
    this.existingData,
    this.docId,
  });

  @override
  State<AddOtherRecordScreen> createState() =>
      _AddOtherRecordScreenState();
}

class _AddOtherRecordScreenState
    extends State<AddOtherRecordScreen> {

  final _formKey = GlobalKey<FormState>();

  final nameController =
  TextEditingController();
  final measurementController =
  TextEditingController();

  DateTime selectedDate =
  DateTime.now();

  bool isSaving = false;

  bool get isEditing =>
      widget.existingData != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final data = widget.existingData!;

      nameController.text =
          data['recordName'] ?? "";

      measurementController.text =
          data['measurement'] ?? "";

      if (data['recordDate'] != null) {
        selectedDate =
            data['recordDate'].toDate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF1F4FA),
      appBar: AppBar(
        backgroundColor:
        const Color(0xFFF1F4FA),
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          isEditing
              ? "Edit Other Record"
              : "Add Other Record",
          style: const TextStyle(
              fontWeight:
              FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              TextFormField(
                controller:
                nameController,
                validator: (value) =>
                value == null ||
                    value.isEmpty
                    ? "Required"
                    : null,
                decoration:
                InputDecoration(
                  labelText:
                  "Record Name",
                  filled: true,
                  fillColor:
                  Colors.white,
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                        18),
                    borderSide:
                    BorderSide
                        .none,
                  ),
                ),
              ),

              const SizedBox(
                  height: 16),

              TextFormField(
                controller:
                measurementController,
                validator: (value) =>
                value == null ||
                    value.isEmpty
                    ? "Required"
                    : null,
                decoration:
                InputDecoration(
                  labelText:
                  "Measurement / Value",
                  filled: true,
                  fillColor:
                  Colors.white,
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                        18),
                    borderSide:
                    BorderSide
                        .none,
                  ),
                ),
              ),

              const SizedBox(
                  height: 16),

              ListTile(
                tileColor:
                Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                      18),
                ),
                title: const Text(
                    "Record Date"),
                subtitle: Text(
                    "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                trailing:
                const Icon(Icons
                    .calendar_today),
                onTap: () async {
                  final picked =
                  await showDatePicker(
                    context:
                    context,
                    initialDate:
                    selectedDate,
                    firstDate:
                    DateTime(
                        2000),
                    lastDate:
                    DateTime
                        .now(),
                  );
                  if (picked !=
                      null) {
                    setState(() {
                      selectedDate =
                          picked;
                    });
                  }
                },
              ),

              const SizedBox(
                  height: 30),

              SizedBox(
                width: double
                    .infinity,
                child:
                ElevatedButton(
                  onPressed:
                  isSaving
                      ? null
                      : _save,
                  child: isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color: Colors
                          .white,
                    ),
                  )
                      : Text(
                    isEditing
                        ? "Update Record"
                        : "Save Record",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
            .updateOtherRecord(
          docId: widget.docId!,
          recordName:
          nameController.text
              .trim(),
          measurement:
          measurementController
              .text
              .trim(),
          recordDate:
          selectedDate,
        );
      } else {
        await FirestoreService
            .addOtherRecord(
          recordName:
          nameController.text
              .trim(),
          measurement:
          measurementController
              .text
              .trim(),
          recordDate:
          selectedDate,
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