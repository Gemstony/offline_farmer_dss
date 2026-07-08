// lib/services/ai_chat_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiChatService {
  // Replace with your own Groq API key (or use a backend proxy)
  static const String _apiKey = 'YOUR_GROQ_API_KEY_HERE';
  static const String _model = 'llama-3.3-70b-versatile';
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  /// Sends a conversation to the AI and returns the assistant's reply.
  /// [messages] is a list of {role, content} maps.
  Future<String> sendMessage(List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        throw Exception('AI service error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }
}
