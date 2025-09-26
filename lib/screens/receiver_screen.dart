import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final _webSocketService = WebSocketService();
  final _messages = <Message>[];
  final _replyController = TextEditingController();
  String _localIP = '获取中...';

  @override
  void initState() {
    super.initState();
    _getLocalIP();
    _webSocketService.onMessageReceived = (message) {
      setState(() {
        _messages.add(message);
      });
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('服务器已启动')),
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
                  ElevatedButton(
                    onPressed: _startServer,
                    child: const Text('启动服务器 (端口: 8080)'),
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
            ],
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
    super.dispose();
  }
}