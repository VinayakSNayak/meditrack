import 'package:flutter/material.dart';
import 'add_prescription_screen.dart';

class PrescriptionListScreen extends StatelessWidget {
  const PrescriptionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescriptions'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPrescriptionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              title: Text('Paracetamol'),
              subtitle: Text('1 tablet • 8:00 AM'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Vitamin D'),
              subtitle: Text('1 capsule • 1:00 PM'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('Metformin'),
              subtitle: Text('1 tablet • 9:00 PM'),
            ),
          ),
        ],
      ),
    );
  }
}
