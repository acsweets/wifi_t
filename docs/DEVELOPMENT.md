# WiFi_T 项目开发文档

## 项目概述

WiFi_T 是一个基于 Flutter 开发的局域网双向通信应用，旨在模拟不同设备在局域网的数据交互场景。通过 WebSocket 协议实现手机与设备间的实时双向通信，支持文本、图片和视频流传输。

### 核心特性
- ✅ 双向实时通信（WebSocket）
- ✅ 文本和图片消息传输
- ✅ 视频流传输（摄像头实时流）
- ✅ mDNS 自动设备发现
- ✅ 手动 IP 连接
- ✅ 简洁的 Tab 界面设计

## 技术架构

### 技术栈
```yaml
框架: Flutter 3.6+
语言: Dart 3.0+
通信协议: WebSocket
设备发现: mDNS (multicast_dns)
图片处理: image_picker
视频处理: camera, video_player
网络信息: network_info_plus
权限管理: permission_handler
图像处理: image
```

### 项目结构
```
lib/
├── models/
│   └── message.dart              # 消息数据模型
├── services/
│   ├── websocket_service.dart    # WebSocket通信服务
│   ├── mdns_service.dart         # mDNS设备发现服务
│   ├── video_stream_service.dart # 视频流处理服务
│   ├── camera_frame_decoder.dart # 摄像头帧解码器
│   └── video_frame_generator.dart # 视频帧生成器
├── screens/
│   ├── home_screen.dart          # 主界面（Tab切换）
│   ├── sender_screen.dart        # 发送端界面
│   ├── receiver_screen.dart      # 接收端界面
│   └── settings_screen.dart      # 设置界面
└── main.dart                     # 应用入口
```

## 核心模块设计

### 1. 消息模型 (Message)

```dart
enum MessageType { text, image, video, videoFrame }

class Message {
  final String id;              // 唯一标识
  final MessageType type;       // 消息类型
  final String? text;           // 文本内容
  final Uint8List? data;        // 二进制数据
  final String sender;          // 发送者
  final DateTime timestamp;     // 时间戳
  final bool isReceived;        // 接收标识
}
```

**设计要点：**
- 支持多种消息类型（文本、图片、视频帧）
- 统一的序列化/反序列化接口
- 区分发送和接收消息

### 2. WebSocket 通信服务

```dart
class WebSocketService {
  WebSocketChannel? _channel;
  HttpServer? _server;
  Function(Message)? onMessageReceived;
  
  // 服务器模式
  Future<void> startServer(int port);
  
  // 客户端模式
  Future<void> connectToServer(String ip, int port);
  
  // 消息处理
  void sendMessage(Message message);
  void _listenToMessages();
}
```

**技术实现：**
- 使用 `web_socket_channel` 包
- 支持服务器和客户端模式
- JSON 格式消息传输
- 自动消息监听和回调

### 3. mDNS 设备发现服务

```dart
class MDnsService {
  static const String _serviceType = '_http._tcp';
  
  // 设备发现
  Future<void> startDiscovery();
  Future<void> _scanTargetNetwork();
  
  // 服务广播
  Future<void> advertiseService(int port);
}
```

**发现机制：**
1. **mDNS 协议发现**：标准 mDNS 服务发现
2. **网络扫描备用**：扫描局域网 IP 范围（1-254）
3. **端口检测**：检测 8080 端口可用性
4. **设备列表管理**：实时更新发现的设备

### 4. 视频流服务

```dart
class VideoStreamService {
  CameraController? _controller;
  Function(Uint8List)? onFrameReady;
  
  Future<void> startVideoStream();
  void _processFrame(CameraImage image);
  Future<Uint8List?> _convertToJPEG(CameraImage image);
}
```

**视频处理流程：**
1. **摄像头初始化**：使用 `camera` 插件
2. **帧数据获取**：实时获取 CameraImage
3. **数据压缩**：YUV → 灰度数据压缩
4. **网络传输**：通过 WebSocket 发送帧数据

## 界面设计

### 主界面 (HomeScreen)
- Tab 切换设计：发送端 | 接收端 | 设置
- 使用 `DefaultTabController` 管理

