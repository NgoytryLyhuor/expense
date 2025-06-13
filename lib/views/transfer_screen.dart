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

class _TransferScreenState extends State<TransferScreen> {
  String _selectedPeriod = 'Daily';
  List<Map<String, dynamic>> _allTransfers = [];
  List<Map<String, dynamic>> _filteredTransfers = [];
  bool _loading = true;
  bool _refreshing = false;

  final List<String> _periods = ['All', 'Daily', 'Weekly', 'Monthly'];
  final Map<String, Color> _colors = {
    'SENT': const Color(0xFFFEB8A8),
    'RECEIVED': const Color(0xFFB6DBAD),
    'PRIMARY': const Color(0xFF2C3E50),
    'SECONDARY': const Color(0xFF999999),
    'BACKGROUND': const Color(0xFFFEFEFF),
    'CARD_BG': const Color(0xFFF8F8FA),
    'BLUE': const Color(0xFF007AFF),
  };

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

  List<Map<String, dynamic>> _filterTransfersByPeriod(
      List<Map<String, dynamic>> transfers, String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case 'Daily':
        final dayStart = today;
        final dayEnd = today.add(const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
        return transfers.where((transfer) {
          final transferDate = DateTime.parse(transfer['date']);
          return transferDate.isAfter(dayStart.subtract(const Duration(microseconds: 1))) &&
              transferDate.isBefore(dayEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'Weekly':
        final weekStart = today.subtract(Duration(days: today.weekday % 7));
        final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
        return transfers.where((transfer) {
          final transferDate = DateTime.parse(transfer['date']);
          return transferDate.isAfter(weekStart.subtract(const Duration(microseconds: 1))) &&
              transferDate.isBefore(weekEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'Monthly':
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return transfers.where((transfer) {
          final transferDate = DateTime.parse(transfer['date']);
          return transferDate.isAfter(monthStart.subtract(const Duration(microseconds: 1))) &&
              transferDate.isBefore(monthEnd.add(const Duration(microseconds: 1)));
        }).toList();

      case 'All':
      default:
        return transfers;
    }
  }

  List<Map<String, dynamic>> _groupTransfersByDate(List<Map<String, dynamic>> transfers) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    for (var transfer in transfers) {
      final date = DateTime.parse(transfer['date']);
      String dateKey;
      if (date.year == today.year && date.month == today.month && date.day == today.day) {
        dateKey = 'Today';
      } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
        dateKey = 'Yesterday';
      } else {
        dateKey = DateFormat('MMM d, yyyy').format(date);
      }

      grouped[dateKey] ??= [];
      grouped[dateKey]!.add(transfer);
    }

    return grouped.entries
        .map((entry) => {
      'date': entry.key,
      'items': entry.value,
      'total': entry.value.fold<double>(0, (sum, t) => sum + t['amount']),
    })
        .toList();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedTransfers = prefs.getString('transactions');
      if (storedTransfers != null) {
        final parsedTransfers = (jsonDecode(storedTransfers) as List)
            .map((t) => {
          ...t,
          'bgColor': t['bgColor'] ?? _generateLightColor().value.toRadixString(16).substring(2),
        })
            .toList();
        setState(() {
          _allTransfers = parsedTransfers.cast<Map<String, dynamic>>();
          _filteredTransfers = _filterTransfersByPeriod(_allTransfers, _selectedPeriod);
        });
      } else {
        setState(() {
          _allTransfers = [];
          _filteredTransfers = [];
        });
      }
    } catch (error) {
      // ignore: avoid_print
      print('Error loading transfers: $error');
      setState(() {
        _allTransfers = [];
        _filteredTransfers = [];
      });
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
      _filteredTransfers = _filterTransfersByPeriod(_allTransfers, period);
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _loadTransactions();
  }

  List<Map<String, dynamic>> _getGroupedTransfers() {
    return _groupTransfersByDate(_filteredTransfers);
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
                        'Transfer History',
                        style: TextStyle(
                          fontSize: 33,
                          color: _colors['PRIMARY'],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Money sent & received',
                        style: TextStyle(
                          fontSize: 16,
                          color: _colors['SECONDARY'],
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
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _colors['CARD_BG'],
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
                                        ? _colors['PRIMARY']
                                        : _colors['SECONDARY'],
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
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Activity',
                              style: TextStyle(
                                fontSize: 16,
                                color: _colors['SECONDARY'],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _loading
                                ? const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(color: Color(0xFF007AFF)),
                                  SizedBox(height: 10),
                                  Text(
                                    'Loading transfers...',
                                    style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                                  ),
                                ],
                              ),
                            )
                                : _filteredTransfers.isEmpty
                                ? Center(
                              child: Column(
                                children: [
                                  const Text(
                                    '💳',
                                    style: TextStyle(fontSize: 50),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No transfers yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: _colors['PRIMARY'],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Transfer history will appear here',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _colors['SECONDARY'],
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : Column(
                              children: _getGroupedTransfers().asMap().entries.map((entry) {
                                final day = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 30),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            day['date'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: _colors['PRIMARY'],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${day['total'] >= 0 ? '+' : ''}\$${day['total'].abs().toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: day['total'] >= 0
                                                  ? _colors['RECEIVED']
                                                  : _colors['SENT'],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      ...day['items'].map((item) => Container(
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
                                                  width: 50,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color: Color(
                                                        int.parse('FF${item['bgColor']}', radix: 16)),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      item['icon'],
                                                      style: const TextStyle(fontSize: 20),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['type'] == 'sent'
                                                          ? 'To ${item['recipient']}'
                                                          : 'From ${item['recipient']}',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: _colors['PRIMARY'],
                                                      ),
                                                    ),
                                                    Text(
                                                      item['note'],
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: _colors['SECONDARY'],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${item['amount'] >= 0 ? '+' : ''}\$${item['amount'].abs().toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: item['amount'] >= 0
                                                        ? _colors['RECEIVED']
                                                        : _colors['SENT'],
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('h:mm a').format(DateTime.parse(item['date'])),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: _colors['SECONDARY'],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      )),
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