import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../backend/services/gemini_service.dart';
import '../backend/services/firestore_service.dart';
import '../backend/services/prescription_firestore_service.dart';
import '../models/chat_message_model.dart';
import '../core/errors/app_exception.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatbotProvider extends ChangeNotifier {
  final List<ChatMessageModel> _messages = [];
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
      'Hello! I\'m MediTrack Assist 👋\n\nI can answer questions about your medications, health records, and general wellness.\n\n⚠️ I provide general health information only. Always consult a qualified doctor for medical advice.',
    ));
  }

  Future<void> sendMessage(String userText) async {
    if (userText.trim().isEmpty) return;

    final trimmed = userText.trim();

    // Add user message + loading indicator
    _messages.add(ChatMessageModel.user(trimmed));
    _messages.add(ChatMessageModel.loading());
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // RAG: Build patient context from Firestore
      final patientContext = await _buildPatientContext();

      // Build chat history as proper Content objects for Gemini multi-turn
      // Skip the welcome message (index 0) and the current user msg + loading
      final history = <Content>[];
      final conversationMessages = _messages
          .where((m) => !m.isLoading)
          .toList();

      // Build pairs from conversation (skip welcome at 0, skip latest user at end)
      for (int i = 1; i < conversationMessages.length - 1; i++) {
        final m = conversationMessages[i];
        if (m.text.isEmpty) continue;
        history.add(Content(
          m.isUser ? 'user' : 'model',
          [TextPart(m.text)],
        ));
      }

      final response = await GeminiService.sendMessage(
        userMessage: trimmed,
        patientContext: patientContext,
        chatHistory: history,
      );

      // Remove loading bubble, add bot response
      _messages.removeWhere((m) => m.isLoading);
      _messages.add(ChatMessageModel.bot(response));
    } on AppException catch (e) {
      _messages.removeWhere((m) => m.isLoading);
      _messages.add(ChatMessageModel.bot('⚠️ ${e.message}'));
      _errorMessage = e.message;
    } catch (e) {
      _messages.removeWhere((m) => m.isLoading);
      _messages.add(ChatMessageModel.bot(
          'Sorry, I couldn\'t connect. Please check your internet connection and try again.'));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _buildPatientContext() async {
    try {
      // Get active memberId
      final memberId = await FirestoreService.getActiveMemberIdOnce();

      // Fetch active medicines from new nested structure
      final List<Map<String, dynamic>> prescriptions = memberId != null
          ? await PrescriptionFirestoreService
              .getActivePrescriptionsForContext(memberId)
          : [];

      final conditions = await FirestoreService.getConditionsForContext();
      final vitals = await FirestoreService.getRecentVitalsForContext();

      final buffer = StringBuffer();

      if (prescriptions.isNotEmpty) {
        buffer.writeln('CURRENT MEDICATIONS:');
        for (final p in prescriptions) {
          final name = p['medicineName'] ?? '';
          final dosage = p['dosage'] ?? '';
          final timing = p['foodTiming'] ?? '';
          final timeStamp = p['reminderTime'] as Timestamp?;
          final timeStr = timeStamp != null
              ? DateFormat('hh:mm a').format(timeStamp.toDate())
              : '';
          buffer.writeln(
              '- $name ${dosage.isNotEmpty ? "($dosage)" : ""}, $timing at $timeStr');
        }
        buffer.writeln();
      }

      if (conditions.isNotEmpty) {
        buffer.writeln('EXISTING CONDITIONS:');
        for (final c in conditions) {
          final name = c['conditionName'] ?? '';
          final status = c['status'] ?? '';
          final medication = c['medication'] ?? '';
          buffer.writeln(
              '- $name (Status: $status)${medication.isNotEmpty ? ", Medication: $medication" : ""}');
        }
        buffer.writeln();
      }

      if (vitals.isNotEmpty) {
        buffer.writeln('RECENT VITALS:');
        for (final v in vitals) {
          final type = v['type'] ?? '';
          final value = v['value']?.toString() ?? '';
          final unit = v['unit'] ?? '';
          final dateStamp = v['recordDate'] as Timestamp?;
          final dateStr = dateStamp != null
              ? DateFormat('dd MMM yyyy').format(dateStamp.toDate())
              : '';
          buffer.writeln('- $type: $value $unit ($dateStr)');
        }
      }

      return buffer.toString();
    } catch (_) {
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
