import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session.dart';


import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ChatApp());
}


const backendBaseUrl = 'http://srv915664.hstgr.cloud:5000';

Future<String?> fetchUsername() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse('$backendBaseUrl/getusername'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'success') {
      print('Username: ${data['username']}');
      return data['username'];
    } else {
      print('Failed to get username: $data');
      return null;
    }
  } catch (e) {
    print('Error fetching username: $e');
    return null;
  }
}

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  String? _username;

  void _login(String username)  {
    
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



class LoginPage extends StatefulWidget {
  final void Function(String username) onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;
  bool _loading = false;

  Future<void> _handleLogin() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    setState(() => _errorText = 'Please enter both fields.');
    return;
  }

  setState(() {
    _loading = true;
    _errorText = null;
  });

  try {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    final idToken = await user?.getIdToken();

    if (idToken == null) throw Exception('Failed to get token');
    final response = await http.post(
      Uri.parse('http://srv915664.hstgr.cloud:5000/getusername'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'success') {
      UserSession.username = data['username'];
      UserSession.email = user?.email;
      UserSession.uid = user?.uid;

      widget.onLogin(data['username']);
    } else {
      setState(() => _errorText = data['error'] ?? 'Login failed.');
    }
  } on FirebaseAuthException catch (e) {
    setState(() => _errorText = e.message ?? 'Invalid email or password.');
  } catch (e) {
    setState(() => _errorText = 'Unexpected error: $e');
  } finally {
    setState(() => _loading = false);
  }
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
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      child: const Text("Login / Sign Up"),
                    ),
                    TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignupPage(onSignedUp: () {
          Navigator.pop(context);
        }),
      ),
    );
  },
  child: const Text("Don't have an account? Sign up here."),
),

              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
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
        title: Text("Chats (${UserSession.username})"),
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



class SignupPage extends StatefulWidget {
  final VoidCallback onSignedUp;

  const SignupPage({super.key, required this.onSignedUp});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _errorText;
  bool _loading = false;

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorText = 'Please fill all fields.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _promptUsername();

    } on FirebaseAuthException catch (e) {
      print("Signup error code: ${e.code}, message: ${e.message}");
      setState(() => _errorText = e.message ?? 'Sign-up failed.');
    } catch (e) {
      setState(() => _errorText = 'Unexpected error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _promptUsername() async {
    _usernameController.text = '';
    bool usernameSet = false;

    while (!usernameSet) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Choose a username"),
          content: TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, _usernameController.text.trim()),
              child: const Text("Save"),
            ),
          ],
        ),
      );

      if (result == null || result.isEmpty) {
        setState(() => _errorText = 'Username cannot be empty.');
        return;
      }

      setState(() => _loading = true);

      try {
        final user = FirebaseAuth.instance.currentUser!;
        final idToken = await user.getIdToken();

        final response = await http.post(
          Uri.parse('http://srv915664.hstgr.cloud:5000/users'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'username': result}),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 200 && data['status'] == 'success') {
          usernameSet = true;
          widget.onSignedUp(); // finish signup flow
        } else {
          setState(() => _errorText = data['error'] ?? 'Username failed.');
        }
      } catch (e) {
        setState(() => _errorText = 'Could not reach backend: $e');
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleSignup,
                      child: const Text("Create Account"),
                    ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

