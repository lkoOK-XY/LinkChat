import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friend.dart';
import '../service/friend_service.dart';
import '../service/storage_service.dart';

/// 好友列表状态
class FriendsState {
  final List<Friend> friends;
  final bool loaded;

  const FriendsState({this.friends = const [], this.loaded = false});

  FriendsState copyWith({List<Friend>? friends, bool? loaded}) {
    return FriendsState(
      friends: friends ?? this.friends,
      loaded: loaded ?? this.loaded,
    );
  }
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  final FriendService _friendService;

  FriendsNotifier(this._friendService) : super(const FriendsState());

  /// 启动时调用，从 Hive 加载所有好友
  Future<void> load() async {
    final list = await _friendService.loadAll();
    state = state.copyWith(friends: list, loaded: true);
  }

  /// 接受/添加好友时调用
  Future<void> upsert({
    required String peerId,
    String? displayName,
    String? avatar,
    String? publicKey,
  }) async {
    final friend = await _friendService.upsert(
      peerId: peerId,
      displayName: displayName,
      avatar: avatar,
      publicKey: publicKey,
    );
    state = state.copyWith(
      friends: [
        for (final f in state.friends)
          if (f.peerId == peerId) friend else f,
      ],
    );
  }

  /// 连接成功时调用，更新 lastConnectedAt
  Future<void> touchLastConnected(String peerId) async {
    await _friendService.touchLastConnected(peerId);
    final updated = _friendService.findByPeerId(peerId);
    if (updated != null) {
      state = state.copyWith(
        friends: [
          for (final f in state.friends)
            if (f.peerId == peerId) updated else f,
        ],
      );
    }
  }

  /// 删除好友
  Future<void> remove(String peerId) async {
    await _friendService.remove(peerId);
    state = state.copyWith(
      friends: state.friends.where((f) => f.peerId != peerId).toList(),
    );
  }

  /// 修改备注名
  Future<void> rename(String peerId, String newDisplayName) async {
    final updated = await _friendService.rename(peerId, newDisplayName);
    if (updated == null) return;
    state = state.copyWith(
      friends: [
        for (final f in state.friends)
          if (f.peerId == peerId) updated else f,
      ],
    );
  }
}

/// Provider
final friendsServiceProvider = Provider<FriendService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return FriendService(storage);
});

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in main');
});

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  return FriendsNotifier(ref.watch(friendsServiceProvider));
});
