import 'package:flutter/material.dart';

class AddFamilyScreen extends StatelessWidget {
  const AddFamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF1F4FA),
        foregroundColor: Colors.black,
        title: const Text(
          'Add Family Member',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _inputField(label: 'Name'),
            const SizedBox(height: 16),
            _inputField(label: 'Age'),
            const SizedBox(height: 16),
            _inputField(label: 'Relation'),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.35),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save Member',
                  style: TextStyle(
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

  Widget _inputField({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
