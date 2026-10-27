import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class AiService {
  // Singleton pattern for centralized access
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  /// Default backend URL:
  /// For Android physical device with USB: run `adb reverse tcp:3000 tcp:3000`, then http://127.0.0.1:3000 works.
  /// Alternatively, provide your PC's local Wi-Fi IP address (e.g., http://192.168.1.10:3000).
  String _baseUrl = 'http://127.0.0.1:3000';

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _baseUrl = cleanUrl;
  }

  /// Sends the user message and recent conversational history to the backend API.
  Future<String> sendMessage({
    required String message,
    List<ChatMessage> history = const [],
  }) async {
    final uri = Uri.parse('$_baseUrl/api/chat');

    // Build compact history for the backend (last 6 messages)
    final formattedHistory = history
        .where((m) => m.status == MessageStatus.sent)
        .take(6)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'history': formattedHistory,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] as String? ?? 'All systems operational, Sir.';
      } else if (response.statusCode == 503) {
        final data = jsonDecode(response.body);
        return data['reply'] as String? ??
            'Sir, the Gemini API key is missing in backend/.env.';
      } else {
        final data = jsonDecode(response.body);
        final err = data['error'] ?? data['reply'] ?? 'Unknown error';
        throw Exception('Server returned ${response.statusCode}: $err');
      }
    } on SocketException catch (_) {
      throw Exception(
        'Cannot reach JARVIS backend at $_baseUrl.\n'
        '1. Ensure backend is running: `npm start` in /backend\n'
        '2. For physical phone via USB, run: `adb reverse tcp:3000 tcp:3000`\n'
        '3. Or update Server URL in Settings to your PC\'s Wi-Fi IP (e.g. http://192.168.x.x:3000).',
      );
    } on TimeoutException catch (_) {
      throw Exception('Request to JARVIS Core timed out. Please check network link.');
    } catch (e) {
      throw Exception('Neural link error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// Checks the connectivity and status of the backend server.
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'statusCode': response.statusCode};
    } catch (e) {
      return {'status': 'unreachable', 'error': e.toString()};
    }
  }
}
