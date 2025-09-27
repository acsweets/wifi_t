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
    try {
      // Release模式下增加端口绑定重试
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
          break;
        } catch (e) {
          retryCount++;
          print('Server bind attempt $retryCount failed: $e');
          if (retryCount >= maxRetries) {
            print('Failed to bind server after $maxRetries attempts');
            rethrow;
          }
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
      
      _server!.transform(WebSocketTransformer()).listen((WebSocket socket) {
        _channel = IOWebSocketChannel(socket);
        _listenToMessages();
      }, onError: (error) {
        print('WebSocket server error: $error');
      });
      
      print('WebSocket server started on port $port');
    } catch (e) {
      print('Failed to start WebSocket server: $e');
      rethrow;
    }
  }

  Future<void> connectToServer(String ip, int port) async {
    try {
      final uri = Uri.parse('ws://$ip:$port');
      
      // Release模式下增加连接超时和重试
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          _channel = WebSocketChannel.connect(
            uri,
            protocols: null,
          );
          
          // 等待连接建立
          await _channel!.ready.timeout(const Duration(seconds: 5));
          _listenToMessages();
          print('Connected to WebSocket server at $ip:$port');
          break;
        } catch (e) {
          retryCount++;
          print('Connection attempt $retryCount failed: $e');
          _channel = null;
          
          if (retryCount >= maxRetries) {
            print('Failed to connect after $maxRetries attempts');
            rethrow;
          }
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }
      }
    } catch (e) {
      print('WebSocket connection error: $e');
      rethrow;
    }
  }

  void _listenToMessages() {
    _channel?.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data);
          final message = Message.fromJson(json);
          onMessageReceived?.call(message);
        } catch (e) {
          print('Message parsing error: $e');
        }
      },
      onError: (error) {
        print('WebSocket stream error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
      },
    );
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