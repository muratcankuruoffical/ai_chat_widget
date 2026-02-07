import 'package:flutter/material.dart';

import '../controller/chat_controller.dart';
import '../models/chat_config.dart';
import 'chat_message_bubble.dart';
import 'typing_indicator.dart';

class AIChatWindow extends StatefulWidget {
  final AIChatConfig config;
  final bool isVisible;
  final VoidCallback? onClose;

  const AIChatWindow({
    super.key,
    required this.config,
    this.isVisible = true,
    this.onClose,
  });

  /// Create a chat window without a launcher (manual control)
  const AIChatWindow.withoutLauncher({
    super.key,
    required this.config,
    required this.isVisible,
    required this.onClose,
  });

  @override
  State<AIChatWindow> createState() => _AIChatWindowState();
}

class _AIChatWindowState extends State<AIChatWindow>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  AIChatController get _chatController => AIChatController.instance;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _chatController.addListener(_onControllerChange);
    _chatController.initialize(widget.config);

    if (widget.isVisible) _animController.forward();
  }

  @override
  void didUpdateWidget(AIChatWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _animController.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _animController.reverse();
    }
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
    _animController.dispose();
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
    if (!widget.isVisible && !_animController.isAnimating) {
      return const SizedBox.shrink();
    }

    final config = _chatController.config ?? widget.config;
    final screenHeight = MediaQuery.of(context).size.height;
    final windowHeight = screenHeight * 0.7;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          height: windowHeight.clamp(400, 600).toDouble(),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                _buildHeader(config),
                Expanded(child: _buildMessageList(config)),
                if (_chatController.quickRepliesVisible &&
                    config.quickReplies.isNotEmpty)
                  _buildQuickReplies(config),
                _buildInputArea(config),
              ],
            ),
          ),
        ),
      ),
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
            child: config.botAvatarType == 'upload' && config.botAvatarUrl != null
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
          IconButton(
            onPressed: () => _chatController.startNewSession(),
            icon: Icon(Icons.refresh, color: config.headerTextColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Close button
          IconButton(
            onPressed: () {
              _chatController.closeChat();
              widget.onClose?.call();
            },
            icon: Icon(Icons.close, color: config.headerTextColor, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
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
            return TypingIndicator(dotColor: config.primaryColor);
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
          return InkWell(
            onTap: () => _handleQuickReply(reply.text),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: config.quickReplyBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: config.quickReplyBorderColor),
              ),
              child: Text(
                reply.icon != null ? '${reply.icon} ${reply.text}' : reply.text,
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
                  style: TextStyle(color: config.inputTextColor, fontSize: 14),
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
