import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../services/mdns_service.dart';
import '../services/video_stream_service.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> with AutomaticKeepAliveClientMixin {
  final _ipController = TextEditingController();
  final _textController = TextEditingController();
  final _webSocketService = WebSocketService();
  final _mdnsService = MDnsService();
  final _messages = <Message>[];
  final _imagePicker = ImagePicker();
  final _videoStreamService = VideoStreamService();
  bool _isDiscovering = false;
  List<DeviceInfo> _discoveredDevices = [];
  bool _isVideoStreaming = false;
  Timer? _videoStreamTimer;
  int _frameNumber = 0;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _webSocketService.onMessageReceived = (message) {
      setState(() {
        _messages.add(message);
      });
    };
    _mdnsService.onDevicesUpdated = (devices) {
      setState(() {
        _discoveredDevices = devices;
      });
    };
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _discoveredDevices.clear();
    });
    
    try {
      ///使用mdn扫描设备
      await _mdnsService.startDiscovery();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('开始搜索设备...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
    
    // 10秒后停止搜索
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
        _mdnsService.stopDiscovery();
      }
    });
  }

  Future<void> _connect([String? ip]) async {
    final targetIp = ip ?? _ipController.text.trim();
    if (targetIp.isNotEmpty) {
      try {
        await _webSocketService.connectToServer(targetIp, 8080);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('连接成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('连接失败: $e')),
          );
        }
      }
    }
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && _webSocketService.isConnected) {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.text,
        text: text,
        sender: '发送端',
        timestamp: DateTime.now(),
        isReceived: false,
      );
      _webSocketService.sendMessage(message);
      setState(() {
        _messages.add(message);
      });
      _textController.clear();
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && _webSocketService.isConnected) {
      final bytes = await File(image.path).readAsBytes();
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.image,
        data: Uint8List.fromList(bytes),
        sender: '发送端',
        timestamp: DateTime.now(),
        isReceived: false,
      );
      _webSocketService.sendMessage(message);
      setState(() {
        _messages.add(message);
      });
    }
  }

  Future<void> _startVideoStream() async {
    if (!_webSocketService.isConnected) return;
    
    try {
      await _videoStreamService.startVideoStream();
      
      setState(() {
        _isVideoStreaming = true;
      });
      
      _videoStreamService.onFrameReady = (frameData) {
        if (_webSocketService.isConnected && _isVideoStreaming) {
          print('Sending camera frame, size: ${frameData.length} bytes');
          
          final message = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.videoFrame,
            data: frameData,
            sender: '发送端',
            timestamp: DateTime.now(),
            isReceived: false,
          );
          _webSocketService.sendMessage(message);
        }
      };
    } catch (e) {
      print('Error starting camera: $e');
    }
  }
  ///TODO 1 方案  处理了再发
  ///压缩成 JPEG/PNG 后再发送/显示
  // import 'package:image/image.dart' as img;
  //
  // Uint8List convertToJpeg(Uint8List yuvBytes, int width, int height) {
  //   final image = img.Image.fromBytes(width, height, yuvBytes); // 先把原始 YUV 转 RGB
  //   return Uint8List.fromList(img.encodeJpg(image, quality: 70));
  // }
  //
  //
  // 然后：
  //
  // // 发送
  // final jpegBytes = convertToJpeg(frameData, width, height);
  // _webSocketService.sendBinary(jpegBytes);
  //
  // // 显示
  // Image.memory(jpegBytes);
  void _stopVideoStream() {
    setState(() {
      _isVideoStreaming = false;
    });
    _videoStreamService.stopVideoStream();
    
    // 发送视频结束消息
    if (_webSocketService.isConnected) {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.videoEnd,
        sender: '发送端',
        timestamp: DateTime.now(),
        isReceived: false,
      );
      _webSocketService.sendMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: '目标IP地址',
                    hintText: '192.168.1.100',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _connect(),
                child: const Text('连接'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isDiscovering ? null : _startDiscovery,
                icon: _isDiscovering 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isDiscovering ? '搜索中...' : '搜索设备'),
              ),
              const SizedBox(width: 8),
              Text('发现 ${_discoveredDevices.length} 台设备'),
            ],
          ),
          if (_discoveredDevices.isNotEmpty)
            Container(
              height: 120,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.devices),
                    title: Text(device.name),
                    subtitle: Text('${device.ip}:${device.port}'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        _ipController.text = device.ip;
                        _connect(device.ip);
                      },
                      child: const Text('连接'),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: '输入消息',
                  ),
                ),
              ),
              IconButton(
                onPressed: _sendText,
                icon: const Icon(Icons.send),
              ),
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
              ),
              IconButton(
                onPressed: _isVideoStreaming ? _stopVideoStream : _startVideoStream,
                icon: Icon(_isVideoStreaming ? Icons.videocam_off : Icons.videocam),
                color: _isVideoStreaming ? Colors.red : null,
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _messages.clear();
                  });
                },
                icon: const Icon(Icons.clear_all),
                tooltip: '清空消息',
              ),
            ],
          ),
          if (_isVideoStreaming && _videoStreamService.controller != null && _videoStreamService.controller!.value.isInitialized)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                ///使用插件提供的视频流预览组件
                child: CameraPreview(_videoStreamService.controller!),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Card(
                  color: message.isReceived ? Colors.grey[200] : Colors.blue[100],
                  child: ListTile(
                    title: message.type == MessageType.text
                        ? Text(message.text ?? '')
                        : message.type == MessageType.image
                            ? Image.memory(message.data!, height: 100)
                            : const Text('视频消息'),
                    subtitle: Text('${message.sender} - ${message.timestamp.toString().substring(11, 19)}'),
                    leading: Icon(
                      message.isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                      color: message.isReceived ? Colors.green : Colors.blue,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopVideoStream();
    _webSocketService.disconnect();
    _mdnsService.stopDiscovery();
    super.dispose();
  }
}