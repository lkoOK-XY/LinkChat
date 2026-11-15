import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart' hide MessageType;
import './webrtc_manager.dart';
import './signaling_client.dart';
import '../utils/constants.dart';
import '../models/message.dart' as app_msg;
import '../service/storage_service.dart';

void _logP2P(String msg) {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final line = '[$timestamp] $msg';
  try {
    File('linkchat_debug.log').writeAsStringSync(
      '${File('linkchat_debug.log').existsSync() ? '\n' : ''}$line',
      mode: FileMode.append,
    );
  } catch (_) {}
}

enum P2PEventType {
  connecting,
  connected,
  disconnected,
  messageReceived,
  connectionFailed,
  incomingRequest,
}

class P2PEvent {
  final P2PEventType type;
  final String? fromPeerId;
  final dynamic data;

  P2PEvent({required this.type, this.fromPeerId, this.data});
}

class P2PService {
  SignalingClient? _signaling;
  WebRTCManager? _webrtc;
  final _eventController = StreamController<P2PEvent>.broadcast();
  final Map<String, RTCPeerConnection> _connections = {};
  bool _isInitiator = false;
  String? _pendingTargetPeerId;

  /// 阶段三：好友持久化回调
  /// - [onFriendUpsert] 在接受连接请求时调，由外部包装 FriendService
  /// - [onFriendTouch] 在连接成功时调，更新 lastConnectedAt
  /// 用回调注入而非直接依赖 FriendService，避免循环依赖
  Future<void> Function(String peerId, {String? publicKey})? onFriendUpsert;
  Future<void> Function(String peerId)? onFriendTouch;

  Stream<P2PEvent> get events => _eventController.stream;
  bool get isConnected =>
      _webrtc?.dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  /// 初始化：连接信令服务器
  /// 从设置中读取信令服务器地址，未配置则使用默认值
  Future<void> init(String selfPeerId) async {
    _logP2P('[P2P] 初始化 P2P 服务，PeerID: $selfPeerId');

    _logP2P('[P2P] 正在获取 StorageService...');
    final storage = await StorageService.getInstance();
    _logP2P('[P2P] StorageService 获取成功');
    final serverUrl =
        storage.getSetting('signaling_server_url') as String? ??
            AppConstants.defaultSignalingServerUrl;
    _logP2P('[P2P] 信令服务器地址: $serverUrl');

    _signaling = SignalingClient(
      onMessage: _handleSignalingMessage,
    );

    _logP2P('[P2P] 正在连接信令服务器...');
    await _signaling!.connect(serverUrl: serverUrl);
    _logP2P('[P2P] 信令服务器连接成功，正在注册...');

    _signaling!.register(selfPeerId);
    _logP2P('[P2P] 已发送注册消息，PeerID: $selfPeerId');
  }

