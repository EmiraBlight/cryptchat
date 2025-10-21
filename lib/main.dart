import 'package:flutter/material.dart';

void main() {
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
      title: 'Multi-Chat App',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: _username == null
          ? LoginPage(onLogin: _login)
          : ChatListPage(username: _username!, onLogout: _logout),
    );
  }
}



class LoginPage extends StatefulWidget {
  final void Function(String username) onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorText;

  // Temporary hardcoded users (replace with API call later)
  final Map<String, String> _users = {
    'alice': 'password123',
    'bob': 'hunter2',
    'charlie': 'letmein',
  };

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Please enter both fields.');
      return;
    }

    final valid = _users[username] == password;

    if (valid) {
      widget.onLogin(username);
    } else {
      setState(() => _errorText = 'Invalid username or password.');
    }

    // If you had an API, you’d replace this block with something like:
    /*
    final response = await http.post(
      Uri.parse('https://yourserver.com/api/login'),
      body: {'username': username, 'password': password},
    );
    if (response.statusCode == 200) {
      widget.onLogin(username);
    } else {
      setState(() => _errorText = 'Login failed');
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _handleLogin,
                child: const Text("Login"),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ]
            ],
          ),
        ),
      ),
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
        title: Text("Chats (${username})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: onLogout,
          )
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
                  builder: (_) => ChatPage(
                    username: username,
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


class ChatPage extends StatefulWidget {
  final String username;
  final String chatPartner;

  const ChatPage({
    super.key,
    required this.username,
    required this.chatPartner,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = []; // {sender, text}

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': widget.username, 'text': text});
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with ${widget.chatPartner}")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[_messages.length - 1 - index];
                final isMe = msg['sender'] == widget.username;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.blueAccent.shade100
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text']!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey.shade200,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
