import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../../state/chat_provider.dart';
import '../../state/connection_provider.dart';
import '../../state/p2p_provider.dart';
import '../../models/message.dart';
import '../../services/identity_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String peerId;

  const ChatPage({
    super.key,
    required this.peerId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  String? _selfPeerId;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final identity = await IdentityService.getInstance();
    setState(() {
      _selfPeerId = identity.peerId;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 通过 DataChannel 发送消息
  void _handleSend(String text) {
    if (text.trim().isEmpty) return;

    // 构建消息对象
    final message = Message(
      fromPeerId: _selfPeerId ?? 'self',
      type: MessageType.text,
      content: {'text': text},
      isSent: true,
    );

    // 先显示在本地 UI（乐观更新）
    ref.read(chatProvider.notifier).addMessage(message);

    // 通过 P2P 发送
    final p2p = ref.read(p2pServiceProvider);
    if (p2p != null) {
      try {
        p2p.sendMessage(widget.peerId, jsonEncode({
          'type': 'text',
          'msg_id': message.id,
          'from': _selfPeerId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'content': {'text': text},
        }));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('P2P 连接未建立')),
      );
    }

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final connectionState = ref.watch(connectionProvider);
    final messages = chatState.messages;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peerId,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              _getConnectionStatusText(connectionState.step),
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(connectionState.step),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                ref.read(chatProvider.notifier).clearMessages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('清空聊天记录'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 连接状态提示
          if (connectionState.step != ConnectionStep.connected &&
              connectionState.step != ConnectionStep.idle)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _getStatusBarColor(connectionState.step),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (connectionState.step == ConnectionStep.connecting ||
                      connectionState.step ==
                          ConnectionStep.exchangingSdp)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (connectionState.step == ConnectionStep.failed)
                    const Icon(Icons.error_outline, size: 16, color: Colors.white)
                  else
                    const Icon(Icons.info_outline, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connectionState.errorMessage ??
                          _getConnectionStatusText(connectionState.step),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 64,
                          color:
                              AppColors.textSecondaryLight.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无消息',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '发送消息开始聊天',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                AppColors.textSecondaryLight.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isSelf =
                          message.fromPeerId == (_selfPeerId ?? 'self');

                      return MessageBubble(
                        content: message.content['text'] ?? '',
                        owner: isSelf
                            ? MessageOwner.self
                            : MessageOwner.other,
                        time: message.timestamp,
                      );
                    },
                  ),
          ),

          // 输入区域
          ChatInput(
            onSend: _handleSend,
            onAttachFile: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('文件功能开发中')),
              );
            },
            onAttachImage: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('图片功能开发中')),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getConnectionStatusText(ConnectionStep step) {
    switch (step) {
      case ConnectionStep.idle:
        return '未连接';
      case ConnectionStep.connecting:
        return '正在连接...';
      case ConnectionStep.waitingAccept:
        return '等待对方接受';
      case ConnectionStep.exchangingSdp:
        return '建立加密通道...';
      case ConnectionStep.connected:
        return '已连接 - 端对端加密';
      case ConnectionStep.failed:
        return '连接失败';
    }
  }

  Color _getStatusColor(ConnectionStep step) {
    switch (step) {
      case ConnectionStep.connected:
        return AppColors.online;
      case ConnectionStep.failed:
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Color _getStatusBarColor(ConnectionStep step) {
    switch (step) {
      case ConnectionStep.connecting:
      case ConnectionStep.waitingAccept:
      case ConnectionStep.exchangingSdp:
        return AppColors.warning;
      case ConnectionStep.failed:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}
