import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';

import '../utils/constants.dart';

void _logIdentity(String msg) {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final line = '[$timestamp] [Identity] $msg';
  try {
    File('linkchat_debug.log').writeAsStringSync(
      '${File('linkchat_debug.log').existsSync() ? '\n' : ''}$line',
      mode: FileMode.append,
    );
  } catch (_) {}
}

/// 稳定身份服务
///
/// 启动时生成（或加载）Ed25519 密钥对：
/// - 私钥：MVP 阶段存 Hive（base64 明文），TODO 阶段四升级到 secure_storage
/// - 公钥：base64 存 Hive settings box
/// - PeerID = SHA-256(公钥) 前 4 字节 hex（8 字符），重启永远不变
///
/// 好友可保存对方公钥，用于后续阶段验证"对方确实是他声称的人"。
class IdentityService {
  static const _kPrivateKey = 'identity.private_key'; // hive（MVP 暂存）
  static const _kPublicKey = 'identity.public_key'; // hive
  static const _kPeerId = 'identity.peer_id'; // hive

  static IdentityService? _instance;
  late Box _box;

  IdentityService._();

  static Future<IdentityService> getInstance() async {
    if (_instance == null) {
      _instance = IdentityService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _box = await Hive.openBox(AppConstants.settingsBoxName);
    final existingPub = _box.get(_kPublicKey) as String?;
    final existingPeerId = _box.get(_kPeerId) as String?;

    if (existingPub == null) {
      // 升级场景：旧版本可能只写了 peerId（UUID），没写 publicKey
      // 此时保留旧 peerId 避免对方找不到自己，同时生成新密钥对
      if (existingPeerId != null && existingPeerId.isNotEmpty) {
        _logIdentity('检测到老格式身份数据，保留旧 peerId=$existingPeerId');
        await _generateAndPersist(keepPeerId: true);
      } else {
        await _generateAndPersist();
      }
    } else {
      _logIdentity('已存在身份: peerId=$existingPeerId');
    }
  }

  Future<void> _generateAndPersist({bool keepPeerId = false}) async {
    final algorithm = Ed25519();

    // 生成 32 字节随机种子作为私钥
    final rng = Random.secure();
    final seedBytes = List<int>.generate(32, (_) => rng.nextInt(256));

    // 用种子构造 keyPair（cryptography 2.7 接受 List<int>）
    final keyPair = await algorithm.newKeyPairFromSeed(seedBytes);

    // 拿公钥字节
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = Uint8List.fromList(await publicKey.bytes);

    // 私钥字节就是 seedBytes
    final privateKeyBytes = Uint8List.fromList(seedBytes);

    // 私钥 base64 存 hive（MVP 临时方案，等装好 MFC 后升级到 secure_storage）
    await _box.put(_kPrivateKey, base64.encode(privateKeyBytes));

    // 公钥 base64 存 hive
    final publicKeyB64 = base64.encode(publicKeyBytes);
    await _box.put(_kPublicKey, publicKeyB64);

    // PeerID
    if (!keepPeerId) {
      // 新身份：PeerID = SHA-256(公钥) 前 4 字节 hex
      final digest = await Sha256().hash(publicKeyBytes);
      final peerId = _digestToPeerId(digest.bytes);
      await _box.put(_kPeerId, peerId);
      _logIdentity('生成新身份: peerId=$peerId');
    } else {
      _logIdentity('保留旧 peerId, 已写入新公钥');
    }
  }

  /// 当前 PeerID（重启不变）
  String get peerId {
    final id = _box.get(_kPeerId) as String?;
    if (id == null || id.isEmpty) return 'unknown';
    return id;
  }

  /// 当前公钥 base64
  String? get publicKeyBase64 => _box.get(_kPublicKey) as String?;

  /// 当前公钥字节
  Uint8List? get publicKeyBytes {
    final b64 = publicKeyBase64;
    if (b64 == null) return null;
    return base64.decode(b64);
  }

  /// 当前私钥字节（MVP 阶段从 hive 读；阶段四升级到 secure_storage）
  Future<Uint8List?> get privateKeyBytes async {
    final b64 = _box.get(_kPrivateKey) as String?;
    if (b64 == null) return null;
    return base64.decode(b64);
  }

  /// 从公钥字节异步计算 PeerID（用于收到对方公钥时验证）
  static Future<String> peerIdFromPublicKey(Uint8List publicKey) async {
    final digest = await Sha256().hash(publicKey);
    return _digestToPeerId(digest.bytes);
  }

  /// 验证某 peerId 是否对应该公钥
  static Future<bool> verifyPeerIdForPublicKey(
      String peerId, String publicKeyB64) async {
    try {
      final bytes = base64.decode(publicKeyB64);
      final expected = await peerIdFromPublicKey(bytes);
      return expected == peerId;
    } catch (_) {
      return false;
    }
  }

  /// 公钥字节 → 短 PeerID（前 4 字节 hex，8 字符）
  static String _digestToPeerId(List<int> digest) {
    return digest
        .take(4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
