import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../p2p/p2p_service.dart';
import '../services/identity_service.dart';
import 'connection_provider.dart';
import 'friends_provider.dart';
import 'peer_provider.dart';
import 'chat_provider.dart';
import '../models/message.dart';
import '../models/peer.dart';

void _logProvider(String msg) {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final line = '[$timestamp] $msg';
  try {
    File('linkchat_debug.log').writeAsStringSync(
      '${File('linkchat_debug.log').existsSync() ? '\n' : ''}$line',
      mode: FileMode.append,
    );
  } catch (_) {}
}

/// 全局 P2P 服务 Provider
final p2pServiceProvider = StateProvider<P2PService?>((ref) => null);

/// 初始化 P2P 服务（在 main 中调用）
Future<P2PService> initP2PService(WidgetRef ref) async {
  // 阶段三：先加载好友列表到 Riverpod 状态
  await ref.read(friendsProvider.notifier).load();
  final loadedFriends = ref.read(friendsProvider).friends;
  _logProvider('[P2PProvider] 加载到 ${loadedFriends.length} 个好友: '
      '${loadedFriends.map((f) => f.peerId).join(", ")}');

  // 阶段三：把持久化好友同步到 peerProvider（重启后会话列表可显示）
  for (final f in loadedFriends) {
    ref.read(peerProvider.notifier).addPeer(
          Peer(id: f.peerId, status: ConnectionStatus.disconnected),
        );
  }
  _logProvider('[P2PProvider] 已将 ${loadedFriends.length} 个好友同步到 peerProvider');

  final identity = await IdentityService.getInstance();
  final peerId = identity.peerId;

  final p2p = P2PService()
    // 接受连接时自动写入好友
    ..onFriendUpsert = (id, {publicKey}) async {
      await ref.read(friendsProvider.notifier).upsert(
            peerId: id,
            publicKey: publicKey,
          );
    }
    // 连接成功时更新 lastConnectedAt
    ..onFriendTouch = (id) async {
      await ref.read(friendsProvider.notifier).touchLastConnected(id);
    };

  // 监听所有 P2P 事件
  p2p.events.listen((event) {
    _logProvider('[P2PProvider] 收到事件: ${event.type}, fromPeerId: ${event.fromPeerId}');
    switch (event.type) {
      case P2PEventType.incomingRequest:
        _logProvider('[P2PProvider] → 设置 incomingRequest: ${event.fromPeerId}');
        ref.read(incomingRequestProvider.notifier).setRequest(
              event.fromPeerId ?? '',
            );
        break;

      case P2PEventType.connected:
        ref.read(connectionProvider.notifier).setConnected(
              event.fromPeerId ?? '',
            );
        ref.read(peerProvider.notifier)
            .updatePeerStatus(event.fromPeerId ?? '', ConnectionStatus.connected);
        break;

      case P2PEventType.messageReceived:
        if (event.data is Message) {
          ref.read(chatProvider.notifier).addMessage(event.data as Message);
        }
        break;

      case P2PEventType.disconnected:
        ref.read(peerProvider.notifier)
            .updatePeerStatus(event.fromPeerId ?? '', ConnectionStatus.disconnected);
        break;

      case P2PEventType.connectionFailed:
        ref.read(connectionProvider.notifier).setFailed(
              event.data?.toString() ?? '连接失败',
            );
        break;

      default:
        break;
    }
  });

  await p2p.init(peerId);

  ref.read(p2pServiceProvider.notifier).state = p2p;
  return p2p;
}

/// 来连接请求状态
class IncomingRequestState {
  final String? fromPeerId;

  const IncomingRequestState({this.fromPeerId});

  const IncomingRequestState.empty() : fromPeerId = null;

  bool get hasRequest => fromPeerId != null && fromPeerId!.isNotEmpty;
}

class IncomingRequestNotifier extends StateNotifier<IncomingRequestState> {
  IncomingRequestNotifier() : super(const IncomingRequestState.empty());

  void setRequest(String fromPeerId) {
    state = IncomingRequestState(fromPeerId: fromPeerId);
  }

  void clear() {
    state = const IncomingRequestState.empty();
  }
}

final incomingRequestProvider =
    StateNotifierProvider<IncomingRequestNotifier, IncomingRequestState>(
  (ref) => IncomingRequestNotifier(),
);
