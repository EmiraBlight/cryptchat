import 'package:flutter/material.dart';
import 'dart:convert';
import 'session.dart';
import 'chatpage.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'decrypt_invites.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

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

  Future<void> _createGroupChat(List<String> users, String chatName) async {
    final url = Uri.parse("http://srv915664.hstgr.cloud:5000/createchat");
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        body: jsonEncode({
          "users": users,
          "chatName": chatName, // added field
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Group chat '$chatName' created successfully!"),
          ),
        );
        setState(() {
          _chats.add("$chatName (${users.join(', ')})");
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

  Future<void> _showCreateGroupDialog() async {
    final TextEditingController usersController = TextEditingController();
    final TextEditingController chatNameController = TextEditingController();
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
                  // Chat name input
                  TextField(
                    controller: chatNameController,
                    maxLength: 128,
                    decoration: const InputDecoration(
                      hintText: "Enter chat name (max 128 chars)",
                      prefixIcon: Icon(Icons.chat),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // User autocomplete
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
                        if (!selectedUsers.contains(selected))
                          selectedUsers.add(selected);
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
                  onPressed:
                      selectedUsers.isEmpty ||
                          chatNameController.text.trim().isEmpty
                      ? null
                      : () async {
                          final chatName = chatNameController.text.trim();
                          if (chatName.length > 128) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Chat name cannot exceed 128 characters",
                                ),
                              ),
                            );
                            return;
                          }
                          usersFocusNode.dispose();
                          Navigator.pop(context);
                          await _createGroupChat(selectedUsers, chatName);
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

  Future<void> _showPrivateKey() async {
    final storage = const FlutterSecureStorage();
    final key = await storage.read(key: 'private_x25519_' + UserSession.uid!);

    if (key == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No private key found in secure storage.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        bool isMasked = true;

        String maskKey(String k) {
          if (k.length <= 8) return '*' * k.length;
          final start = k.substring(0, 4);
          final end = k.substring(k.length - 4);
          return '$start${'*' * (k.length - 8)}$end';
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Private Key'),
              content: SingleChildScrollView(
                child: SelectableText(isMasked ? maskKey(key) : key),
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => isMasked = !isMasked),
                  child: Text(isMasked ? 'Show' : 'Hide'),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: key));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Private key copied!')),
                      );
                    }
                  },
                  child: const Text('Copy'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// --- Fetch and decrypt invites ---

  Future<void> _fetchInvites() async {
    final url = Uri.parse("http://srv915664.hstgr.cloud:5000/getinvites");
    final storage = const FlutterSecureStorage();

    // Load user's keys from secure storage
    final privateKeyBase64 = await storage.read(
      key: 'private_x25519_${UserSession.uid}',
    );
    final publicKeyBase64 = await storage.read(
      key: 'public_x25519_${UserSession.uid}',
    );

    if (privateKeyBase64 == null || publicKeyBase64 == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No private/public key found for user')),
      );
      return;
    }

    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $authToken"},
      );

      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
        return;
      }

      final data = jsonDecode(response.body);
      final invites = data["invites"] as List<dynamic>;

      if (invites.isEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Invites"),
            content: const Text("No invites found."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      final decryptedInvites = <Map<String, String>>[];
      for (var inv in invites) {
        try {
          final decrypted = await InviteDecryptor.decryptInvite(
            privateKeyUserId: privateKeyBase64,
            serverPubKeyBase64: inv['server_pubkey'],
            ciphertextBase64: inv['ciphertext'],
            nonceBase64: inv['nonce'],
          );

          final parts = decrypted.split(';');
          final invMap = {
            'chatID': parts.length > 0 ? parts[0] : '',
            'invitingUser': parts.length > 1 ? parts[1] : '',
            'chatPrivateKey': parts.length > 2 ? parts[2] : '',
            'chatName': parts.length > 3 ? parts[3] : 'Unnamed Chat',
          };

          decryptedInvites.add(invMap);
        } catch (e) {
          decryptedInvites.add({'error': "Failed to decrypt invite: $e"});
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Invites"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: decryptedInvites.length,
              itemBuilder: (context, index) {
                final inv = decryptedInvites[index];

                if (inv.containsKey('error')) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        inv['error']!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Chat Name: ${inv['chatName'] ?? 'Unknown'}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Inviting User: ${inv['invitingUser'] ?? 'Unknown'}",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching invites: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chats (${UserSession.username})"),
        actions: [
          // New invites button
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Check Invites',
            onPressed: _fetchInvites, // your fetch & decrypt function
          ),
          // Existing private key button
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: 'Show Private Key',
            onPressed: _showPrivateKey,
          ),
          // Existing create chat button
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: "New Group Chat",
            onPressed: _showCreateGroupDialog,
          ),
          // Logout button
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
