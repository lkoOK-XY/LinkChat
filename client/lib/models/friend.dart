import 'package:hive/hive.dart';

/// 好友信息
///
/// 持久化在 Hive [AppConstants.friendsBoxName] 中，主键为 [peerId]。
/// 设计要点：
/// - peerId 是 Ed25519 公钥指纹（前 8 字节 hex），重启不变
/// - publicKey 是对方的 Ed25519 公钥，可用于验证身份（防 PeerID 伪造）
/// - 字段都提供默认值，兼容旧数据
class Friend {
  final String peerId;
  final String displayName;
  final String? avatar;
  final DateTime addedAt;
  final DateTime? lastConnectedAt;
  final String? publicKey;

  const Friend({
    required this.peerId,
    required this.displayName,
    this.avatar,
    required this.addedAt,
    this.lastConnectedAt,
    this.publicKey,
  });

  Friend copyWith({
    String? displayName,
    String? avatar,
    DateTime? addedAt,
    DateTime? lastConnectedAt,
    String? publicKey,
  }) {
    return Friend(
      peerId: peerId,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      addedAt: addedAt ?? this.addedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      publicKey: publicKey ?? this.publicKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'peerId': peerId,
        'displayName': displayName,
        'avatar': avatar,
        'addedAt': addedAt.toIso8601String(),
        'lastConnectedAt': lastConnectedAt?.toIso8601String(),
        'publicKey': publicKey,
      };

  factory Friend.fromJson(Map<dynamic, dynamic> json) {
    final addedAtRaw = json['addedAt'];
    final lastConnectedRaw = json['lastConnectedAt'];
    return Friend(
      peerId: json['peerId'] as String,
      displayName: (json['displayName'] as String?) ?? '',
      avatar: json['avatar'] as String?,
      addedAt: addedAtRaw is String
          ? DateTime.tryParse(addedAtRaw) ?? DateTime.now()
          : DateTime.now(),
      lastConnectedAt: lastConnectedRaw is String
          ? DateTime.tryParse(lastConnectedRaw)
          : null,
      publicKey: json['publicKey'] as String?,
    );
  }
}

/// Friend 的 Hive TypeAdapter（手写，避开 build_runner）
///
/// 字段顺序：
/// 0: peerId
/// 1: displayName
/// 2: avatar
/// 3: addedAt (millisSinceEpoch)
/// 4: lastConnectedAt (millisSinceEpoch, -1 表示 null)
/// 5: publicKey
class FriendAdapter extends TypeAdapter<Friend> {
  @override
  final int typeId = 1;

  @override
  Friend read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return Friend(
      peerId: fields[0] as String,
      displayName: fields[1] as String? ?? '',
      avatar: fields[2] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      lastConnectedAt: (fields[4] as int?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      publicKey: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Friend obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.peerId)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.avatar)
      ..writeByte(3)
      ..write(obj.addedAt.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.lastConnectedAt?.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.publicKey);
  }
}
