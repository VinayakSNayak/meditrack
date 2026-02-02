import 'package:flutter/material.dart';

class HealthChart extends StatelessWidget {
  final String title;
  final List<int> values;

  const HealthChart({
    super.key,
    required this.title,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: values
                  .map(
                    (v) => Container(
                  width: 16,
                  height: v.toDouble(),
                  color: Colors.teal,
                ),
              )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
