import 'package:flutter/material.dart';

import '../models/chat_config.dart';
import '../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final AIChatConfig config;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 12,
        right: isUser ? 12 : 48,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? config.userMessageBgColor
                    : config.agentMessageBgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message.message,
                style: TextStyle(
                  color: isUser
                      ? config.userMessageTextColor
                      : config.agentMessageTextColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (config.botAvatarType == 'upload' && config.botAvatarUrl != null) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(config.botAvatarUrl!),
        backgroundColor: config.avatarBgColor,
      );
    }

    if (config.companyLogo != null) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(config.companyLogo!),
        backgroundColor: config.avatarBgColor,
      );
    }

    return CircleAvatar(
      radius: 14,
      backgroundColor: config.avatarBgColor,
      child: Icon(
        Icons.smart_toy_outlined,
        size: 16,
        color: config.primaryColor,
      ),
    );
  }
}
