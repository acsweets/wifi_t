# 项目安装和使用指南

## 环境要求

- Flutter SDK 3.6.2+
- Dart SDK 3.0+
- Android Studio / VS Code
- Android设备或iOS设备（两台，用于测试）

## 安装步骤

### 1. 克隆项目
```bash
git clone <项目地址>
cd wifi_t
```

### 2. 安装依赖
```bash
flutter pub get
```

### 3. 检查Flutter环境
```bash
flutter doctor
```

### 4. 运行项目
```bash
# Android
flutter run

# iOS
flutter run -d ios

# 指定设备
flutter devices
flutter run -d <device_id>
```

## 权限配置

### Android权限 (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS权限 (ios/Runner/Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>需要访问相机来拍照</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册来选择图片</string>
<key>NSLocalNetworkUsageDescription</key>
<string>需要访问本地网络进行设备通信</string>
```

## 使用指南

### 基本使用流程

1. **准备工作**
   - 确保两台设备连接到同一WiFi网络
   - 在两台设备上安装并运行应用

2. **设置接收端（设备A）**
   - 打开应用，切换到"接收端"Tab
   - 点击"启动服务器"按钮
   - 记录显示的本机IP地址（如：192.168.1.100）

3. **设置发送端（设备B）**
   - 打开应用，切换到"发送端"Tab
   - 在IP地址输入框中输入接收端的IP地址
   - 点击"连接"按钮

4. **开始通信**
   - 连接成功后，发送端可以：
     - 输入文本消息并发送
     - 选择图片并发送
   - 接收端可以：
     - 查看接收到的消息
     - 发送回复消息

### 功能说明

#### 发送端界面
- **IP输入框**: 输入接收端设备的IP地址
- **连接按钮**: 建立WebSocket连接
- **文本输入**: 输入要发送的文本消息
- **发送按钮**: 发送文本消息
- **图片按钮**: 选择并发送图片
- **消息列表**: 显示发送和接收的消息历史

#### 接收端界面
- **IP显示**: 显示本机IP地址
- **启动服务器**: 启动WebSocket服务器
- **回复输入**: 输入回复消息
- **回复按钮**: 发送回复消息
- **消息列表**: 显示接收和发送的消息历史

### 消息类型

1. **文本消息**
   - 支持任意长度的文本
   - 实时传输显示

2. **图片消息**
   - 支持JPG、PNG等常见格式
   - 自动压缩传输
   - 接收端实时显示

3. **回复消息**
   - 接收端可发送文本回复
   - 双向通信支持

## 故障排除

### 常见问题

#### 1. 连接失败
**问题**: 点击连接后提示连接失败
**解决方案**:
- 检查两台设备是否在同一WiFi网络
- 确认接收端已启动服务器
- 检查IP地址是否输入正确
- 尝试关闭防火墙或安全软件

#### 2. 无法获取本机IP
**问题**: 接收端显示"无法获取IP"
**解决方案**:
- 检查WiFi连接状态
- 重启应用
- 检查网络权限是否已授予

#### 3. 图片发送失败
**问题**: 选择图片后无法发送
**解决方案**:
- 检查存储权限是否已授予
- 确认网络连接正常
- 尝试选择较小的图片文件

#### 4. 消息接收延迟
**问题**: 消息发送后对方延迟收到
**解决方案**:
- 检查网络信号强度
- 重新建立连接
- 确认没有其他应用占用大量网络带宽

### 调试模式

启用Flutter调试模式查看详细日志：
```bash
flutter run --debug
```

查看网络连接状态：
```bash
flutter logs
```

## 性能优化建议

1. **图片优化**
   - 发送前压缩大图片
   - 限制图片尺寸和质量

2. **网络优化**
   - 使用5GHz WiFi频段
   - 减少网络干扰源

3. **内存优化**
   - 及时清理消息历史
   - 避免同时发送多个大文件

## 开发调试

### 本地测试
可以在同一设备上测试：
1. 使用Android模拟器 + 物理设备
2. 使用两个不同的模拟器
3. 使用localhost (127.0.0.1) 作为IP地址

### 网络调试
使用Wireshark等工具监控WebSocket通信：
- 过滤条件: `websocket`
- 查看消息内容和传输状态