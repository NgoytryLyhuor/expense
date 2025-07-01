import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'add_expense_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with WidgetsBindingObserver {
  String selectedPeriod = 'All';
  String selectedFilter = 'All';
  List<Map<String, dynamic>> allTransactions = [];
  List<Map<String, dynamic>> filteredTransactions = [];
  Map<String, List<Map<String, dynamic>>> groupedTransactions = {};
  bool isLoading = true;
  bool isRefreshing = false;
  bool _isTapped = false;
  double totalSpent = 0;
  double totalIncome = 0;

  final Color spentColor = const Color(0xFFF6856B);
  final Color incomeColor = const Color(0xFF8BE177);
  final Color primaryColor = const Color(0xFF2C3E50);
  final Color secondaryColor = const Color(0xFF95A5A6);
  final Color backgroundColor = const Color(0xFFFEFEFF);
  final Color accentColor = const Color(0xFF3498DB);
  final Color editColor = const Color(0xFFF39C12);

  final List<String> periods = ['All', 'Daily', 'Weekly', 'Monthly'];
  final List<String> filters = ['All', 'Spent', 'Income'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadTransactions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      loadTransactions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Color parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return generateLightColor();
    }
    try {
      String cleanColor = colorString.replaceAll('#', '');
      if (cleanColor.length == 8) {
        return Color(int.parse(cleanColor, radix: 16));
      } else if (cleanColor.length == 6) {
        return Color(int.parse('FF$cleanColor', radix: 16));
      } else {
        return generateLightColor();
      }
    } catch (e) {
      print('Error parsing color: $colorString, error: $e');
      return generateLightColor();
    }
  }

  Color generateLightColor() {
    final random = Random();
    final colors = [
      const Color(0xFFEBF3FF),
      const Color(0xFFF0F8FF),
      const Color(0xFFF5F5F5),
      const Color(0xFFE8F5E8),
      const Color(0xFFFFF0F5),
      const Color(0xFFF0FFF0),
    ];
    return colors[random.nextInt(colors.length)];
  }

  void calculateTotals(List<Map<String, dynamic>> transactions) {
    double spent = 0;
    double income = 0;
    for (var transaction in transactions) {
      final amount = transaction['amount'] is num ? transaction['amount'].toDouble() : 0.0;
      final type = transaction['type']?.toString().toLowerCase();
      if (type == 'spent' || amount < 0) {
        spent += amount.abs();
      } else if (type == 'income' || amount > 0) {
        income += amount.abs();
      }
    }
    setState(() {
      totalSpent = spent;
      totalIncome = income;
    });
  }

  void groupTransactionsByDate(List<Map<String, dynamic>> transactions) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var transaction in transactions) {
      try {
        final date = DateTime.parse(transaction['date']);
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(transaction);
      } catch (e) {
        print('Error parsing date: ${transaction['date']}');
      }
    }
    grouped.forEach((key, value) {
      value.sort((a, b) {
        try {
          return DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
        } catch (e) {
          return 0;
        }
      });
    });
    setState(() {
      groupedTransactions = grouped;
    });
  }

  List<Map<String, dynamic>> filterTransactionsByPeriod(
      List<Map<String, dynamic>> transactions, String period) {
    if (period == 'All') return transactions;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case 'Daily':
        return transactions.where((transaction) {
          try {
            final transactionDate = DateTime.parse(transaction['date']);
            final transactionDay = DateTime(
                transactionDate.year, transactionDate.month, transactionDate.day);
            return transactionDay == today;
          } catch (e) {
            return false;
          }
        }).toList();
      case 'Weekly':
        final weekStart = today.subtract(Duration(days: today.weekday % 7));
        final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
        return transactions.where((transaction) {
          try {
            final transactionDate = DateTime.parse(transaction['date']);
            return transactionDate.isAfter(weekStart.subtract(const Duration(microseconds: 1))) &&
                transactionDate.isBefore(weekEnd.add(const Duration(microseconds: 1)));
          } catch (e) {
            return false;
          }
        }).toList();
      case 'Monthly':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return transactions.where((transaction) {
          try {
            final transactionDate = DateTime.parse(transaction['date']);
            return transactionDate.isAfter(monthStart.subtract(const Duration(microseconds: 1))) &&
                transactionDate.isBefore(monthEnd.add(const Duration(microseconds: 1)));
          } catch (e) {
            return false;
          }
        }).toList();
      default:
        return transactions;
    }
  }

  List<Map<String, dynamic>> filterTransactionsByType(
      List<Map<String, dynamic>> transactions, String filterType) {
    if (filterType == 'All') return transactions;
    return transactions.where((transaction) {
      final amount = transaction['amount'] is num ? transaction['amount'].toDouble() : 0.0;
      final type = transaction['type']?.toString().toLowerCase();
      if (filterType == 'Spent') {
        return type == 'spent' || amount < 0;
      } else if (filterType == 'Income') {
        return type == 'income' || amount > 0;
      }
      return true;
    }).toList();
  }

  Future<void> loadTransactions() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedTransactions = prefs.getString('transactions');
      if (storedTransactions != null && storedTransactions.isNotEmpty) {
        final decodedData = jsonDecode(storedTransactions);
        if (decodedData is List) {
          final parsedTransactions = decodedData.map((t) {
            String category = t['category'] ?? t['recipient'] ?? 'Unknown';
            String recipient = t['recipient'] ?? t['category'] ?? 'Unknown';
            String transactionType;
            double amount = (t['amount'] is num) ? t['amount'].toDouble() : 0.0;
            if (t.containsKey('type')) {
              transactionType = t['type'];
            } else {
              transactionType = amount >= 0 ? 'income' : 'spent';
            }
            return {
              'id': t['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'category': category,
              'recipient': recipient,
              'type': transactionType.toLowerCase(),
              'amount': amount,
              'date': t['date'] ?? DateTime.now().toIso8601String(),
              'icon': t['icon'] ?? (transactionType == 'income' ? '💰' : '💸'),
              'note': t['note'] ?? (transactionType == 'income' ? 'Income' : 'Expense'),
              'bgColor': t['bgColor'] ?? generateLightColor().value.toRadixString(16).padLeft(8, '0'),
              'currency': t['currency'] ?? 'USD',
            };
          }).toList();
          if (mounted) {
            setState(() {
              allTransactions = parsedTransactions.cast<Map<String, dynamic>>();
              applyFilters();
            });
          }
        } else {
          resetData();
        }
      } else {
        resetData();
      }
    } catch (error) {
      print('Error loading transactions: $error');
      resetData();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  void resetData() {
    if (mounted) {
      setState(() {
        allTransactions = [];
        filteredTransactions = [];
        groupedTransactions = {};
        totalSpent = 0;
        totalIncome = 0;
      });
    }
  }

  void applyFilters() {
    var filtered = filterTransactionsByPeriod(allTransactions, selectedPeriod);
    filtered = filterTransactionsByType(filtered, selectedFilter);
    calculateTotals(filtered);
    setState(() {
      filteredTransactions = filtered;
      groupedTransactions = {};
    });
    groupTransactionsByDate(filteredTransactions);
  }

  void handlePeriodChange(String period) {
    if (!mounted) return;
    setState(() {
      selectedPeriod = period;
    });
    applyFilters();
  }

  void handleFilterChange(String filter) {
    if (!mounted) return;
    setState(() {
      selectedFilter = filter;
    });
    applyFilters();
  }

  Future<void> onRefresh() async {
    if (!mounted) return;
    setState(() => isRefreshing = true);
    await loadTransactions();
  }

  String formatDateHeader(String dateKey) {
    try {
      final date = DateTime.parse(dateKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final targetDate = DateTime(date.year, date.month, date.day);
      if (targetDate == today) {
        return 'Today';
      } else if (targetDate == yesterday) {
        return 'Yesterday';
      } else {
        return DateFormat('EEEE, MMM dd').format(date);
      }
    } catch (e) {
      return dateKey;
    }
  }

  Widget buildFilterTab(String text, String currentValue, Function(String) onTap, List<String> options) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(text == 'All' && options.contains('Daily') ? 25 : 12),
      ),
      child: Row(
        children: options.map((option) => Expanded(
          child: GestureDetector(
            onTap: () => onTap(option),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: currentValue == option ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(text == 'All' && options.contains('Daily') ? 20 : 8),
                boxShadow: currentValue == option
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
                option,
                style: TextStyle(
                  fontSize: 14,
                  color: currentValue == option ? const Color(0xFF2C3E50) : const Color(0xFF999999),
                  fontWeight: currentValue == option ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      allTransactions.removeWhere((t) => t['id'] == transactionId);
      final transactionsForStorage = allTransactions.map((t) {
        return {
          'id': t['id'],
          'category': t['category'],
          'recipient': t['recipient'],
          'amount': t['amount'],
          'date': t['date'],
          'icon': t['icon'],
          'note': t['note'],
          'bgColor': t['bgColor'],
          'type': t['type'],
          'currency': t['currency'],
        };
      }).toList();
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(transactionsForStorage);
      await prefs.setString('transactions', jsonString);
      applyFilters();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error deleting transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete transaction'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> showDeleteConfirmation(Map<String, dynamic> transaction) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 40,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Delete Transaction?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete this transaction? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: secondaryColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        transaction['icon'],
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction['recipient'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              "\$${transaction['amount'].abs().toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: secondaryColor.withOpacity(0.3)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: secondaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await deleteTransaction(transaction['id']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> editTransaction(Map<String, dynamic> transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(transaction: transaction),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      try {
        final index = allTransactions.indexWhere((t) => t['id'] == transaction['id']);
        if (index != -1) {
          allTransactions[index] = result;
          final transactionsForStorage = allTransactions.map((t) {
            return {
              'id': t['id'],
              'category': t['category'],
              'recipient': t['recipient'],
              'amount': t['amount'],
              'date': t['date'],
              'icon': t['icon'],
              'note': t['note'],
              'bgColor': t['bgColor'],
              'type': t['type'],
              'currency': t['currency'],
            };
          }).toList();
          final prefs = await SharedPreferences.getInstance();
          final jsonString = jsonEncode(transactionsForStorage);
          await prefs.setString('transactions', jsonString);
          applyFilters();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transaction updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error updating transaction: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update transaction'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget buildTransactionItem(Map<String, dynamic> transaction) {
    final isIncome = transaction['type'] == 'income' || transaction['amount'] > 0;

    return Dismissible(
      key: Key(transaction['id']),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: editColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_outlined,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              'Edit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          await showDeleteConfirmation(transaction);
          return false;
        } else if (direction == DismissDirection.startToEnd) {
          await editTransaction(transaction);
          return false;
        }
        return false;
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isTapped = true),
        onTapUp: (_) => setState(() => _isTapped = false),
        onTapCancel: () => setState(() => _isTapped = false),
        onTap: () {
          final amount = transaction['amount'].abs().toStringAsFixed(2);
          final type = isIncome ? 'Income' : 'Expense';
          final date = DateFormat('MMM dd, yyyy h:mm a').format(DateTime.parse(transaction['date']));
          final recipient = transaction['recipient'];
          final note = transaction['note'] ?? '';

          final shareText = '''
Transaction Details:
Type: $type
Amount: \$$amount
Recipient: $recipient
Date: $date
Note: $note
''';

          try {
            Share.share(shareText, subject: 'Transaction Details');
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to share transaction: $e'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isTapped ? Colors.grey.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: parseColor(transaction['bgColor']),
                  borderRadius: BorderRadius.circular(14),
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
                      transaction['recipient'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('h:mm a').format(DateTime.parse(transaction['date'])),
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'}\$${transaction['amount'].abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isIncome ? incomeColor : spentColor,
                ),
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
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transactions History',
                              style: TextStyle(fontSize: 33, color: Color(0xFF2C3E50)),
                            ),
                            Text(
                              '${filteredTransactions.length} transactions',
                              style: TextStyle(fontSize: 14, color: secondaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: incomeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.trending_up, color: incomeColor, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                '\$${totalIncome.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: incomeColor,
                                ),
                              ),
                              Text(
                                'Income',
                                style: TextStyle(fontSize: 12, color: incomeColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: spentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.trending_down, color: spentColor, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                '\$${totalSpent.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: spentColor,
                                ),
                              ),
                              Text(
                                'Spent',
                                style: TextStyle(fontSize: 12, color: spentColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: buildFilterTab('', selectedPeriod, handlePeriodChange, periods),
                          ),
                          buildFilterTab('', selectedFilter, handleFilterChange, filters),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: onRefresh,
                      color: accentColor,
                      child: isLoading
                          ? Container(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(color: accentColor),
                        ),
                      )
                          : filteredTransactions.isEmpty
                          ? Container(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: secondaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: secondaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your transactions history will appear here',
                              style: TextStyle(fontSize: 16, color: secondaryColor),
                            ),
                          ],
                        ),
                      )
                          : Column(
                        children: () {
                          final dateKeys = groupedTransactions.keys.toList()
                            ..sort((a, b) => b.compareTo(a));
                          return dateKeys.map((dateKey) {
                            final dayTransactions = groupedTransactions[dateKey]!;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatDateHeader(dateKey),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...dayTransactions.map((transaction) {
                                    return buildTransactionItem(transaction);
                                  }).toList(),
                                ],
                              ),
                            );
                          }).toList();
                        }(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}