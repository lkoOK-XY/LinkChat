import 'package:hive/hive.dart';

import '../models/friend.dart';
import '../utils/constants.dart';

/// 存储服务
///
/// 集中管理 Hive box 的打开与注册。Friends 用类型化 box
/// （[Box]<[Friend]>），其余用动态 box。
class StorageService {
  static StorageService? _instance;
  late Box<Friend> _friendsBox;
  late Box _messagesBox;
  late Box _settingsBox;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    // 必须保证 FriendAdapter 已注册（在 main 中注册一次）
    _friendsBox = await Hive.openBox<Friend>(AppConstants.friendsBoxName);
    _messagesBox = await Hive.openBox(AppConstants.messagesBoxName);
    _settingsBox = await Hive.openBox(AppConstants.settingsBoxName);
  }

  // ---- 消息 ----
  Future<void> saveMessage(String key, dynamic value) async {
    await _messagesBox.put(key, value);
  }

  dynamic getMessage(String key) => _messagesBox.get(key);

  List<dynamic> getAllMessages() => _messagesBox.values.toList();

  // ---- 好友（类型化） ----
  Future<void> saveFriend(Friend friend) async {
    await _friendsBox.put(friend.peerId, friend);
  }

  Friend? getFriend(String peerId) => _friendsBox.get(peerId);

  List<Friend> getAllFriends() => _friendsBox.values.toList();

  Future<void> removeFriend(String peerId) async {
    await _friendsBox.delete(peerId);
  }

  // ---- 设置 ----
  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  dynamic getSetting(String key) => _settingsBox.get(key);
}
