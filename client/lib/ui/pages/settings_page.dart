import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../../services/identity_service.dart';
import '../../service/storage_service.dart';
import '../../utils/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _serverUrlController = TextEditingController();
  String? _selfPeerId;
  bool _isLoading = true;
  bool _isSaving = false;

  // 设置项 key
  static const _keyServerUrl = 'signaling_server_url';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 加载身份信息
    final identity = await IdentityService.getInstance();
    // 加载已保存的服务器地址
    final storage = await StorageService.getInstance();
    final savedUrl = storage.getSetting(_keyServerUrl) as String?;

    if (mounted) {
      setState(() {
        _selfPeerId = identity.peerId;
        _serverUrlController.text =
            savedUrl ?? AppConstants.defaultSignalingServerUrl;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveServerUrl() async {
    final url = _serverUrlController.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入信令服务器地址')),
      );
      return;
    }

    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地址必须以 ws:// 或 wss:// 开头')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final storage = await StorageService.getInstance();
      await storage.setSetting(_keyServerUrl, url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置已保存，重启客户端后生效'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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

  void _resetToDefault() {
    setState(() {
      _serverUrlController.text = AppConstants.defaultSignalingServerUrl;
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === 身份信息 ===
          _buildSectionTitle('身份信息'),
          _buildCard([
            _buildInfoRow(
              label: '我的 PeerID',
              value: _selfPeerId ?? '加载中...',
              valueStyle: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              onTap: _copyPeerId,
              trailing: Icon(
                Icons.copy_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // === 连接设置 ===
          _buildSectionTitle('连接设置'),
          _buildCard([
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '信令服务器地址',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
            TextField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                hintText: 'ws://localhost:8080/ws',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: '恢复默认',
                  onPressed: _resetToDefault,
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveServerUrl,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存设置'),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // 提示文字
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '修改信令服务器地址后，需要重启客户端才能生效。\n\n'
                    '本地开发默认使用 ws://localhost:8080/ws，\n'
                    '公网部署请使用 wss:// 开头的安全连接。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // === 关于 ===
          _buildSectionTitle('关于'),
          _buildCard([
            _buildInfoRow(label: '应用名称', value: 'LinkChat'),
            _buildDivider(),
            _buildInfoRow(label: '版本', value: '1.0.0'),
            _buildDivider(),
            _buildInfoRow(
              label: '协议',
              value: 'WebRTC P2P',
              valueStyle: TextStyle(
                color: AppColors.online,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondaryLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    TextStyle? valueStyle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: valueStyle ??
                        TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withOpacity(0.1),
      ),
    );
  }
}
