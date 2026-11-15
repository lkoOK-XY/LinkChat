import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectionStep {
  idle,
  connecting,
  waitingAccept,
  exchangingSdp,
  connected,
  failed,
}

class ConnectionState {
  final ConnectionStep step;
  final String? targetPeerId;
  final String? errorMessage;

  const ConnectionState({
    this.step = ConnectionStep.idle,
    this.targetPeerId,
    this.errorMessage,
  });

  ConnectionState copyWith({
    ConnectionStep? step,
    String? targetPeerId,
    String? errorMessage,
  }) {
    return ConnectionState(
      step: step ?? this.step,
      targetPeerId: targetPeerId ?? this.targetPeerId,
      errorMessage: errorMessage,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  ConnectionNotifier() : super(const ConnectionState());

  void setConnecting(String peerId) {
    state = ConnectionState(step: ConnectionStep.connecting, targetPeerId: peerId);
  }

  void setWaitingAccept(String peerId) {
    state = ConnectionState(step: ConnectionStep.waitingAccept, targetPeerId: peerId);
  }

  void setExchangingSdp(String peerId) {
    state = ConnectionState(step: ConnectionStep.exchangingSdp, targetPeerId: peerId);
  }

  void setConnected(String peerId) {
    state = ConnectionState(step: ConnectionStep.connected, targetPeerId: peerId);
  }

  void setFailed(String error) {
    state = ConnectionState(
      step: ConnectionStep.failed,
      targetPeerId: state.targetPeerId,
      errorMessage: error,
    );
  }

  void reset() {
    state = const ConnectionState();
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  return ConnectionNotifier();
});
