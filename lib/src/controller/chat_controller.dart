import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_config.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';
import '../services/websocket_service.dart';

class AIChatController extends ChangeNotifier {
  // Singleton
  static AIChatController? _instance;
  static AIChatController get instance {
    _instance ??= AIChatController._();
    return _instance!;
  }

  AIChatController._();

  // State
  AIChatConfig? _config;
  final List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _isOpen = false;
  bool _isTyping = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String _selectedLanguage = 'en';
  bool _quickRepliesVisible = true;
  final Set<int> _displayedMessageIds = {};

  // Services
  ChatApiService? _apiService;
  WebSocketService? _wsService;
  Timer? _pollTimer;
  Timer? _autoOpenTimer;

  // Getters
  AIChatConfig? get config => _config;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get sessionId => _sessionId;
  bool get isOpen => _isOpen;
  bool get isTyping => _isTyping;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get selectedLanguage => _selectedLanguage;
  bool get quickRepliesVisible => _quickRepliesVisible;
  int get unreadCount => _messages.where((m) => m.isAgent).length;

  /// Initialize the chat controller with widget configuration
  Future<void> initialize(AIChatConfig config) async {
    if (_isInitialized && _config?.widgetId == config.widgetId) return;

    _isLoading = true;
    notifyListeners();

    _config = config;
    _apiService = ChatApiService(
      apiUrl: config.apiUrl,
      widgetId: config.widgetId,
    );

    // Restore session from SharedPreferences
    await _restoreSession();

    // Fetch remote config
    try {
      final remoteConfig = await _apiService!.fetchConfig();
      _config = config.copyWithRemote(remoteConfig);
      _selectedLanguage = _config!.defaultLanguage;
    } catch (e) {
      debugPrint('AIChatWidget: Failed to fetch config: $e');
    }

    // Connect WebSocket
    await _connectWebSocket();

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();

    // Auto open if configured
    if (_config!.autoOpen) {
      _autoOpenTimer = Timer(
        Duration(seconds: _config!.autoOpenDelay),
        () {
          if (!_isOpen) openChat();
        },
      );
    }
  }

  /// Open the chat window
  void openChat() {
    if (_isOpen) return;
    _isOpen = true;

    // Show welcome message if no messages yet
    if (_messages.isEmpty && _config != null) {
      _messages.add(ChatMessage(
        message: _config!.welcomeMessage,
        direction: MessageDirection.outgoing,
        timestamp: DateTime.now(),
      ));
      _saveMessages();
    }

    // Start polling if WebSocket is not connected
    if (_wsService == null || !_wsService!.isConnected) {
      _startPolling();
    }

    notifyListeners();
  }

  /// Close the chat window
  void closeChat() {
    if (!_isOpen) return;
    _isOpen = false;
    _stopPolling();
    notifyListeners();
  }

  /// Toggle the chat window
  void toggleChat() {
    if (_isOpen) {
      closeChat();
    } else {
      openChat();
    }
  }

