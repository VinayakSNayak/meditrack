import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../backend/services/chatbot_api_service.dart';
import '../backend/services/firestore_service.dart';
import '../backend/services/prescription_firestore_service.dart';
import '../models/chat_message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatbotProvider extends ChangeNotifier {
  final List<ChatMessageModel> _messages = [];
  final ChatbotApiService _api = ChatbotApiService();
  bool _isLoading = false;
  String? _errorMessage;

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChatbotProvider() {
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessageModel.bot(
      'Hello! I\'m MediTrack Assist 👋\n\n'
      'I can answer questions about your medications, health records, and general wellness.\n\n'
      '⚠️ I provide general health information only. '
      'Always consult a qualified doctor for medical advice.',
    ));
  }

  Future<void> sendMessage(String userText) async {
    if (userText.trim().isEmpty) return;
    if (_isLoading) return;

    final trimmed = userText.trim();

    _messages.add(ChatMessageModel.user(trimmed));
    _messages.add(ChatMessageModel.loading());
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Build patient context from Firestore (RAG)
      final patientContext = await _buildPatientContext();

      dev.log(
        '[ChatbotProvider] contextLength=${patientContext.length} chars',
        name: 'ChatbotProvider',
      );

      // Prepend patient context to the user message
      final fullMessage = patientContext.isNotEmpty
          ? '[PATIENT CONTEXT — use this to personalise your answer]\n'
              '$patientContext\n'
              '[END CONTEXT]\n\n'
              '[USER QUESTION]\n$trimmed'
          : trimmed;

      final response = await _api.sendMessage(fullMessage);

      _messages.removeWhere((m) => m.isLoading);
      _messages.add(ChatMessageModel.bot(response));
    } catch (e) {
      dev.log('[ChatbotProvider] error: $e', name: 'ChatbotProvider');
      _messages.removeWhere((m) => m.isLoading);
      final errorText = e.toString().replaceFirst('Exception: ', '');
      _messages.add(ChatMessageModel.bot('⚠️ $errorText'));
      _errorMessage = errorText;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _buildPatientContext() async {
    try {
      final memberId = await FirestoreService.getActiveMemberIdOnce();

      final List<Map<String, dynamic>> prescriptions = memberId != null
          ? await PrescriptionFirestoreService
              .getActivePrescriptionsForContext(memberId)
          : [];

      final conditions = await FirestoreService.getConditionsForContext();
      final vitals = await FirestoreService.getRecentVitalsForContext();

      final buffer = StringBuffer();

      buffer.writeln(
          'TODAY: ${DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now())}');
      buffer.writeln();

      if (prescriptions.isNotEmpty) {
        buffer.writeln('CURRENT MEDICATIONS:');
        for (final p in prescriptions) {
          final name = (p['medicineName'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          final dosage = p['dosage'] as String? ?? '';
          final timing = p['foodTiming'] as String? ?? '';
          final ts = p['reminderTime'];
          String timeStr = '';
          if (ts is Timestamp) {
            timeStr = DateFormat('hh:mm a').format(ts.toDate());
          }
          buffer.writeln(
            '- $name'
            '${dosage.isNotEmpty ? " ($dosage)" : ""}'
            '${timing.isNotEmpty ? ", $timing" : ""}'
            '${timeStr.isNotEmpty ? " at $timeStr" : ""}',
          );
        }
        buffer.writeln();
      }

      if (conditions.isNotEmpty) {
        buffer.writeln('EXISTING CONDITIONS:');
        for (final c in conditions) {
          final name = c['conditionName'] as String? ?? '';
          if (name.isEmpty) continue;
          final status = c['status'] as String? ?? '';
          final medication = c['medication'] as String? ?? '';
          buffer.writeln(
            '- $name'
            '${status.isNotEmpty ? " (Status: $status)" : ""}'
            '${medication.isNotEmpty ? ", Medication: $medication" : ""}',
          );
        }
        buffer.writeln();
      }

      if (vitals.isNotEmpty) {
        buffer.writeln('RECENT VITALS:');
        for (final v in vitals) {
          final type = v['type'] as String? ?? '';
          if (type.isEmpty) continue;
          final value = v['value']?.toString() ?? '';
          final unit = v['unit'] as String? ?? '';
          final dateStamp = v['recordDate'];
          String dateStr = '';
          if (dateStamp is Timestamp) {
            dateStr = DateFormat('dd MMM yyyy').format(dateStamp.toDate());
          }
          buffer.writeln(
            '- $type: $value $unit'
            '${dateStr.isNotEmpty ? " ($dateStr)" : ""}',
          );
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      dev.log('[ChatbotProvider] _buildPatientContext failed: $e',
          name: 'ChatbotProvider');
      return '';
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _addWelcomeMessage();
    notifyListeners();
  }
}
