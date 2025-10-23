import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';

import 'session.dart';
import 'login.dart';
import 'signup.dart';
import 'chatpage.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ChatApp());
}

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  String? _username;

  void _login(String username) {
    setState(() => _username = username);
  }

  void _logout() {
    setState(() => _username = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CryptChat',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: _username == null
          ? LoginPage(onLogin: _login)
          : ChatListPage(username: _username!, onLogout: _logout),
    );
  }
}

class ChatListPage extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;

  const ChatListPage({
    super.key,
    required this.username,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    // Example chat list
    final chats = ['Alice', 'Bob', 'Charlie', 'SupportBot'];

    return Scaffold(
      appBar: AppBar(
        title: Text("Chats (${UserSession.username})"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: onLogout),
        ],
      ),
      body: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chatPartner = chats[index];
          return ListTile(
            title: Text(chatPartner),
            leading: const CircleAvatar(child: Icon(Icons.person)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatPage(username: username, chatPartner: chatPartner),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
