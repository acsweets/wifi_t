# mDNS 自动设备发现功能指南

## 功能概述

mDNS (Multicast DNS) 自动设备发现功能允许设备在局域网内自动发现和连接其他WiFi-T设备，无需手动输入IP地址。

## 工作原理

### 服务广播 (接收端)
1. 接收端启动WebSocket服务器后，同时启动mDNS服务广播
2. 在局域网内广播服务信息：
   - 服务类型：`_wifi-t._tcp`
   - 服务名称：`WiFi-T Device`
   - 端口：8080

### 设备发现 (发送端)
1. 发送端点击"搜索设备"按钮
2. 扫描局域网内的mDNS服务
3. 发现WiFi-T设备并显示在列表中
4. 用户可直接点击连接

## 使用方法

### 接收端操作
1. 打开"接收端"Tab
2. 点击"启动服务器"按钮
3. 看到"🔡 正在广播 mDNS 服务"提示表示成功

### 发送端操作
1. 打开"发送端"Tab
2. 点击"搜索设备"按钮
3. 等待搜索完成（约10秒）
4. 在发现的设备列表中选择目标设备
5. 点击设备旁的"连接"按钮

## 技术实现

### 核心类：MDnsService

```dart
class MDnsService {
  // 服务类型定义
  static const String _serviceType = '_wifi-t._tcp';
  static const String _serviceName = 'WiFi-T Device';
  
  // 开始设备发现
  Future<void> startDiscovery();
  
  // 广播服务
  Future<void> advertiseService(int port);
  
  // 停止服务
  void stopDiscovery();
}
```

### 设备信息模型

```dart
class DeviceInfo {
  final String name;    // 设备名称
  final String ip;      // IP地址
  final int port;       // 端口号
}
```

## 网络要求

### 支持的网络环境
- ✅ 家庭WiFi网络
- ✅ 办公室局域网
- ✅ 移动热点网络

### 不支持的网络环境
- ❌ 企业级网络（可能禁用组播）
- ❌ 公共WiFi（通常隔离设备）
- ❌ VPN网络

## 故障排除

### 搜索不到设备
1. **检查网络连接**
   - 确保两台设备在同一WiFi网络
   - 检查网络是否支持组播

2. **检查服务状态**
   - 确认接收端已启动服务器
   - 查看是否显示"正在广播 mDNS 服务"

3. **重试操作**
   - 重新启动服务器
   - 重新搜索设备

### 连接失败
1. **网络防火墙**
   - 检查设备防火墙设置
   - 确保8080端口未被阻止

2. **服务冲突**
   - 重启应用
   - 更换网络环境测试

## 性能特点

### 发现速度
- 通常在2-5秒内发现设备
- 最长搜索时间：10秒

### 资源消耗
- 低CPU占用
- 最小网络流量
- 自动超时停止

## 安全考虑

### 网络安全
- 仅在局域网内工作
- 不暴露到互联网
- 使用标准mDNS协议

### 隐私保护
- 不收集个人信息
- 仅广播服务可用性
- 连接需用户确认

## 扩展功能

### 未来改进
- [ ] 设备名称自定义
- [ ] 服务加密认证
- [ ] 多服务端口支持
- [ ] 设备状态监控

### 兼容性
- ✅ Android 设备
- ✅ iOS 设备  
- ✅ Windows 桌面
- ✅ macOS 桌面
- ✅ Linux 桌面

## 开发调试

### 调试工具
```bash
# 查看mDNS服务
avahi-browse -rt _wifi-t._tcp

# Windows下使用
dns-sd -B _wifi-t._tcp
```

### 日志输出
应用会在控制台输出mDNS相关日志，便于调试网络问题。