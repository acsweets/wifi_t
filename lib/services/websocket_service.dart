import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/message.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  HttpServer? _server;
  Function(Message)? onMessageReceived;
  
  bool get isConnected => _channel != null;
  bool get isServerRunning => _server != null;

  Future<void> startServer(int port) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.transform(WebSocketTransformer()).listen((WebSocket socket) {
      _channel = IOWebSocketChannel(socket);
      _listenToMessages();
    });
  }

  Future<void> connectToServer(String ip, int port) async {
    final uri = Uri.parse('ws://$ip:$port');
    _channel = WebSocketChannel.connect(uri);
    _listenToMessages();
  }

  void _listenToMessages() {
    _channel?.stream.listen((data) {
      final json = jsonDecode(data);
      final message = Message.fromJson(json);
      onMessageReceived?.call(message);
    });
  }

  void sendMessage(Message message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message.toJson()));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _server?.close();
    _server = null;
  }
}