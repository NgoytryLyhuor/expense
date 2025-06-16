import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  String _selectedPeriod = 'Daily';
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _loading = true;
  bool _refreshing = false;
  double _totalIncome = 0;
  double _totalSpent = 0;
  String _userName = 'Lyhuor';
  String? _userProfileImage; // Add this to store profile image path

  final List<String> _periods = ['All', 'Daily', 'Weekly', 'Monthly'];
  final Color _spentColor = const Color(0xFFFEB8A8);
  final Color _incomeColor = const Color(0xFFB6DBAD);
  final Color _accentColor = const Color(0xFF007AFF);

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadTransactions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload transactions and user name when returning from other screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserName();
      _loadTransactions();
    });
  }

  // Updated method to load both user name and profile image
  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSettings = prefs.getString('userSettings');
      if (savedSettings != null) {
        final userSettings = jsonDecode(savedSettings);
        if (mounted) {
          setState(() {
            _userName = userSettings['name'] ?? 'User';
            _userProfileImage = userSettings['profileImage']; // Load profile image
          });
        }
      }
    } catch (error) {
      print('Error loading user settings: $error');
      if (mounted) {
        setState(() {
          _userName = 'User';
          _userProfileImage = null;
        });
      }
    }
  }

  // Helper method to generate avatar initials
  String _generateAvatar(String name) {
    final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join().toUpperCase();
    return initials.isNotEmpty ? initials : 'U';
  }

  // Helper method to build profile widget
  Widget _buildProfileWidget() {
    return GestureDetector(
      onTap: () {
        // You can navigate to profile screen here if needed
        // Navigator.pushNamed(context, '/profile');
      },
      child: Container(
        width: 80,
        height: 80,
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
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _userProfileImage != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Image.file(
            File(_userProfileImage!),
            fit: BoxFit.cover,
            width: 60,
            height: 60,
            errorBuilder: (context, error, stackTrace) {
              // If image fails to load, show initials
              return Center(
                child: Text(
                  _generateAvatar(_userName),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        )
            : Center(
          child: Text(
            _generateAvatar(_userName),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return _generateLightColor();
    }
 
    try {
      // Remove any leading '#' if present
      String cleanColor = colorString.replaceAll('#', '');

      // If it's already 8 characters (AARRGGBB), use as is
      if (cleanColor.length == 8) {
        return Color(int.parse(cleanColor, radix: 16));
      }
      // If it's 6 characters (RRGGBB), add FF prefix for full opacity
      else if (cleanColor.length == 6) {
        return Color(int.parse('FF$cleanColor', radix: 16));
      }
      // If it's some other length, generate a new color
      else {
        return _generateLightColor();
      }
    } catch (e) {
      print('Error parsing color: $colorString, error: $e');
      return _generateLightColor();
    }
  }

  Color _generateLightColor() {
    final random = Random();
    final r = 200 + random.nextInt(56);
    final g = 200 + random.nextInt(56);
    final b = 200 + random.nextInt(56);
    return Color.fromRGBO(r, g, b, 1);
  }

  void _calculateTotals(List<Map<String, dynamic>> transactions) {
    double income = 0;
    double spent = 0;

    for (var transaction in transactions) {
      final amount = transaction['amount'];
      if (amount is num) {
        if (amount > 0) {
          income += amount.toDouble();
        } else {
          spent += amount.abs().toDouble();
        }
      }
    }

    setState(() {
      _totalIncome = income;
      _totalSpent = spent;
    });
  }

  List<Map<String, dynamic>> _filterTransactionsByPeriod(
      List<Map<String, dynamic>> transactions, String period) {
    if (period == 'All') return transactions;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case 'Daily':
        return transactions.where((t) {
          try {
            final transactionDate = DateTime.parse(t['date']);
            final transactionDay = DateTime(
                transactionDate.year, transactionDate.month, transactionDate.day);
            return transactionDay == today;
          } catch (e) {
            print('Error parsing date: ${t['date']}');
            return false;
          }
        }).toList();

      case 'Weekly':
        final weekStart = today.subtract(Duration(days: today.weekday % 7));
        final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
        return transactions.where((t) {
          try {
            final transactionDate = DateTime.parse(t['date']);
            return transactionDate.isAfter(weekStart.subtract(const Duration(microseconds: 1))) &&
                transactionDate.isBefore(weekEnd.add(const Duration(microseconds: 1)));
          } catch (e) {
            print('Error parsing date: ${t['date']}');
            return false;
          }
        }).toList();

      case 'Monthly':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return transactions.where((t) {
          try {
            final transactionDate = DateTime.parse(t['date']);
            return transactionDate.isAfter(monthStart.subtract(const Duration(microseconds: 1))) &&
                transactionDate.isBefore(monthEnd.add(const Duration(microseconds: 1)));
          } catch (e) {
            print('Error parsing date: ${t['date']}');
            return false;
          }
        }).toList();

      default:
        return transactions;
    }
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedTransactions = prefs.getString('transactions');

      if (storedTransactions != null && storedTransactions.isNotEmpty) {
        final decodedData = jsonDecode(storedTransactions);

        if (decodedData is List) {
          final parsedTransactions = decodedData.map((t) {
            // Ensure all required fields exist with proper types
            return {
              'id': t['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'category': t['category'] ?? 'Unknown',
              'amount': (t['amount'] is num) ? t['amount'].toDouble() : 0.0,
              'date': t['date'] ?? DateTime.now().toIso8601String(),
              'icon': t['icon'] ?? '💰',
              'bgColor': t['bgColor'] ?? _generateLightColor().value.toRadixString(16).padLeft(8, '0'),
              'note': t['note'] ?? '--',
            };
          }).toList();

          if (mounted) {
            setState(() {
              _allTransactions = parsedTransactions.cast<Map<String, dynamic>>();
              _filteredTransactions = _filterTransactionsByPeriod(_allTransactions, _selectedPeriod);
              _calculateTotals(_filteredTransactions);
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _allTransactions = [];
              _filteredTransactions = [];
              _totalIncome = 0;
              _totalSpent = 0;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _allTransactions = [];
            _filteredTransactions = [];
            _totalIncome = 0;
            _totalSpent = 0;
          });
        }
      }
    } catch (error) {
      print('Error loading transactions: $error');
      if (mounted) {
        setState(() {
          _allTransactions = [];
          _filteredTransactions = [];
          _totalIncome = 0;
          _totalSpent = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _handlePeriodChange(String period) {
    if (!mounted) return;

    setState(() {
      _selectedPeriod = period;
      _filteredTransactions = _filterTransactionsByPeriod(_allTransactions, period);
      _calculateTotals(_filteredTransactions);
    });
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;

    setState(() => _refreshing = true);
    await _loadUserName();
    await _loadTransactions();
  }

  double _getSpentPercentage() {
    final total = _totalIncome + _totalSpent;
    return total > 0 ? (_totalSpent / total) * 100 : 0;
  }

  Widget _buildDonutChart() {
    final total = _totalIncome + _totalSpent;
    final spentPercentage = total > 0 ? (_totalSpent / total) * 100 : 0;

    if (total == 0) {
      return SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF0F0F0), width: 20),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '0%',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  Text(
                    'No Data',
                    style: TextStyle(fontSize: 10, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF0F0F0), width: 20),
            ),
          ),
          // Income ring (full circle)
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 20,
              valueColor: AlwaysStoppedAnimation<Color>(_incomeColor),
              backgroundColor: Colors.transparent,
            ),
          ),
          // Spent ring
          if (spentPercentage > 0)
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: spentPercentage / 100,
                strokeWidth: 20,
                valueColor: AlwaysStoppedAnimation<Color>(_spentColor),
                backgroundColor: Colors.transparent,
              ),
            ),
          // Center content
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${spentPercentage.round()}%',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const Text(
                  'Spent',
                  style: TextStyle(fontSize: 10, color: Color(0xFF999999)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFF),
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
                      const Text(
                        'Hello,',
                        style: TextStyle(fontSize: 33, color: Color(0xFF2C3E50)),
                      ),
                      Text(
                        _userName,
                        style: const TextStyle(fontSize: 33, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                      ),
                    ],
                  ),
                  // Add profile widget to top right
                  _buildProfileWidget(),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: const Color(0xFF007AFF),
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8FA),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: _periods
                              .map((period) => Expanded(
                            child: GestureDetector(
                              onTap: () => _handlePeriodChange(period),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedPeriod == period ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _selectedPeriod == period
                                      ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  period,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedPeriod == period
                                        ? const Color(0xFF2C3E50)
                                        : const Color(0xFF999999),
                                    fontWeight: _selectedPeriod == period ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ))
                              .toList(),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8FA),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 16,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: _incomeColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const Text(
                                        'Income',
                                        style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${_totalIncome.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 16,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: _spentColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const Text(
                                        'Spent',
                                        style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${_totalSpent.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            _buildDonutChart(),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent transactions (${_selectedPeriod.toLowerCase()})',
                              style: const TextStyle(fontSize: 16, color: Color(0xFF999999)),
                            ),
                          ],
                        ),
                      ),
                      _filteredTransactions.isEmpty
                          ? Container(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'No transactions available for ${_selectedPeriod.toLowerCase()} period',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF999999)),
                          textAlign: TextAlign.center,
                        ),
                      )
                          : Column(
                        children: _filteredTransactions.reversed.map((transaction) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            margin: EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _parseColor(transaction['bgColor']),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            transaction['icon'],
                                            style: const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              transaction['category'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                                color: Color(0xFF2C3E50),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (transaction['note'] != null && transaction['note'].isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  transaction['note'],
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF515A70).withOpacity(0.8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${transaction['amount'] > 0 ? '+' : '-'}\$${transaction['amount'].abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: transaction['amount'] > 0 ? _incomeColor : _spentColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat.MMMd().format(DateTime.parse(transaction['date'])),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF999999),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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