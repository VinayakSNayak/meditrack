import 'package:flutter/material.dart';

class FamilyCard extends StatelessWidget {
  final String name;
  final int age;

  const FamilyCard({
    super.key,
    required this.name,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person),
        title: Text(name),
        subtitle: Text('Age: $age'),
      ),
    );
  }
}
