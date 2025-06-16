import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './biometric_auth.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const AuthScreen({
    super.key,
    this.onAuthSuccess,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  String _enteredPin = '';
  String _correctPin = '1234';
  bool _showBiometric = false;
  bool _hasEnrolledFingerprints = false;

  // Profile data
  String _userName = 'User';
  String? _profileImagePath;

  // Colors
  final Color _primaryColor = const Color(0xFF2C3E50);
  final Color _secondaryColor = const Color(0xFF999999);
  final Color _accentColor = const Color(0xFF007AFF);
  final Color _backgroundColor = const Color(0xFFFEFEFF);
  final Color _surfaceColor = const Color(0xFFFFFFFF);
  final Color _borderColor = const Color(0xFFF0F0F0);

  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadProfileData();
    _checkBiometricAvailability();
    _loadPinCode();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPinCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _correctPin = prefs.getString('pinCode') ?? '1234';
    });
  }

  void _initAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSettings = prefs.getString('userSettings');
      if (savedSettings != null) {
        final userSettings = jsonDecode(savedSettings);
        setState(() {
          _userName = userSettings['name'] ?? 'User';
          _profileImagePath = userSettings['profileImage'];
        });
      }
    } catch (error) {
      debugPrint('Error loading profile data: $error');
    }
  }

  String _generateAvatar(String name) {
    final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join().toUpperCase();
    return initials.isNotEmpty ? initials : 'U';
  }

  Future<void> _checkBiometricAvailability() async {
    final result = await BiometricAuth.isBiometricAvailable();
    setState(() {
      _showBiometric = result['isAvailable'] ?? false;
      _hasEnrolledFingerprints = result['hasEnrolledFingerprints'] ?? false;
    });
    if (result['error'] != null) {
      debugPrint('Biometric availability error: ${result['error']}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric setup error: ${result['error']}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_isLoading || !_hasEnrolledFingerprints) {
      debugPrint('Biometric auth skipped: isLoading=$_isLoading, hasEnrolledFingerprints=$_hasEnrolledFingerprints');
      return;
    }

    debugPrint('Initiating biometric authentication');
    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    final result = await BiometricAuth.authenticate();
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      debugPrint('Biometric authentication successful');
      HapticFeedback.lightImpact();
      _onAuthenticationSuccess();
    } else {
      debugPrint('Biometric authentication failed: ${result['error']}');
      HapticFeedback.heavyImpact();
      if (result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4 && !_isLoading) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin += number;
        if (_enteredPin.length == 4) {
          _validatePin();
        }
      });
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty && !_isLoading) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _validatePin() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (_enteredPin == _correctPin) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 1000));
      _onAuthenticationSuccess();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward().then((_) {
        _shakeController.reverse();
      });

      setState(() {
        _enteredPin = '';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Incorrect PIN. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _onAuthenticationSuccess() {
    debugPrint('Authentication success, navigating to main');
    widget.onAuthSuccess?.call();
    Navigator.of(context).pushReplacementNamed('/main');
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _surfaceColor,
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _accentColor,
                        _accentColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _profileImagePath != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.file(
                      File(_profileImagePath!),
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    ),
                  )
                      : Center(
                    child: Text(
                      _generateAvatar(_userName),
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 16,
              color: _secondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _onNumberPressed(number),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    bool isLoading = false,
  }) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onTap,
          child: Center(
            child: isLoading
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  iconColor ?? _accentColor,
                ),
              ),
            )
                : Icon(
              icon,
              size: 24,
              color: iconColor ?? _secondaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final bool isFilled = index < _enteredPin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? _accentColor : Colors.transparent,
            border: Border.all(
              color: isFilled ? _accentColor : _borderColor,
              width: 2,
            ),
            boxShadow: isFilled
                ? [
              BoxShadow(
                color: _accentColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildProfileSection(),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildPinIndicator(),
                        const SizedBox(height: 48),
                        Column(
                          children: [
                            for (int row = 0; row < 3; row++) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  for (int col = 1; col <= 3; col++)
                                    _buildNumberButton('${row * 3 + col}'),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _showBiometric && _hasEnrolledFingerprints
                                    ? _buildActionButton(
                                  icon: Icons.fingerprint,
                                  iconColor: _accentColor,
                                  onTap: _authenticateWithBiometric,
                                  isLoading: _isLoading,
                                )
                                    : const SizedBox(width: 70, height: 70),
                                _buildNumberButton('0'),
                                _buildActionButton(
                                  icon: Icons.backspace_outlined,
                                  onTap: _onDeletePressed,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}