### 发送端界面 (SenderScreen)
**功能区域：**
- IP 输入和连接控制
- 设备搜索和发现列表
- 消息输入和发送控制
- 视频流预览（发送时）
- 消息历史列表

**关键组件：**
```dart
// 设备发现列表
Container(
  height: 120,
  child: ListView.builder(
    itemBuilder: (context, index) {
      final device = _discoveredDevices[index];
      return ListTile(
        title: Text(device.name),
        subtitle: Text('${device.ip}:${device.port}'),
        trailing: ElevatedButton(
          onPressed: () => _connect(device.ip),
          child: Text('连接'),
        ),
      );
    },
  ),
)
```

### 接收端界面 (ReceiverScreen)
**功能区域：**
- 本机 IP 显示和服务器控制
- 视频流显示区域
- 回复消息输入
- 消息历史列表

**视频显示处理：**
```dart
// 视频帧解码和显示
Future<void> _decodeAndDisplayFrame(List<int>? frameData) async {
  if (frameData == null) return;
  
  try {
    final pngBytes = await CameraFrameDecoder.decodeYUVToImage(
      Uint8List.fromList(frameData), 160, 120
    );
    
    if (pngBytes != null) {
      setState(() {
        _currentVideoFrame = pngBytes;
      });
    }
  } catch (e) {
    print('Frame decode error: $e');
  }
}
```

## 数据流设计

### 连接建立流程
```
接收端: 启动服务器(8080) → mDNS广播服务
发送端: 搜索设备 → 选择设备 → WebSocket连接
```

### 消息传输流程
```
发送端: 创建Message → JSON序列化 → WebSocket发送
接收端: WebSocket接收 → JSON反序列化 → UI更新
```

### 视频流传输
```
发送端: 摄像头帧 → YUV压缩 → WebSocket发送
接收端: 接收帧数据 → 解码显示 → UI更新
```

## 关键技术实现

### 1. 网络通信
- **协议**：WebSocket over TCP
- **端口**：8080（固定）
- **数据格式**：JSON
- **连接模式**：一对一连接

### 2. 设备发现
```dart
// mDNS 发现
await for (final PtrResourceRecord ptr in _client!.lookup<PtrResourceRecord>(
  ResourceRecordQuery.serverPointer(_serviceType),
)) {
  // 处理发现的服务
}

// 网络扫描备用
for (int i = 1; i <= 254; i++) {
  futures.add(_checkDevice('$localSubnet.$i'));
}
```

### 3. 视频帧处理
```dart
// YUV 数据压缩
Future<Uint8List?> _convertToJPEG(CameraImage image) async {
  final yPlane = image.planes[0];
  const targetWidth = 80;
  const targetHeight = 60;
  final targetData = Uint8List(targetWidth * targetHeight);
  
  // 采样压缩
  for (int y = 0; y < targetHeight; y++) {
    for (int x = 0; x < targetWidth; x++) {
      final srcX = (x * width / targetWidth).floor();
      final srcY = (y * height / targetHeight).floor();
      targetData[y * targetWidth + x] = yPlane.bytes[srcIndex];
    }
  }
  return targetData;
}
```

### 4. 图像解码显示
```dart
// 帧数据转图像
static Future<Uint8List?> decodeYUVToImage(Uint8List yData, int width, int height) async {
  final rgbaBytes = Uint8List(width * height * 4);
  
  // 灰度转RGBA
  for (int i = 0; i < yData.length && i < width * height; i++) {
    final gray = yData[i];
    final index = i * 4;
    rgbaBytes[index] = gray;     // R
    rgbaBytes[index + 1] = gray; // G
    rgbaBytes[index + 2] = gray; // B
    rgbaBytes[index + 3] = 255;  // A
  }
  
  // 转换为PNG
  final completer = Completer<Uint8List>();
  ui.decodeImageFromPixels(rgbaBytes, width, height, ui.PixelFormat.rgba8888, 
    (ui.Image img) async {
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      completer.complete(byteData?.buffer.asUint8List());
    }
  );
  return completer.future;
}
```

## 性能优化

### 1. 视频流优化
- **帧率控制**：限制发送帧率减少网络负载
- **分辨率压缩**：80x60 低分辨率传输
- **数据压缩**：仅传输 Y 通道灰度数据

