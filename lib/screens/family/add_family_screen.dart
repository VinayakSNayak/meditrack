import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../backend/services/firestore_service.dart';

class AddFamilyScreen extends StatefulWidget {
  const AddFamilyScreen({super.key});

  @override
  State<AddFamilyScreen> createState() => _AddFamilyScreenState();
}

class _AddFamilyScreenState extends State<AddFamilyScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _relationController = TextEditingController();

  Future<void> _saveMember() async {
    await FirestoreService.addFamilyMember(
      name: _nameController.text,
      age: int.tryParse(_ageController.text) ?? 0,
      gender: "Not Specified",
      relation: _relationController.text,
      bloodGroup: "",
      conditions: [],
      isPrimary: false,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF1F4FA),
        foregroundColor: Colors.black,
        title: Text(
          tr('add_family_member'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _inputField(label: tr('name'), controller: _nameController),
            const SizedBox(height: 16),
            _inputField(label: tr('age'), controller: _ageController),
            const SizedBox(height: 16),
            _inputField(label: tr('relation'), controller: _relationController),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextButton(
                onPressed: _saveMember,
                child: Text(
                  tr('save_member'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
