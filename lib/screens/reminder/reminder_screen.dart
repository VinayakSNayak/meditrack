import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../backend/services/reminder_service.dart';
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
            return const Center(child: CircularProgressIndicator());
          }
          return _ReminderBody(memberId: memberId);
        },
      ),
    );
  }
}

// =====================================================================
// _ReminderBody
// =====================================================================

class _ReminderBody extends StatefulWidget {
  final String memberId;
  const _ReminderBody({required this.memberId});

  @override
  State<_ReminderBody> createState() => _ReminderBodyState();
}

class _ReminderBodyState extends State<_ReminderBody> {
  // ── stable per-prescription medicine stream subscriptions ──────
  // Key: prescriptionId  |  Value: latest list of _RemEntry for that presc.
  final Map<String, List<_RemEntry>> _entriesByPresc = {};
  final Map<String, StreamSubscription<List<MedicineModel>>> _subsByPresc = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _prescSub;

  // Combined list emitted to the StreamBuilder below
  final StreamController<List<_RemEntry>> _controller =
      StreamController<List<_RemEntry>>.broadcast();

  @override
  void initState() {
    super.initState();
    _subscribePrescriptions();
  }

  @override
  void didUpdateWidget(_ReminderBody old) {
    super.didUpdateWidget(old);
    if (old.memberId != widget.memberId) {
      // Member changed — tear down everything and restart
      _cancelAll();
      _entriesByPresc.clear();
      _subsByPresc.clear();
      _subscribePrescriptions();
    }
  }

