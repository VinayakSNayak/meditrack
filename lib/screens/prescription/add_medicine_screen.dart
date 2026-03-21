import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../backend/services/prescription_firestore_service.dart';
import '../../models/medicine_model.dart';

class AddMedicineScreen extends StatefulWidget {
  final String memberId;
  final String prescriptionId;
  final MedicineModel? existingMedicine;

  const AddMedicineScreen({
    super.key,
    required this.memberId,
    required this.prescriptionId,
    this.existingMedicine,
  });

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _frequency = '';
  String _foodTiming = 'After Food';

  /// List of "HH:mm" strings — one per daily reminder slot.
  List<String> _times = ['08:00'];

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;
  bool _reminderEnabled = true;

  bool get _isEditing => widget.existingMedicine != null;

  static const _frequencyOptions = [
    '', 'Once daily', 'Twice daily', 'Thrice daily',
  ];

  static const _foodTimingOptions = [
    'After Food', 'Before Food', 'With Food',
  ];

  /// Default time slots for each count of doses per day.
  static List<String> _defaultTimesForCount(int count) {
    switch (count) {
      case 2:
        return ['08:00', '21:00'];
      case 3:
        return ['08:00', '14:00', '21:00'];
      default:
        return ['08:00'];
    }
  }

  /// Resize _times list when frequency changes:
  /// - grow  → pad with sensible defaults
  /// - shrink → truncate
  void _initTimesForFrequency(String freq) {
    final needed = MedicineModel.timesCountForFrequency(freq);
    final defaults = _defaultTimesForCount(needed);
    if (_times.length == needed) return; // already correct size
    final updated = List<String>.generate(needed, (i) {
      if (i < _times.length) return _times[i]; // keep existing
      return defaults[i];                      // fill with default
    });
    setState(() => _times = updated);
  }

