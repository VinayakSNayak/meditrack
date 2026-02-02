import 'package:flutter/material.dart';

class MedicineCard extends StatelessWidget {
  final String name;
  final String time;
  final String dose;

  const MedicineCard({
    super.key,
    required this.name,
    required this.time,
    required this.dose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text('$dose • $time'),
        trailing: const Icon(Icons.medication),
      ),
    );
  }
}
