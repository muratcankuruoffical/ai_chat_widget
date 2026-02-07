enum MessageDirection { incoming, outgoing }

class ChatMessage {
  final int? id;
  final String message;
  final MessageDirection direction;
  final DateTime timestamp;

  const ChatMessage({
    this.id,
    required this.message,
    required this.direction,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int?,
      message: json['message'] as String,
      direction: json['direction'] == 'outgoing'
          ? MessageDirection.outgoing
          : MessageDirection.incoming,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'direction': direction == MessageDirection.outgoing ? 'outgoing' : 'incoming',
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// User messages are incoming (from widget perspective, sent TO backend)
  bool get isUser => direction == MessageDirection.incoming;

  /// Agent messages are outgoing (from backend, sent TO widget)
  bool get isAgent => direction == MessageDirection.outgoing;
}