  /// 发起连接请求（发起方调用）
  /// 发送连接请求给对方，等待对方接受后自动完成 SDP 协商
  Future<bool> connectTo(String targetPeerId) async {
    if (_connections.containsKey(targetPeerId)) {
      return true; // 已连接
    }

    _isInitiator = true;
    _pendingTargetPeerId = targetPeerId;

    // 阶段三：发起方也写入好友（连接建立前先建立好友关系）
    if (onFriendUpsert != null) {
      try {
        await onFriendUpsert!(targetPeerId);
      } catch (e) {
        _logP2P('[P2P] 写入好友失败: $e');
      }
    }

    _eventController.add(P2PEvent(
      type: P2PEventType.connecting,
      fromPeerId: targetPeerId,
    ));

    // 1. 先发送连接请求（等对方接受后再创建 Offer）
    _signaling?.sendConnectRequest(targetPeerId, '');
    _logP2P('[P2P] 已发送连接请求到 $targetPeerId，等待对方接受...');

    // 2. 创建 PeerConnection（先准备好，不急着发 Offer）
    final webrtc = WebRTCManager();
    _webrtc = webrtc;

    await webrtc.createConnection(
      onLocalDescription: (desc) {
        if (_isInitiator) {
          _signaling?.sendOffer(
              _pendingTargetPeerId!, jsonEncode(desc.toMap()));
        } else {
          _signaling?.sendAnswer(
              _pendingTargetPeerId!, jsonEncode(desc.toMap()));
        }
      },
      onIceCandidate: (candidate) {
        // 解析 candidate 字符串提取 type（flutter_webrtc 0.10.x 不暴露 type 字段）
        final c = candidate.candidate ?? '';
        final typMatch = RegExp(r'typ\s+(\w+)').firstMatch(c);
        final type = typMatch?.group(1) ?? 'unknown';
        _logP2P('[P2P] 发送 ICE 候选到 $_pendingTargetPeerId: type=$type');
        _signaling?.sendIceCandidate(
          _pendingTargetPeerId!,
          candidate.toMap(),
        );
      },
      onDataChannelMessage: _handleDataChannelMessage,
      onDataChannelState: _handleDataChannelState,
    );

    _logP2P('[P2P] PeerConnection 已创建，等待对方接受连接请求');
    return true;
  }

  /// 对方已接受连接后，发起方创建并发送 Offer
  Future<void> _createAndSendOffer() async {
    final webrtc = _webrtc;
    if (webrtc == null || _pendingTargetPeerId == null) return;

    await webrtc.createOffer();
    _logP2P('[P2P] Offer 已创建并发送给 $_pendingTargetPeerId');
  }

  /// 处理收到的连接请求（被连接方调用）
  Future<void> acceptConnection(String fromPeerId) async {
    _isInitiator = false;
    _pendingTargetPeerId = fromPeerId;

    _eventController.add(P2PEvent(
      type: P2PEventType.connecting,
      fromPeerId: fromPeerId,
    ));

    // 阶段三：接受连接时写入好友表（如果不存在）
    if (onFriendUpsert != null) {
      try {
        await onFriendUpsert!(fromPeerId);
      } catch (e) {
        _logP2P('[P2P] 写入好友失败: $e');
      }
    }

    // 通知发起方：我已接受，你可以发 Offer 了
    _signaling?.sendAccept(fromPeerId);

    final webrtc = WebRTCManager();
    _webrtc = webrtc;

    await webrtc.createConnection(
      onLocalDescription: (desc) {
        _signaling?.sendAnswer(fromPeerId, jsonEncode(desc.toMap()));
      },
      onIceCandidate: (candidate) {
        _signaling?.sendIceCandidate(fromPeerId, candidate.toMap());
      },
      onDataChannelMessage: _handleDataChannelMessage,
      onDataChannelState: _handleDataChannelState,
    );

    _logP2P('[P2P] 已接受 $fromPeerId 的连接，等待 Offer...');
  }

  /// 处理信令消息
  Future<void> _handleSignalingMessage(
      SignalingMessageType type, Map<String, dynamic> json) async {
    final from = json['from'] as String? ?? '';
    _logP2P('[P2P] 收到信令消息: type=$type, from=$from');

    switch (type) {
      case SignalingMessageType.connectRequest:
        _logP2P('[P2P] 触发 incomingRequest 事件, from=$from');
        _eventController.add(P2PEvent(
          type: P2PEventType.incomingRequest,
          fromPeerId: from,
        ));
        break;

      case SignalingMessageType.accepted:
        // 对方接受了连接请求，发起方现在创建并发送 Offer
        _logP2P('[P2P] $from 已接受连接，开始创建 Offer...');
        // 必须先创建 DataChannel，再 createOffer。
        // SDP 中的 m=application 描述 DataChannel 协商，
        // 如果先 createOffer，SDP 中没有 m=application，
        // 接收端 answer 也不会有，DataChannel 协商永远不进行。
        await _webrtc?.createDataChannel();
        await _createAndSendOffer();
        // 状态/消息回调已在 createConnection 时注册到 webrtc_manager
        break;

      case SignalingMessageType.offer:
        _handleOffer(from, json);
        break;

      case SignalingMessageType.answer:
        _handleAnswer(from, json);
        break;

      case SignalingMessageType.iceCandidate:
        _handleIceCandidate(json);
        break;

      case SignalingMessageType.disconnect:
        _handleDisconnect(from);
        break;

      default:
        break;
    }
  }