### 2. 网络优化
- **连接复用**：单一 WebSocket 连接
- **消息队列**：避免消息丢失
- **错误重试**：网络异常自动重连

### 3. 内存管理
- **及时释放**：摄像头资源及时释放
- **数据清理**：定期清理消息历史
- **状态管理**：使用 `AutomaticKeepAliveClientMixin` 保持状态

## 开发指南

### 环境配置
```bash
# 检查Flutter环境
flutter doctor

# 安装依赖
flutter pub get

# 运行项目
flutter run
```

### 权限配置
**Android (android/app/src/main/AndroidManifest.xml):**
```xml
<!-- 网络权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />

<!-- 设备权限 -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**注意**：这些权限必须在主 AndroidManifest.xml 中声明，Debug/Profile 配置中的权限在 Release 模式下不生效。

**iOS (Info.plist):**
```xml
<key>NSCameraUsageDescription</key>
<string>需要访问相机来拍照</string>
<key>NSLocalNetworkUsageDescription</key>
<string>需要访问本地网络进行设备通信</string>
```

### 调试技巧
1. **网络调试**：使用 Wireshark 监控 WebSocket 通信
2. **日志输出**：关键节点添加 print 调试信息
3. **模拟器测试**：使用 localhost 进行本地测试

## 扩展功能

### 已实现功能
- ✅ 文本消息双向传输
- ✅ 图片选择和传输
- ✅ 视频流实时传输
- ✅ mDNS 自动设备发现
- ✅ 手动 IP 连接

### 待扩展功能
- 🔄 文件传输支持
- 🔄 多设备连接
- 🔄 消息加密
- 🔄 断线重连机制
- 🔄 消息持久化存储

## 使用场景

### 典型应用场景
- **VR/AR 设备通信**：智能眼镜与手机数据交互
- **设备投屏**：手机内容投射到其他设备
- **局域网聊天**：无需互联网的本地通信
- **游戏数据同步**：多设备游戏数据传输
- **智能家居控制**：设备间控制指令传输

### 技术优势
- **实时性**：WebSocket 全双工通信，延迟低
- **简单性**：标准协议，无需自定义格式
- **跨平台**：Flutter 良好支持
- **调试友好**：可用浏览器工具调试

## 故障排除

### 常见问题

#### 1. Release 模式服务启动失败
**问题**：Debug 模式正常，Release 模式下 mDNS 和 WebSocket 服务启动失败

**原因**：
- Release 模式下缺少网络权限声明
- mDNS 服务在 Release 模式下启动更严格
- WebSocket 服务绑定可能被系统限制

**解决方案**：
1. **添加完整权限声明**（已修复）：
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

2. **重试机制**（已实现）：
- mDNS 服务启动增加 3 次重试
- WebSocket 服务器绑定增加重试机制
- 连接超时和错误处理优化

3. **测试 Release 版本**：
```bash
# 构建 Release APK
flutter build apk --release

# 安装并测试
flutter install --release
```

#### 2. 其他常见问题
1. **连接失败**：检查网络和 IP 地址
2. **设备发现失败**：检查 mDNS 支持和网络权限
3. **视频流卡顿**：调整帧率和分辨率
4. **内存泄漏**：及时释放摄像头和网络资源

### 调试命令
```bash
# 查看设备列表
flutter devices

# 查看日志
flutter logs

# 调试模式运行
flutter run --debug

# Release 模式测试
flutter run --release
flutter build apk --release
```

### Release 模式测试清单
- [ ] WebSocket 服务器启动成功
- [ ] mDNS 设备发现功能正常
- [ ] 网络扫描备用机制工作
- [ ] 设备连接建立成功
- [ ] 消息传输正常
- [ ] 视频流传输稳定

## 总结

WiFi_T 项目通过 Flutter + WebSocket 技术栈，实现了功能完整的局域网双向通信应用。项目架构清晰，模块化设计良好，支持文本、图片和视频流的实时传输。通过 mDNS 自动发现和手动连接两种方式，提供了灵活的设备连接方案。

项目具有良好的扩展性，可以根据实际需求添加更多功能，如文件传输、多设备连接、消息加密等。整体设计符合移动应用开发最佳实践，代码结构清晰，便于维护和扩展。