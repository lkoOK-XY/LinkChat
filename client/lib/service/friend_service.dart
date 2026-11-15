import 'dart:io';
import '../models/friend.dart';
import 'storage_service.dart';

void _logFriend(String msg) {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final line = '[$timestamp] [FriendSvc] $msg';
  try {
    File('linkchat_debug.log').writeAsStringSync(
      '${File('linkchat_debug.log').existsSync() ? '\n' : ''}$line',
      mode: FileMode.append,
    );
  } catch (_) {}
}

/// 好友服务
///
/// 单一职责：管理好友的 CRUD + 启动加载。
/// 接受/连接成功时由 P2PService 调 [upsert] / [touchLastConnected]。
class FriendService {
  final StorageService _storage;
  List<Friend> _cache = [];
  bool _loaded = false;

  FriendService(this._storage);

  /// 启动时加载所有好友到内存缓存
  Future<List<Friend>> loadAll() async {
    _cache = _storage.getAllFriends();
    _loaded = true;
    _logFriend('loadAll: 加载到 ${_cache.length} 个好友: '
        '${_cache.map((f) => "${f.peerId}(${f.displayName})").join(", ")}');
    return List.unmodifiable(_cache);
  }

  /// 当前缓存（已加载后）
  List<Friend> get all => List.unmodifiable(_cache);

  /// 查询某 peerId 的好友
  Friend? findByPeerId(String peerId) {
    if (!_loaded) return _storage.getFriend(peerId);
    for (final f in _cache) {
      if (f.peerId == peerId) return f;
    }
    return null;
  }

  /// 添加或更新好友
  ///
  /// - 如果已存在：只更新 [displayName] / [avatar] / [publicKey]，
  ///   保留 [addedAt]
  /// - 如果不存在：新建并写入
  Future<Friend> upsert({
    required String peerId,
    String? displayName,
    String? avatar,
    String? publicKey,
  }) async {
    final existing = findByPeerId(peerId);
    Friend next;
    if (existing != null) {
      next = existing.copyWith(
        displayName: displayName,
        avatar: avatar,
        publicKey: publicKey,
      );
    } else {
      next = Friend(
        peerId: peerId,
        displayName: displayName ?? peerId,
        avatar: avatar,
        addedAt: DateTime.now(),
        publicKey: publicKey,
      );
    }
    await _storage.saveFriend(next);
    _logFriend('upsert: peerId=$peerId, displayName=${next.displayName}, '
        'box.name=${_storage.getAllFriends().length}个好友');
    if (_loaded) {
      _cache = [
        ..._cache.where((f) => f.peerId != peerId),
        next,
      ];
    }
    return next;
  }

  /// 连接成功后更新 lastConnectedAt
  Future<void> touchLastConnected(String peerId) async {
    final existing = findByPeerId(peerId);
    if (existing == null) {
      // 还没保存为好友（例如没经过"接受"流程），跳过
      return;
    }
    final next = existing.copyWith(lastConnectedAt: DateTime.now());
    await _storage.saveFriend(next);
    if (_loaded) {
      _cache = [
        for (final f in _cache)
          if (f.peerId == peerId) next else f,
      ];
    }
  }

  /// 删除好友
  Future<void> remove(String peerId) async {
    await _storage.removeFriend(peerId);
    if (_loaded) {
      _cache = _cache.where((f) => f.peerId != peerId).toList();
    }
  }

  /// 修改备注名
  Future<Friend?> rename(String peerId, String newDisplayName) async {
    final existing = findByPeerId(peerId);
    if (existing == null) return null;
    final next = existing.copyWith(displayName: newDisplayName);
    await _storage.saveFriend(next);
    if (_loaded) {
      _cache = [
        for (final f in _cache)
          if (f.peerId == peerId) next else f,
      ];
    }
    return next;
  }
}