  Future<void> _handleOffer(
      String from, Map<String, dynamic> json) async {
    _logP2P('[P2P] 收到来自 $from 的 Offer');
    final sdpMap = jsonDecode(json['sdp'] as String);
    final offer =
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);

    await _webrtc?.setRemoteDescription(offer);
    await _webrtc!.createAnswer(offer);
    _logP2P('[P2P] Answer 已创建并发送');
  }

  Future<void> _handleAnswer(
      String from, Map<String, dynamic> json) async {
    _logP2P('[P2P] 收到来自 $from 的 Answer');
    final sdpMap = jsonDecode(json['sdp'] as String);
    final answer =
        RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);

    await _webrtc?.setRemoteDescription(answer);
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> json) async {
    final candidateMap = json['candidate'] as Map<String, dynamic>;
    final candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await _webrtc?.addIceCandidate(candidate);
  }

  void _handleDisconnect(String from) {
    _logP2P('[P2P] $from 断开连接');
    _connections.remove(from);
    _eventController.add(P2PEvent(
      type: P2PEventType.disconnected,
      fromPeerId: from,
    ));
  }

  void _handleDataChannelMessage(dynamic data) {
    if (data is RTCDataChannelMessage) {
      try {
        final json = jsonDecode(data.text) as Map<String, dynamic>;
        final message = app_msg.Message.fromJson(json);
        _eventController.add(P2PEvent(
          type: P2PEventType.messageReceived,
          fromPeerId: message.fromPeerId,
          data: message,
        ));
      } catch (e) {
        _logP2P('[P2P] 解析消息失败: $e');
      }
    }
  }

  void _handleDataChannelState(RTCDataChannelState state) {
    _logP2P('[P2P] DataChannel 状态: $state');
    if (state == RTCDataChannelState.RTCDataChannelOpen) {
      final peerId = _pendingTargetPeerId;
      _eventController.add(P2PEvent(
        type: P2PEventType.connected,
        fromPeerId: peerId,
      ));
      // 阶段三：连接成功，更新 lastConnectedAt
      if (peerId != null && onFriendTouch != null) {
        onFriendTouch!(peerId).catchError((Object e) {
          _logP2P('[P2P] 更新 lastConnectedAt 失败: $e');
        });
      }
    }
  }

  /// 发起方：Offer 设置完成后创建 DataChannel
  Future<void> onDataChannelReady() async {
    await _webrtc?.createDataChannel();
    // DataChannel 的状态/消息回调已在 createConnection 时注册到
    // webrtc_manager，这里无需再设置。
  }

  /// 通过 DataChannel 发送消息（JSON 格式）
  void sendMessage(String peerId, String messageJson) {
    if (_webrtc?.dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      _logP2P('[P2P] DataChannel 未打开，无法发送消息');
      throw Exception('P2P 连接未建立');
    }
    _webrtc?.sendMessage(messageJson);
    _logP2P('[P2P] 消息已发送给 $peerId');
  }

  /// 发送文本消息（便捷方法）
  void sendTextMessage(String text, String selfPeerId) {
    final msg = app_msg.Message(
      fromPeerId: selfPeerId,
      type: app_msg.MessageType.text,
      content: {'text': text},
    );
    _webrtc?.sendMessage(jsonEncode(msg.toJson()));
  }

  /// 释放资源
  Future<void> dispose() async {
    await _signaling?.dispose();
    await _webrtc?.dispose();
    _connections.clear();
    await _eventController.close();
  }
}