  @override
  void initState() {
    super.initState();
    final m = widget.existingMedicine;
    if (m != null) {
      _nameCtrl.text = m.medicineName;
      _dosageCtrl.text = m.dosage;
      _notesCtrl.text = m.notes;
      _frequency = m.frequency;
      _foodTiming = m.foodTiming;
      // Use existing times list (already handles backward compat via reminderTime)
      _times = List<String>.from(m.times.isNotEmpty ? m.times : ['08:00']);
      _startDate = m.startDate;
      _endDate = m.endDate;
      _reminderEnabled = m.reminderEnabled;
    } else {
      // Initialise default time slots for blank form
      _initTimesForFrequency(_frequency);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await PrescriptionFirestoreService.updateMedicine(
          memberId: widget.memberId,
          prescriptionId: widget.prescriptionId,
          medicineId: widget.existingMedicine!.id,
          medicineName: _nameCtrl.text.trim(),
          dosage: _dosageCtrl.text.trim(),
          frequency: _frequency,
          foodTiming: _foodTiming,
          times: _times,
          oldTimes: List<String>.from(widget.existingMedicine!.times),
          startDate: _startDate,
          endDate: _endDate,
          notes: _notesCtrl.text.trim(),
          oldNotificationIds: widget.existingMedicine!.notificationIds,
          reminderEnabled: _reminderEnabled,
        );
      } else {
        await PrescriptionFirestoreService.addMedicine(
          memberId: widget.memberId,
          prescriptionId: widget.prescriptionId,
          medicineName: _nameCtrl.text.trim(),
          dosage: _dosageCtrl.text.trim(),
          frequency: _frequency,
          foodTiming: _foodTiming,
          times: _times,
          startDate: _startDate,
          endDate: _endDate,
          notes: _notesCtrl.text.trim(),
          reminderEnabled: _reminderEnabled,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: Text(
          _isEditing ? 'Edit Medicine' : 'Add Medicine',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine name
              _field(cardBg,
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Medicine Name *',
                      hintText: 'e.g. Metformin',
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  )),
              const SizedBox(height: 12),

              // Dosage
              _field(cardBg,
                  child: TextFormField(
                    controller: _dosageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dosage',
                      hintText: 'e.g. 500mg',
                      border: InputBorder.none,
                    ),
                  )),
              const SizedBox(height: 12),

              // Frequency dropdown
              _field(cardBg,
                  child: DropdownButtonFormField<String>(
                    initialValue: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: InputBorder.none,
                    ),
                    items: _frequencyOptions
                        .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.isEmpty ? 'Select frequency' : f)))
                        .toList(),
                    onChanged: (v) {
                      final freq = v ?? '';
                      final needed = MedicineModel.timesCountForFrequency(freq);
                      final defaults = _defaultTimesForCount(needed);
                      // Single setState so _frequency and _times are ALWAYS
                      // in sync — prevents any frame with mismatched slot count.
                      setState(() {
                        _frequency = freq;
                        if (_times.length != needed) {
                          _times = List<String>.generate(needed, (i) {
                            if (i < _times.length) return _times[i];
                            return defaults[i];
                          });
                        }
                      });
                    },
                  )),
              const SizedBox(height: 12),

              // Food timing dropdown
              _field(cardBg,
                  child: DropdownButtonFormField<String>(
                    initialValue: _foodTiming,
                    decoration: const InputDecoration(
                      labelText: 'Food Timing',
                      border: InputBorder.none,
                    ),
                    items: _foodTimingOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _foodTiming = v ?? 'After Food'),
                  )),
              const SizedBox(height: 12),

              // Enable Reminder toggle
              _field(cardBg,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      _reminderEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                      color: _reminderEnabled ? Colors.green : Colors.grey,
                    ),
                    title: const Text('Enable Reminder'),
                    subtitle: Text(
                      _reminderEnabled
                          ? 'Notifications will be scheduled'
                          : 'No notifications will be sent',
                      style: TextStyle(
                          color: _reminderEnabled ? Colors.green : Colors.grey,
                          fontSize: 12),
                    ),
                    value: _reminderEnabled,
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.green.withValues(alpha: 0.4),
                    onChanged: (v) => setState(() => _reminderEnabled = v),
                  )),
              const SizedBox(height: 12),

              // Dynamic reminder time pickers (one per dose) — only when reminder enabled
              if (_reminderEnabled) ...[
                ..._buildTimePickers(cardBg),
                const SizedBox(height: 12),
              ],

              // Start date (nullable)
              _dateRow(
                cardBg: cardBg,
                label: 'Start Date',
                value: _startDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
                onClear: () => setState(() => _startDate = null),
              ),
              const SizedBox(height: 12),

              // End date (nullable)
              _dateRow(
                cardBg: cardBg,
                label: 'End Date',
                value: _endDate,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ??
                        (_startDate ?? DateTime.now())
                            .add(const Duration(days: 7)),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
                onClear: () => setState(() => _endDate = null),
              ),
              const SizedBox(height: 12),

              // Notes
              _field(cardBg,
                  child: TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Additional instructions...',
                      border: InputBorder.none,
                    ),
                  )),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _isEditing ? 'Save Changes' : 'Add Medicine',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds one time-picker tile for each slot in [_times].
  List<Widget> _buildTimePickers(Color cardBg) {
    final labels = _times.length == 1
        ? ['Reminder Time']
        : List<String>.generate(
            _times.length, (i) => 'Dose ${i + 1} Time');

    final tiles = <Widget>[];
    for (int i = 0; i < _times.length; i++) {
      final timeStr = _times[i];
      final parts = timeStr.split(':');
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final displayTime = DateFormat('hh:mm a')
          .format(DateTime(2000, 1, 1, hour, minute));

      tiles.add(
        _field(cardBg,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm_outlined, color: Colors.green),
              title: Text(labels[i]),
              subtitle: Text(displayTime,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.green)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: hour, minute: minute),
                );
                if (picked != null && mounted) {
                  final hh = picked.hour.toString().padLeft(2, '0');
                  final mm = picked.minute.toString().padLeft(2, '0');
                  final updated = List<String>.from(_times);
                  updated[i] = '$hh:$mm';
                  setState(() => _times = updated);
                }
              },
            )),
      );
      tiles.add(const SizedBox(height: 12));
    }
    return tiles;
  }

  Widget _field(Color bg, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: child,
    );
  }

  Widget _dateRow({
    required Color cardBg,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return _field(
      cardBg,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_today_outlined,
            color: Colors.blue, size: 20),
        title: Text(label),
        subtitle: Text(
          value != null
              ? DateFormat('dd MMM yyyy').format(value)
              : 'Not set (optional)',
          style: TextStyle(
              color: value != null ? Colors.blue : Colors.grey,
              fontWeight:
                  value != null ? FontWeight.w500 : FontWeight.normal),
        ),
        trailing: value != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                tooltip: 'Remove date',
                onPressed: onClear,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

