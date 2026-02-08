import 'package:flutter/widgets.dart';

import 'quick_reply.dart';

class AIChatConfig {
  /// Required: Your widget ID from the dashboard
  final String widgetId;

  /// API base URL (default: https://replyit.ai)
  final String apiUrl;

  // -- Colors --
  final Color primaryColor;
  final Color headerColor;
  final Color headerTextColor;
  final Color avatarBgColor;
  final Color footerBgColor;
  final Color inputBgColor;
  final Color inputTextColor;
  final Color inputBorderColor;
  final Color sendBtnBgColor;
  final Color sendBtnTextColor;
  final Color agentMessageBgColor;
  final Color agentMessageTextColor;
  final Color userMessageBgColor;
  final Color userMessageTextColor;
  final Color quickReplyBgColor;
  final Color quickReplyTextColor;
  final Color quickReplyBorderColor;

  // -- Texts --
  final String headerText;
  final String welcomeMessage;
  final String placeholderText;

  // -- Avatar --
  final String botAvatarType;
  final String? botAvatarUrl;
  final String? companyLogo;

  // -- Quick Replies --
  final List<QuickReply> quickReplies;

  // -- Behavior --
  final bool enableSound;
  final bool autoOpen;
  final int autoOpenDelay;
  final String position;

  // -- Language --
  final String defaultLanguage;
  final List<String> supportedLanguages;
  final bool enableLanguageSelector;

  // -- WebSocket --
  final String? websocketKey;
  final String? websocketHost;
  final int websocketPort;
  final String websocketScheme;

  // -- Custom launcher --
  final Widget Function(BuildContext context, VoidCallback onTap)? customLauncher;

  // -- Origin (for mobile apps that need to pass allowed domain) --
  final String? origin;

  const AIChatConfig({
    required this.widgetId,
    this.apiUrl = 'https://replyit.ai',
    this.primaryColor = const Color(0xFF6366F1),
    this.headerColor = const Color(0xFF6366F1),
    this.headerTextColor = const Color(0xFFFFFFFF),
    this.avatarBgColor = const Color(0x33FFFFFF),
    this.footerBgColor = const Color(0xFFFFFFFF),
    this.inputBgColor = const Color(0xFFFFFFFF),
    this.inputTextColor = const Color(0xFF1F2937),
    this.inputBorderColor = const Color(0xFFD1D5DB),
    this.sendBtnBgColor = const Color(0xFF6366F1),
    this.sendBtnTextColor = const Color(0xFFFFFFFF),
    this.agentMessageBgColor = const Color(0xFFFFFFFF),
    this.agentMessageTextColor = const Color(0xFF1F2937),
    this.userMessageBgColor = const Color(0xFF6366F1),
    this.userMessageTextColor = const Color(0xFFFFFFFF),
    this.quickReplyBgColor = const Color(0xFFFFFFFF),
    this.quickReplyTextColor = const Color(0xFF6366F1),
    this.quickReplyBorderColor = const Color(0xFF6366F1),
    this.headerText = 'Chat Support',
    this.welcomeMessage = 'Hello! How can I help you?',
    this.placeholderText = 'Type a message...',
    this.botAvatarType = 'default',
    this.botAvatarUrl,
    this.companyLogo,
    this.quickReplies = const [],
    this.enableSound = true,
    this.autoOpen = false,
    this.autoOpenDelay = 5,
    this.position = 'bottom-right',
    this.defaultLanguage = 'en',
    this.supportedLanguages = const ['en'],
    this.enableLanguageSelector = false,
    this.websocketKey,
    this.websocketHost,
    this.websocketPort = 443,
    this.websocketScheme = 'wss',
    this.customLauncher,
    this.origin,
  });

