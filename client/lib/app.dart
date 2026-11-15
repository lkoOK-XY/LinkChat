import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/pages/chat_list_page.dart';
import 'ui/pages/chat_page.dart';
import 'ui/pages/add_friend_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/theme/app_theme.dart';
import 'state/p2p_provider.dart';

void _logApp(String msg) {
  final timestamp = DateTime.now().toString().substring(0, 19);
  final line = '[$timestamp] [App] $msg';
  try {
    File('linkchat_debug.log').writeAsStringSync(
      '${File('linkchat_debug.log').existsSync() ? '\n' : ''}$line',
      mode: FileMode.append,
    );
  } catch (_) {}
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ChatListPage(),
      ),
      GoRoute(
        path: '/chat/:peerId',
        builder: (context, state) {
          final peerId = state.pathParameters['peerId']!;
          return ChatPage(peerId: peerId);
        },
      ),
      GoRoute(
        path: '/add-friend',
        builder: (context, state) => const AddFriendPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

class LinkChatApp extends ConsumerStatefulWidget {
  const LinkChatApp({super.key});

  @override
  ConsumerState<LinkChatApp> createState() => _LinkChatAppState();
}

class _LinkChatAppState extends ConsumerState<LinkChatApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _logApp('开始初始化 P2P 服务...');
      // 初始化 P2P 服务（连接信令服务器）
      await initP2PService(ref);
      _logApp('P2P 服务初始化完成');
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e, stackTrace) {
      _logApp('P2P 服务初始化失败: $e\n$stackTrace');
      // 即使信令服务连接失败，也允许进入主界面
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // 启动加载页
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(height: 16),
                Text('正在连接信令服务...'),
              ],
            ),
          ),
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'LinkChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
