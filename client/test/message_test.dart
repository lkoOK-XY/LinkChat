import 'package:flutter_test/flutter_test.dart';
import 'package:linkchat_client/models/message.dart';

void main() {
  test('Message JSON round-trip keeps the DataChannel wire format', () {
    final message = Message(
      id: 'msg-1',
      fromPeerId: 'a1b2c3d4',
      type: MessageType.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1718000000000),
      content: {'text': 'hello'},
    );

    final json = message.toJson();
    expect(json['type'], 'text');
    expect(json['msg_id'], 'msg-1');
    expect(json['from'], 'a1b2c3d4');
    expect(json['timestamp'], 1718000000000);

    final decoded = Message.fromJson(json);
    expect(decoded.id, message.id);
    expect(decoded.fromPeerId, message.fromPeerId);
    expect(decoded.type, MessageType.text);
    expect(decoded.timestamp, message.timestamp);
    expect(decoded.content['text'], 'hello');
  });

  test('Unknown message type falls back to text', () {
    final decoded = Message.fromJson({
      'msg_id': 'msg-2',
      'from': 'ffffffff',
      'type': 'unknown-type',
      'timestamp': 1718000000000,
      'content': <String, dynamic>{},
    });

    expect(decoded.type, MessageType.text);
  });
}
