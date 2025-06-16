import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Main screen widget that shows transaction history
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {

  // ============ VARIABLES (Data Storage) ============
  // These variables store the current state of our screen

  String selectedPeriod = 'All';           // Which time period is selected (All, Daily, Weekly, Monthly)
  String selectedFilter = 'All';           // Which type filter is selected (All, Spent, Income)

  List<Map<String, dynamic>> allTransactions = [];       // All transactions from storage
  List<Map<String, dynamic>> filteredTransactions = [];  // Transactions after applying filters
  Map<String, List<Map<String, dynamic>>> groupedTransactions = {}; // Transactions grouped by date

  bool isLoading = true;                   // Shows loading spinner when true
  bool isRefreshing = false;               // Shows refresh indicator when true

  double totalSpent = 0;                   // Total amount spent
  double totalIncome = 0;                  // Total amount earned

  // ============ UI COLORS ============
  // Define colors used throughout the app
  final Color spentColor = const Color(0xFFF6856B);      // Red color for expenses
  final Color incomeColor = const Color(0xFF8BE177);     // Green color for income
  final Color primaryColor = const Color(0xFF2C3E50);    // Dark blue for text
  final Color secondaryColor = const Color(0xFF95A5A6);  // Gray for secondary text
  final Color backgroundColor = const Color(0xFFFEFEFF); // Light background
  final Color accentColor = const Color(0xFF3498DB);     // Blue for accents

  // ============ DROPDOWN OPTIONS ============
  final List<String> periods = ['All', 'Daily', 'Weekly', 'Monthly'];
  final List<String> filters = ['All', 'Spent', 'Income'];

  // ============ STARTUP FUNCTION ============
  // This runs when the screen first loads
  @override
  void initState() {
    super.initState();
    loadTransactions(); // Load transactions from storage
  }

  // This runs every time we come back to this screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadTransactions(); // Reload transactions
    });
  }

  // ============ COLOR HELPER FUNCTIONS ============

  // Convert color string to Flutter Color object
  Color parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return generateLightColor(); // Use random color if none provided
    }

    try {
      String cleanColor = colorString.replaceAll('#', ''); // Remove # symbol
      if (cleanColor.length == 8) {
        return Color(int.parse(cleanColor, radix: 16)); // Convert hex to color
      } else if (cleanColor.length == 6) {
        return Color(int.parse('FF$cleanColor', radix: 16)); // Add alpha channel
      } else {
        return generateLightColor();
      }
    } catch (e) {
      print('Error parsing color: $colorString, error: $e');
      return generateLightColor();
    }
  }

  // Generate a random light color for transaction icons
  Color generateLightColor() {
    final random = Random();
    final colors = [
      const Color(0xFFEBF3FF), // Light Blue
      const Color(0xFFF0F8FF), // Alice Blue
      const Color(0xFFF5F5F5), // White Smoke
      const Color(0xFFE8F5E8), // Light Green
      const Color(0xFFFFF0F5), // Lavender Blush
      const Color(0xFFF0FFF0), // Honeydew
    ];
    return colors[random.nextInt(colors.length)]; // Pick random color
  }

  // ============ CALCULATION FUNCTIONS ============

  // Calculate total spent and income from transactions list
  void calculateTotals(List<Map<String, dynamic>> transactions) {
    print('Calculating totals for ${transactions.length} transactions');

    double spent = 0;
    double income = 0;

    for (var transaction in transactions) {
      final amount = transaction['amount'] is num ? transaction['amount'].toDouble() : 0.0;
      final type = transaction['type']?.toString().toLowerCase();

      print('Transaction: ${transaction['recipient']}, Amount: $amount, Type: $type');

      if (type == 'spent' || amount < 0) {
        spent += amount.abs();
        print('Added to spent: $amount');
      } else if (type == 'income' || amount > 0) {
        income += amount.abs();
        print('Added to income: $amount');
      }
    }

    print('New totals - Income: $income, Spent: $spent');

    setState(() {
      totalSpent = spent;
      totalIncome = income;
    });
  }

  // ============ GROUPING FUNCTIONS ============

  // Group transactions by date (so we can show "Today", "Yesterday", etc.)
  void groupTransactionsByDate(List<Map<String, dynamic>> transactions) {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    // Loop through each transaction
    for (var transaction in transactions) {
      try {
        final date = DateTime.parse(transaction['date']); // Parse date string
        final dateKey = DateFormat('yyyy-MM-dd').format(date); // Format as YYYY-MM-DD

        // Create new list for this date if it doesn't exist
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(transaction); // Add transaction to this date group
      } catch (e) {
        print('Error parsing date: ${transaction['date']}');
      }
    }

    // Sort transactions within each day (newest first)
    grouped.forEach((key, value) {
      value.sort((a, b) {
        try {
          return DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
        } catch (e) {
          return 0;
        }
      });
    });

    // Update the UI with grouped transactions
    setState(() {
      groupedTransactions = grouped;
    });
  }

  // ============ FILTERING FUNCTIONS ============

  // Filter transactions by time period (Daily, Weekly, Monthly, All)
  List<Map<String, dynamic>> filterTransactionsByPeriod(
      List<Map<String, dynamic>> transactions, String period) {

    if (period == 'All') return transactions; // Return all if no filter

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case 'Daily': // Show only today's transactions
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

      case 'Weekly': // Show this week's transactions
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

      case 'Monthly': // Show this month's transactions
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

  // Filter transactions by type (All, Spent, Income)
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

// ============ DATA LOADING FUNCTIONS ============

// Load transactions from phone storage
  Future<void> loadTransactions() async {
    if (!mounted) return; // Don't continue if widget is destroyed

    setState(() => isLoading = true); // Show loading spinner

    try {
      final prefs = await SharedPreferences.getInstance(); // Get phone storage
      final storedTransactions = prefs.getString('transactions'); // Get saved transactions

      if (storedTransactions != null && storedTransactions.isNotEmpty) {
        final decodedData = jsonDecode(storedTransactions); // Convert JSON string to data

        if (decodedData is List) {
          // Convert each transaction to STANDARDIZED format that matches HomeScreen
          final parsedTransactions = decodedData.map((t) {
            // For display purposes, we need both 'category' and 'recipient' fields
            // Keep the original 'category' field for HomeScreen compatibility
            String category = t['category'] ?? t['recipient'] ?? 'Unknown';
            String recipient = t['recipient'] ?? t['category'] ?? 'Unknown';

            // Determine transaction type from amount or existing type field
            String transactionType;
            double amount = (t['amount'] is num) ? t['amount'].toDouble() : 0.0;

            if (t.containsKey('type')) {
              transactionType = t['type'];
            } else {
              transactionType = amount >= 0 ? 'income' : 'spent';
            }

            // Return standardized transaction format that works with BOTH screens
            // Return standardized transaction format that works with BOTH screens
            return {
              'id': t['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'category': category,
              'recipient': recipient,
              'type': transactionType.toLowerCase(), // Ensure consistent case
              'amount': amount,
              'date': t['date'] ?? DateTime.now().toIso8601String(),
              'icon': t['icon'] ?? (transactionType == 'income' ? '💰' : '💸'),
              'note': t['note'] ?? (transactionType == 'income' ? 'Income' : 'Expense'),
              'bgColor': t['bgColor'] ?? generateLightColor().value.toRadixString(16).padLeft(8, '0'),
            };
          }).toList();

          if (mounted) { // Make sure widget still exists
            setState(() {
              allTransactions = parsedTransactions.cast<Map<String, dynamic>>();
              applyFilters(); // Apply current filters to new data
            });
          }
        } else {
          resetData(); // Clear data if format is wrong
        }
      } else {
        resetData(); // Clear data if no transactions found
      }
    } catch (error) {
      print('Error loading transactions: $error');
      resetData(); // Clear data if error occurred
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;    // Hide loading spinner
          isRefreshing = false; // Hide refresh indicator
        });
      }
    }
  }

  // Clear all data (used when no transactions or error)
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

  // Apply current filters to all transactions
  void applyFilters() {
    // First filter by period (time)
    var filtered = filterTransactionsByPeriod(allTransactions, selectedPeriod);
    // Then filter by type (spent/income)
    filtered = filterTransactionsByType(filtered, selectedFilter);

    // Calculate totals BEFORE updating state
    calculateTotals(filtered);

    setState(() {
      filteredTransactions = filtered;
      groupedTransactions = {}; // Clear old grouping
    });

    // Update grouping based on filtered data
    groupTransactionsByDate(filteredTransactions);
  }

  // ============ USER INTERACTION FUNCTIONS ============

  // Handle when user selects different time period
  void handlePeriodChange(String period) {
    if (!mounted) return;
    setState(() {
      selectedPeriod = period;
    });
    applyFilters(); // Re-filter with new period
  }

  // Handle when user selects different transaction type filter
  void handleFilterChange(String filter) {
    if (!mounted) return;
    setState(() {
      selectedFilter = filter;
    });
    applyFilters(); // Re-filter with new type
  }

  // Handle pull-to-refresh action
  Future<void> onRefresh() async {
    if (!mounted) return;
    setState(() => isRefreshing = true);
    await loadTransactions(); // Reload all data
  }

  // ============ UI HELPER FUNCTIONS ============

  // Format date for display (Today, Yesterday, or day name)
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
        return DateFormat('EEEE, MMM dd').format(date); // e.g., "Monday, Jan 15"
      }
    } catch (e) {
      return dateKey;
    }
  }

  // ============ BUILD UI COMPONENTS ============

  // Build filter tab button
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
                boxShadow: currentValue == option ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ] : [],
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

