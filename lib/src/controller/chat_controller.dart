import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_config.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';

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

  bool _isInitializing = false;

  /// Initialize the chat controller with widget configuration
  Future<void> initialize(AIChatConfig config) async {
    if (_isInitializing) return;

    // If already initialized with same widget, just refresh config in background
    if (_isInitialized && _config?.widgetId == config.widgetId) {
      _refreshConfigInBackground(config);
      return;
    }

    _isInitializing = true;
    _isLoading = true;
    _safeNotifyListeners();

    _config = config;
    _apiService = ChatApiService(
      apiUrl: config.apiUrl,
      widgetId: config.widgetId,
      origin: config.origin,
    );

    // Restore session from SharedPreferences
    await _restoreSession();

    // Fetch remote config
    await _fetchAndApplyConfig(config);

    _isInitialized = true;
    _isLoading = false;
    _isInitializing = false;
    _safeNotifyListeners();

    // Start polling if chat is already open
    if (_isOpen) {
      _startPolling();
    }

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

  Future<void> _fetchAndApplyConfig(AIChatConfig baseConfig) async {
    try {
      final remoteConfig = await _apiService!.fetchConfig();
      debugPrint('AIChatWidget: Config fetched successfully');
      _config = baseConfig.copyWithRemote(remoteConfig);
      _selectedLanguage = _config!.defaultLanguage;
      _updateWelcomeMessage();
    } catch (e) {
      debugPrint('AIChatWidget: Failed to fetch config: $e');
    }
  }

  Future<void> _refreshConfigInBackground(AIChatConfig baseConfig) async {
    // Re-fetch config without blocking
    try {
      final remoteConfig = await ChatApiService(
        apiUrl: baseConfig.apiUrl,
        widgetId: baseConfig.widgetId,
        origin: baseConfig.origin,
      ).fetchConfig();
      debugPrint('AIChatWidget: Config refreshed successfully');
      _config = baseConfig.copyWithRemote(remoteConfig);
      _selectedLanguage = _config!.defaultLanguage;
      _updateWelcomeMessage();
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('AIChatWidget: Failed to refresh config: $e');
    }
  }

  /// Force re-fetch config from backend
  Future<void> refreshConfig() async {
    if (_apiService == null || _config == null) return;

    try {
      final remoteConfig = await _apiService!.fetchConfig();
      final baseConfig = AIChatConfig(
        widgetId: _config!.widgetId,
        apiUrl: _config!.apiUrl,
        origin: _config!.origin,
        customLauncher: _config!.customLauncher,
      );
      _config = baseConfig.copyWithRemote(remoteConfig);
      _selectedLanguage = _config!.defaultLanguage;
      _updateWelcomeMessage();
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('AIChatWidget: Failed to refresh config: $e');
    }
  }

  /// Update the welcome message if the first message is old default
  void _updateWelcomeMessage() {
    if (_messages.isNotEmpty && _messages.first.isAgent && _config != null) {
      final firstMsg = _messages.first;
      // If the first message is a welcome message (no id = locally generated)
      if (firstMsg.id == null && firstMsg.message != _config!.welcomeMessage) {
        _messages[0] = ChatMessage(
          message: _config!.welcomeMessage,
          direction: MessageDirection.outgoing,
          timestamp: firstMsg.timestamp,
        );
        _saveMessages();
      }
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

    _startPolling();

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
      final response = await _apiService!.sendMessage(
        sessionId: _sessionId!,
        message: trimmed,
        language: _selectedLanguage,
      );
      debugPrint('AIChatWidget: Message sent successfully, response: $response');

      // Check if the POST response itself contains an AI reply
      final responseMessage = _extractResponseMessage(response);
      if (responseMessage != null) {
        debugPrint('AIChatWidget: Got direct response from POST');
        _isTyping = false;
        _messages.add(responseMessage);
        notifyListeners();
        _saveMessages();
        return;
      }

      // Ensure polling is running to catch the response
      _startPolling();

      // Do an immediate poll right after sending
      await Future.delayed(const Duration(milliseconds: 500));
      await _poll();
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

  /// Safely notify listeners, deferring if called during build phase
  void _safeNotifyListeners() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  // -- Private methods --

  /// Try to extract an AI response message from the POST /chat response
  ChatMessage? _extractResponseMessage(Map<String, dynamic> response) {
    try {
      // Check common response formats:
      // { "result": { "reply": "...", "message": "..." } }
      // { "reply": "..." }
      // { "response": "..." }
      final result = response['result'];
      if (result is Map<String, dynamic>) {
        final reply = result['reply'] ?? result['response'];
        if (reply is String && reply.isNotEmpty) {
          return ChatMessage(
            id: result['id'] as int?,
            message: reply,
            direction: MessageDirection.outgoing,
            timestamp: DateTime.now(),
          );
        }
      }

      final directReply = response['reply'] ?? response['response'];
      if (directReply is String && directReply.isNotEmpty) {
        return ChatMessage(
          message: directReply,
          direction: MessageDirection.outgoing,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('AIChatWidget: Error extracting response message: $e');
    }
    return null;
  }

  void _startPolling() {
    // Cancel existing timer and restart to ensure fresh polling
    _pollTimer?.cancel();
    _pollTimer = null;
    debugPrint('AIChatWidget: Polling started (sessionId: $_sessionId)');
    // Do an immediate poll, then periodic
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  void _stopPolling() {
    if (_pollTimer != null) {
      debugPrint('AIChatWidget: Polling stopped');
    }
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (_apiService == null || _sessionId == null) {
      debugPrint('AIChatWidget: Poll skipped - apiService: ${_apiService != null}, sessionId: $_sessionId');
      return;
    }

    try {
      final newMessages = await _apiService!.pollMessages(_sessionId!);
      debugPrint('AIChatWidget: Poll returned ${newMessages.length} messages');
      var hasNew = false;
      for (final message in newMessages) {
        if (message.id != null && _displayedMessageIds.contains(message.id)) {
          continue;
        }
        // Skip user messages from polling - they are already added locally
        if (message.isUser) {
          if (message.id != null) _displayedMessageIds.add(message.id!);
          continue;
        }
        debugPrint('AIChatWidget: New agent message from poll: ${message.message.substring(0, message.message.length.clamp(0, 50))}');
        if (message.id != null) {
          _displayedMessageIds.add(message.id!);
        }
        _messages.add(message);
        _isTyping = false;
        hasNew = true;
      }
      if (hasNew) {
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
    _instance = null;
    super.dispose();
  }
}
