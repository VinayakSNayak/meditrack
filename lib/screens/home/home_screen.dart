import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // DocumentSnapshot, QuerySnapshot
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../widgets/member_selector.dart';
import '../../backend/services/firestore_service.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../providers/member_provider.dart';
import '../prescription/prescription_list_screen.dart';
import '../prescription/add_prescription_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../profile/profile_screen.dart';
import '../health/health_and_stats_screen.dart';
import '../reminder/reminder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  void switchTab(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: bg,
      appBar: currentIndex == 0
          ? AppBar(
              backgroundColor: Theme.of(context).cardColor,
              elevation: 0,
              title: const MemberSelector(),
            )
          : null,
      body: SafeArea(
        child: IndexedStack(
          index: currentIndex,
          children: const [
            _HomeContent(),          // 0 — Home
            PrescriptionListScreen(), // 1 — Meds
            HealthAndStatsScreen(),  // 2 — Health & Stats (combined)
            ReminderScreen(),        // 3 — Reminders
            ChatbotScreen(),         // 4 — Chat
            ProfileScreen(),         // 5 — Profile
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _bottomNav() {
    final navBg = Theme.of(context).cardColor;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: navBg,
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_outlined,      Icons.home,      tr('home'),      0),
          _navItem(Icons.medication_outlined, Icons.medication, tr('meds'),     1),
          _navItem(Icons.favorite_outline,   Icons.favorite,  tr('health'),    2),
          _navItem(Icons.alarm_outlined,     Icons.alarm,     tr('reminders'), 3),
          _navItem(Icons.chat_outlined,      Icons.chat,      tr('chat'),      4),
          _navItem(Icons.person_outline,     Icons.person,    tr('profile'),   5),
        ],
      ),
    );
  }

  Widget _navItem(
      IconData icon, IconData activeIcon, String label, int index) {
    final active = currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? activeIcon : icon,
              color: active ? Colors.green : Colors.grey, size: 22),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: active ? Colors.green : Colors.grey,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ========================= HOME CONTENT =========================

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = DateFormat('EEEE, d MMMM').format(today);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            stream: FirestoreService.getAccountOwner(),
            builder: (context, snapshot) {
              String name = 'User';
              if (snapshot.hasData && snapshot.data != null) {
                name = snapshot.data!.data()?['name'] as String? ?? 'User';
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hi $name 👋',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(todayStr,
                      style: const TextStyle(
                          color: Color(0xFF8E8E93), fontSize: 13)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Today's Medicines — uses new nested medicine structure
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Medicines",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Consumer<MemberProvider>(
                  builder: (context, memberProvider, _) {
                    final memberId = memberProvider.activeMemberId;
                    if (memberId == null) {
                      return const Text('No profile selected',
                          style: TextStyle(color: Colors.grey));
                    }
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      // ValueKey forces a fresh Future when memberId changes,
                      // preventing stale data from the previous member.
                      key: ValueKey(memberId),
                      future: PrescriptionFirestoreService
                          .getActiveMedicinesForToday(memberId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2));
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return const Text('No medicines for today',
                              style: TextStyle(color: Colors.grey));
                        }
                        return Column(
                          children: items.map((item) {
                            final med = item['medicine'];
                            final name =
                                med.medicineName as String? ?? '';
                            final timeStr = DateFormat('hh:mm a')
                                .format(med.reminderTime as DateTime);
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10),
                              child: _medicineRow(context, name, timeStr),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Quick Actions
          const Text('Quick Actions',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  Icons.add,
                  'Add\nPrescription',
                  Colors.blue,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AddPrescriptionScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionTile(
                  Icons.camera_alt,
                  'Scan\nPrescription',
                  Colors.purple,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AddPrescriptionScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionTile(
                  Icons.alarm,
                  'Reminders',
                  Colors.orange,
                  () {
                    final homeState = context
                        .findAncestorStateOfType<_HomeScreenState>();
                    homeState?.switchTab(3);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Health & Stats shortcut
          GestureDetector(
            onTap: () {
              final homeState =
                  context.findAncestorStateOfType<_HomeScreenState>();
              homeState?.switchTab(2);
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.favorite,
                        color: Colors.green, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Health & Stats',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        Text('Records, vitals & adherence charts',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  Widget _medicineRow(BuildContext context, String name, String time) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.medication, size: 28, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(time,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}