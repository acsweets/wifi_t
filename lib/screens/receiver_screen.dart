
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../services/mdns_service.dart';
import '../services/camera_frame_decoder.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> with AutomaticKeepAliveClientMixin {
  final _webSocketService = WebSocketService();
  final _mdnsService = MDnsService();
  final _messages = <Message>[];
  final _replyController = TextEditingController();
  String _localIP = '获取中...';
  bool _isAdvertising = false;
  Uint8List? _currentVideoFrame;
  bool _isReceivingVideo = false;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _getLocalIP();
    _webSocketService.onMessageReceived = (message) {
      print('Received message type: ${message.type}, sender: ${message.sender}');
      
      // 添加所有消息到列表用于调试
      setState(() {
        _messages.add(message);
      });
      
      if (message.type == MessageType.videoFrame) {
        print('Video frame received, data length: ${message.data?.length}');
        _decodeAndDisplayFrame(message.data);
      }
    };
  }

  Future<void> _getLocalIP() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      setState(() {
        _localIP = ip ?? '无法获取IP';
      });
    } catch (e) {
      setState(() {
        _localIP = '获取失败';
      });
    }
  }

  Future<void> _startServer() async {
    try {
      await _webSocketService.startServer(8080);
      await _mdnsService.advertiseService(8080);
      setState(() {
        _isAdvertising = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('服务器已启动，并开始广播服务')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败: $e')),
        );
      }
    }
  }
  
  Future<void> _stopServer() async {
    _webSocketService.disconnect();
    _mdnsService.stopDiscovery();
    setState(() {
      _isAdvertising = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('服务器已停止')),
      );
    }
  }

  Future<void> _decodeAndDisplayFrame(List<int>? frameData) async {
    if (frameData == null) return;
    print('解析’frameData');
    try {
      final decodedImage = await CameraFrameDecoder.decodeYUVToImage(
        Uint8List.fromList(frameData), 
        160, 
        120
      );
      
      setState(() {
        _currentVideoFrame = decodedImage;
        _isReceivingVideo = true;
      });
    } catch (e) {
      print('Frame decode error: $e');
    }
  }

  void _sendReply() {
    final text = _replyController.text.trim();
    if (text.isNotEmpty && _webSocketService.isConnected) {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.text,
        text: text,
        sender: '接收端',
        timestamp: DateTime.now(),
        isReceived: false,
      );
      _webSocketService.sendMessage(message);
      setState(() {
        _messages.add(message);
      });
      _replyController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('本机IP: $_localIP'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _isAdvertising ? null : _startServer,
                        child: const Text('启动服务器'),
                      ),
                      ElevatedButton(
                        onPressed: _isAdvertising ? _stopServer : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('停止服务器'),
                      ),
                    ],
                  ),
                  if (_isAdvertising)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('📡 正在广播 mDNS 服务', style: TextStyle(color: Colors.green)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: const InputDecoration(
                    labelText: '回复消息',
                  ),
                ),
              ),
              IconButton(
                onPressed: _sendReply,
                icon: const Icon(Icons.reply),
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
          if (_isReceivingVideo)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _currentVideoFrame != null
                  ? Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('摄像头数据可视化'),
                            Text('大小: ${_currentVideoFrame!.length} 字节'),
                            const SizedBox(height: 10),
                            Container(
                              width: 150,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black),
                              ),
                              child: CustomPaint(
                                painter: DataVisualizationPainter(_currentVideoFrame!),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('等待视频流...',
                        style: TextStyle(fontSize: 16, color: Colors.green),
                      ),
                    ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Card(
                  color: message.isReceived ? Colors.green[100] : Colors.orange[100],
                  child: ListTile(
                    title: message.type == MessageType.text
                        ? Text(message.text ?? '')
                        : message.type == MessageType.image
                            ? Image.memory(message.data!, height: 150)
                            : message.type == MessageType.videoFrame
                                ? const Text('视频消息')
                                : const Text('视频消息'),
                    subtitle: Text('${message.sender} - ${message.timestamp.toString().substring(11, 19)}'),
                    leading: Icon(
                      message.isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                      color: message.isReceived ? Colors.green : Colors.orange,
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
    _webSocketService.disconnect();
    _mdnsService.stopDiscovery();
    super.dispose();
  }
}

class DataVisualizationPainter extends CustomPainter {
  final Uint8List data;
  
  DataVisualizationPainter(this.data);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final pixelWidth = size.width / 150;
    final pixelHeight = size.height / 100;
    
    for (int i = 0; i < data.length && i < 15000; i++) {
      final x = (i % 150) * pixelWidth;
      final y = (i ~/ 150) * pixelHeight;
      final gray = data[i] / 255.0;
      
      paint.color = Color.fromRGBO(
        (gray * 255).round(),
        (gray * 255).round(), 
        (gray * 255).round(),
        1.0
      );
      
      canvas.drawRect(
        Rect.fromLTWH(x, y, pixelWidth, pixelHeight),
        paint
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}