import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  _TransferScreenState createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> with RouteAware {
  String _selectedPeriod = 'All';
  List<Map<String, dynamic>> _allTransfers = [];
  List<Map<String, dynamic>> _filteredTransfers = [];
  Map<String, List<Map<String, dynamic>>> _groupedTransfers = {};
  bool _loading = true;
  bool _refreshing = false;
  double _totalSpent = 0;
  double _totalIncome = 0;
  String _selectedFilter = 'All'; // All, Spent, Income

  final List<String> _periods = ['All', 'Daily', 'Weekly', 'Monthly'];
  final List<String> _filters = ['All', 'Spent', 'Income'];
  final Color _spentColor = const Color(0xFFFEB8A8);
  final Color _incomeColor = const Color(0xFFB6DBAD);
  final Color _primaryColor = const Color(0xFF2C3E50);
  final Color _secondaryColor = const Color(0xFF95A5A6);
  final Color _backgroundColor = const Color(0xFFFEFEFF);
  final Color _accentColor = const Color(0xFF3498DB);

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return _generateLightColor();
    }

    try {
      String cleanColor = colorString.replaceAll('#', '');
      if (cleanColor.length == 8) {
        return Color(int.parse(cleanColor, radix: 16));
      } else if (cleanColor.length == 6) {
        return Color(int.parse('FF$cleanColor', radix: 16));
      } else {
        return _generateLightColor();
      }
    } catch (e) {
      print('Error parsing color: $colorString, error: $e');
      return _generateLightColor();
    }
  }

  Color _generateLightColor() {
    final random = Random();
    final colors = [
      const Color(0xFFEBF3FF), // Light Blue
      const Color(0xFFF0F8FF), // Alice Blue
      const Color(0xFFF5F5F5), // White Smoke
      const Color(0xFFE8F5E8), // Light Green
      const Color(0xFFFFF0F5), // Lavender Blush
      const Color(0xFFF0FFF0), // Honeydew
    ];
    return colors[random.nextInt(colors.length)];
  }

  void _calculateTotals(List<Map<String, dynamic>> transfers) {
    double spent = 0;
    double income = 0;

    for (var transfer in transfers) {
      final amount = transfer['amount'];
      if (amount is num) {
        if (transfer['type'] == 'spent') {
          spent += amount.abs().toDouble();
        } else if (transfer['type'] == 'income') {
          income += amount.abs().toDouble();
        }
      }
    }

    setState(() {
      _totalSpent = spent;
      _totalIncome = income;
    });
  }

  void _groupTransfersByDate(List<Map<String, dynamic>> transfers) {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var transfer in transfers) {
      try {
        final date = DateTime.parse(transfer['date']);
        final dateKey = DateFormat('yyyy-MM-dd').format(date);

        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(transfer);
      } catch (e) {
        print('Error parsing date: ${transfer['date']}');
      }
    }

    // Sort each day's transfers by time (newest first)
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
      _groupedTransfers = grouped;
    });
  }

  List<Map<String, dynamic>> _filterTransfersByPeriod(
      List<Map<String, dynamic>> transfers, String period) {
    if (period == 'All') return transfers;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case 'Daily':
        return transfers.where((transfer) {
          try {
            final transferDate = DateTime.parse(transfer['date']);
            final transferDay = DateTime(
                transferDate.year, transferDate.month, transferDate.day);
            return transferDay == today;
          } catch (e) {
            return false;
          }
        }).toList();

      case 'Weekly':
        final weekStart = today.subtract(Duration(days: today.weekday % 7));
        final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
        return transfers.where((transfer) {
          try {
            final transferDate = DateTime.parse(transfer['date']);
            return transferDate.isAfter(weekStart.subtract(const Duration(microseconds: 1))) &&
                transferDate.isBefore(weekEnd.add(const Duration(microseconds: 1)));
          } catch (e) {
            return false;
          }
        }).toList();

      case 'Monthly':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return transfers.where((transfer) {
          try {
            final transferDate = DateTime.parse(transfer['date']);
            return transferDate.isAfter(monthStart.subtract(const Duration(microseconds: 1))) &&
                transferDate.isBefore(monthEnd.add(const Duration(microseconds: 1)));
          } catch (e) {
            return false;
          }
        }).toList();

      default:
        return transfers;
    }
  }

  List<Map<String, dynamic>> _filterTransfersByType(
      List<Map<String, dynamic>> transfers, String filterType) {
    if (filterType == 'All') return transfers;

    return transfers.where((transfer) {
      if (filterType == 'Spent') {
        return transfer['type'] == 'spent' || transfer['amount'] < 0;
      } else if (filterType == 'Income') {
        return transfer['type'] == 'income' || transfer['amount'] > 0;
      }
      return true;
    }).toList();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedTransfers = prefs.getString('transfers') ?? prefs.getString('transactions');

      if (storedTransfers != null && storedTransfers.isNotEmpty) {
        final decodedData = jsonDecode(storedTransfers);

        if (decodedData is List) {
          final parsedTransfers = decodedData.map((t) {
            String transferType = 'spent';
            String recipient = 'Unknown';
            String note = 'Transfer';

            if (t.containsKey('category')) {
              final amount = t['amount'] ?? 0;
              transferType = amount > 0 ? 'income' : 'spent';
              recipient = t['category'] ?? 'Unknown';
              note = amount > 0 ? 'Income' : 'Expense';
            } else {
              transferType = t['type'] ?? 'spent';
              recipient = t['recipient'] ?? 'Unknown';
              note = t['note'] ?? 'Transfer';
            }

            return {
              'id': t['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'type': transferType,
              'recipient': recipient,
              'amount': (t['amount'] is num) ? t['amount'].toDouble() : 0.0,
              'date': t['date'] ?? DateTime.now().toIso8601String(),
              'icon': t['icon'] ?? (transferType == 'income' ? '💰' : '💸'),
              'note': note,
              'bgColor': t['bgColor'] ?? _generateLightColor().value.toRadixString(16).padLeft(8, '0'),
            };
          }).toList();

          if (mounted) {
            setState(() {
              _allTransfers = parsedTransfers.cast<Map<String, dynamic>>();
              _applyFilters();
            });
          }
        } else {
          _resetData();
        }
      } else {
        _resetData();
      }
    } catch (error) {
      print('Error loading transfers: $error');
      _resetData();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _resetData() {
    if (mounted) {
      setState(() {
        _allTransfers = [];
        _filteredTransfers = [];
        _groupedTransfers = {};
        _totalSpent = 0;
        _totalIncome = 0;
      });
    }
  }

  void _applyFilters() {
    var filtered = _filterTransfersByPeriod(_allTransfers, _selectedPeriod);
    filtered = _filterTransfersByType(filtered, _selectedFilter);

    setState(() {
      _filteredTransfers = filtered;
    });

    _calculateTotals(_filteredTransfers);
    _groupTransfersByDate(_filteredTransfers);
  }

  void _handlePeriodChange(String period) {
    if (!mounted) return;
    setState(() {
      _selectedPeriod = period;
    });
    _applyFilters();
  }

  void _handleFilterChange(String filter) {
    if (!mounted) return;
    setState(() {
      _selectedFilter = filter;
    });
    _applyFilters();
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;
    setState(() => _refreshing = true);
    await _loadTransactions();
  }

  String _formatDateHeader(String dateKey) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button (Non-scrollable)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transfer History',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            Text(
                              '${_filteredTransfers.length} transactions',
                              style: TextStyle(
                                fontSize: 14,
                                color: _secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Quick Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _incomeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _incomeColor.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.trending_up, color: _incomeColor, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                '\$${_totalIncome.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _incomeColor,
                                ),
                              ),
                              Text(
                                'Income',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _incomeColor,
                                ),
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
                            color: _spentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _spentColor.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.trending_down, color: _spentColor, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                '\$${_totalSpent.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _spentColor,
                                ),
                              ),
                              Text(
                                'Spent',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _spentColor,
                                ),
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

            // Scrollable Content (Filter Tabs + Transfer List)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Filter Tabs (Now Scrollable)
                    Container(
                      margin: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Period Filter - HomeScreen Style
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8FA),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: _periods.map((period) =>
                                  Expanded(
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
                                  ),
                              ).toList(),
                            ),
                          ),
                          // Type Filter - HomeScreen Style
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: _filters.map((filter) =>
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _handleFilterChange(filter),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _selectedFilter == filter ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: _selectedFilter == filter
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
                                          filter,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _selectedFilter == filter
                                                ? const Color(0xFF2C3E50)
                                                : const Color(0xFF999999),
                                            fontWeight: _selectedFilter == filter ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Transfer List
                    RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: _accentColor,
                      child: _loading
                          ? Container(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(color: _accentColor),
                        ),
                      )
                          : _filteredTransfers.isEmpty
                          ? Container(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _secondaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: _secondaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transfers found',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your transfer history will appear here',
                              style: TextStyle(
                                fontSize: 16,
                                color: _secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      )
                          : Column(
                        children: () {
                          final dateKeys = _groupedTransfers.keys.toList()
                            ..sort((a, b) => b.compareTo(a)); // Sort newest first

                          return dateKeys.map((dateKey) {
                            final dayTransfers = _groupedTransfers[dateKey]!;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Header
                                  Container(
                                    child: Text(
                                      _formatDateHeader(dateKey),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ),
                                  // Transfers for this date
                                  ...dayTransfers.map((transfer) {
                                    final isIncome = transfer['type'] == 'income' || transfer['amount'] > 0;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
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
                                          // Icon with direction indicator
                                          Stack(
                                            children: [
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: _parseColor(transfer['bgColor']),
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    transfer['icon'],
                                                    style: const TextStyle(fontSize: 20),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 16),
                                          // Transfer details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isIncome
                                                      ? '${transfer['recipient']}'
                                                      : '${transfer['recipient']}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                    color: _primaryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  DateFormat('h:mm a').format(DateTime.parse(transfer['date'])),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: _secondaryColor.withOpacity(0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Amount
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${isIncome ? '+' : '-'}\$${transfer['amount'].abs().toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isIncome ? _incomeColor : _spentColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
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