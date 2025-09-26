# API 文档

## WebSocket 通信协议

### 连接信息
- **协议**: WebSocket
- **端口**: 8080
- **URL格式**: `ws://[IP地址]:8080`

### 消息格式

所有消息均采用JSON格式传输：

```json
{
  "id": "消息唯一标识符",
  "type": "消息类型",
  "text": "文本内容（可选）",
  "data": "二进制数据数组（可选）",
  "sender": "发送者标识",
  "timestamp": "时间戳（毫秒）"
}
```

### 消息类型

#### 1. 文本消息
```json
{
  "id": "1703123456789",
  "type": "text",
  "text": "Hello World",
  "sender": "发送端",
  "timestamp": 1703123456789
}
```

#### 2. 图片消息
```json
{
  "id": "1703123456790",
  "type": "image",
  "data": [255, 216, 255, 224, ...],
  "sender": "发送端",
  "timestamp": 1703123456790
}
```

#### 3. 视频消息（预留）
```json
{
  "id": "1703123456791",
  "type": "video",
  "data": [0, 0, 0, 24, ...],
  "sender": "发送端",
  "timestamp": 1703123456791
}
```

## 核心类接口

### Message 类

```dart
class Message {
  final String id;
  final MessageType type;
  final String? text;
  final Uint8List? data;
  final String sender;
  final DateTime timestamp;
  final bool isReceived;

  // 构造函数
  Message({
    required this.id,
    required this.type,
    this.text,
    this.data,
    required this.sender,
    required this.timestamp,
    required this.isReceived,
  });

  // JSON序列化
  Map<String, dynamic> toJson();
  
  // JSON反序列化
  factory Message.fromJson(Map<String, dynamic> json);
}
```

### WebSocketService 类

```dart
class WebSocketService {
  // 属性
  bool get isConnected;
  bool get isServerRunning;
  Function(Message)? onMessageReceived;

  // 服务器端方法
  Future<void> startServer(int port);

  // 客户端方法
  Future<void> connectToServer(String ip, int port);

  // 通用方法
  void sendMessage(Message message);
  void disconnect();
}
```

## 错误处理

### 连接错误
- **连接超时**: 检查IP地址和网络连接
- **端口占用**: 更换端口或重启应用
- **网络不可达**: 确保设备在同一局域网

### 数据传输错误
- **消息过大**: 图片数据超过WebSocket限制
- **格式错误**: JSON解析失败
- **连接断开**: 网络中断或对方关闭连接

## 使用示例

### 启动服务器
```dart
final service = WebSocketService();
await service.startServer(8080);
```

### 连接服务器
```dart
final service = WebSocketService();
await service.connectToServer('192.168.1.100', 8080);
```

### 发送文本消息
```dart
final message = Message(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  type: MessageType.text,
  text: 'Hello',
  sender: '发送端',
  timestamp: DateTime.now(),
  isReceived: false,
);
service.sendMessage(message);
```

### 发送图片消息
```dart
final bytes = await File(imagePath).readAsBytes();
final message = Message(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  type: MessageType.image,
  data: Uint8List.fromList(bytes),
  sender: '发送端',
  timestamp: DateTime.now(),
  isReceived: false,
);
service.sendMessage(message);
```