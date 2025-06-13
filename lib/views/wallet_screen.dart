import 'dart:convert';
import 'dart:math';
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
  List<Map<String, dynamic>> _recentTransactions = [];

  final Map<String, Color> _colors = {
    'PRIMARY': const Color(0xFF2C3E50),
    'SECONDARY': const Color(0xFF999999),
    'BACKGROUND': const Color(0xFFFEFEFF),
    'CARD_BG': const Color(0xFFF8F8FA),
    'BLUE': const Color(0xFF007AFF),
    'SUCCESS': const Color(0xFFB6DBAD),
    'WARNING': const Color(0xFFFEB8A8),
    'WHITE': const Color(0xFFFFFFFF),
  };

  final List<Map<String, dynamic>> _walletCards = [
    {
      'id': 1,
      'type': 'Main Wallet',
      'balance': 2450.75,
      'cardNumber': '**** **** **** 1234',
      'gradient': [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      'icon': '💳'
    },
    {
      'id': 2,
      'type': 'Savings',
      'balance': 8920.50,
      'cardNumber': '**** **** **** 5678',
      'gradient': [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      'icon': '🏦'
    },
    {
      'id': 3,
      'type': 'Business',
      'balance': 15670.25,
      'cardNumber': '**** **** **** 9012',
      'gradient': [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      'icon': '💼'
    },
  ];

  final List<Map<String, dynamic>> _quickActions = [
    {'id': 1, 'title': 'Add Money', 'icon': '💰', 'color': const Color(0xFFB6DBAD)},
    {'id': 2, 'title': 'Send', 'icon': '📤', 'color': const Color(0xFF007AFF)},
    {'id': 3, 'title': 'Request', 'icon': '📥', 'color': const Color(0xFFFEB8A8)},
    {'id': 4, 'title': 'Pay Bills', 'icon': '🧾', 'color': const Color(0xFF2C3E50)},
  ];

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Color _generateLightColor() {
    final random = Random();
    final r = 200 + random.nextInt(56);
    final g = 200 + random.nextInt(56);
    final b = 200 + random.nextInt(56);
    return Color.fromRGBO(r, g, b, 1);
  }

  Future<void> _loadWalletData() async {
    setState(() => _loading = true);
    try {
      final total = _walletCards.fold<double>(0, (sum, card) => sum + card['balance']);
      setState(() => _totalBalance = total);

      final prefs = await SharedPreferences.getInstance();
      final storedTransactions = prefs.getString('transactions');
      if (storedTransactions != null) {
        final parsedTransactions = (jsonDecode(storedTransactions) as List)
            .map((t) => {
          ...t,
          'bgColor': t['bgColor'] ?? _generateLightColor().value.toRadixString(16).substring(2),
        })
            .toList();
        setState(() {
          _recentTransactions = parsedTransactions.cast<Map<String, dynamic>>().reversed.take(5).toList();
        });
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error loading wallet data: $error');
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _loadWalletData();
  }

  void _handleCardPress(int index) {
    setState(() => _selectedCard = index);
  }

  void _handleQuickAction(Map<String, dynamic> action) {
    switch (action['title']) {
      case 'Send':
        Navigator.pushNamed(context, '/transfer');
        break;
      case 'Add Money':
      // ignore: avoid_print
        print('Add Money pressed');
        break;
      case 'Request':
      // ignore: avoid_print
        print('Request Money pressed');
        break;
      case 'Pay Bills':
      // ignore: avoid_print
        print('Pay Bills pressed');
        break;
    }
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
              color: Colors.black.withOpacity(isSelected ? 0.2 : 0.1),
              offset: const Offset(0, 2),
              blurRadius: isSelected ? 8 : 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: card['gradient'][0],
            ),
            height: 160,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      card['icon'],
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
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
                    const Text(
                      'Available Balance',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(card['balance'])}',
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  card['cardNumber'],
                  style: const TextStyle(fontSize: 14, color: Colors.white70, letterSpacing: 1),
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
      backgroundColor: _colors['BACKGROUND'],
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
                          fontSize: 33,
                          color: _colors['PRIMARY'],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Manage your finances',
                        style: TextStyle(
                          fontSize: 16,
                          color: _colors['SECONDARY'],
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _colors['CARD_BG'],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          '⚙️',
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: _colors['BLUE'],
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
                      Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.only(bottom: 30),
                        decoration: BoxDecoration(
                          color: _colors['PRIMARY'],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Balance',
                              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2).format(_totalBalance)}',
                              style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  '📈',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '+2.5% from last month',
                                  style: TextStyle(fontSize: 14, color: _colors['SUCCESS']),
                                ),
                              ],
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
                              'Your Cards',
                              style: TextStyle(fontSize: 18, color: _colors['PRIMARY']),
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
                      Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Actions',
                              style: TextStyle(fontSize: 18, color: _colors['PRIMARY']),
                            ),
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                              itemCount: _quickActions.length,
                              itemBuilder: (context, index) {
                                final action = _quickActions[index];
                                return GestureDetector(
                                  onTap: () => _handleQuickAction(action),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
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
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: action['color'].withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                          child: Center(
                                            child: Text(
                                              action['icon'],
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          action['title'],
                                          style: TextStyle(fontSize: 14, color: _colors['PRIMARY']),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Activity',
                                  style: TextStyle(fontSize: 18, color: _colors['PRIMARY']),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, '/transfer'),
                                  child: Text(
                                    'See All →',
                                    style: TextStyle(fontSize: 14, color: _colors['BLUE']),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _loading
                                ? const Center(
                              child: CircularProgressIndicator(color: Color(0xFF007AFF)),
                            )
                                : _recentTransactions.isEmpty
                                ? Center(
                              child: Column(
                                children: [
                                  const Text(
                                    '📱',
                                    style: TextStyle(fontSize: 40),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No recent activity',
                                    style: TextStyle(fontSize: 16, color: _colors['SECONDARY']),
                                  ),
                                ],
                              ),
                            )
                                : Column(
                              children: _recentTransactions.map((transaction) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(16),
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
                                              color: Color(
                                                  int.parse('FF${transaction['bgColor']}', radix: 16)),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                transaction['icon'],
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                transaction['category'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _colors['PRIMARY'],
                                                ),
                                              ),
                                              Text(
                                                DateFormat.yMd().format(
                                                    DateTime.parse(transaction['date'])),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _colors['SECONDARY'],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${transaction['amount'] > 0 ? '+' : '-'}\$${transaction['amount'].abs().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: transaction['amount'] > 0
                                              ? _colors['SUCCESS']
                                              : _colors['WARNING'],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
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