import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../../backend/services/notification_service.dart';
import '../../backend/services/sync_service.dart';
import '../../providers/member_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // BUG FIX: Use authStateChanges() instead of synchronous getCurrentUser()
    // This properly waits for Firebase to restore the auth session.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Sync any offline-cached medicine statusesa
    SyncService.syncPendingStatuses();

    // Use one-time stream to get the current auth state reliably
    final user = await FirebaseAuth.instance.authStateChanges().first;

    if (!mounted) return;

    if (user != null) {
      // Start listening to active member changes
      if (mounted) {
        context.read<MemberProvider>().init();
      }
      // Reschedule all notifications after login — AWAITED so alarms are
      // registered with alarmClock mode before the user opens the app.
      await NotificationService.rescheduleAll();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.medication,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MediTrack',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.green,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'One App to Remember, Record & Revive',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
