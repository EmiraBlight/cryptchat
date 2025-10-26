import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login.dart';
import 'chatlist.dart';

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
