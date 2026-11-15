import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'models/friend.dart';
import 'service/storage_service.dart';
import 'state/friends_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();
  final appDir = await getApplicationDocumentsDirectory();
  Hive.init(appDir.path);

  // 注册自定义 TypeAdapter
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(FriendAdapter());
  }

  // 预初始化存储服务（确保 box 已打开）
  await StorageService.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(
          await StorageService.getInstance(),
        ),
      ],
      child: const LinkChatApp(),
    ),
  );
}
