import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart'; // Importa la schermata principale

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final String backendUrl = "http://10.0.2.2:8000";
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoginMode = true; // True = Login, False = Register
  bool _isLoading = false;
  String _errorMessage = "";
  String _successMessage = "";

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _successMessage = "";
    });

    try {
      if (_isLoginMode) {
        // --- CHIAMATA LOGIN ---
        final response = await http.post(
          Uri.parse('$backendUrl/users/login'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "username": _usernameController.text.trim(),
            "password": _passwordController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          final userData = json.decode(response.body);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(userId: userData['id'], username: userData['username']),
            ),
          );
        } else {
          setState(() {
            _errorMessage = "Invalid username or password.";
          });
        }
      } else {
        // --- CHIAMATA REGISTRAZIONE ---
        final response = await http.post(
          Uri.parse('$backendUrl/users/register'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "username": _usernameController.text.trim(),
            "email": _emailController.text.trim(),
            "password": _passwordController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          setState(() {
            _successMessage = "Registration successful! Please log in.";
            _isLoginMode = true; // Riporta l'utente alla schermata di login
          });
        } else {
          final body = json.decode(response.body);
          setState(() {
            _errorMessage = body['detail'] ?? "Registration failed.";
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoginMode ? 'Urban Food Hunt - Login' : 'Urban Food Hunt - Register'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.storefront, size: 80, color: Colors.orange),
                const SizedBox(height: 20),
                Text(
                  _isLoginMode ? 'Welcome Back!' : 'Create an Account',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                // Mostra il campo Email solo se siamo in modalità Registrazione
                if (!_isLoginMode) ...[
                  const SizedBox(height: 15),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                if (_successMessage.isNotEmpty)
                  Text(
                    _successMessage,
                    style: const TextStyle(color: Colors.green, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _isLoginMode ? 'Login' : 'Register',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                      _errorMessage = "";
                      _successMessage = "";
                    });
                  },
                  child: Text(
                    _isLoginMode
                        ? "Don't have an account? Register here"
                        : "Already have an account? Login here",
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}