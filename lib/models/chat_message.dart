enum MessageSender { user, jarvis }

enum MessageStatus { sending, sent, error }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isVoice;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isVoice = false,
  });

  bool get isUser => sender == MessageSender.user;
  bool get isJarvis => sender == MessageSender.jarvis;

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isVoice,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isVoice: isVoice ?? this.isVoice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'isVoice': isVoice,
    };
  }
}
