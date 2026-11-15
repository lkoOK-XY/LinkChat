import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../../state/peer_provider.dart';
import '../../state/p2p_provider.dart';
import '../../state/connection_provider.dart';
import '../../state/friends_provider.dart';
import '../../services/identity_service.dart';
import '../../models/peer.dart';
import '../../models/friend.dart';

void _logUI(String msg) {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final line = '[$timestamp] [UI] $msg';
  try {
    File('linkchat_debug.log').writeAsStringSync(
      '${File('linkchat_debug.log').existsSync() ? '\n' : ''}$line',
      mode: FileMode.append,
    );
  } catch (_) {}
}

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  String? _selfPeerId;

  @override
  void initState() {
    super.initState();
    _logUI('ChatListPage initState 被调用');
    _loadIdentity();
    // 监听在 build 中通过 ref.listen 注册（Riverpod 推荐做法），
    // 这里是初始状态检查：若打开页面时已有未处理的请求，第一帧后再弹窗，
    // 避免 initState 中 context 还未 attach 就弹窗。
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialRequest());
  }

  /// 检查打开页面时是否已有未处理的连接请求
  void _checkInitialRequest() {
    if (!mounted) return;
    _logUI('PostFrame: 检查初始 incomingRequest 状态');
    final current = ref.read(incomingRequestProvider);
    if (current.hasRequest) {
      _logUI('发现已有未处理请求: ${current.fromPeerId}，立即弹窗');
      _showIncomingRequestDialog(current.fromPeerId!);
    }
  }

  Future<void> _loadIdentity() async {
    final identity = await IdentityService.getInstance();
    setState(() {
      _selfPeerId = identity.peerId;
    });
  }

  /// 弹出来连接请求对话框
  void _showIncomingRequestDialog(String fromPeerId) {
    _logUI('showDialog 被调用: fromPeerId=$fromPeerId, mounted=$mounted');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primary),
            SizedBox(width: 8),
            Text('收到连接请求'),
          ],
        ),
        content: Text('PeerID $fromPeerId 想要与你建立 P2P 连接。\n\n接受后将开始端对端加密通信。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(incomingRequestProvider.notifier).clear();
              _logUI('用户点击了拒绝');
            },
            child: const Text('拒绝'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(incomingRequestProvider.notifier).clear();
              _logUI('用户点击了接受，开始调用 acceptConnection');
              _acceptIncomingConnection(fromPeerId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('接受连接'),
          ),
        ],
      ),
    );
  }

  /// 接受来连接请求
  Future<void> _acceptIncomingConnection(String fromPeerId) async {
    _logUI('acceptIncomingConnection 开始: fromPeerId=$fromPeerId');

    // 添加到好友列表
    ref.read(peerProvider.notifier).addPeer(
          Peer(id: fromPeerId, status: ConnectionStatus.connecting),
        );

    // 更新连接状态
    ref.read(connectionProvider.notifier).setConnecting(fromPeerId);

    final p2p = ref.read(p2pServiceProvider);
    _logUI('获取 p2p 服务: ${p2p != null ? "成功" : "null!"}');
    if (p2p != null) {
      try {
        _logUI('调用 p2p.acceptConnection($fromPeerId)...');
        await p2p.acceptConnection(fromPeerId);
        _logUI('acceptConnection 成功，准备跳转聊天页');
        // 连接成功后跳转到聊天页
        if (mounted) {
          context.push('/chat/$fromPeerId');
        }
      } catch (e, stackTrace) {
        _logUI('acceptConnection 失败: $e\n$stackTrace');
        ref.read(connectionProvider.notifier).setFailed(e.toString());
        ref.read(peerProvider.notifier)
            .updatePeerStatus(fromPeerId, ConnectionStatus.failed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('接受连接失败: $e')),
          );
        }
      }
    } else {
      _logUI('错误: P2P 服务为 null，无法接受连接');
    }
  }

  void _copyPeerId() {
    if (_selfPeerId != null) {
      Clipboard.setData(ClipboardData(text: _selfPeerId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PeerID 已复制'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听来连接请求，弹出确认对话框。
    // 放在 build 中（而不是 initState/microtask），这是 Riverpod 官方推荐做法，
    // 能保证监听器在 widget 生命周期中稳定生效，不会因为 microtask 时机问题而漏掉事件。
    ref.listen<IncomingRequestState>(incomingRequestProvider,
        (previous, next) {
      _logUI('incomingRequest 变化: previous=${previous?.hasRequest}, next.hasRequest=${next.hasRequest}, fromPeerId=${next.fromPeerId}');
      if (next.hasRequest && mounted) {
        _logUI('准备弹出来连接请求对话框: ${next.fromPeerId}');
        _showIncomingRequestDialog(next.fromPeerId!);
      }
    });

    final peerState = ref.watch(peerProvider);
    final peers = peerState.peers;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _copyPeerId,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('消息'),
              if (_selfPeerId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selfPeerId!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.push('/add-friend'),
          ),
        ],
      ),
      body: peers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: AppColors.textSecondaryLight.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无会话',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮添加好友',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryLight.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: peers.length,
              itemBuilder: (context, index) {
                final peer = peers[index];
                return _buildPeerTile(peer);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-friend'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPeerTile(Peer peer) {
    final isOnline = peer.status == ConnectionStatus.connected;
    // 阶段三：优先显示好友备注名
    final friends = ref.watch(friendsProvider.select((s) => s.friends));
    Friend? friend;
    for (final f in friends) {
      if (f.peerId == peer.id) {
        friend = f;
        break;
      }
    }
    final displayName = (friend != null && friend.displayName.isNotEmpty)
        ? friend.displayName
        : (peer.nickname ?? peer.id);

    return InkWell(
      onTap: () => context.push('/chat/${peer.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 头像
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isOnline ? '在线' : '离线',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline
                              ? AppColors.online
                              : AppColors.offline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    peer.id,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
