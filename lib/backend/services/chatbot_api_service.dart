import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

/// Chatbot service — GitHub AI inference API (OpenAI-compatible).
/// Model: openai/gpt-4o-mini via https://models.github.ai
class ChatbotApiService {
  static const String _token =
      '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';

  static const String _endpoint =
      'https://models.github.ai/inference/v1/chat/completions';

  static const String _model = 'openai/gpt-4o-mini';

  static const String _systemPrompt =
      'You are MediTrack Assist, a helpful AI health companion integrated '
      'into the MediTrack app.\n\n'
      'Your role:\n'
      '- Answer questions about the user\'s medications, prescriptions, and '
      'health records using the provided patient context.\n'
      '- Provide general health and wellness information.\n'
      '- Help users understand medication timing, food interactions, and adherence.\n'
      '- Explain medical terms in simple language.\n\n'
      'CRITICAL RULES:\n'
      '1. NEVER diagnose medical conditions.\n'
      '2. NEVER recommend stopping or changing prescribed medications.\n'
      '3. ALWAYS add a disclaimer when discussing symptoms or suggesting '
      'actions: "⚠️ Please consult your doctor for medical advice."\n'
      '4. If you don\'t have enough context, say so clearly.\n'
      '5. Keep responses concise, friendly, and easy to understand.\n'
      '6. Use the patient data provided to give personalised responses.\n'
      '7. Today\'s date context may be in the patient data — use it for '
      'time-sensitive advice.';

  Future<String> sendMessage(String message) async {
    dev.log('[ChatbotApiService] POST $_endpoint  model=$_model',
        name: 'ChatbotApiService');

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': message},
              ],
              'temperature': 0.7,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 30));

      dev.log('[ChatbotApiService] status=${response.statusCode}',
          name: 'ChatbotApiService');
      dev.log('[ChatbotApiService] body=${response.body}',
          name: 'ChatbotApiService');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            data['choices']?[0]?['message']?['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          throw Exception('Empty response from AI service.');
        }
        return content.trim();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        dev.log('[ChatbotApiService] Auth error: ${response.body}',
            name: 'ChatbotApiService');
        throw Exception(
            'GitHub AI token expired or invalid (${response.statusCode}). '
            'Please update the token in chatbot_api_service.dart.');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit reached. Please wait and try again.');
      } else {
        dev.log('[ChatbotApiService] error body: ${response.body}',
            name: 'ChatbotApiService');
        throw Exception(
            'API error ${response.statusCode}: ${response.body}');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      dev.log('[ChatbotApiService] Network/parse error: $e',
          name: 'ChatbotApiService');
      throw Exception('Network error: $e');
    }
  }
}