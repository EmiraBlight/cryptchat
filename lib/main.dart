import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';

import 'session.dart';
import 'login.dart';
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

class ChatListPage extends StatefulWidget {
  final String username;
  final VoidCallback onLogout;

  const ChatListPage({
    super.key,
    required this.username,
    required this.onLogout,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  // Example chat list
  final List<String> _chats = ['Alice', 'Bob', 'Charlie', 'SupportBot'];

  // TODO: replace this with your actual session token logic
  final String? authToken = UserSession.token;

  /// Prompts user to enter usernames and creates group chat
  Future<void> _showCreateGroupDialog() async {
    final TextEditingController usersController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Group Chat"),
        content: TextField(
          controller: usersController,
          decoration: const InputDecoration(
            hintText: "Enter usernames separated by commas",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final userInput = usersController.text.trim();
              if (userInput.isEmpty) return;
              final users = userInput.split(',').map((u) => u.trim()).toList();

              Navigator.pop(context);
              await _createGroupChat(users);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  /// Sends POST request to backend to create group
  Future<void> _createGroupChat(List<String> users) async {
    final url = Uri.parse("http://srv915664.hstgr.cloud:5000/createchat");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({"users ": users}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Group chat created successfully!")),
        );

        // Optionally update the chat list with new group
        setState(() {
          _chats.add("Group (${users.join(', ')})");
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chats (${UserSession.username})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: "New Group Chat",
            onPressed: _showCreateGroupDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chatPartner = _chats[index];
          return ListTile(
            title: Text(chatPartner),
            leading: const CircleAvatar(child: Icon(Icons.person)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    username: widget.username,
                    chatPartner: chatPartner,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
