import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Main widget class - this creates the Add Expense screen
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

// State class - this holds all the data and functions for the screen
class _AddExpenseScreenState extends State<AddExpenseScreen> {

  // VARIABLES - These store the user's input data
  String _amount = '';                    // Stores the amount user types
  String _category = 'Food';              // Currently selected category
  String _currency = 'USD';               // Currently selected currency (USD or KHR)
  String _transactionType = 'Expense';    // Either 'Expense' or 'Income'
  String _note = '';                      // Optional note from user

  // SUCCESS POPUP VARIABLES
  bool _showSuccess = false;              // Controls if success popup is visible
  Map<String, dynamic>? _successData;     // Stores data to show in success popup

  // CONTROLLERS - These connect to text input fields
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // FOCUS NODES - These control which text field is currently active
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();

  // CATEGORY LIST - All available expense categories with their icons and colors
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'emoji': '🍽️', 'bgColor': const Color(0xFFFFF3E0)},
    {'name': 'Shopping', 'emoji': '🛍️', 'bgColor': const Color(0xFFF3E5F5)},
    {'name': 'Transportation', 'emoji': '🚗', 'bgColor': const Color(0xFFE8F5E8)},
    {'name': 'Entertainment', 'emoji': '🎬', 'bgColor': const Color(0xFFE3F2FD)},
    {'name': 'Bills', 'emoji': '💡', 'bgColor': const Color(0xFFFFF8E1)},
    {'name': 'Health', 'emoji': '⚕️', 'bgColor': const Color(0xFFF1F8E9)},
    {'name': 'Education', 'emoji': '📚', 'bgColor': const Color(0xFFFCE4EC)},
    {'name': 'Other', 'emoji': '📋', 'bgColor': const Color(0xFFF8F8FA)},
  ];

  // CURRENCY AND TRANSACTION TYPE OPTIONS
  final List<String> _currencies = ['USD', 'KHR'];
  final List<String> _transactionTypes = ['Expense', 'Income'];

  // CLEANUP FUNCTION - Called when screen is destroyed
  @override
  void dispose() {
    // Clean up controllers and focus nodes to prevent memory leaks
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  // SAVE TRANSACTION FUNCTION - Saves the transaction to phone storage
  Future<void> _saveTransaction(Map<String, dynamic> newTransaction) async {
    try {
      print('Saving transaction: $newTransaction');

      // Get access to phone's local storage
      final prefs = await SharedPreferences.getInstance();

      // Get existing transactions from storage (if any)
      final storedTransactions = prefs.getString('transactions');
      List<dynamic> transactions = [];

      // If there are existing transactions, decode them from JSON
      if (storedTransactions != null && storedTransactions.isNotEmpty) {
        try {
          transactions = jsonDecode(storedTransactions) as List;
        } catch (e) {
          print('Error reading existing transactions: $e');
          transactions = []; // Start fresh if data is corrupted
        }
      }

      // Add the new transaction to the list
      transactions.add(newTransaction);

      // Save the updated list back to storage as JSON
      final transactionsJson = jsonEncode(transactions);
      await prefs.setString('transactions', transactionsJson);

      print('Transaction saved successfully!');

    } catch (error) {
      print('Error saving transaction: $error');

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // GET CURRENT CATEGORY FUNCTION - Returns the currently selected category data
  Map<String, dynamic> _getCurrentCategory() {
    return _categories.firstWhere(
            (cat) => cat['name'] == _category,
        orElse: () => _categories[0] // Default to first category if not found
    );
  }

  // FORMAT AMOUNT FUNCTION - Makes sure amount input is properly formatted
  String _formatAmount(String text) {
    // Remove everything except numbers and decimal point
    final cleanText = text.replaceAll(RegExp(r'[^0-9.]'), '');

    // Handle multiple decimal points
    final parts = cleanText.split('.');
    if (parts.length > 2) {
      return '${parts[0]}.${parts.sublist(1).join('')}';
    }

    // Limit to 2 decimal places
    if (parts.length == 2 && parts[1].length > 2) {
      return '${parts[0]}.${parts[1].substring(0, 2)}';
    }

    return cleanText;
  }

  // HANDLE AMOUNT CHANGE - Called when user types in amount field
  void _handleAmountChange(String text) {
    final formatted = _formatAmount(text);
    setState(() {
      _amount = formatted;
      _amountController.text = formatted;
    });
  }

  // HANDLE NOTE CHANGE - Called when user types in note field
  void _handleNoteChange(String text) {
    setState(() {
      _note = text;
    });
  }

  // RESET FORM FUNCTION - Clears all input fields
  void _resetForm() {
    setState(() {
      _amount = '';
      _category = 'Food';
      _currency = 'USD';
      _transactionType = 'Expense';
      _note = '';
    });
    _amountController.clear();
    _noteController.clear();
  }

  // MAIN ADD FUNCTION - Called when user taps "Add" button
  void _handleAdd() async {
    // First, dismiss any open keyboards
    FocusScope.of(context).unfocus();

    // Check if amount is valid
    if (_amount.isEmpty || double.tryParse(_amount) == null || double.parse(_amount) <= 0) {
      return; // Exit if amount is invalid
    }

    // Convert amount to double and handle currency conversion
    final amountValue = double.parse(_amount);
    final amountInUSD = _currency == 'KHR' ? amountValue / 4000 : amountValue;
    final finalAmount = _transactionType == 'Income' ? amountInUSD : -amountInUSD;

    // Get current category data
    final currentCategory = _getCurrentCategory();

    // Create transaction object with all the data
    final newTransaction = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'amount': finalAmount,
      'originalAmount': amountValue,
      'category': _transactionType == 'Income' ? 'Income' : _category,
      'categoryData': _transactionType == 'Income'
          ? {'name': 'Income', 'emoji': '💰', 'bgColor': 0xFFE8F5E8}
          : {
        'name': currentCategory['name'],
        'emoji': currentCategory['emoji'],
        'bgColor': (currentCategory['bgColor'] as Color).value
      },
      'date': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'icon': _transactionType == 'Income' ? '💰' : currentCategory['emoji'],
      'bgColor': _transactionType == 'Income'
          ? 'FFE8F5E8'
          : (currentCategory['bgColor'] as Color).value.toRadixString(16).substring(2).toUpperCase(),
      'currency': _currency,
      'type': _transactionType,
      'note': _note,
    };

    // Save the transaction
    await _saveTransaction(newTransaction);

    // Store data for success popup
    _successData = {
      'amount': _amount,
      'currency': _currency,
      'type': _transactionType,
      'category': _category,
      'note': _note,
    };

    // Reset form and show success popup
    _resetForm();
    setState(() {
      _showSuccess = true;
    });

    // Hide success popup after 3 seconds and go back to main screen
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
          _successData = null;
        });
        Navigator.pushReplacementNamed(context, '/main', arguments: {'selectedIndex': 0});
      }
    });
  }

  // HANDLE CATEGORY SELECT - Called when user picks a category
  void _handleCategorySelect(String categoryName) {
    setState(() {
      _category = categoryName;
    });
    Navigator.pop(context); // Close the category selection popup
  }

  // HANDLE CURRENCY SELECT - Called when user picks USD or KHR
  void _handleCurrencySelect(String selectedCurrency) {
    setState(() {
      _currency = selectedCurrency;
      _amount = ''; // Clear amount when currency changes
    });
    _amountController.clear();
  }

  // HANDLE TRANSACTION TYPE SELECT - Called when user picks Expense or Income
  void _handleTransactionTypeSelect(String type) {
    setState(() {
      _transactionType = type;
      if (type == 'Expense') {
        _category = 'Food'; // Reset to default category for expenses
      }
    });
  }

  // SHOW CATEGORY POPUP - Shows the bottom sheet with category options
  void _showCategoryPopup() {
    FocusScope.of(context).unfocus(); // Hide keyboard

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: const Color(0xFFFEFEFF),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Popup title
            const Text(
              'Select Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),

            // List of category options
            ..._categories.map((cat) {
              final isSelected = _category == cat['name'];
              return GestureDetector(
                onTap: () => _handleCategorySelect(cat['name']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF8F8FA) : Colors.transparent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Category icon container
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cat['bgColor'],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(cat['emoji'], style: const TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Category name
                          Text(
                            cat['name'],
                            style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF2C3E50),
                                fontWeight: FontWeight.w500
                            ),
                          ),
                        ],
                      ),
                      // Checkmark for selected category
                      if (isSelected)
                        const Text(
                          '✓',
                          style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFB7DBAF),
                              fontWeight: FontWeight.bold
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // BUILD FUNCTION - This creates the visual layout of the screen
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // MAIN SCREEN LAYOUT
        Scaffold(
          backgroundColor: const Color(0xFFFEFEFF),
          body: SafeArea(
            child: Column(
              children: [
                // TOP HEADER with back button and title
                _buildHeader(),

                // SCROLLABLE CONTENT AREA
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount input section
                        _buildAmountSection(),

                        // Transaction type selection (Expense/Income)
                        _buildTransactionTypeSection(),

                        // Category selection (only for expenses)
                        if (_transactionType == 'Expense')
                          _buildCategorySection(),

                        // Note input section
                        _buildNoteSection(),
                      ],
                    ),
                  ),
                ),

                // BOTTOM ADD BUTTON
                _buildAddButton(),
              ],
            ),
          ),
        ),

        // SUCCESS POPUP (shown on top when transaction is added)
        if (_showSuccess && _successData != null)
          _buildSuccessPopup(),
      ],
    );
  }

  // HEADER WIDGET - Top bar with back button and title
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/main', arguments: {'selectedIndex': 0});
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          // Screen title
          const Text(
            'Add Transaction',
            style: TextStyle(fontSize: 33, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(width: 48), // Balances the back button space
        ],
      ),
    );
  }

  // AMOUNT SECTION - Amount input field and currency selector
  Widget _buildAmountSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Text(
            'Amount',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 12),

          // Amount input field
          GestureDetector(
            onTap: () => FocusScope.of(context).requestFocus(_amountFocusNode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Currency symbol
                  Text(
                    _currency == 'USD' ? '\$' : '៛',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Amount text field
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      onChanged: _handleAmountChange,
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Color(0xFF999999)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 28,
                        color: Color(0xFF2C3E50),
                        fontWeight: FontWeight.bold,
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Currency selector (USD/KHR toggle)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FA),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: _currencies.map((curr) => Expanded(
                child: GestureDetector(
                  onTap: () => _handleCurrencySelect(curr),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _currency == curr ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _currency == curr
                          ? [BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 1),
                        blurRadius: 4,
                      )]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      curr,
                      style: TextStyle(
                        fontSize: 14,
                        color: _currency == curr
                            ? const Color(0xFF2C3E50)
                            : const Color(0xFF999999),
                        fontWeight: _currency == curr ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // TRANSACTION TYPE SECTION - Expense/Income selector
  Widget _buildTransactionTypeSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Text(
            'Transaction Type',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 12),

          // Toggle buttons for Expense/Income
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FA),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: _transactionTypes.map((type) => Expanded(
                child: GestureDetector(
                  onTap: () => _handleTransactionTypeSelect(type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _transactionType == type ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _transactionType == type
                          ? [BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 1),
                        blurRadius: 4,
                      )]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 14,
                        color: _transactionType == type
                            ? const Color(0xFF2C3E50)
                            : const Color(0xFF999999),
                        fontWeight: _transactionType == type ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // CATEGORY SECTION - Category selector (only shown for expenses)
  Widget _buildCategorySection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Text(
            'Category',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 12),

          // Category selection button
          GestureDetector(
            onTap: _showCategoryPopup,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Category icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getCurrentCategory()['bgColor'],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            _getCurrentCategory()['emoji'],
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Category name
                      Text(
                        _category,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Dropdown arrow
                  const Text(
                    '⌄',
                    style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NOTE SECTION - Optional note input field
  Widget _buildNoteSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Text(
            'Note (Optional)',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 12),

          // Note input field
          GestureDetector(
            onTap: () => FocusScope.of(context).requestFocus(_noteFocusNode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextFormField(
                controller: _noteController,
                focusNode: _noteFocusNode,
                onChanged: _handleNoteChange,
                decoration: const InputDecoration(
                  hintText: 'e.g. Pizza for dinner',
                  hintStyle: TextStyle(color: Color(0xFF999999)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2C3E50),
                ),
                keyboardType: TextInputType.text,
                maxLines: 1,
                maxLength: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ADD BUTTON - Bottom button to save the transaction
  Widget _buildAddButton() {
    // Check if form is valid (amount is entered and valid)
    final isFormValid = _amount.isNotEmpty &&
        double.tryParse(_amount) != null &&
        double.parse(_amount) > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFEFEFF),
      ),
      child: GestureDetector(
        onTap: _handleAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            // Button color changes based on form validity
            color: isFormValid
                ? const Color(0xFFB7DBAF)  // Green when valid
                : const Color(0xFFF8F8FA), // Gray when invalid
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(
            'Add $_transactionType',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

// SUCCESS POPUP - Fixed version without yellow underlines
  Widget _buildSuccessPopup() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: const Offset(0, 10),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFB7DBAF),
                      const Color(0xFF98C98C),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB7DBAF).withOpacity(0.4),
                      offset: const Offset(0, 8),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _successData!['type'] == 'Income' ? '💰' : '✅',
                    style: const TextStyle(
                      fontSize: 36,
                      decoration: TextDecoration.none, // Fix: Remove any text decoration
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Success title
              Text(
                '${_successData!['type']} Added Successfully!',
                style: const TextStyle(
                  fontSize: 22,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  decoration: TextDecoration.none, // Fix: Remove any text decoration
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Your transaction has been saved',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF2C3E50).withOpacity(0.6),
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  decoration: TextDecoration.none, // Fix: Remove any text decoration
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Transaction details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE9ECEF),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Amount
                    _buildDetailRow(
                      icon: '💵',
                      title: 'Amount',
                      value: '${_successData!['currency'] == 'USD' ? '\$' : '៛'} ${double.parse(_successData!['amount']).toStringAsFixed(2)}',
                      isHighlighted: true,
                    ),

                    if (_successData!['type'] == 'Expense') ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: _getCurrentCategory()['emoji'],
                        title: 'Category',
                        value: _successData!['category'],
                      ),
                    ],

                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: _successData!['type'] == 'Income' ? '📈' : '📉',
                      title: 'Type',
                      value: _successData!['type'],
                    ),

                    if (_successData!['note'] != null && _successData!['note'].isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: '📝',
                        title: 'Note',
                        value: _successData!['note'],
                        isMultiline: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Home button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showSuccess = false;
                      _successData = null;
                    });
                    Navigator.pushReplacementNamed(context, '/main', arguments: {'selectedIndex': 0});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB7DBAF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Go to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none, // Fix: Remove any text decoration
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Fixed detail row widget without yellow underlines
  Widget _buildDetailRow({
    required String icon,
    required String title,
    required String value,
    bool isHighlighted = false,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(
                fontSize: 18,
                decoration: TextDecoration.none, // Fix: Remove any text decoration
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6C757D),
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none, // Fix: Remove any text decoration
                ),
              ),
              const SizedBox(height: 4),

              // Value
              Text(
                value,
                style: TextStyle(
                  fontSize: isHighlighted ? 17 : 15,
                  color: const Color(0xFF2C3E50),
                  fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                  height: 1.3,
                  decoration: TextDecoration.none, // Fix: Remove any text decoration
                ),
                maxLines: isMultiline ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

}