  void _subscribePrescriptions() {
    _prescSub = PrescriptionFirestoreService
        .rawPrescriptionsRef(widget.memberId)
        .snapshots(includeMetadataChanges: true)
        .listen((prescSnap) {
      final currentIds = prescSnap.docs.map((d) => d.id).toSet();

      // Remove subscriptions for prescriptions that no longer exist
      final removed = _subsByPresc.keys
          .where((id) => !currentIds.contains(id))
          .toList();
      for (final id in removed) {
        _subsByPresc[id]?.cancel();
        _subsByPresc.remove(id);
        _entriesByPresc.remove(id);
      }

      // Add new subscriptions for prescriptions we haven't seen yet,
      // and keep existing ones alive (no tear-down on doc update).
      for (final prescDoc in prescSnap.docs) {
        final prescId = prescDoc.id;
        if (_subsByPresc.containsKey(prescId)) {
          // Already subscribed — just update the prescription name in
          // existing entries in case it was renamed.
          final newName = prescDoc.data()['name'] as String? ?? '';
          if (_entriesByPresc.containsKey(prescId)) {
            final updated = _entriesByPresc[prescId]!
                .map((e) => _RemEntry(
                      prescriptionId: e.prescriptionId,
                      prescriptionName: newName,
                      medicine: e.medicine,
                      timeSlot: e.timeSlot,
                    ))
                .toList();
            _entriesByPresc[prescId] = updated;
            _emit();
          }
          continue;
        }

        // New prescription — subscribe to its medicines stream.
        final prescName = prescDoc.data()['name'] as String? ?? '';
        final medStream = PrescriptionFirestoreService.medicinesStream(
            widget.memberId, prescId);

        final sub = medStream.listen((medicines) {
          _entriesByPresc[prescId] = medicines
              .expand((m) {
                final slots = m.times.isNotEmpty
                    ? m.times
                    : [_formatTime(m.reminderTime)];
                return slots.map((slot) => _RemEntry(
                      prescriptionId: prescId,
                      prescriptionName: prescName,
                      medicine: m,
                      timeSlot: slot,
                    ));
              })
              .toList();
          _emit();
        });

        _subsByPresc[prescId] = sub;
      }

      if (removed.isNotEmpty) _emit();
    });
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_entriesByPresc.values.expand((e) => e).toList());
    }
  }

  void _cancelAll() {
    _prescSub?.cancel();
    _prescSub = null;
    for (final sub in _subsByPresc.values) {
      sub.cancel();
    }
    _subsByPresc.clear();
  }

  @override
  void dispose() {
    _cancelAll();
    _controller.close();
    super.dispose();
  }

  static String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    // Combine reminder entries stream with logged-keys stream so that
    // taken/skipped slots disappear immediately without a page refresh.
    return StreamBuilder<Set<String>>(
      stream: ReminderService.loggedKeysStream(widget.memberId),
      builder: (context, loggedSnap) {
        final loggedKeys = loggedSnap.data ?? const <String>{};

        return StreamBuilder<List<_RemEntry>>(
          stream: _controller.stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
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

            // One entry per (medicine, timeSlot) — filter where medicine is active today.
            // Also filter out slots already logged (taken/skipped) today.
            final active = items
                .where((e) => e.medicine.isActiveToday(today))
                .where((e) {
                  final key = '${e.medicine.id}_${e.timeSlot}';
                  return !loggedKeys.contains(key);
                })
                .toList();

            // Sort by time slot so the screen is ordered chronologically
            active.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));

            if (active.isEmpty) {
              return _emptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: active.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _ReminderCard(
                entry: active[i],
                memberId: widget.memberId,
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
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

// =====================================================================
// Data model — one instance per (medicine × timeSlot)
// =====================================================================

class _RemEntry {
  final String prescriptionId;
  final String prescriptionName;
  final MedicineModel medicine;
  /// "HH:mm" — the specific time slot this card represents.
  final String timeSlot;

  const _RemEntry({
    required this.prescriptionId,
    required this.prescriptionName,
    required this.medicine,
    required this.timeSlot,
  });
}

// =====================================================================
// _ReminderCard — one card per (medicine, timeSlot)
// =====================================================================

class _ReminderCard extends StatefulWidget {
  final _RemEntry entry;
  final String memberId;

  const _ReminderCard({
    required this.entry,
    required this.memberId,
  });

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  bool _isSnoozed = false;
  bool _isBusy = false;
  bool _isDone = false; // true when taken or skipped (card fades out)

  /// Parse "HH:mm" → displayable "hh:mm a" string
  String get _displayTime {
    final parts = widget.entry.timeSlot.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateFormat('hh:mm a').format(DateTime(2000, 1, 1, hour, minute));
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final med = widget.entry.medicine;

    return AnimatedOpacity(
      opacity: (_isSnoozed || _isDone) ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: _isSnoozed
              ? Border.all(
                  color: Colors.orange.withValues(alpha: 0.5), width: 1.5)
              : null,
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
                // Medicine icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSnoozed
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _isSnoozed ? Icons.snooze : Icons.medication,
                    color: _isSnoozed ? Colors.orange : Colors.green,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Medicine info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.medicineName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (med.dosage.isNotEmpty) med.dosage,
                          med.foodTiming,
                          if (med.frequency.isNotEmpty) med.frequency,
                        ].join(' • '),
                        style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 12),
                      ),
                      if (widget.entry.prescriptionName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.entry.prescriptionName,
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade500),
                          ),
                        ),
                      // Date range
                      if (med.startDate != null || med.endDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [
                              if (med.startDate != null)
                                'From ${DateFormat('dd MMM').format(med.startDate!)}',
                              if (med.endDate != null)
                                'To ${DateFormat('dd MMM').format(med.endDate!)}',
                            ].join('  '),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                ),

                // Time chip — shows THIS slot's time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _displayTime,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _isSnoozed ? Colors.orange : null),
                    ),
                    if (_isSnoozed)
                      const Text('snoozed',
                          style: TextStyle(
                              fontSize: 10, color: Colors.orange)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Action buttons row — Snooze | Taken | Skip
            Row(
              children: [
                // Snooze button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: (_isBusy || _isSnoozed || _isDone)
                        ? null
                        : _snooze,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.orange))
                        : const Icon(Icons.snooze, size: 16),
                    label: Text(
                      _isSnoozed ? 'Snoozed' : 'Snooze',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Taken button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: (_isBusy || _isDone) ? null : _taken,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text(
                      'Taken',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Skip button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: (_isBusy || _isDone) ? null : _skip,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text(
                      'Skip',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _snooze() async {
    setState(() => _isBusy = true);
    try {
      await ReminderService.snooze(
        memberId: widget.memberId,
        prescriptionId: widget.entry.prescriptionId,
        medicineId: widget.entry.medicine.id,
        medicineName: widget.entry.medicine.medicineName,
        foodTiming: widget.entry.medicine.foodTiming,
        timeSlot: widget.entry.timeSlot,
      );

      if (mounted) {
        setState(() {
          _isBusy = false;
          _isSnoozed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⏰ ${widget.entry.medicine.medicineName} snoozed for 10 minutes'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to snooze: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _taken() async {
    setState(() => _isBusy = true);
    try {
      await ReminderService.markTaken(
        memberId: widget.memberId,
        prescriptionId: widget.entry.prescriptionId,
        medicineId: widget.entry.medicine.id,
        timeSlot: widget.entry.timeSlot,
      );
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isDone = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ ${widget.entry.medicine.medicineName} marked as taken'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to mark as taken: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _skip() async {
    setState(() => _isBusy = true);
    try {
      await ReminderService.skipToday(
        memberId: widget.memberId,
        prescriptionId: widget.entry.prescriptionId,
        medicineId: widget.entry.medicine.id,
        timeSlot: widget.entry.timeSlot,
      );
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isDone = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ ${widget.entry.medicine.medicineName} skipped for this slot'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to skip: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
