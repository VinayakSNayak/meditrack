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
import '../health/health_records_screen.dart';
import '../reminder/reminder_screen.dart';
import '../report/health_report_screen.dart';

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
              title: Text(tr('app_name'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
            )
          : null,
      body: SafeArea(
        child: IndexedStack(
          index: currentIndex,
          children: [
            _HomeContent(onSwitchTab: switchTab), // 0 — Home
            const PrescriptionListScreen(),        // 1 — Meds
            const HealthAndStatsScreen(),          // 2 — Health & Stats
            const ReminderScreen(),                // 3 — Reminders
            const ChatbotScreen(),                 // 4 — Chat
            const ProfileScreen(),                 // 5 — Profile
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
  final void Function(int) onSwitchTab;
  const _HomeContent({required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = DateFormat('EEEE, d MMMM').format(today);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── SECTION 1: Greeting (unchanged logic) ──────────────────
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

          const SizedBox(height: 16),

          // ── SECTION 2: Active Profile Selector ─────────────────────
          _card(
            context,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.person, color: Colors.green, size: 18),
                ),
                const SizedBox(width: 10),
                Text(tr('profile'),
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey)),
                const Spacer(),
                // MemberSelector dropdown — unchanged logic & data flow
                const MemberSelector(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── SECTION 3: Today's Medicines (unchanged logic) ──────────
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.medication_liquid_outlined,
                          color: Colors.blue, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(tr('todays_medicines'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                Consumer<MemberProvider>(
                  builder: (context, memberProvider, _) {
                    final memberId = memberProvider.activeMemberId;
                    if (memberId == null) {
                      return Text('No profile selected',
                          style: const TextStyle(color: Colors.grey));
                    }
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      // ValueKey forces a fresh Future when memberId changes
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
                          return Text(tr('no_medicines_today'),
                              style: const TextStyle(color: Colors.grey));
                        }
                        return Column(
                          children: items.map((item) {
                            final med = item['medicine'];
                            final name =
                                med.medicineName as String? ?? '';
                            final timeStr = DateFormat('hh:mm a')
                                .format(med.reminderTime as DateTime);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
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

          // ── SECTION 4: Quick Actions (3 updated tiles) ─────────────
          Text(tr('quick_actions'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              // 1 — Add Prescription
              Expanded(
                child: _actionTile(
                  context: context,
                  icon: Icons.note_add_outlined,
                  label: tr('add_prescription'),
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddPrescriptionScreen())),
                ),
              ),
              const SizedBox(width: 12),
              // 2 — Add Health Record
              Expanded(
                child: _actionTile(
                  context: context,
                  icon: Icons.monitor_heart_outlined,
                  label: tr('health_records'),
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HealthRecordsScreen())),
                ),
              ),
              const SizedBox(width: 12),
              // 3 — Generate Health Report
              Expanded(
                child: _actionTile(
                  context: context,
                  icon: Icons.description_outlined,
                  label: tr('generate_report'),
                  color: Colors.green,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HealthReportScreen())),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── SECTION 5: Weekly Adherence Summary ────────────────────
          _weeklyAdherenceCard(context),
        ],
      ),
    );
  }

  // ── Weekly adherence card — uses existing FirestoreService.getWeeklyAdherenceRate() ──
  Widget _weeklyAdherenceCard(BuildContext context) {
    return FutureBuilder<double>(
      future: FirestoreService.getWeeklyAdherenceRate(),
      builder: (context, snapshot) {
        final rate = snapshot.data ?? 0.0;
        final pct = (rate * 100).round();
        final Color barColor = pct >= 80
            ? Colors.green
            : pct >= 50
                ? Colors.orange
                : Colors.redAccent;

        return GestureDetector(
          onTap: () => onSwitchTab(2),
          child: _card(
            context,
            child: Row(
              children: [
                // Circular progress gauge
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: snapshot.hasData ? rate.clamp(0.0, 1.0) : null,
                        strokeWidth: 6,
                        backgroundColor:
                            barColor.withValues(alpha: 0.15),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(barColor),
                      ),
                      if (snapshot.hasData)
                        Center(
                          child: Text('$pct%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: barColor)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('this_week'),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 3),
                      Text(tr('adherence_rate'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: snapshot.hasData
                              ? rate.clamp(0.0, 1.0)
                              : null,
                          minHeight: 7,
                          backgroundColor:
                              barColor.withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  Widget _card(BuildContext context,
      {required Widget child,
      EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) {
    return Container(
      width: double.infinity,
      padding: padding,
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

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}