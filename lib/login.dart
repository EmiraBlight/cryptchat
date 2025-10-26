import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'session.dart';
import 'signup.dart';
import 'keys.dart';

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
      // Sign in with Firebase
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('User not found');

      // Ensure private key exists for this user
      final hasKeys = await KeyManager.keysExist(user.uid);
      if (!hasKeys) {
        await FirebaseAuth.instance.signOut();
        setState(
          () => _errorText =
              'Private key not found on this device. You can only log in from a device where this account was created.',
        );
        return;
      }

      final idToken = await user.getIdToken();
      UserSession.token = idToken;

      // Fetch username from backend
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
        UserSession.email = user.email;
        UserSession.uid = user.uid;

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
                      child: const Text("Login"),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SignupPage(
                        onSignedUp: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
                child: const Text("Don't have an account? Sign up here."),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(_errorText!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
