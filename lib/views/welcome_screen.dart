import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const WelcomeScreen({super.key, this.onComplete});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _userName = 'Lyhuor'; // Default name

  @override
  void initState() {
    super.initState();
    _loadUserName();

    // Auto navigate to Auth screen after 2 seconds
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          widget.onComplete?.call();
        }
      });
    });
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSettings = prefs.getString('userSettings');
      if (savedSettings != null) {
        final userSettings = jsonDecode(savedSettings);
        if (mounted) {
          setState(() {
            _userName = userSettings['name'] ?? 'Lyhuor';
          });
        }
      }
    } catch (error) {
      print('Error loading user settings: $error');
      if (mounted) {
        setState(() {
          _userName = 'User';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Center(
          child: Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.only(bottom: 40),
                  child: Image.asset(
                    'assets/images/welcome.png',
                    width: 400,
                    height: 400,
                    fit: BoxFit.contain,
                  ),
                ),
                Text(
                  _userName.toUpperCase(), // Display dynamic name in uppercase
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'your minimal budgeting app',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}