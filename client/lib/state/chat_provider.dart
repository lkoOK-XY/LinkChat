import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';

// 消息列表状态
class ChatState {
  final List<Message> messages;
  final bool isLoading;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 聊天状态通知器
class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(const ChatState());

  void addMessage(Message message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }
}

// Provider
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
