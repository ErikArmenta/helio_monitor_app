import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class AiChatProvider extends ChangeNotifier {
  final AiService _aiService = AiService();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  bool _connected = false;
  String _streamBuffer = '';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get connected => _connected;
  AiService get service => _aiService;

  Future<void> testConnection() async {
    _connected = await _aiService.testConnection();
    notifyListeners();
  }

  void configure({String? baseUrl, String? model}) {
    _aiService.configure(baseUrl: baseUrl, model: model);
    testConnection();
  }

  Future<void> sendMessage(String text, {String? dataSnapshot}) async {
    _messages.add(ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    ));
    _loading = true;
    _streamBuffer = '';
    notifyListeners();

    final history = _messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .take(6)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    try {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
      ));

      await for (final token in _aiService.chatStream(
        text,
        dataSnapshot: dataSnapshot,
        history: history,
      )) {
        _streamBuffer += token;
        _messages[_messages.length - 1] = ChatMessage(
          role: 'assistant',
          content: _streamBuffer,
          timestamp: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      if (_streamBuffer.isEmpty) {
        _messages[_messages.length - 1] = ChatMessage(
          role: 'assistant',
          content: 'Error de conexion: $e',
          timestamp: DateTime.now(),
        );
      }
    }

    _loading = false;
    _streamBuffer = '';
    notifyListeners();
  }

  void clearHistory() {
    _messages.clear();
    notifyListeners();
  }
}
