import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../../state/connection_provider.dart';
import '../../state/peer_provider.dart';
import '../../state/p2p_provider.dart';
import '../../models/peer.dart';
import '../../services/identity_service.dart';

class AddFriendPage extends ConsumerStatefulWidget {
  const AddFriendPage({super.key});

  @override
  ConsumerState<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends ConsumerState<AddFriendPage> {
  final _peerIdController = TextEditingController();
  String? _selfPeerId;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  @override
  void dispose() {
    _peerIdController.dispose();
    super.dispose();
  }

  Future<void> _loadIdentity() async {
    final identity = await IdentityService.getInstance();
    setState(() {
      _selfPeerId = identity.peerId;
    });
  }

  void _copyPeerId() {
    if (_selfPeerId != null) {
      Clipboard.setData(ClipboardData(text: _selfPeerId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PeerID 已复制到剪贴板'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// 发起真实 P2P 连接
  Future<void> _connectToPeer() async {
    final targetPeerId = _peerIdController.text.trim();

    if (targetPeerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入对方 PeerID')),
      );
      return;
    }

    if (targetPeerId == _selfPeerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能连接自己')),
      );
      return;
    }

    final p2p = ref.read(p2pServiceProvider);
    if (p2p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('P2P 服务未就绪，请稍候')),
      );
      return;
    }

    setState(() => _isConnecting = true);

    // 更新连接状态
    ref.read(connectionProvider.notifier).setConnecting(targetPeerId);

    // 添加好友到列表
    ref.read(peerProvider.notifier).addPeer(
          Peer(id: targetPeerId, status: ConnectionStatus.connecting),
        );

    try {
      // 真正的 P2P 连接流程
      await p2p.connectTo(targetPeerId);

      // 等待连接建立（DataChannel 打开）
      // connected 事件会通过 p2p_provider 自动更新 connectionState

      if (mounted) {
        context.push('/chat/$targetPeerId');
      }
    } catch (e) {
      ref.read(connectionProvider.notifier).setFailed(e.toString());
      ref.read(peerProvider.notifier)
          .updatePeerStatus(targetPeerId, ConnectionStatus.failed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加好友'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 自己的 PeerID 展示区
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      '我的 PeerID',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        _selfPeerId ?? '加载中...',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _copyPeerId,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制 PeerID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 分隔线
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '或连接对方',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),

            const SizedBox(height: 32),

            // 输入对方 PeerID
            TextField(
              controller: _peerIdController,
              enabled: !_isConnecting,
              decoration: InputDecoration(
                hintText: '输入对方的 PeerID',
                prefixIcon: const Icon(Icons.person_search_outlined),
                suffixIcon: _peerIdController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _peerIdController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // 连接按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isConnecting ||
                        _peerIdController.text.trim().isEmpty)
                    ? null
                    : _connectToPeer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '发起连接',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // 连接状态提示
            if (connectionState.step != ConnectionStep.idle)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusCardColor(connectionState.step),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(connectionState.step),
                      color: _getStatusColor(connectionState.step),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        connectionState.errorMessage ??
                            _getStatusText(connectionState.step),
                        style: TextStyle(
                          color: _getStatusColor(connectionState.step),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 提示信息
            Card(
              color: AppColors.backgroundLight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          '使用说明',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• 将你的 PeerID 分享给好友\n'
                      '• 好友在应用中输入你的 PeerID\n'
                      '• 点击"发起连接"建立 P2P 加密通道\n'
                      '• 连接成功后即可开始聊天\n\n'
                      '所有消息通过端对端加密传输，不经过服务器。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(ConnectionStep step) {
    switch (step) {
      case ConnectionStep.connecting:
        return '正在连接到对方...';
      case ConnectionStep.waitingAccept:
        return '等待对方接受连接请求...';
      case ConnectionStep.exchangingSdp:
        return '正在交换加密密钥...';
      case ConnectionStep.connected:
        return '连接成功！';
      case ConnectionStep.failed:
        return '连接失败，请重试';
      default:
        return '';
    }
  }

  IconData _getStatusIcon(ConnectionStep step) {
    switch (step) {
      case ConnectionStep.connecting:
      case ConnectionStep.waitingAccept:
      case ConnectionStep.exchangingSdp:
        return Icons.hourglass_empty;
      case ConnectionStep.connected:
        return Icons.check_circle;
      case ConnectionStep.failed:
        return Icons.error;
      default:
        return Icons.info;
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

  Color? _getStatusCardColor(ConnectionStep step) {
    switch (step) {
      case ConnectionStep.connected:
        return AppColors.online.withOpacity(0.1);
      case ConnectionStep.failed:
        return AppColors.error.withOpacity(0.1);
      default:
        return AppColors.warning.withOpacity(0.1);
    }
  }
}
