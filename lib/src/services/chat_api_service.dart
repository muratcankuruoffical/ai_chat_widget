import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class ChatApiService {
  final String apiUrl;
  final String widgetId;
  final String? origin;

  ChatApiService({
    required this.apiUrl,
    required this.widgetId,
    this.origin,
  });

  String get _baseUrl => '$apiUrl/api/widgets/$widgetId';

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (origin != null) 'Origin': origin!,
        if (origin != null) 'Referer': origin!,
      };

  /// Fetch widget configuration from backend
  Future<Map<String, dynamic>> fetchConfig() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/config'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Backend returns config inside 'config' key
      if (data is Map<String, dynamic> && data.containsKey('config')) {
        return data['config'] as Map<String, dynamic>;
      }
      return data as Map<String, dynamic>;
    }

    throw Exception('Failed to load widget config: ${response.statusCode}');
  }

  /// Send a user message to the chat widget
  Future<Map<String, dynamic>> sendMessage({
    required String sessionId,
    required String message,
    String language = 'en',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: {
        ..._headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': message,
        'session_id': sessionId,
        'language': language,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to send message: ${response.statusCode}');
  }

  /// Poll for new messages (fallback when WebSocket is unavailable)
  Future<List<ChatMessage>> pollMessages(String sessionId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/poll/$sessionId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // API returns { result: { messages: [...] } } or { messages: [...] }
      final result = data['result'] as Map<String, dynamic>?;
      final messages = (result?['messages'] ?? data['messages']) as List? ?? [];
      return messages
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    return [];
  }
}
