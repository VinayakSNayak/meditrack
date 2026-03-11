import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../backend/services/firestore_service.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../providers/member_provider.dart';
import '../../models/medicine_model.dart';
import '../health/add_metric_screen.dart';
import '../health/add_condition_screen.dart';
import '../health/add_other_record_screen.dart';
import '../health/body_vitals_view_screen.dart';
import '../health/blood_records_view_screen.dart';
import '../health/conditions_view_screen.dart';
import '../health/other_records_view_screen.dart';

/// Combined Health & Stats screen with two tabs:
///   Tab 0 — Health Records (vitals, blood, conditions, other)
///   Tab 1 — Dashboard (adherence chart, recent status, recent vitals)
class HealthAndStatsScreen extends StatefulWidget {
  const HealthAndStatsScreen({super.key});

  @override
  State<HealthAndStatsScreen> createState() => _HealthAndStatsScreenState();
}

class _HealthAndStatsScreenState extends State<HealthAndStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1115) : const Color(0xFFF1F4FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text('Health & Stats',
            style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.favorite_outline, size: 18), text: 'Health'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Stats'),
          ],
        ),
        actions: [
          // FAB-style add button visible on Health tab
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => _tabController.index == 0
                ? IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.green,
                    tooltip: 'Add Health Record',
                    onPressed: () => _showAddOptions(context),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_outlined),
                    tooltip: 'Refresh Stats',
                    onPressed: () {
                      _DashboardTab.refreshKey.currentState?.refresh();
                    },
                  ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _HealthTab(),
          _DashboardTab(),
        ],
      ),
    );
  }

  // ====================== ADD OPTIONS BOTTOM SHEET ======================

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Health Record',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _addOption(context, Icons.monitor_heart_outlined, 'Body Vital',
                Colors.blue, () => _showBodyVitalPicker(context)),
            _addOption(context, Icons.bloodtype_outlined, 'Blood Record',
                Colors.red, () => _showBloodRecordPicker(context)),
            _addOption(context, Icons.medical_information_outlined, 'Condition',
                Colors.orange, () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddConditionScreen()));
            }),
            _addOption(context, Icons.note_add_outlined, 'Other Record',
                Colors.purple, () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddOtherRecordScreen()));
            }),
          ],
        ),
      ),
    );
  }

  void _showBodyVitalPicker(BuildContext context) {
    Navigator.pop(context);
    const types = [
      'Blood Pressure', 'Heart Rate', 'Temperature',
      'Respiratory Rate', 'SpO₂', 'Weight', 'Height',
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TypePickerSheet(
        title: 'Select Body Vital',
        types: types,
        color: Colors.blue,
        category: 'bodyVitals',
      ),
    );
  }

  void _showBloodRecordPicker(BuildContext context) {
    Navigator.pop(context);
    const types = [
      'Hemoglobin', 'RBC', 'WBC', 'Platelets',
      'FBS', 'HbA1c', 'Cholesterol', 'LDL', 'HDL', 'Triglycerides',
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TypePickerSheet(
        title: 'Select Blood Record',
        types: types,
        color: Colors.red,
        category: 'bloodRecords',
      ),
    );
  }

  Widget _addOption(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// =========================================================================
//  TYPE PICKER SHEET — choose specific metric before AddMetricScreen
// =========================================================================

class _TypePickerSheet extends StatelessWidget {
  final String title;
  final List<String> types;
  final Color color;
  final String category;

  const _TypePickerSheet({
    required this.title,
    required this.types,
    required this.color,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: types.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddMetricScreen(
                        metricType: types[i],
                        category: category,
                      ),
                    ),
                  );
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    types[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
//  TAB 0 — HEALTH RECORDS
// =========================================================================

class _HealthTab extends StatelessWidget {
  const _HealthTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('My Health Records'),
        const SizedBox(height: 14),
        _healthTile(context, Icons.monitor_heart_outlined, 'Body Vitals',
            'BP, weight, temperature…', Colors.blue,
            const BodyVitalsViewScreen()),
        _healthTile(context, Icons.bloodtype_outlined, 'Blood Records',
            'Blood sugar, HbA1c, CBC…', Colors.red,
            const BloodRecordsViewScreen()),
        _healthTile(context, Icons.medical_information_outlined,
            'Existing Conditions', 'Chronic & past conditions', Colors.orange,
            const ConditionsViewScreen()),
        _healthTile(context, Icons.folder_open_outlined, 'Other Records',
            'Lab reports, scans, notes…', Colors.purple,
            const OtherRecordsViewScreen()),
        const SizedBox(height: 28),
        _sectionHeader('Quick Stats'),
        const SizedBox(height: 14),
        _QuickStatsRow(),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
  }

  Widget _healthTile(BuildContext context, IconData icon, String title,
      String subtitle, Color color, Widget screen) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ——— Quick Stats: shows LATEST value per metric category ———

class _QuickStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Latest body vital
        _LatestVitalTile(
          stream: FirestoreService.getBodyVitalMetrics(),
          label: 'Latest Body Vital',
          icon: Icons.monitor_heart_outlined,
          color: Colors.blue,
        ),
        const SizedBox(height: 10),
        // Latest blood record
        _LatestVitalTile(
          stream: FirestoreService.getBloodMetrics(),
          label: 'Latest Blood Record',
          icon: Icons.bloodtype_outlined,
          color: Colors.red,
        ),
        const SizedBox(height: 10),
        // Current week adherence
        _AdherenceTile(),
      ],
    );
  }
}

