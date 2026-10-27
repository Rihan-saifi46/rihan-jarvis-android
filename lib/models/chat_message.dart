enum MessageSender { user, jarvis }

enum MessageStatus { sending, sent, error }

class ActionData {
  final String action; // 'google_search', 'youtube_search', 'open_app'
  final String? query;
  final String? app;
  final bool isExecuted;
  final bool? isSuccess;
  final String? executionMessage;

  const ActionData({
    required this.action,
    this.query,
    this.app,
    this.isExecuted = false,
    this.isSuccess,
    this.executionMessage,
  });

  ActionData copyWith({
    String? action,
    String? query,
    String? app,
    bool? isExecuted,
    bool? isSuccess,
    String? executionMessage,
  }) {
    return ActionData(
      action: action ?? this.action,
      query: query ?? this.query,
      app: app ?? this.app,
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
  bool get isJarvis => sender == MessageSender.jarvis;
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
}
