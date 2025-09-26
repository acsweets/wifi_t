import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:camera/camera.dart';
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
      final pngBytes = await CameraFrameDecoder.decodeYUVToImage(Uint8List.fromList(frameData), 160, 120);

      if (pngBytes != null) {
        setState(() {
          _currentVideoFrame = pngBytes;
        });
      }
      
      setState(() {
        // _currentVideoFrame = decodedImage;

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
              height: 220,
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
                            Text('摄像头数据大小: ${_currentVideoFrame!.length} 字节'),
                            const SizedBox(height: 10),
                            Container(
                              width: 100,
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black),
                              ),
                              ///Image.memory(Uint8List) 只能显示 合法的图片编码数据（JPEG、PNG、WebP 等）。
                              // 原始灰度/相机数据 不是 JPEG/PNG，所以 Image.memory(frameData) 无法显示，或者显示是噪点/灰色。
                              // 直接用原始 CameraImage 的 bytes 当作 Image.memory 是不行的。
                              // child: CustomPaint(
                              //   painter: DataVisualizationPainter(_currentVideoFrame!),
                              // ),
                              child: Image.memory(_currentVideoFrame!),
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
  Uint8List convertYUV420ToRGB(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final rgbBytes = Uint8List(width * height * 4); // RGBA

    int yp = 0;
    for (int j = 0; j < height; j++) {
      final uvRow = j ~/ 2;
      for (int i = 0; i < width; i++) {
        final uvCol = i ~/ 2;

        final y = yPlane[yp] & 0xff;
        final u = uPlane[uvRow * (width ~/ 2) + uvCol] & 0xff;
        final v = vPlane[uvRow * (width ~/ 2) + uvCol] & 0xff;

        // YUV -> RGB
        int r = (y + 1.402 * (v - 128)).round();
        int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round();
        int b = (y + 1.772 * (u - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        final index = yp * 4;
        rgbBytes[index] = r;
        rgbBytes[index + 1] = g;
        rgbBytes[index + 2] = b;
        rgbBytes[index + 3] = 255; // alpha

        yp++;
      }
    }
    return rgbBytes;
  }
}
///TODO 使用 camera 插件自带方法
// Uint8List convertYUV420ToRGB(CameraImage image) {
//   final width = image.width;
//   final height = image.height;
//
//   final yPlane = image.planes[0].bytes;
//   final uPlane = image.planes[1].bytes;
//   final vPlane = image.planes[2].bytes;
//
//   final rgbBytes = Uint8List(width * height * 4); // RGBA
//
//   int yp = 0;
//   for (int j = 0; j < height; j++) {
//     final uvRow = j ~/ 2;
//     for (int i = 0; i < width; i++) {
//       final uvCol = i ~/ 2;
//
//       final y = yPlane[yp] & 0xff;
//       final u = uPlane[uvRow * (width ~/ 2) + uvCol] & 0xff;
//       final v = vPlane[uvRow * (width ~/ 2) + uvCol] & 0xff;
//
//       // YUV -> RGB
//       int r = (y + 1.402 * (v - 128)).round();
//       int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round();
//       int b = (y + 1.772 * (u - 128)).round();
//
//       r = r.clamp(0, 255);
//       g = g.clamp(0, 255);
//       b = b.clamp(0, 255);
//
//       final index = yp * 4;
//       rgbBytes[index] = r;
//       rgbBytes[index + 1] = g;
//       rgbBytes[index + 2] = b;
//       rgbBytes[index + 3] = 255; // alpha
//
//       yp++;
//     }
//   }
//   return rgbBytes;
// }

class DataVisualizationPainter extends CustomPainter {
  final Uint8List data;
  
  DataVisualizationPainter(this.data);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const imageWidth = 80;
    const imageHeight = 60;
    final pixelWidth = size.width / imageHeight; // 交换宽高
    final pixelHeight = size.height / imageWidth;
    
    for (int i = 0; i < data.length && i < imageWidth * imageHeight; i++) {
      final srcX = i % imageWidth;
      final srcY = i ~/ imageWidth;
      
      // 旋转-90度：(x,y) -> (height-1-y, x)
      final x = (imageHeight - 1 - srcY) * pixelWidth;
      final y = srcX * pixelHeight;
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