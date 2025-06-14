import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  bool _refreshing = false;
  int _selectedCard = 0;
  double _totalBalance = 0;

  // Color palette matching HomeScreen
  final Color _primaryColor = const Color(0xFF2C3E50);
  final Color _secondaryColor = const Color(0xFF999999);
  final Color _accentColor = const Color(0xFF007AFF);
  final Color _backgroundColor = const Color(0xFFFEFEFF);
  final Color _surfaceColor = const Color(0xFFFFFFFF);
  final Color _cardColor = const Color(0xFFF8F8FA);
  final Color _borderColor = const Color(0xFFF0F0F0);
  final Color _successColor = const Color(0xFF4CAF50);

  List<Map<String, dynamic>> _walletCards = [];

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedWallets = prefs.getString('wallets');

      if (storedWallets != null && storedWallets.isNotEmpty) {
        final decodedData = jsonDecode(storedWallets);

        if (decodedData is List) {
          final parsedWallets = decodedData.map((w) {
            return {
              'id': w['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'type': w['type'] ?? 'Wallet',
              'balance': (w['balance'] is num) ? w['balance'].toDouble() : 0.0,
              'cardNumber': w['cardNumber'] ?? '•••• •••• •••• ••••',
              'gradient': _parseGradient(w['gradient']),
              'icon': _parseIcon(w['icon']),
            };
          }).toList();

          setState(() {
            _walletCards = parsedWallets.cast<Map<String, dynamic>>();
            _totalBalance = _walletCards.fold<double>(0, (sum, card) => sum + card['balance']);
          });
        }
      } else {
        // Default wallets if none exist
        setState(() {
          _walletCards = [
            {
              'id': 1,
              'type': 'Main Wallet',
              'balance': 2450.75,
              'cardNumber': '•••• •••• •••• 1234',
              'gradient': [const Color(0xFF007AFF), const Color(0xFF00B4FF)],
              'icon': Icons.account_balance_wallet_rounded
            },
            {
              'id': 2,
              'type': 'Savings',
              'balance': 8920.50,
              'cardNumber': '•••• •••• •••• 5678',
              'gradient': [const Color(0xFF4CAF50), const Color(0xFF8BC34A)],
              'icon': Icons.savings_rounded
            },
            {
              'id': 3,
              'type': 'Business',
              'balance': 15670.25,
              'cardNumber': '•••• •••• •••• 9012',
              'gradient': [const Color(0xFF9C27B0), const Color(0xFFE91E63)],
              'icon': Icons.business_center_rounded
            },
          ];
          _totalBalance = _walletCards.fold<double>(0, (sum, card) => sum + card['balance']);
        });
      }
    } catch (error) {
      debugPrint('Error loading wallet data: $error');
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  List<Color> _parseGradient(dynamic gradientData) {
    if (gradientData is List && gradientData.length >= 2) {
      try {
        return [
          Color(int.parse(gradientData[0].toString().replaceAll('#', ''), radix: 16)),
          Color(int.parse(gradientData[1].toString().replaceAll('#', ''), radix: 16))
        ];
      } catch (e) {
        debugPrint('Error parsing gradient: $e');
      }
    }
    // Default gradient if parsing fails
    return [const Color(0xFF007AFF), const Color(0xFF00B4FF)];
  }

  IconData _parseIcon(dynamic iconData) {
    if (iconData is IconData) {
      return iconData;
    }
    // Default icon if parsing fails
    return Icons.account_balance_wallet_rounded;
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _loadWalletData();
  }

  void _handleCardPress(int index) {
    setState(() => _selectedCard = index);
  }

  Widget _buildWalletCard(Map<String, dynamic> card, bool isSelected, VoidCallback onPress) {
    return GestureDetector(
      onTap: onPress,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.15 : 0.05),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: card['gradient'],
              ),
            ),
            height: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          card['icon'],
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      card['type'],
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(card['balance'])}',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  card['cardNumber'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Wallet',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Manage your finances',
                        style: TextStyle(
                          fontSize: 16,
                          color: _secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: _accentColor,
                child: _loading
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF007AFF)),
                      SizedBox(height: 10),
                      Text(
                        'Loading...',
                        style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                      ),
                    ],
                  ),
                )
                    : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Balance Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Balance',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _secondaryColor,
                                  ),
                                ),
                                Icon(
                                  Icons.visibility_outlined,
                                  color: _secondaryColor,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(_totalBalance)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  color: _successColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '+2.5% from last month',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _successColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Your Cards Section
                      Text(
                        'Your Cards',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _walletCards.length,
                          itemBuilder: (context, index) {
                            final card = _walletCards[index];
                            final isSelected = _selectedCard == index;
                            return _buildWalletCard(
                              card,
                              isSelected,
                                  () => _handleCardPress(index),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}