import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _userSettings = {
    'name': 'Lyhuor',
    'email': 'lyhuor@example.com',
    'phone': '+855 12 345 678',
    'currency': 'USD',
    'profileImage': null,
    'notifications': true,
    'faceId': false,
    'darkMode': false,
    'autoBackup': true,
  };

  bool _showEditModal = false;
  bool _showCurrencyModal = false;
  bool _showExportModal = false;
  bool _showClearDataModal = false;
  bool _showHelpModal = false;
  bool _showAboutModal = false;
  String _editField = '';
  String _editValue = '';
  bool _loading = false;

  final Map<String, Color> _colors = {
    'PRIMARY': const Color(0xFF2C3E50),
    'SECONDARY': const Color(0xFF999999),
    'BACKGROUND': const Color(0xFFFEFEFF),
    'CARD_BG': const Color(0xFFF8F8FA),
    'BLUE': const Color(0xFF007AFF),
    'GREEN': const Color(0xFFB6DBAD),
    'RED': const Color(0xFFFEB8A8),
    'WHITE': const Color(0xFFFFFFFF),
  };

  final List<Map<String, String>> _currencies = [
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'KHR', 'symbol': '៛', 'name': 'Cambodian Riel'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
  ];

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  String _generateAvatar(String name) {
    final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join().toUpperCase();
    return initials.isNotEmpty ? initials : 'U';
  }

  Future<bool> _requestPermissions() async {
    return true; // Permissions are handled automatically by image_picker in Flutter
  }

  Future<void> _pickImage() async {
    final hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _openCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.pop(context);
                _openImageLibrary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image != null) {
      final newSettings = {..._userSettings, 'profileImage': image.path};
      await _saveUserSettings(newSettings);
    }
  }

  Future<void> _openImageLibrary() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final newSettings = {..._userSettings, 'profileImage': image.path};
      await _saveUserSettings(newSettings);
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSettings = prefs.getString('userSettings');
      if (savedSettings != null) {
        setState(() {
          _userSettings = jsonDecode(savedSettings);
        });
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error loading user settings: $error');
    }
  }

  Future<void> _saveUserSettings(Map<String, dynamic> newSettings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userSettings', jsonEncode(newSettings));
      setState(() {
        _userSettings = newSettings;
      });
    } catch (error) {
      // ignore: avoid_print
      print('Error saving user settings: $error');
    }
  }

  void _handleEditField(String field, String currentValue) {
    setState(() {
      _editField = field;
      _editValue = currentValue;
      _editController.text = currentValue;
      _showEditModal = true;
    });
  }

  void _handleSaveEdit() {
    if (_editValue.trim().isNotEmpty) {
      final newSettings = {..._userSettings, _editField: _editValue.trim()};
      _saveUserSettings(newSettings);
      setState(() {
        _showEditModal = false;
        _editField = '';
        _editValue = '';
        _editController.clear();
      });
    }
  }

  void _handleToggleSetting(String setting) {
    final newSettings = {..._userSettings, setting: !_userSettings[setting]};
    _saveUserSettings(newSettings);
  }

  void _handleSelectCurrency(Map<String, String> currency) {
    final newSettings = {..._userSettings, 'currency': currency['code']};
    _saveUserSettings(newSettings);
    setState(() => _showCurrencyModal = false);
  }

  Future<void> _handleExportData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactions = prefs.getString('transactions');
      if (transactions != null) {
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _loading = false;
          _showExportModal = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export Successful: Data prepared for download.')),
        );
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Data: No transaction data found to export.')),
        );
      }
    } catch (error) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Failed to export data.')),
      );
    }
  }

  Future<void> _handleClearData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      setState(() {
        _showClearDataModal = false;
        _userSettings = {
          'name': 'Lyhuor',
          'email': 'lyhuor@example.com',
          'phone': '+855 12 345 678',
          'currency': 'USD',
          'profileImage': null,
          'notifications': true,
          'faceId': false,
          'darkMode': false,
          'autoBackup': true,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Success: All data has been cleared.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Failed to clear data.')),
      );
    }
  }

  Widget _buildProfileItem({
    required String icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? rightElement,
    bool showArrow = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _colors['CARD_BG'],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, color: _colors['PRIMARY']),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 14, color: _colors['SECONDARY']),
                      ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                if (rightElement != null) rightElement,
                if (showArrow)
                  Text(
                    '›',
                    style: TextStyle(fontSize: 20, color: _colors['SECONDARY']),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomModal({
    required String title,
    required Widget content,
    bool showActions = true,
    VoidCallback? onConfirm,
    String confirmText = 'Save',
    bool isDanger = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 20, color: _colors['PRIMARY']),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _colors['CARD_BG'],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          '✕',
                          style: TextStyle(fontSize: 16, color: _colors['SECONDARY']),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: content,
                ),
              ),
              if (showActions)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          decoration: BoxDecoration(
                            color: _colors['CARD_BG'],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Cancel',
                            style: TextStyle(fontSize: 16, color: _colors['SECONDARY']),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onConfirm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          decoration: BoxDecoration(
                            color: isDanger ? _colors['RED'] : _colors['BLUE'],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            confirmText,
                            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors['BACKGROUND'],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(fontSize: 33, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage your account',
                    style: TextStyle(fontSize: 16, color: _colors['SECONDARY']),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _colors['BLUE'],
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: _userSettings['profileImage'] != null
                                      ? ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Image.file(
                                      File(_userSettings['profileImage']),
                                      fit: BoxFit.cover,
                                      width: 60,
                                      height: 60,
                                    ),
                                  )
                                      : Center(
                                    child: Text(
                                      _generateAvatar(_userSettings['name']),
                                      style: const TextStyle(fontSize: 24, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text('📷', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _colors['GREEN'],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userSettings['name'],
                                  style: TextStyle(fontSize: 20, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _userSettings['email'],
                                  style: TextStyle(fontSize: 14, color: _colors['SECONDARY']),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _handleEditField('name', _userSettings['name']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _colors['CARD_BG'],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Edit',
                                style: TextStyle(fontSize: 14, color: _colors['BLUE']),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: TextStyle(fontSize: 18, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          _buildProfileItem(
                            icon: '📧',
                            title: 'Email',
                            subtitle: _userSettings['email'],
                            onTap: () => _handleEditField('email', _userSettings['email']),
                          ),
                          _buildProfileItem(
                            icon: '📱',
                            title: 'Phone',
                            subtitle: _userSettings['phone'],
                            onTap: () => _handleEditField('phone', _userSettings['phone']),
                          ),
                          _buildProfileItem(
                            icon: '💰',
                            title: 'Currency',
                            subtitle:
                            '${_userSettings['currency']} (${_currencies.firstWhere((c) => c['code'] == _userSettings['currency'], orElse: () => {'symbol': '\$'})['symbol']})',
                            onTap: () => setState(() => _showCurrencyModal = true),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security',
                            style: TextStyle(fontSize: 18, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          _buildProfileItem(
                            icon: '🔒',
                            title: 'Face ID / Touch ID',
                            subtitle: 'Secure app access',
                            rightElement: Switch(
                              value: _userSettings['faceId'],
                              onChanged: (value) => _handleToggleSetting('faceId'),
                              activeColor: _colors['GREEN'],
                              inactiveTrackColor: const Color(0xFFF0F0F0),
                              thumbColor: WidgetStateProperty.resolveWith<Color>(
                                    (states) => _userSettings['faceId'] ? Colors.white : const Color(0xFFF4F3F4),
                              ),
                            ),
                            showArrow: false,
                          ),
                          _buildProfileItem(
                            icon: '🔑',
                            title: 'Change Password',
                            subtitle: 'Update your password',
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password change functionality would be implemented here.')),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Settings',
                            style: TextStyle(fontSize: 18, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          _buildProfileItem(
                            icon: '🔔',
                            title: 'Notifications',
                            subtitle: 'Push notifications',
                            rightElement: Switch(
                              value: _userSettings['notifications'],
                              onChanged: (value) => _handleToggleSetting('notifications'),
                              activeColor: _colors['GREEN'],
                              inactiveTrackColor: const Color(0xFFF0F0F0),
                              thumbColor: WidgetStateProperty.resolveWith<Color>(
                                    (states) => _userSettings['notifications'] ? Colors.white : const Color(0xFFF4F3F4),
                              ),
                            ),
                            showArrow: false,
                          ),
                          _buildProfileItem(
                            icon: '🌙',
                            title: 'Dark Mode',
                            subtitle: 'Coming soon',
                            rightElement: Switch(
                              value: _userSettings['darkMode'],
                              onChanged: (value) {},
                              activeColor: _colors['GREEN'],
                              inactiveTrackColor: const Color(0xFFF0F0F0),
                              thumbColor: WidgetStateProperty.resolveWith<Color>(
                                    (states) => _userSettings['darkMode'] ? Colors.white : const Color(0xFFF4F3F4),
                              ),
                              inactiveThumbColor: const Color(0xFFF4F3F4),
                            ),
                            showArrow: false,
                          ),
                          _buildProfileItem(
                            icon: '☁️',
                            title: 'Auto Backup',
                            subtitle: 'Backup data automatically',
                            rightElement: Switch(
                              value: _userSettings['autoBackup'],
                              onChanged: (value) => _handleToggleSetting('autoBackup'),
                              activeColor: _colors['GREEN'],
                              inactiveTrackColor: const Color(0xFFF0F0F0),
                              thumbColor: WidgetStateProperty.resolveWith<Color>(
                                    (states) => _userSettings['autoBackup'] ? Colors.white : const Color(0xFFF4F3F4),
                              ),
                            ),
                            showArrow: false,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data & Storage',
                            style: TextStyle(fontSize: 18, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          _buildProfileItem(
                            icon: '📤',
                            title: 'Export Data',
                            subtitle: 'Download your data',
                            onTap: () => setState(() => _showExportModal = true),
                          ),
                          _buildProfileItem(
                            icon: '🗑️',
                            title: 'Clear All Data',
                            subtitle: 'Reset app data',
                            onTap: () => setState(() => _showClearDataModal = true),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support & About',
                            style: TextStyle(fontSize: 18, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          _buildProfileItem(
                            icon: '❓',
                            title: 'Help & Support',
                            subtitle: 'Get help',
                            onTap: () => setState(() => _showHelpModal = true),
                          ),
                          _buildProfileItem(
                            icon: '⭐',
                            title: 'Rate App',
                            subtitle: 'Rate us on App Store',
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Thank you for your feedback!')),
                            ),
                          ),
                          _buildProfileItem(
                            icon: 'ℹ️',
                            title: 'About',
                            subtitle: 'Version 1.0.0',
                            onTap: () => setState(() => _showAboutModal = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_showEditModal) {
      _showCustomModal(
        title: 'Edit ${_editField[0].toUpperCase()}${_editField.substring(1)}',
        content: Column(
          children: [
            TextField(
              controller: _editController,
              onChanged: (value) => setState(() => _editValue = value),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
                ),
                filled: true,
                fillColor: _colors['CARD_BG'],
                contentPadding: const EdgeInsets.all(12),
                hintText: 'Enter $_editField',
              ),
              keyboardType: _editField == 'phone'
                  ? TextInputType.phone
                  : _editField == 'email'
                  ? TextInputType.emailAddress
                  : TextInputType.text,
              textCapitalization: _editField == 'name' ? TextCapitalization.words : TextCapitalization.none,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
          ],
        ),
        onConfirm: _handleSaveEdit,
      );
    } else if (_showCurrencyModal) {
      _showCustomModal(
        title: 'Select Currency',
        content: Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _currencies.length,
            itemBuilder: (context, index) {
              final currency = _currencies[index];
              return GestureDetector(
                onTap: () => _handleSelectCurrency(currency),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _userSettings['currency'] == currency['code']
                        ? const Color(0xFFE8F4FD)
                        : _colors['CARD_BG'],
                    borderRadius: BorderRadius.circular(8),
                    border: _userSettings['currency'] == currency['code']
                        ? Border.all(color: _colors['BLUE']!)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              currency['symbol']!,
                              style: const TextStyle(fontSize: 24),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency['code']!,
                                style: TextStyle(fontSize: 16, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                              ),
                              Text(
                                currency['name']!,
                                style: TextStyle(fontSize: 14, color: _colors['SECONDARY']),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_userSettings['currency'] == currency['code'])
                        Text(
                          '✓',
                          style: TextStyle(fontSize: 18, color: _colors['BLUE'], fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        showActions: false,
      );
    } else if (_showExportModal) {
      _showCustomModal(
        title: 'Export Data',
        content: Column(
          children: [
            const Text(
              '📤',
              style: TextStyle(fontSize: 48),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'This will export all your transaction data, categories, and settings to a downloadable file.',
              style: TextStyle(fontSize: 16, color: const Color(0xFF666666), height: 1.375),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_loading)
              Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF007AFF)),
                  const SizedBox(height: 10),
                  Text(
                    'Preparing your data...',
                    style: TextStyle(fontSize: 16, color: _colors['SECONDARY']),
                  ),
                ],
              ),
          ],
        ),
        onConfirm: _handleExportData,
        confirmText: 'Export',
      );
    } else if (_showClearDataModal) {
      _showCustomModal(
        title: 'Clear All Data',
        content: Column(
          children: [
            const Text(
              '⚠️',
              style: TextStyle(fontSize: 48),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Are you sure?',
              style: TextStyle(fontSize: 18, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'This will permanently delete all your transactions, categories, and settings. This action cannot be undone.',
              style: TextStyle(fontSize: 16, color: const Color(0xFF666666), height: 1.375),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
        onConfirm: _handleClearData,
        confirmText: 'Clear Data',
        isDanger: true,
      );
    } else if (_showHelpModal) {
      _showCustomModal(
        title: 'Help & Support',
        content: Column(
          children: [
            const Text(
              '💬',
              style: TextStyle(fontSize: 48),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _colors['CARD_BG'],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📧 Email Support',
                    style: TextStyle(fontSize: 16, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'support@moneymanager.com',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _colors['CARD_BG'],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💬 Live Chat',
                    style: TextStyle(fontSize: 16, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Available 24/7 for instant help',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _colors['CARD_BG'],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📚 FAQ',
                    style: TextStyle(fontSize: 16, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Find answers to common questions',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: _colors['BLUE'],
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Contact Support',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        showActions: false,
      );
    } else if (_showAboutModal) {
      _showCustomModal(
        title: 'About Money Manager',
        content: Column(
          children: [
            const Text(
              '💰',
              style: TextStyle(fontSize: 48),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Money Manager',
              style: TextStyle(fontSize: 24, color: _colors['PRIMARY'], fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 16, color: const Color(0xFF666666)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'A simple and intuitive way to track your expenses and manage your finances. Built with Flutter for the best mobile experience.',
              style: TextStyle(fontSize: 16, color: const Color(0xFF666666), height: 1.375),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '• Track income and expenses',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                SizedBox(height: 6),
                Text(
                  '• Categorize transactions',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                SizedBox(height: 6),
                Text(
                  '• Visual reports and analytics',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                SizedBox(height: 6),
                Text(
                  '• Data backup and export',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '© 2025 Money Manager. All rights reserved.',
              style: TextStyle(fontSize: 12, color: _colors['SECONDARY']),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: _colors['BLUE'],
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        showActions: false,
      );
    }
  }
}