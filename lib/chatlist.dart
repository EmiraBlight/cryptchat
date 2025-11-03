import 'package:flutter/material.dart';
import 'dart:convert';
import 'session.dart';
import 'chatpage.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'decrypt_invites.dart';
import 'package:flutter/services.dart';

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
  List<Map<String, String>> _savedChats = [];

  final String? authToken = UserSession.token;

  Future<void> _createGroupChat(List<String> users, String chatName) async {
    final url = Uri.parse("https://srv915664.hstgr.cloud:5000/createchat");
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
                          "https://srv915664.hstgr.cloud:5000/search_users?q=$query",
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

  Future<void> resetTestData() async {
    final storage = const FlutterSecureStorage();

    // Delete saved chats for current user
    await storage.delete(key: 'saved_chats_${UserSession.uid}');

    // Optionally delete private/public keys
    await storage.delete(key: 'private_x25519_${UserSession.uid}');
    await storage.delete(key: 'public_x25519_${UserSession.uid}');

    print("✅ Test data wiped.");
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
          "https://srv915664.hstgr.cloud:5000/search_users?q=$query",
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

  Future<void> _respondToInvite(
    int inviteId,
    bool accepted, {
    String? chatID,
    String? privateKey,
    String? chatName, // optional pre-filled chat name
  }) async {
    final storage = const FlutterSecureStorage();
    final storageKey = 'saved_chats_${UserSession.uid}';

    try {
      if (accepted) {
        if (chatID == null || privateKey == null) {
          throw Exception("Missing chatID or privateKey for accepted invite.");
        }

        String finalChatName = chatName ?? '';

        // Ask user for a local name override
        final nameController = TextEditingController(text: finalChatName);
        if (!mounted) return;

        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Name your chat"),
            content: TextField(
              controller: nameController,
              maxLength: 128,
              decoration: const InputDecoration(hintText: "Enter a chat name"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
                child: const Text("OK"),
              ),
            ],
          ),
        );

        // If user provided a name, use it
        if (result != null && result.isNotEmpty) {
          finalChatName = result;
        }

        // Load existing chats list (if any)
        final existingJson = await storage.read(key: storageKey);
        List<Map<String, String>> savedChats = [];

        if (existingJson != null && existingJson.isNotEmpty) {
          final decoded = jsonDecode(existingJson);
          if (decoded is List) {
            savedChats = decoded
                .whereType<Map>()
                .map(
                  (e) => e.map((k, v) => MapEntry(k.toString(), v.toString())),
                )
                .toList();
          }
        }

        // Add new chat to savedChats
        final newChat = {
          'chatID': chatID,
          'privateKey': privateKey,
          'chatName': finalChatName,
          'createdAt': DateTime.now().toIso8601String(),
        };
        savedChats.add(newChat);

        // Save updated list
        await storage.write(key: storageKey, value: jsonEncode(savedChats));

        // --- Immediately update in-memory chat list for UI ---
        if (mounted) {
          setState(() {
            _savedChats.add(newChat); // Add to in-memory chat list
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Accepted invite and stored chat: $finalChatName"),
              backgroundColor: Colors.green.shade600,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Declined invite ID $inviteId"),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }

      // --- Call deleteinvite API ---
      final url = Uri.parse("https://srv915664.hstgr.cloud:5000/deleteinvite");
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $authToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"invite_id": inviteId}),
      );

      if (response.statusCode != 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to remove invite from server"),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    }
  }

  Future<void> _loadSavedChats() async {
    final storage = const FlutterSecureStorage();
    final storageKey = 'saved_chats_${UserSession.uid}';
    final existingJson = await storage.read(key: storageKey);

    List<Map<String, String>> savedChats = [];
    if (existingJson != null && existingJson.isNotEmpty) {
      final decoded = jsonDecode(existingJson);
      if (decoded is List) {
        savedChats = decoded
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList();
      }
    }

    if (!mounted) return;
    setState(() {
      _savedChats = savedChats;
    });
  }

  Future<void> _fetchInvites() async {
    final url = Uri.parse("https://srv915664.hstgr.cloud:5000/getinvites");
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
      final invites = data["invites"] as List<dynamic>?;

      if (invites == null) {
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

      final decryptedInvites = <Map<String, dynamic>>[];

      for (var inv in invites) {
        try {
          final decrypted = await InviteDecryptor.decryptInvite(
            privateKeyUserId: privateKeyBase64,
            serverPubKeyBase64: inv['server_pubkey'],
            ciphertextBase64: inv['ciphertext'],
            nonceBase64: inv['nonce'],
          );

          final parts = decrypted.split(';');
          final createdAtStr = inv['created_at'] ?? '';
          DateTime? createdAt;
          String timeDisplay = "Unknown time";

          if (createdAtStr.isNotEmpty) {
            createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
            if (createdAt != null) {
              final diff = DateTime.now().difference(createdAt);
              if (diff.inSeconds < 60) {
                timeDisplay = "${diff.inSeconds}s ago";
              } else if (diff.inMinutes < 60) {
                timeDisplay = "${diff.inMinutes}m ago";
              } else if (diff.inHours < 24) {
                timeDisplay = "${diff.inHours}h ago";
              } else {
                timeDisplay = DateFormat('MMM d').format(createdAt);
              }
            }
          }

          final invMap = {
            'id': inv['id'],
            'chatID': parts.length > 0 ? parts[0] : '',
            'invitingUser': parts.length > 1 ? parts[1] : '',
            'privateKey': parts.length > 2 ? parts[2] : '',
            'chatName': parts.length > 3 ? parts[3] : '',
            'createdAt': createdAtStr,
            'timeDisplay': timeDisplay,
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
          title: const Text("Invitations"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: decryptedInvites.length,
              itemBuilder: (context, index) {
                final inv = decryptedInvites[index];

                if (inv.containsKey('error')) {
                  return Card(
                    color: Colors.red.shade50,
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
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                inv['chatName']?.isNotEmpty == true
                                    ? inv['chatName']
                                    : "Unnamed Chat",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              inv['timeDisplay'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Invited by: ${inv['invitingUser'] ?? 'Unknown'}",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text("Decline"),
                              onPressed: () async {
                                await _respondToInvite(
                                  inv['id'],
                                  true,
                                  chatID: inv['chatID'],
                                  privateKey: inv['privateKey'],
                                  chatName: inv['chatName'],
                                );
                                Navigator.pop(context);
                              },
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              label: const Text("Accept"),
                              onPressed: () async {
                                await _respondToInvite(
                                  inv['id'],
                                  true,
                                  chatID: inv['chatID'],
                                  privateKey: inv['privateKey'],
                                  chatName: inv['chatName'],
                                );
                                Navigator.pop(context);
                              },
                            ),
                          ],
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
  void initState() {
    super.initState();
    _loadSavedChats();
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
            onPressed: _fetchInvites,
          ),
          // Show private key
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: 'Show Private Key',
            onPressed: _showPrivateKey,
          ),
          // Create new group chat
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: "New Group Chat",
            onPressed: _showCreateGroupDialog,
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _savedChats.isEmpty
          ? const Center(
              child: Text(
                'No chats yet. Accept an invite or create a group!',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: _savedChats.length,
              itemBuilder: (context, index) {
                final chat = _savedChats[index];
                print(chat);
                final chatName = chat['chatName'] ?? 'Unnamed Chat';
                return ListTile(
                  title: Text(chatName),
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          username: widget.username,
                          chatName: chatName,
                          chatID: chat['chatID']!,
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
