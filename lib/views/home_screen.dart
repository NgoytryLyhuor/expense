import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedPeriod = 'Daily';
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _loading = true;
  bool _refreshing = false;
  double _totalIncome = 0;
  double _totalSpent = 0;

  final List<String> _periods = ['All', 'Daily', 'Weekly', 'Monthly'];
  final Color _spentColor = const Color(0xFFFEB8A8);
  final Color _incomeColor = const Color(0xFFB6DBAD);

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Color _generateLightColor() {
    final random = Random();
    final r = 200 + random.nextInt(56);
    final g = 200 + random.nextInt(56);
    final b = 200 + random.nextInt(56);
    return Color.fromRGBO(r, g, b, 1);
  }

  void _calculateTotals(List<Map<String, dynamic>> transactions) {
    final income = transactions
        .where((t) => t['amount'] > 0)
        .fold<double>(0, (sum, t) => sum + t['amount']);
    final spent = transactions
        .where((t) => t['amount'] < 0)
        .fold<double>(0, (sum, t) => sum + t['amount'].abs());
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
          final transactionDate = DateTime.parse(t['date']);
          final transactionDay =
          DateTime(transactionDate.year, transactionDate.month, transactionDate.day);
          return transactionDay == today;
        }).toList();

      case 'Weekly':
        final weekStart = today.subtract(Duration(days: today.weekday % 7));
        final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
        return transactions.where((t) {
          final transactionDate = DateTime.parse(t['date']);
          return transactionDate.isAfter(weekStart.subtract(const Duration(microseconds: 1))) &&
              transactionDate.isBefore(weekEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'Monthly':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return transactions.where((t) {
          final transactionDate = DateTime.parse(t['date']);
          return transactionDate.isAfter(monthStart.subtract(const Duration(microseconds: 1))) &&
              transactionDate.isBefore(monthEnd.add(const Duration(microseconds: 1)));
        }).toList();

      default:
        return transactions;
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
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
          _allTransactions = parsedTransactions.cast<Map<String, dynamic>>();
          _filteredTransactions = _filterTransactionsByPeriod(_allTransactions, _selectedPeriod);
          _calculateTotals(_filteredTransactions);
        });
      } else {
        setState(() {
          _allTransactions = [];
          _filteredTransactions = [];
          _totalIncome = 0;
          _totalSpent = 0;
        });
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error loading transactions: $error');
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _handlePeriodChange(String period) {
    setState(() {
      _selectedPeriod = period;
      _filteredTransactions = _filterTransactionsByPeriod(_allTransactions, period);
      _calculateTotals(_filteredTransactions);
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
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
          Container(
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
            Container(
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
                    children: const [
                      Text(
                        'Hello,',
                        style: TextStyle(fontSize: 33, color: Color(0xFF2C3E50)),
                      ),
                      Text(
                        'Lyhuor',
                        style: TextStyle(fontSize: 33, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                      ),
                    ],
                  ),
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
                                    fontWeight:
                                    _selectedPeriod == period ? FontWeight.w600 : FontWeight.normal,
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
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/transfer'),
                              child: const Text(
                                'See All →',
                                style: TextStyle(fontSize: 14, color: Color(0xFF007AFF)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _loading
                          ? const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF007AFF)),
                            SizedBox(height: 10),
                            Text(
                              'Loading transactions...',
                              style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                            ),
                          ],
                        ),
                      )
                          : _filteredTransactions.isEmpty
                          ? Text(
                        'No transactions available for ${_selectedPeriod.toLowerCase()} period',
                        style: const TextStyle(fontSize: 16, color: Color(0xFF999999)),
                        textAlign: TextAlign.center,
                      )
                          : Column(
                        children: _filteredTransactions.reversed.map((transaction) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFF8F8FA))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse('FF${transaction['bgColor']}', radix: 16)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          transaction['icon'],
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      transaction['category'],
                                      style: const TextStyle(fontSize: 16, color: Color(0xFF2C3E50)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${transaction['amount'] > 0 ? '+' : '-'}\$${transaction['amount'].abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: transaction['amount'] > 0 ? _incomeColor : _spentColor,
                                      ),
                                    ),
                                    Text(
                                      DateFormat.yMd().format(DateTime.parse(transaction['date'])),
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
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