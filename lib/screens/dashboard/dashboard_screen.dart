import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../backend/services/firestore_service.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../models/medicine_model.dart';
import '../../providers/member_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, int> _adherenceCounts = {};
  double _adherenceRate = 0.0;
  List<Map<String, dynamic>> _vitals = [];
  List<Map<String, dynamic>> _todayMedicines = [];
  String _selectedFilter = 'Weekly';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // Capture memberId synchronously before any await — safe context access.
    final memberId = context.read<MemberProvider>().activeMemberId;
    try {
      final Map<String, int> counts;
      final double rate;

      // Respect the selected filter
      if (_selectedFilter == 'Monthly') {
        counts = await FirestoreService.getMonthlyAdherenceCounts();
        rate = await FirestoreService.getMonthlyAdherenceRate();
      } else {
        counts = await FirestoreService.getWeeklyAdherenceCounts();
        rate = await FirestoreService.getWeeklyAdherenceRate();
      }

      final vitals = await FirestoreService.getRecentVitalsForContext();

      List<Map<String, dynamic>> todayMeds = [];
      if (memberId != null) {
        todayMeds = await PrescriptionFirestoreService
            .getActiveMedicinesForToday(memberId);
      }

      if (mounted) {
        setState(() {
          _adherenceCounts = counts;
          // getWeekly/MonthlyAdherenceRate returns 0.0–1.0; convert to 0.0–100.0
          // so the card display, colour thresholds, and progress indicator are correct.
          _adherenceRate = rate * 100;
          _vitals = vitals;
          _todayMedicines = todayMeds;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Log error so it's visible in debug console, don't crash silently
      debugPrint('[DashboardScreen] _loadData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text('Dashboard',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======= ADHERENCE RATE CARD =======
                    _adherenceRateCard(),
                    const SizedBox(height: 20),

                    // ======= FILTER CHIPS =======
                    _filterChips(),
                    const SizedBox(height: 20),

                    // ======= ADHERENCE BAR CHART =======
                    _sectionTitle('Medicine Adherence (Last 7 Days)'),
                    const SizedBox(height: 12),
                    _adherenceBarChart(),
                    const SizedBox(height: 24),

                    // ======= TODAY'S MEDICINE STATUS =======
                    _sectionTitle("Today's Medicines"),
                    const SizedBox(height: 12),
                    _todayMedicinesSection(),
                    const SizedBox(height: 24),

                    // ======= RECENT VITALS =======
                    _sectionTitle('Recent Health Vitals'),
                    const SizedBox(height: 12),
                    _vitalsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _adherenceRateCard() {
    final rate = _adherenceRate.clamp(0.0, 100.0);
    final color = rate >= 80
        ? Colors.green
        : rate >= 50
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
                Text('$_selectedFilter Adherence Rate',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text('${rate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  rate >= 80
                      ? '🎉 Excellent adherence!'
                      : rate >= 50
                          ? '⚠️ Could be improved'
                          : '🔴 Needs attention',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: rate / 100,
              strokeWidth: 8,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return Row(
      children: ['Weekly', 'Monthly'].map((filter) {
        final selected = _selectedFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(filter),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedFilter = filter);
              _loadData();
            },
            selectedColor: Colors.green,
            labelStyle: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );
  }

  Widget _adherenceBarChart() {
    if (_adherenceCounts.isEmpty) {
      return _noDataCard(
          'No adherence data yet. Start taking medicines to see trends!');
    }

    final entries = _adherenceCounts.entries.toList();
    final maxY = entries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

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

  /// Today's medicines — uses new nested medicine subcollection structure.
  Widget _todayMedicinesSection() {
    if (_todayMedicines.isEmpty) {
      return _noDataCard('No medicines scheduled for today.');
    }

    return Column(
      children: _todayMedicines.map((item) {
        final med = item['medicine'] as MedicineModel;
        final timeStr = DateFormat('hh:mm a').format(med.reminderTime);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.green.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.medication, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.medicineName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    if (med.dosage.isNotEmpty || med.foodTiming.isNotEmpty)
                      Text(
                        [
                          if (med.dosage.isNotEmpty) med.dosage,
                          if (med.foodTiming.isNotEmpty) med.foodTiming,
                        ].join(' • '),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _vitalsSection() {
    if (_vitals.isEmpty) {
      return _noDataCard(
          'No vitals recorded yet. Add health records to see trends.');
    }

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
                              color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Text('$value $unit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.blue)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
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
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
        ],
      ),
    );
  }
}

