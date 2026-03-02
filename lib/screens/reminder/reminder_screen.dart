import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../backend/services/notification_service.dart';
import '../../models/medicine_model.dart';
import '../../providers/member_provider.dart';

class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key});

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
        title: const Text("Today's Reminders",
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Consumer<MemberProvider>(
        builder: (context, memberProvider, _) {
          final memberId = memberProvider.activeMemberId;
          if (memberId == null) {
            return const Center(
                child: CircularProgressIndicator());
          }
          return _ReminderBody(memberId: memberId);
        },
      ),
    );
  }
}

// =====================================================================
// _ReminderBody — uses a StreamBuilder for live updates.
// Streams all prescriptions for this member, then for each prescription
// streams its medicines and filters active-today ones.
// This way, adding a new medicine immediately appears without refresh.
// =====================================================================

class _ReminderBody extends StatelessWidget {
  final String memberId;
  const _ReminderBody({required this.memberId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_RemEntry>>(
      stream: _buildReminderStream(memberId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading reminders:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];
        final today = DateTime.now();

        // Filter to active-today medicines
        final active = items
            .where((e) => e.medicine.isActiveToday(today))
            .toList();

        if (active.isEmpty) {
          return _emptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: active.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) => _ReminderCard(
            entry: active[i],
            memberId: memberId,
          ),
        );
      },
    );
  }

  /// Streams prescriptions → for each, streams its medicines → flattens.
  /// Re-emits whenever any prescription or medicine changes.
  static Stream<List<_RemEntry>> _buildReminderStream(String memberId) async* {
    // Get all prescriptions once (sufficient — prescriptions don't change often)
    final prescSnap = await PrescriptionFirestoreService
        .rawPrescriptionsRef(memberId)
        .get();

    if (prescSnap.docs.isEmpty) {
      yield [];
      return;
    }

    // Merge multiple medicine streams into one combined stream
    final streams = prescSnap.docs.map((prescDoc) {
      final prescName = prescDoc.data()['name'] as String? ?? '';
      return PrescriptionFirestoreService
          .medicinesStream(memberId, prescDoc.id)
          .map((medicines) => medicines
              .map((m) => _RemEntry(
                    prescriptionId: prescDoc.id,
                    prescriptionName: prescName,
                    medicine: m,
                  ))
              .toList());
    }).toList();

    // Combine all streams — emit combined list whenever any stream emits
    yield* _mergeStreams(streams);
  }

  /// Merges a list of `Stream<List<T>>` into a single `Stream<List<T>>`
  /// that emits the flattened combined list whenever any source emits.
  static Stream<List<_RemEntry>> _mergeStreams(
      List<Stream<List<_RemEntry>>> streams) async* {
    if (streams.isEmpty) {
      yield [];
      return;
    }

    final latestValues = List<List<_RemEntry>>.filled(
        streams.length, [], growable: false);
    final controller = StreamController<List<_RemEntry>>.broadcast();

    int completedCount = 0;
    for (int i = 0; i < streams.length; i++) {
      final idx = i;
      streams[idx].listen(
        (data) {
          latestValues[idx] = data;
          if (!controller.isClosed) {
            controller.add(latestValues.expand((e) => e).toList());
          }
        },
        onDone: () {
          completedCount++;
          if (completedCount == streams.length) {
            controller.close();
          }
        },
        onError: (e) => controller.addError(e),
      );
    }

    yield* controller.stream;
  }

  Widget _emptyState() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 64, color: Colors.green),
              SizedBox(height: 16),
              Text('No medicines scheduled for today',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
              SizedBox(height: 6),
              Text('Add prescriptions & medicines to set reminders',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// Data container for one medicine reminder entry
class _RemEntry {
  final String prescriptionId;
  final String prescriptionName;
  final MedicineModel medicine;

  const _RemEntry({
    required this.prescriptionId,
    required this.prescriptionName,
    required this.medicine,
  });
}

// =====================================================================
// _ReminderCard
// =====================================================================

class _ReminderCard extends StatelessWidget {
  final _RemEntry entry;
  final String memberId;

  const _ReminderCard({
    required this.entry,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('hh:mm a').format(entry.medicine.reminderTime);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.medication,
                    color: Colors.green, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.medicine.medicineName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (entry.medicine.dosage.isNotEmpty)
                          entry.medicine.dosage,
                        entry.medicine.foodTiming,
                        if (entry.medicine.frequency.isNotEmpty)
                          entry.medicine.frequency,
                      ].join(' • '),
                      style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 12),
                    ),
                    if (entry.prescriptionName.isNotEmpty)
                      Text(
                        entry.prescriptionName,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500),
                      ),
                    // Show date range if set
                    if (entry.medicine.startDate != null ||
                        entry.medicine.endDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (entry.medicine.startDate != null)
                              'From ${DateFormat('dd MMM').format(entry.medicine.startDate!)}',
                            if (entry.medicine.endDate != null)
                              'To ${DateFormat('dd MMM').format(entry.medicine.endDate!)}',
                          ].join('  '),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
              Text(timeStr,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Snooze-only action button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: BorderSide(
                    color: Colors.orange.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _snooze(context),
              icon: const Icon(Icons.snooze, size: 18),
              label: const Text('Snooze 10 min',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _snooze(BuildContext context) async {
    try {
      for (final id in entry.medicine.notificationIds) {
        await NotificationService.cancelNotification(id);
      }

      final snoozeTime = DateTime.now().add(const Duration(minutes: 10));

      await NotificationService.scheduleDailyNotification(
        title: entry.medicine.medicineName,
        body: '(Snoozed) ${entry.medicine.foodTiming}',
        time: snoozeTime,
        payload: '$memberId|${entry.prescriptionId}|${entry.medicine.id}',
      );

      await PrescriptionFirestoreService.snoozeLog(
        memberId: memberId,
        prescriptionId: entry.prescriptionId,
        medicineId: entry.medicine.id,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Snoozed for 10 minutes'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to snooze: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}

