import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/theme_provider.dart';
import '../../backend/services/auth_service.dart';
import '../../backend/services/firestore_service.dart';
import '../auth/login_screen.dart';
import '../family/add_family_screen.dart';
import '../report/health_report_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _profileCard(user),
            const SizedBox(height: 20),
            _familySection(context),
            const SizedBox(height: 20),
            _settingsSection(context),
            const SizedBox(height: 20),
            _logoutButton(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(User? user) {
    return StreamBuilder(
      stream: FirestoreService.getActiveMember(),
      builder: (context, snapshot) {
        String name = 'User';
        String age = '';
        String relation = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] as String? ?? 'User';
          age = data['age']?.toString() ?? '';
          relation = data['relation'] as String? ?? '';
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.green.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700, color: Colors.green),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    if (user?.email != null)
                      Text(user!.email!,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (relation.isNotEmpty)
                      Text('Relation: $relation',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (age.isNotEmpty)
                      Text('Age: $age',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _familySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Family Members',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddFamilyScreen())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: FirestoreService.getMembers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                    height: 40,
                    child:
                        Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final members = snapshot.data!.docs;
              return StreamBuilder<String?>(
                stream: FirestoreService.getActiveMemberId(),
                builder: (ctx, activeSnap) {
                  final activeId = activeSnap.data;
                  return Column(
                    children: members.map((m) {
                      final data = m.data();
                      final isActive = m.id == activeId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.1),
                          child: Icon(Icons.person,
                              color: isActive ? Colors.green : Colors.grey),
                        ),
                        title: Text(data['name'] as String? ?? '',
                            style: TextStyle(
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                        subtitle: Text(data['relation'] as String? ?? ''),
                        trailing: isActive
                            ? const Chip(
                                label: Text('Active',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white)),
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.zero,
                              )
                            : null,
                        onTap: () => FirestoreService.setActiveMember(m.id),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _settingsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          // Dark Mode
          Consumer<ThemeProvider>(
            builder: (ctx, themeProvider, _) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark Mode'),
              value: themeProvider.isDark,
              activeThumbColor: Colors.green,
              onChanged: (val) => themeProvider.toggleTheme(val),
            ),
          ),
          const Divider(height: 1, indent: 56),

          // Biometric
          FutureBuilder<bool>(
            future: AuthService.isBiometricAvailable(),
            builder: (ctx, snap) {
              if (snap.data != true) return const SizedBox();
              return StatefulBuilder(builder: (context, setState) {
                return FutureBuilder<bool>(
                  future: SharedPreferences.getInstance()
                      .then((p) => p.getBool('biometric_enabled') ?? false),
                  builder: (ctx2, prefSnap) {
                    return SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text('Biometric Login'),
                      value: prefSnap.data ?? false,
                      activeThumbColor: Colors.green,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('biometric_enabled', val);
                        setState(() {});
                      },
                    );
                  },
                );
              });
            },
          ),
          const Divider(height: 1, indent: 56),

          // Language
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: context.locale.languageCode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ')),
              ],
              onChanged: (lang) {
                if (lang != null) context.setLocale(Locale(lang));
              },
            ),
          ),
          const Divider(height: 1, indent: 56),

          // Generate Report
          ListTile(
            leading: const Icon(Icons.description_outlined, color: Colors.green),
            title: const Text('Generate Health Report'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HealthReportScreen())),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text('Logout',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        onPressed: () async {
          await context.read<app_auth.AuthProvider>().logout();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
      ),
    );
  }
}

