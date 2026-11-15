import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/constants.dart';

/// 日志写入文件（Release 模式下命令行看不到 print 输出）
void _log(String msg) {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final line = '[$timestamp] $msg';
  // 注意：这里不能用 _log，否则会无限递归
  try {
    File('linkchat_debug.log').writeAsStringSync(
      '${File('linkchat_debug.log').existsSync() ? '\n' : ''}$line',
      mode: FileMode.append,
    );
  } catch (_) {}
}

/// 信令消息类型（Dart enum name 是驼峰，发送时转为下划线匹配 Go 服务端）
enum SignalingMessageType {
  register,       // register
  offer,          // offer
  answer,         // answer
  iceCandidate,   // ice_candidate
  connectRequest, // connect_request
  accepted,       // accepted
  connectResponse,// connect_response
  disconnect,     // disconnect
}

/// 枚举名 → 下划线格式（匹配 Go 服务端）
String _toWireFormat(SignalingMessageType type) {
  switch (type) {
    case SignalingMessageType.register:
      return 'register';
    case SignalingMessageType.offer:
      return 'offer';
    case SignalingMessageType.answer:
      return 'answer';
    case SignalingMessageType.iceCandidate:
      return 'ice_candidate';
    case SignalingMessageType.connectRequest:
      return 'connect_request';
    case SignalingMessageType.accepted:
      return 'accepted';
    case SignalingMessageType.connectResponse:
      return 'connect_response';
    case SignalingMessageType.disconnect:
      return 'disconnect';
  }
}

/// 下划线格式 → 枚举（从服务端收消息时解析）
SignalingMessageType _fromWireFormat(String typeStr) {
  switch (typeStr) {
    case 'register':
      return SignalingMessageType.register;
    case 'offer':
      return SignalingMessageType.offer;
    case 'answer':
      return SignalingMessageType.answer;
    case 'ice_candidate':
      return SignalingMessageType.iceCandidate;
    case 'connect_request':
      return SignalingMessageType.connectRequest;
    case 'accepted':
      return SignalingMessageType.accepted;
    case 'connect_response':
      return SignalingMessageType.connectResponse;
    case 'disconnect':
      return SignalingMessageType.disconnect;
    default:
      return SignalingMessageType.register;
  }
}

class SignalingClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final void Function(SignalingMessageType, Map<String, dynamic>)? onMessage;

  SignalingClient({this.onMessage});

  bool get isConnected => _channel != null;

  /// 连接信令服务器
  Future<void> connect({String? serverUrl}) async {
    final url = serverUrl ?? AppConstants.defaultSignalingServerUrl;
    _log('正在连接信令服务器: $url');
    _channel = WebSocketChannel.connect(
      Uri.parse(url),
    );
    _log('WebSocket 已创建，准备监听消息流...');

    _subscription = _channel!.stream.listen(
      (data) {
        _log('[原始数据] 收到 WebSocket 数据: $data');
        _handleMessage(data);
      },
      onError: (error) => _log('信令错误: $error'),
      onDone: () => _log('信令连接断开'),
    );
    _log('Stream 监听器已设置完成');
  }

  /// 注册到信令服务器
  void register(String peerId) {
    _send({
      'type': _toWireFormat(SignalingMessageType.register),
      'peer_id': peerId,
    });
  }

  /// 发起连接请求
  void sendConnectRequest(String targetPeerId, String selfPeerId) {
    _send({
      'type': _toWireFormat(SignalingMessageType.connectRequest),
      'from': selfPeerId,
      'to': targetPeerId,
    });
  }

  /// 接受连接请求（通知发起方）
  void sendAccept(String targetPeerId) {
    _send({
      'type': _toWireFormat(SignalingMessageType.accepted),
      'to': targetPeerId,
    });
  }

  /// 发送 SDP Offer
  void sendOffer(String targetPeerId, String sdp) {
    _send({
      'type': _toWireFormat(SignalingMessageType.offer),
      'to': targetPeerId,
      'sdp': sdp,
    });
  }

  /// 发送 SDP Answer
  void sendAnswer(String targetPeerId, String sdp) {
    _send({
      'type': _toWireFormat(SignalingMessageType.answer),
      'to': targetPeerId,
      'sdp': sdp,
    });
  }

  /// 发送 ICE 候选
  void sendIceCandidate(String targetPeerId, Map<String, dynamic> candidate) {
    _send({
      'type': _toWireFormat(SignalingMessageType.iceCandidate),
      'to': targetPeerId,
      'candidate': candidate,
    });
  }

  /// 发送断开通知
  void sendDisconnect(String targetPeerId) {
    _send({
      'type': _toWireFormat(SignalingMessageType.disconnect),
      'to': targetPeerId,
    });
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final typeStr = json['type'] as String;
      _log('[Signaling] 收到消息: type=$typeStr');
      final type = _fromWireFormat(typeStr);
      _log('[Signaling] 解析为枚举: $type');
      onMessage?.call(type, json);
    } catch (e, stackTrace) {
      _log('[Signaling] 解析信令消息失败: $e\n$stackTrace');
    }
  }

  /// 断开连接
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }
}
