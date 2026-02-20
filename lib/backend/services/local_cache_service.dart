import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const String _key =
      'pending_medicine_status';

  static Future<void> saveStatus({
    required String prescriptionId,
    required String status,
  }) async {
    final prefs =
    await SharedPreferences.getInstance();

    final today = DateTime.now();
    final dateId =
        "${today.year}-${today.month}-${today.day}";

    final Map<String, dynamic> entry = {
      'prescriptionId': prescriptionId,
      'status': status,
      'dateId': dateId,
    };

    final List<String> existing =
        prefs.getStringList(_key) ?? [];

    existing.add(jsonEncode(entry));

    await prefs.setStringList(_key, existing);
  }

  static Future<List<Map<String, dynamic>>>
  getPendingStatuses() async {
    final prefs =
    await SharedPreferences.getInstance();

    final List<String> existing =
        prefs.getStringList(_key) ?? [];

    return existing
        .map((e) =>
    jsonDecode(e)
    as Map<String, dynamic>)
        .toList();
  }

  static Future<void> clearPending() async {
    final prefs =
    await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}