import 'package:flutter/material.dart';

import '../controller/chat_controller.dart';
import '../models/chat_config.dart';
import 'chat_message_bubble.dart';
import 'typing_indicator.dart';

/// An embeddable chat view that can be placed directly in the widget tree.
///
/// Unlike [AIChatWidget] which shows a floating overlay with a launcher button,
/// [AIChatView] is designed to be embedded as part of the page content.
///
/// Example usage:
/// ```dart
/// // Full page chat
/// Scaffold(
///   body: AIChatView(
///     config: AIChatConfig(widgetId: 'widget_xxx'),
///   ),
/// )
///
/// // As part of a layout
/// Column(
///   children: [
///     SomeHeader(),
///     Expanded(
///       child: AIChatView(
///         config: AIChatConfig(widgetId: 'widget_xxx'),
///         showHeader: false,
///       ),
///     ),
///   ],
/// )
/// ```
class AIChatView extends StatefulWidget {
  final AIChatConfig config;

  /// Whether to show the chat header. Defaults to true.
  final bool showHeader;

  /// Whether to show the close button in the header. Defaults to false.
  final bool showCloseButton;

  /// Callback when the close button is tapped.
  final VoidCallback? onClose;

  const AIChatView({
    super.key,
    required this.config,
    this.showHeader = true,
    this.showCloseButton = false,
    this.onClose,
  });

  @override
  State<AIChatView> createState() => _AIChatViewState();
}

class _AIChatViewState extends State<AIChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  AIChatController get _chatController => AIChatController.instance;

  @override
  void initState() {
    super.initState();
    _chatController.addListener(_onControllerChange);
    _initializeAndOpen();
  }

  Future<void> _initializeAndOpen() async {
    await _chatController.initialize(widget.config);
    _chatController.openChat();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatController.removeListener(_onControllerChange);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _chatController.sendMessage(text);
    _textController.clear();
  }

  void _handleQuickReply(String text) {
    _chatController.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final config = _chatController.config ?? widget.config;

    return Column(
      children: [
        if (widget.showHeader) _buildHeader(config),
        Expanded(child: _buildMessageList(config)),
        if (_chatController.quickRepliesVisible &&
            config.quickReplies.isNotEmpty)
          _buildQuickReplies(config),
        _buildInputArea(config),
      ],
    );
  }

  Widget _buildHeader(AIChatConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: config.headerColor,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: config.avatarBgColor,
            child: config.botAvatarType == 'upload' &&
                    config.botAvatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      config.botAvatarUrl!,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: config.headerTextColor,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              config.headerText,
              style: TextStyle(
                color: config.headerTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // New session button
          GestureDetector(
            onTap: () => _chatController.startNewSession(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.refresh,
                  color: config.headerTextColor, size: 20),
            ),
          ),
          if (widget.showCloseButton) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                _chatController.closeChat();
                widget.onClose?.call();
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    color: config.headerTextColor, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageList(AIChatConfig config) {
    final messages = _chatController.messages;

    return Container(
      color: const Color(0xFFF3F4F6),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: messages.length + (_chatController.isTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return Align(
              alignment: Alignment.centerLeft,
              child: TypingIndicator(dotColor: config.primaryColor),
            );
          }
          return ChatMessageBubble(
            message: messages[index],
            config: config,
          );
        },
      ),
    );
  }

  Widget _buildQuickReplies(AIChatConfig config) {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: config.quickReplies.map((reply) {
          return GestureDetector(
            onTap: () => _handleQuickReply(reply.text),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: config.quickReplyBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: config.quickReplyBorderColor),
              ),
              child: Text(
                reply.icon != null
                    ? '${reply.icon} ${reply.text}'
                    : reply.text,
                style: TextStyle(
                  color: config.quickReplyTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputArea(AIChatConfig config) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: config.footerBgColor,
        border: Border(
          top: BorderSide(color: config.inputBorderColor.withOpacity(0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: config.inputBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: config.inputBorderColor),
                ),
                child: TextField(
                  controller: _textController,
                  style:
                      TextStyle(color: config.inputTextColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: config.placeholderText,
                    hintStyle: TextStyle(
                      color: config.inputTextColor.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: config.sendBtnBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: config.sendBtnTextColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
