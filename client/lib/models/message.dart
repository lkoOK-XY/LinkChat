import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum MessageType { text, file, image, system }

class Message {
  final String id;
  final String fromPeerId;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic> content;
  bool isSent; // 发送状态
  bool isRead; // 已读状态

  Message({
    String? id,
    required this.fromPeerId,
    required this.type,
    DateTime? timestamp,
    required this.content,
    this.isSent = false,
    this.isRead = false,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();

  /// 从 DataChannel JSON 消息解析
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['msg_id'] as String,
      fromPeerId: json['from'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      content: json['content'] as Map<String, dynamic>,
    );
  }

  /// 序列化为 DataChannel JSON 消息
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'msg_id': id,
      'from': fromPeerId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'content': content,
    };
  }

  Message copyWith({
    String? id,
    String? fromPeerId,
    MessageType? type,
    DateTime? timestamp,
    Map<String, dynamic>? content,
    bool? isSent,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      fromPeerId: fromPeerId ?? this.fromPeerId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      isSent: isSent ?? this.isSent,
      isRead: isRead ?? this.isRead,
    );
  }
}
