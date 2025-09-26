import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  final _ipController = TextEditingController();
  final _textController = TextEditingController();
  final _webSocketService = WebSocketService();
  final _messages = <Message>[];
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _webSocketService.onMessageReceived = (message) {
      setState(() {
        _messages.add(message);
      });
    };
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    if (ip.isNotEmpty) {
      try {
        await _webSocketService.connectToServer(ip, 8080);
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

  @override
  Widget build(BuildContext context) {
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
                onPressed: _connect,
                child: const Text('连接'),
              ),
            ],
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
            ],
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
    _webSocketService.disconnect();
    super.dispose();
  }
}