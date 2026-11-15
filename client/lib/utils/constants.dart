class AppConstants {
  // 私有构造，防止实例化
  AppConstants._();

  // 默认信令服务器地址
  // 注：实际部署时需在「设置」页改成你自己的服务器（如 wss://your.domain.com/ws）
  static const String defaultSignalingServerUrl = 'ws://localhost:8080/ws';

  // STUN 服务器列表
  // 默认使用公共 STUN；自建 STUN/TURN 后替换为你的服务器地址
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.cloudflare.com:3478'},
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  // TURN 服务器配置（如需中继穿透对称型 NAT）
  // 自建 coturn 后启用：
  // {
  //   'urls': 'turn:1.2.3.4:3478',
  //   'username': 'linkchat',
  //   'credential': 'YourStrongPass123',
  // },

  // DataChannel 配置
  static const String dataChannelLabel = 'linkchat-messages';

  // 文件传输分片大小 (16KB)
  static const int fileChunkSize = 16384;

  // Hive Box 名称
  static const String messagesBoxName = 'messages';
  static const String friendsBoxName = 'friends';
  static const String settingsBoxName = 'settings';
}
