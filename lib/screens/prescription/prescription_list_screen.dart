import 'package:flutter/material.dart';
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
            MaterialPageRoute(builder: (_) => const AddPrescriptionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _prescriptionCard(
            name: 'Aspirin',
            dose: '1 Tablet',
            time: '8:00 AM',
          ),
          _prescriptionCard(
            name: 'Vitamin D',
            dose: '1 Capsule',
            time: '1:00 PM',
          ),
          _prescriptionCard(
            name: 'Metformin',
            dose: '1 Tablet',
            time: '9:00 PM',
          ),
        ],
      ),
    );
  }

  Widget _prescriptionCard({
    required String name,
    required String dose,
    required String time,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.medication,
              color: Colors.blue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$dose • $time',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
