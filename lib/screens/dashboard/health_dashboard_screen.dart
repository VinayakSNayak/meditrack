import 'package:flutter/material.dart';

class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('Blood Pressure'),
                subtitle: const Text('120 / 80'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Sugar Level'),
                subtitle: const Text('95 mg/dL'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Weight'),
                subtitle: const Text('68 kg'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
