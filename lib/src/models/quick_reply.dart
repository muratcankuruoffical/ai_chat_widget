class QuickReply {
  final String text;
  final String? icon;

  const QuickReply({
    required this.text,
    this.icon,
  });

  factory QuickReply.fromJson(Map<String, dynamic> json) {
    return QuickReply(
      text: json['text'] as String,
      icon: json['icon'] as String?,
    );
  }
}
