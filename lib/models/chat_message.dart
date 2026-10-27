enum MessageSender { user, jarvis, mickey }

enum MessageStatus { sending, sent, error }

class ActionData {
  final String action; // 'google_search', 'youtube_search', 'open_app', 'make_call', 'send_sms', 'open_whatsapp'
  final String? query;
  final String? app;
  final String? phoneNumber;
  final String? message;
  final bool isExecuted;
  final bool? isSuccess;
  final String? executionMessage;

  const ActionData({
    required this.action,
    this.query,
    this.app,
    this.phoneNumber,
    this.message,
    this.isExecuted = false,
    this.isSuccess,
    this.executionMessage,
  });

  ActionData copyWith({
    String? action,
    String? query,
    String? app,
    String? phoneNumber,
    String? message,
    bool? isExecuted,
    bool? isSuccess,
    String? executionMessage,
  }) {
    return ActionData(
      action: action ?? this.action,
      query: query ?? this.query,
      app: app ?? this.app,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      message: message ?? this.message,
      isExecuted: isExecuted ?? this.isExecuted,
      isSuccess: isSuccess ?? this.isSuccess,
      executionMessage: executionMessage ?? this.executionMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'query': query,
      'app': app,
      'phoneNumber': phoneNumber,
      'message': message,
      'isExecuted': isExecuted,
      'isSuccess': isSuccess,
      'executionMessage': executionMessage,
    };
  }

  factory ActionData.fromJson(Map<String, dynamic> json) {
    return ActionData(
      action: json['action'] as String? ?? '',
      query: json['query'] as String?,
      app: json['app'] as String?,
      phoneNumber: (json['phoneNumber'] ?? json['number']) as String?,
      message: (json['message'] ?? json['text'] ?? json['sms_body']) as String?,
      isExecuted: json['isExecuted'] as bool? ?? false,
      isSuccess: json['isSuccess'] as bool?,
      executionMessage: json['executionMessage'] as String?,
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isVoice;
  final ActionData? actionData;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isVoice = false,
    this.actionData,
  });

  bool get isUser => sender == MessageSender.user;
  bool get isJarvis => sender == MessageSender.jarvis || sender == MessageSender.mickey;
  bool get isMickey => isJarvis;
  bool get hasAction => actionData != null;

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isVoice,
    ActionData? actionData,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isVoice: isVoice ?? this.isVoice,
      actionData: actionData ?? this.actionData,
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
      'actionData': actionData?.toJson(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    MessageSender parseSender(String? name) {
      if (name == 'mickey') return MessageSender.mickey;
      if (name == 'user') return MessageSender.user;
      return MessageSender.jarvis;
    }

    MessageStatus parseStatus(String? name) {
      if (name == 'sending') return MessageStatus.sending;
      if (name == 'error') return MessageStatus.error;
      return MessageStatus.sent;
    }

    return ChatMessage(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      sender: parseSender(json['sender'] as String?),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: parseStatus(json['status'] as String?),
      isVoice: json['isVoice'] as bool? ?? false,
      actionData: json['actionData'] != null
          ? ActionData.fromJson(json['actionData'] as Map<String, dynamic>)
          : null,
    );
  }
}
