import 'package:flutter/material.dart';

class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Paracetamol'),
              subtitle: const Text('8:00 AM'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () {}, child: const Text('Snooze')),
                  TextButton(onPressed: () {}, child: const Text('Taken')),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Vitamin D'),
              subtitle: const Text('1:00 PM'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () {}, child: const Text('Snooze')),
                  TextButton(onPressed: () {}, child: const Text('Taken')),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Metformin'),
              subtitle: const Text('9:00 PM'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () {}, child: const Text('Snooze')),
                  TextButton(onPressed: () {}, child: const Text('Taken')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
