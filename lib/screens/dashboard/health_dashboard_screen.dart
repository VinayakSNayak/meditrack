import 'package:flutter/material.dart';
import '../../backend/services/firestore_service.dart';

class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF1F4FA),
        foregroundColor: Colors.black,
        title: const Text(
          'Health Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: const [
            _HealthScoreSection(),
            SizedBox(height: 24),
            _WeeklyChartSection(),
            SizedBox(height: 24),
            _StreakSection(),
            SizedBox(height: 24),
            _CalendarHeatmapSection(),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// HEALTH SCORE SECTION
//////////////////////////////////////////////////////////////

class _HealthScoreSection extends StatelessWidget {
  const _HealthScoreSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: FirestoreService.getTodayTakenCountStream(),
      builder: (context, takenSnap) {
        final taken = takenSnap.data ?? 0;

        return StreamBuilder<int>(
          stream: FirestoreService.getTodayMissedCountStream(),
          builder: (context, missedSnap) {
            final missed = missedSnap.data ?? 0;
            final total = taken + missed;

            final adherence =
            total == 0 ? 0 : ((taken / total) * 100).round();

            return _card(
              child: Column(
                children: [
                  const Text(
                    "Health Score",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TweenAnimationBuilder<double>(
                    tween:
                    Tween(begin: 0, end: adherence / 100),
                    duration:
                    const Duration(milliseconds: 900),
                    builder: (context, value, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 12,
                              backgroundColor:
                              Colors.grey.shade200,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                adherence >= 80
                                    ? Colors.green
                                    : adherence >= 50
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                            ),
                          ),
                          Text(
                            "$adherence%",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

//////////////////////////////////////////////////////////////
/// WEEKLY SMOOTH ANIMATED BAR CHART
//////////////////////////////////////////////////////////////

class _WeeklyChartSection extends StatelessWidget {
  const _WeeklyChartSection();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Weekly Progress",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<Map<String, int>>(
            stream:
            FirestoreService.getWeeklyStatusSummaryStream(),
            builder: (context, snapshot) {
              final data =
                  snapshot.data ?? <String, int>{};

              final values = data.values.toList();
              final maxValue = values.isEmpty
                  ? 1
                  : values.reduce(
                      (a, b) => a > b ? a : b);

              return Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: List.generate(
                  values.length,
                      (index) {
                    final value = values[index];
                    final height =
                    maxValue == 0
                        ? 0.1
                        : value / maxValue;

                    return TweenAnimationBuilder<double>(
                      tween:
                      Tween(begin: 0, end: height),
                      duration: const Duration(
                          milliseconds: 600),
                      builder:
                          (context, animatedHeight, _) {
                        return Column(
                          children: [
                            Container(
                              width: 16,
                              height:
                              90 * animatedHeight + 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius:
                                BorderRadius.circular(
                                    8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _dayLabel(index),
                              style:
                              const TextStyle(
                                  fontSize: 10),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _dayLabel(int index) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return labels[index % 7];
  }
}

//////////////////////////////////////////////////////////////
/// STREAK SECTION
//////////////////////////////////////////////////////////////

class _StreakSection extends StatelessWidget {
  const _StreakSection();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: StreamBuilder<int>(
        stream: FirestoreService.getCurrentStreakStream(),
        builder: (context, snapshot) {
          final streak = snapshot.data ?? 0;

          return Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.orange,
                size: 42,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Current Streak",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$streak days",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// CALENDAR HEATMAP SECTION
//////////////////////////////////////////////////////////////

class _CalendarHeatmapSection extends StatelessWidget {
  const _CalendarHeatmapSection();

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Monthly Activity",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<Map<String, bool>>(
            stream:
            FirestoreService.getMonthlyHeatmapStream(),
            builder: (context, snapshot) {
              final data =
                  snapshot.data ?? <String, bool>{};

              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: data.entries.map((entry) {
                  final taken = entry.value;

                  return Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: taken
                          ? Colors.green
                          : Colors.grey.shade300,
                      borderRadius:
                      BorderRadius.circular(4),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////////
/// REUSABLE CARD
//////////////////////////////////////////////////////////////

Widget _card({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}