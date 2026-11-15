enum ConnectionStatus { disconnected, connecting, connected, failed }

class Peer {
  final String id;
  final String? nickname;
  final String? avatar;
  final ConnectionStatus status;
  final DateTime? lastSeenTime;

  const Peer({
    required this.id,
    this.nickname,
    this.avatar,
    this.status = ConnectionStatus.disconnected,
    this.lastSeenTime,
  });

  Peer copyWith({
    String? id,
    String? nickname,
    String? avatar,
    ConnectionStatus? status,
    DateTime? lastSeenTime,
  }) {
    return Peer(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      status: status ?? this.status,
      lastSeenTime: lastSeenTime ?? this.lastSeenTime,
    );
  }
}