class _LatestVitalTile extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String label;
  final IconData icon;
  final Color color;

  const _LatestVitalTile({
    required this.stream,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _statCard(context, icon, color, label, '--', '', '');
        }
        // Already ordered by recordDate DESC — first doc is latest
        final doc = snapshot.data!.docs.first;
        final d = doc.data();
        final type = d['type'] as String? ?? label;
        final value = d['value']?.toString() ?? '--';
        final unit = d['unit'] as String? ?? '';
        final ts = (d['recordDate'] as Timestamp?)?.toDate();
        final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts) : '';
        return _statCard(context, icon, color, type, value, unit, dateStr);
      },
    );
  }

  Widget _statCard(BuildContext context, IconData icon, Color color,
      String type, String value, String unit, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (date.isNotEmpty)
                  Text(date,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text('$value${unit.isNotEmpty ? ' $unit' : ''}',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: color)),
        ],
      ),
    );
  }
}

class _AdherenceTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: FirestoreService.getWeeklyAdherenceRate(),
      builder: (context, snapshot) {
        final rate = snapshot.data ?? 0.0;
        final pct = (rate * 100).round();
        final color = pct >= 80
            ? Colors.green
            : pct >= 50
                ? Colors.orange
                : Colors.redAccent;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check_circle_outline, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Adherence',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Last 7 days',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Text('$pct%',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: color)),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================================
//  TAB 1 — DASHBOARD / STATS
// =========================================================================

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  static final GlobalKey<_DashboardTabState> refreshKey =
      GlobalKey<_DashboardTabState>();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _isLoading = true;
  Map<String, int> _adherenceCounts = {};
  double _adherenceRate = 0.0;
  List<Map<String, dynamic>> _vitals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> refresh() => _loadData();

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final counts = await FirestoreService.getWeeklyAdherenceCounts();
      final rate = await FirestoreService.getWeeklyAdherenceRate();
      final vitals = await FirestoreService.getRecentVitalsForContext();
      if (mounted) {
        setState(() {
          _adherenceCounts = counts;
          _adherenceRate = rate;
          _vitals = vitals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.green));
    }

    return RefreshIndicator(
      color: Colors.green,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            const Text(
              'This Week',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 18),

            // Adherence Rate Card
            _adherenceCard(),

            const SizedBox(height: 20),

            // Bar Chart
            if (_adherenceCounts.isNotEmpty) ...[
              const Text('Medicine Taken Per Day',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              _barChartCard(),
              const SizedBox(height: 20),
            ],

            // Adherence Status List
            _recentStatusSection(),

            const SizedBox(height: 20),

            // Recent Vitals
            if (_vitals.isNotEmpty) ...[
              const Text('Recent Vitals',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              _vitalsSection(),
            ],
          ],
        ),
      ),
    );
  }

  // ————————— Adherence Rate Card —————————

  Widget _adherenceCard() {
    final pct = (_adherenceRate * 100).round();
    final color = pct >= 80
        ? Colors.green
        : pct >= 50
            ? Colors.orange
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Adherence',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      height: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  pct >= 80
                      ? '🎉 Excellent! Keep it up'
                      : pct >= 50
                          ? '⚠️ Could be better'
                          : '❌ Needs attention',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _adherenceRate,
                  strokeWidth: 8,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation(Colors.white),
                ),
                Text('$pct%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ————————— Bar Chart —————————

  Widget _barChartCard() {
    final entries = _adherenceCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxY =
        entries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12)
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY < 1 ? 1 : maxY + 1,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= entries.length) {
                    return const SizedBox();
                  }
                  final dateStr = entries[value.toInt()].key;
                  final parts = dateStr.split('-');
                  if (parts.length < 3) return const SizedBox();
                  final day = parts[2];
                  final month = DateFormat('MMM').format(DateTime(
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                      int.parse(parts[2])));
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$day\n$month',
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.center),
                  );
                },
                reservedSize: 36,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10)),
                reservedSize: 24,
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
                color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  color: e.value.value > 0
                      ? Colors.green
                      : Colors.grey.shade300,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ————————— Recent Adherence Status —————————

  Widget _recentStatusSection() {
    final memberId =
        context.read<MemberProvider>().activeMemberId;
    if (memberId == null) return _noDataCard('No profile selected.');

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: PrescriptionFirestoreService.getActiveMedicinesForToday(
          memberId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return _noDataCard('No medicines scheduled for today.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Medicines",
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            ...items.map((item) {
              final med = item['medicine'] as MedicineModel;
              final color = Colors.green;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: color.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medication, color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(med.medicineName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600))),
                    Text(
                      DateFormat('hh:mm a').format(med.reminderTime),
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // ————————— Recent Vitals —————————

  Widget _vitalsSection() {
    return Column(
      children: _vitals.map((v) {
        final type = v['type'] as String? ?? 'Unknown';
        final value = v['value']?.toString() ?? '';
        final unit = v['unit'] as String? ?? '';
        final dateStamp = v['recordDate'] as Timestamp?;
        final dateStr = dateStamp != null
            ? DateFormat('dd MMM yyyy').format(dateStamp.toDate())
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8)
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monitor_heart_outlined,
                    color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    if (dateStr.isNotEmpty)
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Text('$value $unit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.blue)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _noDataCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}

