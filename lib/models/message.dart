import 'dart:typed_data';

enum MessageType { text, image, video, videoFrame }

class Message {
  final String id;
  final MessageType type;
  final String? text;
  final Uint8List? data;
  final String sender;
  final DateTime timestamp;
  final bool isReceived;

  Message({
    required this.id,
    required this.type,
    this.text,
    this.data,
    required this.sender,
    required this.timestamp,
    required this.isReceived,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'text': text,
    'data': data?.toList(),
    'sender': sender,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'],
    type: MessageType.values.firstWhere((e) => e.name == json['type']),
    text: json['text'],
    data: json['data'] != null ? Uint8List.fromList(List<int>.from(json['data'])) : null,
    sender: json['sender'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    isReceived: true,
  );
}