// ============ DELETE TRANSACTION FUNCTION (FIXED) ============
// This function removes a transaction from storage and updates the UI
  Future<void> deleteTransaction(String transactionId) async {
    try {
      // Remove from current lists
      allTransactions.removeWhere((t) => t['id'] == transactionId);

      // Convert back to the ORIGINAL format before saving
      // This ensures HomeScreen can still read the data correctly
      final transactionsForStorage = allTransactions.map((t) {
        return {
          'id': t['id'],
          'category': t['category'],  // ← Use 'category' for storage (HomeScreen format)
          'amount': t['amount'],
          'date': t['date'],
          'icon': t['icon'],
          'note': t['note'],
          'bgColor': t['bgColor'],
        };
      }).toList();

      // Save updated list to phone storage in HomeScreen-compatible format
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(transactionsForStorage);
      await prefs.setString('transactions', jsonString);

      // Refresh the display
      applyFilters();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error deleting transaction: $e');
      // Show error message if deletion fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete transaction'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ============ SHOW DELETE CONFIRMATION MODAL ============
  // This shows a beautiful popup asking user to confirm deletion
  Future<void> showDeleteConfirmation(Map<String, dynamic> transaction) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
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
                // Warning Icon
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

                // Title
                Text(
                  'Delete Transaction?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
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

                // Transaction details
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

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close modal
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

                    // Delete Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close modal
                          await deleteTransaction(transaction['id']); // Delete the transaction
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

  // ============ BUILD TRANSACTION CARD WITH SWIPE ============
  // This function creates each individual transaction card that you see in the list
  // Each card shows: icon, recipient name, time, and amount
  // Now with swipe-to-delete functionality!
  Widget buildTransactionItem(Map<String, dynamic> transaction) {
    final isIncome = transaction['type'] == 'income' || transaction['amount'] > 0;

    return Dismissible(
      key: Key(transaction['id']), // Unique key for each transaction
      direction: DismissDirection.endToStart, // Only allow swipe from right to left
      background: Container(
        // This is the red background that appears when swiping
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
        // This prevents immediate deletion and shows confirmation instead
        await showDeleteConfirmation(transaction);
        return false; // Always return false to prevent auto-deletion
      },
      child: Container(
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
            // Transaction Icon
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

            // Transaction Details
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

            // Transaction Amount
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
    );
  }

  // ============ MAIN UI BUILD FUNCTION ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [

            // ========== HEADER SECTION (Non-scrollable) ==========
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Title and transaction count
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

                  // Income and Spent Summary Cards
                  Row(
                    children: [
                      // Income Card
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

                      // Spent Card
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

            // ========== SCROLLABLE CONTENT SECTION ==========
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [

                    // ========== FILTER TABS SECTION ==========
                    Container(
                      margin: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Period Filter (All, Daily, Weekly, Monthly)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: buildFilterTab('', selectedPeriod, handlePeriodChange, periods),
                          ),

                          // Type Filter (All, Spent, Income)
                          buildFilterTab('', selectedFilter, handleFilterChange, filters),
                        ],
                      ),
                    ),

                    // ========== TRANSACTIONS LIST SECTION ==========
                    RefreshIndicator(
                      onRefresh: onRefresh,
                      color: accentColor,
                      child: isLoading
                          ? // Show loading spinner
                      Container(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(color: accentColor),
                        ),
                      )
                          : filteredTransactions.isEmpty
                          ? // Show empty state when no transactions
                      Container(
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
                          : // Show transactions list grouped by date
                      Column(
                        children: () {
                          // Get all dates and sort them (newest first)
                          final dateKeys = groupedTransactions.keys.toList()
                            ..sort((a, b) => b.compareTo(a));

                          // Build UI for each date group
                          return dateKeys.map((dateKey) {
                            final dayTransactions = groupedTransactions[dateKey]!;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Header (Today, Yesterday, etc.)
                                  Text(
                                    formatDateHeader(dateKey),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // ========== TRANSACTION CARDS FOR THIS DATE ==========
                                  // This is where each individual transaction card is created
                                  ...dayTransactions.map((transaction) {
                                    return buildTransactionItem(transaction); // Creates each transaction card
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