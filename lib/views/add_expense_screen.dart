import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? transaction;

  const AddExpenseScreen({super.key, this.transaction});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  String _amount = '';
  String _category = 'Food';
  String _currency = 'KHR';
  String _transactionType = 'Expense';
  String _note = '';
  String? _transactionId;

  bool _showSuccess = false;
  Map<String, dynamic>? _successData;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();

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

  final List<String> _currencies = ['USD', 'KHR'];
  final List<String> _transactionTypes = ['Expense', 'Income'];

  bool get _isEditMode => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final transaction = widget.transaction!;
      _transactionId = transaction['id'];
      _amount = transaction['amount'].abs().toStringAsFixed(2);
      _category = transaction['type'] == 'income' ? 'Income' : transaction['category'];
      _currency = transaction['currency'] ?? 'USD';
      _transactionType = transaction['type'] == 'income' ? 'Income' : 'Expense';
      _note = transaction['note'] ?? '';
      _amountController.text = _amount;
      _noteController.text = _note;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction(Map<String, dynamic> newTransaction) async {
    try {
      print('Saving transaction: $newTransaction');
      final prefs = await SharedPreferences.getInstance();
      final storedTransactions = prefs.getString('transactions');
      List<dynamic> transactions = [];

      if (storedTransactions != null && storedTransactions.isNotEmpty) {
        try {
          transactions = jsonDecode(storedTransactions) as List;
        } catch (e) {
          print('Error reading existing transactions: $e');
          transactions = [];
        }
      }

      if (_isEditMode) {
        final index = transactions.indexWhere((t) => t['id'] == _transactionId);
        if (index != -1) {
          transactions[index] = newTransaction;
        } else {
          transactions.add(newTransaction);
        }
      } else {
        transactions.add(newTransaction);
      }

      final transactionsJson = jsonEncode(transactions);
      await prefs.setString('transactions', transactionsJson);
      print('Transaction ${_isEditMode ? 'updated' : 'saved'} successfully!');
    } catch (error) {
      print('Error saving transaction: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${_isEditMode ? 'updating' : 'saving'} transaction: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getCurrentCategory() {
    return _categories.firstWhere(
          (cat) => cat['name'] == _category,
      orElse: () => _categories[0],
    );
  }

  String _formatAmount(String text) {
    final cleanText = text.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = cleanText.split('.');
    if (parts.length > 2) {
      return '${parts[0]}.${parts.sublist(1).join('')}';
    }
    if (parts.length == 2 && parts[1].length > 2) {
      return '${parts[0]}.${parts[1].substring(0, 2)}';
    }
    return cleanText;
  }

  void _handleAmountChange(String text) {
    final formatted = _formatAmount(text);
    setState(() {
      _amount = formatted;
      _amountController.text = formatted;
    });
  }

  void _handleNoteChange(String text) {
    setState(() {
      _note = text;
    });
  }

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

  void _handleAdd() async {
    FocusScope.of(context).unfocus();

    if (_amount.isEmpty || double.tryParse(_amount) == null || double.parse(_amount) <= 0) {
      return;
    }

    final amountValue = double.parse(_amount);
    final amountInUSD = _currency == 'KHR' ? amountValue / 4000 : amountValue;
    final finalAmount = _transactionType == 'Income' ? amountInUSD : -amountInUSD;

    final currentCategory = _getCurrentCategory();

    final newTransaction = {
      'id': _isEditMode ? _transactionId : DateTime.now().millisecondsSinceEpoch.toString(),
      'amount': finalAmount,
      'originalAmount': amountValue,
      'category': _transactionType == 'Income' ? 'Income' : _category,
      'recipient': _transactionType == 'Income' ? 'Income' : _category,
      'categoryData': _transactionType == 'Income'
          ? {'name': 'Income', 'emoji': '💰', 'bgColor': 0xFFE8F5E8}
          : {
        'name': currentCategory['name'],
        'emoji': currentCategory['emoji'],
        'bgColor': (currentCategory['bgColor'] as Color).value,
      },
      'date': _isEditMode ? widget.transaction!['date'] : DateTime.now().toIso8601String(),
      'timestamp': _isEditMode
          ? widget.transaction!['timestamp'] ?? DateTime.now().millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch,
      'icon': _transactionType == 'Income' ? '💰' : currentCategory['emoji'],
      'bgColor': _transactionType == 'Income'
          ? 'FFE8F5E8'
          : (currentCategory['bgColor'] as Color).value.toRadixString(16).substring(2).toUpperCase(),
      'currency': _currency,
      'type': _transactionType.toLowerCase(),
      'note': _note,
    };

    await _saveTransaction(newTransaction);

    _successData = {
      'amount': _amount,
      'currency': _currency,
      'type': _transactionType,
      'category': _category,
      'note': _note,
    };

    if (!_isEditMode) {
      _resetForm();
    }

    setState(() {
      _showSuccess = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
          _successData = null;
        });
        Navigator.pop(context, newTransaction);
      }
    });
  }

  void _handleCategorySelect(String categoryName) {
    setState(() {
      _category = categoryName;
    });
    Navigator.pop(context);
  }

  void _handleCurrencySelect(String selectedCurrency) {
    setState(() {
      _currency = selectedCurrency;
      _amount = '';
    });
    _amountController.clear();
  }

  void _handleTransactionTypeSelect(String type) {
    setState(() {
      _transactionType = type;
      if (type == 'Expense') {
        _category = 'Food';
      }
    });
  }

  void _showCategoryPopup() {
    FocusScope.of(context).unfocus();

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
            const Text(
              'Select Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
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
                          Text(
                            cat['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2C3E50),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (isSelected)
                        const Text(
                          '✓',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFB7DBAF),
                            fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFEFEFF),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAmountSection(),
                        _buildTransactionTypeSection(),
                        if (_transactionType == 'Expense') _buildCategorySection(),
                        _buildNoteSection(),
                      ],
                    ),
                  ),
                ),
                _buildAddButton(),
              ],
            ),
          ),
        ),
        if (_showSuccess && _successData != null) _buildSuccessPopup(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
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
          Text(
            _isEditMode ? 'Edit Transaction' : 'Add Transaction',
            style: const TextStyle(fontSize: 33, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amount',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 12),
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
                  Text(
                    _currency == 'USD' ? '\$' : '៛',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
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
                          ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: const Offset(0, 1),
                          blurRadius: 4,
                        )
                      ]
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

  Widget _buildTransactionTypeSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction Type',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 12),
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
                          ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: const Offset(0, 1),
                          blurRadius: 4,
                        )
                      ]
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

  Widget _buildCategorySection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 12),
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

  Widget _buildNoteSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Note (Optional)',
            style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 12),
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

  Widget _buildAddButton() {
    final isFormValid =
        _amount.isNotEmpty && double.tryParse(_amount) != null && double.parse(_amount) > 0;

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
            color: isFormValid ? const Color(0xFFB7DBAF) : const Color(0xFFF8F8FA),
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(
            _isEditMode ? 'Update Transaction' : 'Add $_transactionType',
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
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '${_successData!['type']} ${_isEditMode ? 'Updated' : 'Added'} Successfully!',
                style: const TextStyle(
                  fontSize: 22,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your transaction has been ${_isEditMode ? 'updated' : 'saved'}',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF2C3E50).withOpacity(0.6),
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                    _buildDetailRow(
                      icon: '💵',
                      title: 'Amount',
                      value:
                      '${_successData!['currency'] == 'USD' ? '\$' : '៛'} ${double.parse(_successData!['amount']).toStringAsFixed(2)}',
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showSuccess = false;
                      _successData = null;
                    });
                    Navigator.pop(context);
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
                      Icon(Icons.arrow_back_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Back to Transactions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
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
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6C757D),
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isHighlighted ? 17 : 15,
                  color: const Color(0xFF2C3E50),
                  fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                  height: 1.3,
                  decoration: TextDecoration.none,
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