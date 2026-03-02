import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/errors/app_exception.dart';

class GeminiService {
  static GenerativeModel? _model;
  static String? _apiKey;

  static Future<void> initialize() async {
    try {
      final configJson = await rootBundle.loadString('assets/config.json');
      final config = jsonDecode(configJson) as Map<String, dynamic>;
      _apiKey = config['gemini_api_key'] as String?;

      if (_apiKey == null ||
          _apiKey!.trim().isEmpty ||
          _apiKey == "AIzaSyDinYElbusPqZ8NLS-6v8icLq3OtvWHlLI") {
        // Not configured — chatbot will show graceful error
        _model = null;
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey!,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
        systemInstruction: Content.system(
          '''You are MediTrack Assist, a helpful AI health companion integrated into the MediTrack app.

Your role:
- Answer questions about the user's medications, prescriptions, and health records using the provided patient context.
- Provide general health and wellness information.
- Help users understand medication timing, food interactions, and adherence.
- Explain medical terms in simple language.

CRITICAL RULES:
1. NEVER diagnose medical conditions.
2. NEVER recommend stopping or changing prescribed medications.
3. ALWAYS add a disclaimer when discussing symptoms or suggesting actions: "⚠️ Please consult your doctor for medical advice."
4. If you don't have enough context, say so clearly.
5. Keep responses concise, friendly, and easy to understand.
6. Use the patient data provided to give personalized responses.''',
        ),
      );
    } catch (e) {
      // Config load failure — model stays null, UI handles gracefully
      _model = null;
    }
  }

  static bool get isConfigured => _model != null;

  /// RAG: Build context from user's health data + send to Gemini
  static Future<String> sendMessage({
    required String userMessage,
    required String patientContext,
    List<Content> chatHistory = const [],
  }) async {
    if (_model == null) {
      return 'MediTrack Assist is not configured yet. Please add your Gemini API key in assets/config.json to enable AI features.';
    }

    try {
      final chat = _model!.startChat(history: chatHistory);

      // Inject patient context as part of the message (RAG pattern)
      final fullMessage = patientContext.isNotEmpty
          ? '''[PATIENT CONTEXT - Use this to answer the question]
$patientContext

[USER QUESTION]
$userMessage'''
          : userMessage;

      final response = await chat.sendMessage(Content.text(fullMessage));
      final text = response.text;

      if (text == null || text.isEmpty) {
        return 'I could not generate a response. Please try again.';
      }

      return text;
    } on GenerativeAIException catch (e) {
      if (e.message.contains('API_KEY_INVALID')) {
        throw AppException('Invalid Gemini API key. Please check your config.json.');
      }
      if (e.message.contains('RESOURCE_EXHAUSTED')) {
        throw AppException('API quota exceeded. Please try again later.');
      }
      throw AppException('AI service error: ${e.message}');
    } catch (e) {
      throw AppException('Failed to connect to AI service. Check your internet connection.');
    }
  }
}
