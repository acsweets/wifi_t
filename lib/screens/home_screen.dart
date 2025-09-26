import 'package:flutter/material.dart';
import 'sender_screen.dart';
import 'receiver_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('局域网通信'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '发送端', icon: Icon(Icons.send)),
              Tab(text: '接收端', icon: Icon(Icons.inbox)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SenderScreen(),
            ReceiverScreen(),
          ],
        ),
      ),
    );
  }
}