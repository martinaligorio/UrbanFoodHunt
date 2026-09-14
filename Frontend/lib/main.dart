import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const UrbanFoodHuntApp());
}

class UrbanFoodHuntApp extends StatelessWidget {
  const UrbanFoodHuntApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Food Hunt',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}