  /// Create config by merging local defaults with backend response
  AIChatConfig copyWithRemote(Map<String, dynamic> json) {
    return AIChatConfig(
      widgetId: widgetId,
      apiUrl: apiUrl,
      customLauncher: customLauncher,
      origin: origin,
      primaryColor: _parseColor(json['primary_color']) ?? primaryColor,
      headerColor: _parseColor(json['header_color']) ?? _parseColor(json['primary_color']) ?? headerColor,
      headerTextColor: _parseColor(json['header_text_color']) ?? headerTextColor,
      avatarBgColor: _parseColor(json['avatar_bg_color']) ?? avatarBgColor,
      footerBgColor: _parseColor(json['footer_bg_color']) ?? footerBgColor,
      inputBgColor: _parseColor(json['input_bg_color']) ?? inputBgColor,
      inputTextColor: _parseColor(json['input_text_color']) ?? inputTextColor,
      inputBorderColor: _parseColor(json['input_border_color']) ?? inputBorderColor,
      sendBtnBgColor: _parseColor(json['send_btn_bg_color']) ?? _parseColor(json['primary_color']) ?? sendBtnBgColor,
      sendBtnTextColor: _parseColor(json['send_btn_text_color']) ?? sendBtnTextColor,
      agentMessageBgColor: _parseColor(json['agent_message_bg_color']) ?? agentMessageBgColor,
      agentMessageTextColor: _parseColor(json['agent_message_text_color']) ?? agentMessageTextColor,
      userMessageBgColor: _parseColor(json['user_message_bg_color']) ?? _parseColor(json['primary_color']) ?? userMessageBgColor,
      userMessageTextColor: _parseColor(json['user_message_text_color']) ?? userMessageTextColor,
      quickReplyBgColor: _parseColor(json['quick_reply_bg_color']) ?? quickReplyBgColor,
      quickReplyTextColor: _parseColor(json['quick_reply_text_color']) ?? _parseColor(json['primary_color']) ?? quickReplyTextColor,
      quickReplyBorderColor: _parseColor(json['quick_reply_border_color']) ?? _parseColor(json['primary_color']) ?? quickReplyBorderColor,
      headerText: json['header_text'] as String? ?? json['company_name'] as String? ?? headerText,
      welcomeMessage: json['welcome_message'] as String? ?? welcomeMessage,
      placeholderText: json['placeholder_text'] as String? ?? placeholderText,
      botAvatarType: json['bot_avatar_type'] as String? ?? botAvatarType,
      botAvatarUrl: json['bot_avatar_url'] as String? ?? botAvatarUrl,
      companyLogo: json['company_logo'] as String? ?? companyLogo,
      quickReplies: json['quick_replies'] != null
          ? (json['quick_replies'] as List).map((e) => QuickReply.fromJson(e as Map<String, dynamic>)).toList()
          : quickReplies,
      enableSound: json['enable_sound'] as bool? ?? enableSound,
      autoOpen: json['auto_open'] as bool? ?? autoOpen,
      autoOpenDelay: _parseInt(json['auto_open_delay']) ?? autoOpenDelay,
      position: json['widget_position'] as String? ?? position,
      defaultLanguage: json['default_language'] as String? ?? defaultLanguage,
      supportedLanguages: json['supported_languages'] != null
          ? List<String>.from(json['supported_languages'] as List)
          : supportedLanguages,
      enableLanguageSelector: json['enable_language_selector'] as bool? ?? enableLanguageSelector,
      websocketKey: json['websocket_key'] as String? ?? websocketKey,
      websocketHost: json['websocket_host'] as String? ?? websocketHost,
      websocketPort: _parseInt(json['websocket_port']) ?? websocketPort,
      websocketScheme: json['websocket_scheme'] as String? ?? websocketScheme,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty) return null;

    // Hex color: #RRGGBB or #RGB
    if (str.startsWith('#')) {
      var hex = str.substring(1);
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      if (hex.length == 6) {
        final intVal = int.tryParse(hex, radix: 16);
        if (intVal != null) return Color(0xFF000000 | intVal);
      }
    }

    // rgba(r, g, b, a)
    final rgbaMatch = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)').firstMatch(str);
    if (rgbaMatch != null) {
      final r = int.parse(rgbaMatch.group(1)!);
      final g = int.parse(rgbaMatch.group(2)!);
      final b = int.parse(rgbaMatch.group(3)!);
      final a = rgbaMatch.group(4) != null ? double.parse(rgbaMatch.group(4)!) : 1.0;
      return Color.fromARGB((a * 255).round(), r, g, b);
    }

    // Named colors
    const namedColors = {
      'white': Color(0xFFFFFFFF),
      'black': Color(0xFF000000),
      'red': Color(0xFFFF0000),
      'green': Color(0xFF00FF00),
      'blue': Color(0xFF0000FF),
    };
    return namedColors[str.toLowerCase()];
  }
}