  /// Send a message
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _apiService == null || _sessionId == null) return;

    // Add user message to UI immediately
    _messages.add(ChatMessage(
      message: trimmed,
      direction: MessageDirection.incoming,
      timestamp: DateTime.now(),
    ));
    _isTyping = true;
    _quickRepliesVisible = false;
    notifyListeners();
    _saveMessages();

    try {
      await _apiService!.sendMessage(
        sessionId: _sessionId!,
        message: trimmed,
        language: _selectedLanguage,
      );
    } catch (e) {
      debugPrint('AIChatWidget: Failed to send message: $e');
      _isTyping = false;
      notifyListeners();
    }
  }

  /// Start a new chat session
  void startNewSession() {
    _messages.clear();
    _displayedMessageIds.clear();
    _sessionId = _generateSessionId();
    _isTyping = false;
    _quickRepliesVisible = true;
    _saveSession();
    _saveMessages();

    // Re-subscribe WebSocket to new session
    if (_wsService != null && _wsService!.isConnected && _config != null) {
      _wsService!.subscribe(_config!.widgetId, _sessionId!);
    }

    // Show welcome message
    if (_config != null) {
      _messages.add(ChatMessage(
        message: _config!.welcomeMessage,
        direction: MessageDirection.outgoing,
        timestamp: DateTime.now(),
      ));
      _saveMessages();
    }

    notifyListeners();
  }

  /// Change the chat language
  void setLanguage(String languageCode) {
    _selectedLanguage = languageCode;
    notifyListeners();
  }

  // -- Private methods --

  Future<void> _connectWebSocket() async {
    if (_config == null ||
        _config!.websocketKey == null ||
        _config!.websocketHost == null) {
      return;
    }

    _wsService = WebSocketService(
      onMessage: _handleWebSocketMessage,
      onConnected: () {
        debugPrint('AIChatWidget: WebSocket connected');
        _stopPolling();
      },
      onDisconnected: () {
        debugPrint('AIChatWidget: WebSocket disconnected');
        if (_isOpen) _startPolling();
      },
      onError: (error) {
        debugPrint('AIChatWidget: WebSocket error: $error');
        if (_isOpen) _startPolling();
      },
    );

    final connected = await _wsService!.connect(
      host: _config!.websocketHost!,
      port: _config!.websocketPort,
      appKey: _config!.websocketKey!,
      scheme: _config!.websocketScheme,
    );

    if (connected && _sessionId != null) {
      _wsService!.subscribe(_config!.widgetId, _sessionId!);
    } else if (_isOpen) {
      _startPolling();
    }
  }

  void _handleWebSocketMessage(ChatMessage message) {
    // Avoid duplicate messages
    if (message.id != null && _displayedMessageIds.contains(message.id)) {
      return;
    }

    if (message.id != null) {
      _displayedMessageIds.add(message.id!);
    }

    _messages.add(message);
    _isTyping = false;
    notifyListeners();
    _saveMessages();
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (_apiService == null || _sessionId == null) return;

    try {
      final newMessages = await _apiService!.pollMessages(_sessionId!);
      for (final message in newMessages) {
        if (message.id != null && _displayedMessageIds.contains(message.id)) {
          continue;
        }
        if (message.id != null) {
          _displayedMessageIds.add(message.id!);
        }
        _messages.add(message);
        _isTyping = false;
      }
      if (newMessages.isNotEmpty) {
        notifyListeners();
        _saveMessages();
      }
    } catch (e) {
      debugPrint('AIChatWidget: Polling error: $e');
    }
  }

  // -- Session persistence --

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final widgetId = _config!.widgetId;

    _sessionId = prefs.getString('cw_session_$widgetId');
    if (_sessionId == null) {
      _sessionId = _generateSessionId();
      await _saveSession();
    }

    // Restore messages
    final messagesJson = prefs.getString('cw_messages_$widgetId');
    if (messagesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(messagesJson);
        _messages.clear();
        for (final item in decoded) {
          final msg = ChatMessage.fromJson(item as Map<String, dynamic>);
          _messages.add(msg);
          if (msg.id != null) {
            _displayedMessageIds.add(msg.id!);
          }
        }
      } catch (e) {
        debugPrint('AIChatWidget: Failed to restore messages: $e');
      }
    }

    // Restore language
    final savedLang = prefs.getString('cw_language_$widgetId');
    if (savedLang != null) {
      _selectedLanguage = savedLang;
    }
  }

  Future<void> _saveSession() async {
    if (_sessionId == null || _config == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cw_session_${_config!.widgetId}', _sessionId!);
  }

  Future<void> _saveMessages() async {
    if (_config == null) return;
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString('cw_messages_${_config!.widgetId}', json);
  }

  String _generateSessionId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final id = List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
    return 'sess_${id}_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _autoOpenTimer?.cancel();
    _stopPolling();
    _wsService?.disconnect();
    _instance = null;
    super.dispose();
  }
}
