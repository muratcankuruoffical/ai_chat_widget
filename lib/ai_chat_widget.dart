/// AI Chat Widget - A Flutter package for AI-powered customer support chat.
///
/// Connects to ReplyIt.ai backend with HTTP polling support.
///
/// Basic usage:
/// ```dart
/// AIChatWidget(
///   config: AIChatConfig(widgetId: 'widget_xxxxx'),
/// )
/// ```
library ai_chat_widget;

// Models
export 'src/models/chat_config.dart';
export 'src/models/chat_message.dart';
export 'src/models/quick_reply.dart';

// Controller
export 'src/controller/chat_controller.dart';

// UI Widgets
export 'src/ui/chat_view.dart';
export 'src/ui/chat_widget.dart';
export 'src/ui/chat_window.dart';
export 'src/ui/default_launcher.dart';
export 'src/ui/chat_message_bubble.dart';
export 'src/ui/typing_indicator.dart';
