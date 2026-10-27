import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _androidChatApiBaseUrl = 'http://192.168.29.172:5000';
const String _loopbackChatApiBaseUrl = 'http://127.0.0.1:5000';

String get defaultChatApiBaseUrl {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return _androidChatApiBaseUrl;
  }
  return _loopbackChatApiBaseUrl;
}

class ChatApiService {
  ChatApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultChatApiBaseUrl;

  final http.Client _client;
  final String baseUrl;

  Future<ChatApiReply> sendMessage({
    required List<Map<String, String>> messages,
    Map<String, dynamic>? pendingWord,
  }) async {
    final uri = Uri.parse(baseUrl).resolve('/chat');

    try {
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': messages,
              'pending_word': pendingWord,
            }),
          )
          .timeout(const Duration(minutes: 3));

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ChatApiException(
          'The server returned an unexpected response. Please try again.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded['error'];
        throw ChatApiException(
          message is String && message.isNotEmpty
              ? message
              : 'The server returned an error (${response.statusCode}).',
        );
      }

      final reply = decoded['reply'];
      if (reply is! String) {
        throw const ChatApiException(
          'The server response did not include a chat reply.',
        );
      }

      final pending = decoded['pending_word'];
      return ChatApiReply(
        reply: reply,
        pendingWord: pending is Map<String, dynamic> ? pending : null,
      );
    } on TimeoutException {
      throw const ChatApiException(
        'ChhanaAI took too long to respond. Check that Flask and Ollama are '
        'running, then try again.',
      );
    } on http.ClientException {
      throw ChatApiException(
        'Could not reach the Flask server at $baseUrl. Make sure '
        'it is running. In Chrome, this can also happen if Flask blocks the '
        'Flutter web app because CORS is not enabled.',
      );
    } on FormatException {
      throw const ChatApiException(
        'The Flask server returned invalid JSON. Please check the backend '
        'logs and try again.',
      );
    }
  }

  void close() => _client.close();
}

class ChatApiReply {
  const ChatApiReply({required this.reply, required this.pendingWord});

  final String reply;
  final Map<String, dynamic>? pendingWord;
}

class ChatApiException implements Exception {
  const ChatApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
