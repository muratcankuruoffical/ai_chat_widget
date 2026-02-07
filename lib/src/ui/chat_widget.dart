import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../controller/chat_controller.dart';
import '../models/chat_config.dart';
import 'chat_window.dart';
import 'default_launcher.dart';

/// Main widget that combines the launcher button and chat window.
///
/// Usage:
/// ```dart
/// // Simple - with default floating button
/// AIChatWidget(
///   config: AIChatConfig(widgetId: 'widget_xxx'),
/// )
///
/// // With custom launcher
/// AIChatWidget(
///   config: AIChatConfig(
///     widgetId: 'widget_xxx',
///     customLauncher: (context, onTap) => FloatingActionButton(
///       onPressed: onTap,
///       child: Icon(Icons.chat),
///     ),
///   ),
/// )
/// ```
class AIChatWidget extends StatefulWidget {
  final AIChatConfig config;

  const AIChatWidget({
    super.key,
    required this.config,
  });

  /// Shorthand constructor with widgetId and apiUrl
  AIChatWidget.simple({
    super.key,
    required String widgetId,
    String apiUrl = 'https://replyit.ai',
    String? origin,
  }) : config = AIChatConfig(widgetId: widgetId, apiUrl: apiUrl, origin: origin);

  @override
  State<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends State<AIChatWidget> {
  AIChatController get _controller => AIChatController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChange);
    _controller.initialize(widget.config);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRight = widget.config.position != 'bottom-left';

    return SizedBox.expand(
      child: Stack(
        children: [
          // Chat window
          Positioned(
            bottom: 76,
            left: isRight ? null : 20,
            right: isRight ? 20 : null,
            width: MediaQuery.of(context).size.width > 400
                ? 370
                : MediaQuery.of(context).size.width - 40,
            child: AIChatWindow(
              config: widget.config,
              isVisible: _controller.isOpen,
              onClose: () => _controller.closeChat(),
            ),
          ),

          // Launcher button
          Positioned(
            bottom: 20,
            left: isRight ? null : 20,
            right: isRight ? 20 : null,
            child: widget.config.customLauncher != null
                ? widget.config.customLauncher!(
                    context,
                    () => _controller.toggleChat(),
                  )
                : DefaultChatLauncher(
                    onTap: () => _controller.toggleChat(),
                    backgroundColor: widget.config.primaryColor,
                    isOpen: _controller.isOpen,
                  ),
          ),
        ],
      ),
    );
  }
}
