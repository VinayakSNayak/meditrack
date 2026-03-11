import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/theme_provider.dart';
import '../../backend/services/auth_service.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _settingsCard(context),
            const SizedBox(height: 20),
            _logoutButton(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dark Mode
          Consumer<ThemeProvider>(
            builder: (ctx, themeProvider, _) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: Text(tr('dark_mode')),
              value: themeProvider.isDark,
              activeThumbColor: Colors.green,
              onChanged: (val) => themeProvider.toggleTheme(val),
            ),
          ),
          const Divider(height: 1, indent: 56),

          // Biometric Login
          FutureBuilder<bool>(
            future: AuthService.isBiometricAvailable(),
            builder: (ctx, snap) {
              if (snap.data != true) return const SizedBox();
              return StatefulBuilder(
                builder: (context, setState) {
                  return FutureBuilder<bool>(
                    future: SharedPreferences.getInstance()
                        .then((p) => p.getBool('biometric_enabled') ?? false),
                    builder: (ctx2, prefSnap) {
                      return Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.fingerprint),
                            title: Text(tr('biometric_login')),
                            value: prefSnap.data ?? false,
                            activeThumbColor: Colors.green,
                            onChanged: (val) async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('biometric_enabled', val);
                              setState(() {});
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          // Language
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(tr('language')),
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
        label: Text(
          tr('logout'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
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

