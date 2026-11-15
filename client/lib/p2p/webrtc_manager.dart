import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/constants.dart';

class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  Function(RTCPeerConnectionState)? _onConnectionChange;
  Function(RTCDataChannel)? onRemoteDataChannel;
  // 保存本地 SDP 回调，用于在 createOffer/createAnswer 后把 SDP 发回对端
  Function(RTCSessionDescription)? _onLocalDescription;
  // 保存 DataChannel 消息回调和状态回调，避免 P2PService 二次设置失败
  // 导致状态/消息丢失。回调在 createConnection 时传入并保存。
  Function(dynamic)? _onDataChannelMessage;
  Function(RTCDataChannelState)? _onDataChannelState;

  /// 公开的 dataChannel getter
  RTCDataChannel? get dataChannel => _dataChannel;

  /// 公开的 dataChannel setter
  set dataChannel(RTCDataChannel? channel) {
    _dataChannel = channel;
  }

  /// 创建 PeerConnection 并开始连接流程
  Future<void> createConnection({
    required Function(RTCSessionDescription) onLocalDescription,
    required Function(RTCIceCandidate) onIceCandidate,
    Function(dynamic)? onDataChannelMessage,
    Function(RTCDataChannelState)? onDataChannelState,
  }) async {
    // 关键：必须保存所有回调，否则 createOffer/createAnswer 后没人调用
    // 回调，SDP 永远到不了对端，P2P 协商会卡死；DataChannel 状态变化也
    // 不会被监听，connected 事件永远不触发。
    _onLocalDescription = onLocalDescription;
    _onDataChannelMessage = onDataChannelMessage;
    _onDataChannelState = onDataChannelState;

    // flutter_webrtc 0.10.x 使用 Map 配置，不是类
    final configuration = <String, dynamic>{
      'iceServers': AppConstants.iceServers,
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      // 详细日志：解析 candidate 字符串提取 type/address
      // 格式: candidate:... typ host|srflx|relay ...
      final c = candidate.candidate ?? '';
      final typMatch = RegExp(r'typ\s+(\w+)').firstMatch(c);
      final type = typMatch?.group(1) ?? 'unknown';
      // 仅有 host 意味着 STUN 没通；srflx 才是公网反射地址
      print('[WebRTC] ICE 候选: type=$type, address=$c');
      onIceCandidate(candidate);
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('[WebRTC] ICE 连接状态: $state');
    };

    _peerConnection!.onConnectionState = (state) {
      _onConnectionChange?.call(state);
    };

    _peerConnection!.onDataChannel = (channel) {
      // 接收端路径：远端发起方创建 DataChannel 后，本端 PeerConnection
      // 触发 onDataChannel 事件。必须走 _setupDataChannel 才能绑定
      // onMessage 和 onDataChannelState，否则 DataChannel 状态变化
      // 没人监听，connected 事件永远不触发。
      _setupDataChannel(channel);
      onRemoteDataChannel?.call(channel);
    };
  }

  /// 创建 Offer（发起方调用）
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    // setLocalDescription 后回调，通知调用方把 SDP 发给对端
    _onLocalDescription?.call(offer);
    return offer;
  }

  /// 创建 Answer（接收方调用）
  Future<RTCSessionDescription> createAnswer(RTCSessionDescription offer) async {
    await _peerConnection!.setRemoteDescription(offer);
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    _onLocalDescription?.call(answer);
    return answer;
  }

  /// 设置远程描述
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  /// 添加 ICE 候选
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  /// 创建 DataChannel
  Future<void> createDataChannel() async {
    final dataChannel = await _peerConnection!.createDataChannel(
      AppConstants.dataChannelLabel,
      RTCDataChannelInit()..ordered = true,
    );

    _setupDataChannel(dataChannel);
  }

  /// 处理远程 DataChannel
  void handleRemoteDataChannel(RTCDataChannel channel) {
    _setupDataChannel(channel);
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    _dataChannel!.onMessage = (data) {
      _onDataChannelMessage?.call(data);
    };
    // 必须设置 onDataChannelState，否则 DataChannel 状态变化
    // （特别是 connecting -> open）没人感知，connected 事件不触发
    _dataChannel!.onDataChannelState = (state) {
      _onDataChannelState?.call(state);
    };
  }

  /// 通过 DataChannel 发送消息
  void sendMessage(String message) {
    _dataChannel?.send(RTCDataChannelMessage(message));
  }

  /// 发送二进制数据（文件传输用）
  void sendBytes(Uint8List data) {
    _dataChannel?.send(RTCDataChannelMessage.fromBinary(data));
  }

  /// 关闭连接
  Future<void> dispose() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
  }
}
