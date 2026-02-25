import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';
import 'add_metric_screen.dart';
import 'add_condition_screen.dart';
import 'add_other_record_screen.dart';
import 'body_vitals_view_screen.dart';
import 'blood_records_view_screen.dart';
import 'conditions_view_screen.dart';
import 'other_records_view_screen.dart';

class HealthRecordsScreen extends StatelessWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F6FA),
        foregroundColor: Colors.black,
        title: const Text(
          "Health Records",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _tile(context, "Body Vitals", const BodyVitalsViewScreen()),
          const SizedBox(height: 16),
          _tile(context, "Blood Records", const BloodRecordsViewScreen()),
          const SizedBox(height: 16),
          _tile(context, "Existing Conditions", const ConditionsViewScreen()),
          const SizedBox(height: 16),
          _tile(context, "Other Records", const OtherRecordsViewScreen()),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
            )
          ],
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) async {
    final bodySnapshot =
    await FirestoreService.getBodyVitalMetrics().first;
    final bloodSnapshot =
    await FirestoreService.getBloodMetrics().first;

    final existingBodyTypes = bodySnapshot.docs
        .where((e) => e.data().containsKey('type'))
        .map((e) => e.data()['type'])
        .toSet();

    final existingBloodTypes = bloodSnapshot.docs
        .where((e) => e.data().containsKey('type'))
        .map((e) => e.data()['type'])
        .toSet();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            shrinkWrap: true,
            children: [

              /// BODY VITALS
              const Text(
                "Body Vitals",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              ..._bodyMetrics
                  .where((m) => !existingBodyTypes.contains(m))
                  .map((type) => _metricOption(
                context,
                type,
                "body",
              )),

              const SizedBox(height: 24),

              /// BLOOD RECORDS
              const Text(
                "Blood Records",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              ..._bloodMetrics
                  .where((m) => !existingBloodTypes.contains(m))
                  .map((type) => _metricOption(
                context,
                type,
                "blood",
              )),

              const SizedBox(height: 24),

              /// EXISTING CONDITIONS
              const Text(
                "Existing Conditions",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              ListTile(
                title: const Text("Add Condition"),
                trailing:
                const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddConditionScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              /// OTHER RECORDS
              const Text(
                "Other Records",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              ListTile(
                title: const Text("Add Other Record"),
                trailing:
                const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const AddOtherRecordScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricOption(
      BuildContext context, String type, String category) {
    return ListTile(
      title: Text(type),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddMetricScreen(
              metricType: type,
              category: category,
            ),
          ),
        );
      },
    );
  }

  static const List<String> _bodyMetrics = [
    "Blood Pressure",
    "Heart Rate",
    "Temperature",
    "Respiratory Rate",
    "SpO2",
    "Weight",
    "Height",
  ];

  static const List<String> _bloodMetrics = [
    "Hemoglobin",
    "RBC",
    "WBC",
    "Platelets",
    "Cholesterol",
    "Blood Sugar",
  ];
}