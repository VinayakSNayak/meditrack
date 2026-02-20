import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../backend/services/auth_service.dart';
import '../../backend/services/firestore_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import '../../main.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            /// 🔹 PROFILE CARD
            _profileCard(user),

            const SizedBox(height: 24),

            /// 🔹 FAMILY MEMBERS SECTION
            _familySection(),

            const SizedBox(height: 24),

            /// 🔹 DARK MODE
            _settingTile(
              context: context,
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              trailing: Switch(
                value: themeNotifier.value == ThemeMode.dark,
                onChanged: (value) {
                  themeNotifier.value =
                  value ? ThemeMode.dark : ThemeMode.light;
                },
              ),
            ),

            const Spacer(),

            /// 🔹 LOGOUT
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: () async {
                  await AuthService.logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                        (route) => false,
                  );
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= PROFILE CARD =================

  Widget _profileCard(User? user) {
    return StreamBuilder(
      stream: FirestoreService.getActiveMember(),
      builder: (context, snapshot) {
        String name = "User";
        String age = "";
        String relation = "";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data =
          snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? "User";
          age = data['age']?.toString() ?? "";
          relation = data['relation'] ?? "";
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 32,
                child: Icon(Icons.person),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    Text(user?.email ?? '',
                        style:
                        const TextStyle(color: Colors.grey)),
                    if (relation.isNotEmpty)
                      Text("Relation: $relation",
                          style: const TextStyle(
                              color: Colors.grey)),
                    if (age.isNotEmpty)
                      Text("Age: $age",
                          style: const TextStyle(
                              color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ================= FAMILY SECTION =================

  Widget _familySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Family Members",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 16),

          StreamBuilder(
            stream: FirestoreService.getMembers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final members = snapshot.data!.docs;

              return Column(
                children: [
                  for (var member in members)
                    ListTile(
                      title: Text(member['name']),
                      subtitle:
                      Text(member['relation']),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () async {
                        await FirestoreService
                            .setActiveMember(member.id);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                              content: Text(
                                  "${member['name']} selected")),
                        );
                      },
                    ),

                  const SizedBox(height: 8),

                  /// ➕ ADD MEMBER BUTTON
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showAddMemberDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text("Add Member"),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// ================= ADD MEMBER DIALOG =================

  void _showAddMemberDialog(BuildContext context) {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final relationController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Family Member"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration:
              const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration:
              const InputDecoration(labelText: "Age"),
            ),
            TextField(
              controller: relationController,
              decoration:
              const InputDecoration(labelText: "Relation"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService.addMember(
                name: nameController.text,
                age: int.tryParse(ageController.text) ?? 0,
                relation: relationController.text,
              );

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  /// ================= SETTINGS TILE =================

  Widget _settingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          trailing,
        ],
      ),
    );
  }
}