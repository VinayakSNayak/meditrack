import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../backend/services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  final _nameController =
  TextEditingController();
  final _ageController =
  TextEditingController();
  final _relationController =
  TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final snapshot =
    await FirestoreService
        .getActiveMember()
        .first;

    if (snapshot.exists) {
      final data =
      snapshot.data()
      as Map<String, dynamic>;

      _nameController.text =
          data['name'] ?? '';
      _ageController.text =
          data['age']?.toString() ?? '';
      _relationController.text =
          data['relation'] ?? '';
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    await FirestoreService
        .updateActiveMemberProfile(
      name: _nameController.text,
      age:
      int.tryParse(
        _ageController.text,
      ) ??
          0,
      relation:
      _relationController.text,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child:
            CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Edit Profile"),
      ),
      body: Padding(
        padding:
        const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller:
              _nameController,
              decoration:
              const InputDecoration(
                labelText: "Name",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller:
              _ageController,
              keyboardType:
              TextInputType.number,
              decoration:
              const InputDecoration(
                labelText: "Age",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller:
              _relationController,
              decoration:
              const InputDecoration(
                labelText:
                "Relation",
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child:
              ElevatedButton(
                onPressed:
                _saveProfile,
                child: const Text(
                    "Save"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
