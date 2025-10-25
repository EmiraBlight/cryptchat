import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
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
  final List<String> _chats = ['Alice', 'Bob', 'Charlie', 'SupportBot'];
  final String? authToken = UserSession.token;

  // --- For user search ---
  List<String> _searchResults = [];
  Timer? _debounce;
  bool _isSearching = false;

  Future<void> _searchUsers(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.isEmpty) {
        setState(() => _searchResults = []);
        return;
      }

      setState(() => _isSearching = true);
      try {
        final url = Uri.parse(
          "http://srv915664.hstgr.cloud:5000/search_users?q=$query",
        );
        final response = await http.get(
          url,
          headers: {"Authorization": "Bearer $authToken"},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _searchResults = List<String>.from(data["results"]);
          });
        } else {
          setState(() => _searchResults = []);
        }
      } catch (_) {
        setState(() => _searchResults = []);
      } finally {
        setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _showCreateGroupDialog() async {
    final TextEditingController usersController = TextEditingController();
    final FocusNode usersFocusNode = FocusNode();
    final List<String> selectedUsers = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text("Create Group Chat"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RawAutocomplete<String>(
                    textEditingController: usersController,
                    focusNode: usersFocusNode,
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      final query = textEditingValue.text.trim();
                      if (query.isEmpty) return const Iterable<String>.empty();

                      try {
                        final url = Uri.parse(
                          "http://srv915664.hstgr.cloud:5000/search_users?q=$query",
                        );
                        final response = await http.get(
                          url,
                          headers: {"Authorization": "Bearer $authToken"},
                        );

                        if (response.statusCode == 200) {
                          final data = jsonDecode(response.body);
                          final results = List<String>.from(
                            data["results"] ?? [],
                          );
                          // Exclude users already selected
                          return results
                              .where((u) => !selectedUsers.contains(u))
                              .toList();
                        }
                      } catch (_) {}
                      return const Iterable<String>.empty();
                    },
                    displayStringForOption: (option) => option,
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: "Search usernames...",
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => onFieldSubmitted(),
                          );
                        },
                    optionsViewBuilder:
                        (context, onSelected, Iterable<String> options) {
                          final query = usersController.text
                              .trim()
                              .toLowerCase();

                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    final lowerOption = option.toLowerCase();
                                    final matchIndex = lowerOption.indexOf(
                                      query,
                                    );

                                    // If the query is found, split the text into before/match/after
                                    if (matchIndex != -1 && query.isNotEmpty) {
                                      final before = option.substring(
                                        0,
                                        matchIndex,
                                      );
                                      final match = option.substring(
                                        matchIndex,
                                        matchIndex + query.length,
                                      );
                                      final after = option.substring(
                                        matchIndex + query.length,
                                      );

                                      return ListTile(
                                        title: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              color: Colors.black,
                                            ),
                                            children: [
                                              TextSpan(text: before),
                                              TextSpan(
                                                text: match,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              TextSpan(text: after),
                                            ],
                                          ),
                                        ),
                                        onTap: () => onSelected(option),
                                      );
                                    } else {
                                      // fallback if query is empty
                                      return ListTile(
                                        title: Text(option),
                                        onTap: () => onSelected(option),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                    onSelected: (String selected) {
                      setLocalState(() {
                        if (!selectedUsers.contains(selected)) {
                          selectedUsers.add(selected);
                        }
                        usersController.clear();
                        usersFocusNode.requestFocus();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: selectedUsers
                        .map(
                          (user) => Chip(
                            label: Text(user),
                            onDeleted: () => setLocalState(() {
                              selectedUsers.remove(user);
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    usersFocusNode.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: selectedUsers.isEmpty
                      ? null
                      : () async {
                          usersFocusNode.dispose();
                          Navigator.pop(context);
                          await _createGroupChat(selectedUsers);
                        },
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
