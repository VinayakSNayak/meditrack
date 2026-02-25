import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/member_selector.dart';
import '../prescription/prescription_list_screen.dart';
import '../prescription/add_prescription_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../profile/profile_screen.dart';
import '../health/health_records_screen.dart';
import '../../backend/services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const MemberSelector(),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: currentIndex,
          children: [
            _homeContent(),
            const PrescriptionListScreen(),
            const HealthRecordsScreen(),
            const ChatbotScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _homeContent() {
    final today = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 👋 Greeting
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.getAccountOwner(),
            builder: (context, snapshot) {
              String name = "User";
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data();
                name = data?['name'] ?? "User";
              }
              return Text(
                'Hi $name 👋',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),

          const SizedBox(height: 6),

          const Text(
            'Stay healthy today',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 26),

          // ================= TODAY MEDICINES =================

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Medicines",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.getPrescriptions(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return const Text(
                        'No medicines for today',
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    final todayList = docs.where((doc) {
                      final data = doc.data();

                      final start =
                      (data['startDate'] as Timestamp?)?.toDate();
                      final end =
                      (data['endDate'] as Timestamp?)?.toDate();

                      if (start != null &&
                          today.isBefore(
                              DateTime(start.year, start.month, start.day))) {
                        return false;
                      }

                      if (end != null &&
                          today.isAfter(
                              DateTime(end.year, end.month, end.day))) {
                        return false;
                      }

                      return true;
                    }).toList();

                    if (todayList.isEmpty) {
                      return const Text(
                        'No medicines for today',
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    return Column(
                      children: todayList.map((doc) {
                        final data = doc.data();
                        final name = data['medicineName'] ?? '';
                        final timeStamp = data['time'] as Timestamp?;
                        final time = timeStamp != null
                            ? TimeOfDay.fromDateTime(
                            timeStamp.toDate())
                            .format(context)
                            : '';

                        return Padding(
                          padding:
                          const EdgeInsets.only(bottom: 12),
                          child: _medicineRow(name, time),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // ================= QUICK ACTIONS =================

          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              _actionTile(
                Icons.add,
                'Add\nPrescription',
                Colors.blue,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                        const AddPrescriptionScreen()),
                  );
                },
              ),

              _actionTile(
                Icons.camera_alt,
                'Scan\nPrescription',
                Colors.purple,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                        const AddPrescriptionScreen()),
                  );
                },
              ),

              _actionTile(
                Icons.favorite,
                'Health\nRecords',
                Colors.green,
                    () {
                  setState(() {
                    currentIndex = 2;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _medicineRow(String name, String time) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.medication, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                Text(time,
                    style: const TextStyle(
                        color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      padding:
      const EdgeInsets.symmetric(vertical: 12),
      decoration:
      const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Home', 0),
          _navItem(Icons.medication, 'Prescriptions', 1),
          _navItem(Icons.favorite, 'Health', 2),
          _navItem(Icons.chat, 'Chat', 3),
          _navItem(Icons.settings, 'Settings', 4),
        ],
      ),
    );
  }

  Widget _navItem(
      IconData icon, String label, int index) {
    final active = currentIndex == index;

    return GestureDetector(
      onTap: () =>
          setState(() => currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color:
              active ? Colors.green : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active
                  ? Colors.green
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }

  Widget _actionTile(IconData icon, String label,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor:
              color.withValues(alpha: 0.18),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style:
                const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}