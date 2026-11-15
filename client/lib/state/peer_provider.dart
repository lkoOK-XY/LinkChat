import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/peer.dart';

// Peer 列表状态
class PeerState {
  final List<Peer> peers;
  final String? currentPeerId;

  const PeerState({
    this.peers = const [],
    this.currentPeerId,
  });

  PeerState copyWith({
    List<Peer>? peers,
    String? currentPeerId,
  }) {
    return PeerState(
      peers: peers ?? this.peers,
      currentPeerId: currentPeerId ?? this.currentPeerId,
    );
  }
}

// Peer 状态通知器
class PeerNotifier extends StateNotifier<PeerState> {
  PeerNotifier() : super(const PeerState());

  void addPeer(Peer peer) {
    if (!state.peers.any((p) => p.id == peer.id)) {
      state = state.copyWith(peers: [...state.peers, peer]);
    }
  }

  void updatePeerStatus(String peerId, ConnectionStatus status) {
    final updatedPeers = state.peers.map((p) {
      if (p.id == peerId) {
        return p.copyWith(status: status);
      }
      return p;
    }).toList();
    state = state.copyWith(peers: updatedPeers);
  }

  void removePeer(String peerId) {
    state = state.copyWith(
      peers: state.peers.where((p) => p.id != peerId).toList(),
    );
  }

  void setCurrentPeer(String? peerId) {
    state = state.copyWith(currentPeerId: peerId);
  }
}

// Provider
final peerProvider = StateNotifierProvider<PeerNotifier, PeerState>((ref) {
  return PeerNotifier();
});
