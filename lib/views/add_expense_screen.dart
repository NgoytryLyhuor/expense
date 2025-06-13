import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> with TickerProviderStateMixin {
  String _amount = '';
  String _category = 'Food';
  String _currency = 'USD';
  String _transactionType = 'Expense';
  bool _showSuccess = false;
  Map<String, dynamic>? _successData;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  bool _isMounted = true;

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

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(_slideController);
    _pulseAnimation = Tween<double>(begin: 1, end: 1.1).animate(_pulseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_amountFocusNode);
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction(Map<String, dynamic> newTransaction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedTransactions = prefs.getString('transactions');
      final transactions = storedTransactions != null ? jsonDecode(storedTransactions) as List : [];
      transactions.add(newTransaction);
      await prefs.setString('transactions', jsonEncode(transactions));
    } catch (error) {
      print('Error saving transaction: $error');
    }
  }

  Map<String, dynamic> _getCurrentCategory() {
    return _successData?['category'] != null
        ? _categories.firstWhere((cat) => cat['name'] == _successData!['category'])
        : _categories.firstWhere((cat) => cat['name'] == _category, orElse: () => _categories[0]);
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

  void _resetForm() {
    setState(() {
      _amount = '';
      _amountController.clear();
      _category = 'Food';
      _currency = 'USD';
      _transactionType = 'Expense';
    });
  }

  void _handleAdd() {
    if (_amount.isEmpty || double.tryParse(_amount) == null || double.parse(_amount) <= 0) {
      return;
    }

    final amountInUSD = _currency == 'KHR' ? double.parse(_amount) / 4000 : double.parse(_amount);
    final finalAmount = _transactionType == 'Income' ? amountInUSD : -amountInUSD;

    final displayAmount = _amount;
    final displayCurrency = _currency;
    final displayType = _transactionType;
    final displayCategory = _category;

    final newTransaction = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'amount': finalAmount,
      'category': _transactionType == 'Income' ? 'Income' : _category,
      'categoryData': _transactionType == 'Income'
          ? {'name': 'Income', 'emoji': '💰', 'bgColor': '#E8F5E8'}
          : _getCurrentCategory(),
      'date': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'icon': _transactionType == 'Income' ? '💰' : _getCurrentCategory()['emoji'],
      'bgColor': _transactionType == 'Income' ? '#E8F5E8' : _getCurrentCategory()['bgColor'].value.toRadixString(16).substring(2),
      'currency': _currency,
    };

    _saveTransaction(newTransaction);

    _resetForm();

    setState(() {
      _successData = {
        'amount': displayAmount,
        'currency': displayCurrency,
        'type': displayType,
        'category': displayCategory,
      };
      _showSuccess = true;
    });

    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();

    Future.delayed(const Duration(milliseconds: 200), () {
      _pulseController.forward().then((_) => _pulseController.reverse());
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!_isMounted) return;
      _fadeController.reverse();
      _scaleController.reverse();
      _slideController.reverse().then((_) {
        if (!_isMounted) return;
        setState(() {
          _showSuccess = false;
          _successData = null;
        });
        _fadeController.reset();
        _scaleController.reset();
        _slideController.reset();
        _pulseController.reset();
        Navigator.pushReplacementNamed(context, '/main', arguments: {'selectedIndex': 0});
      });
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
      _amountController.clear();
    });
  }

  void _handleTransactionTypeSelect(String type) {
    setState(() {
      _transactionType = type;
      if (type == 'Expense') {
        _category = 'Food';
      }
    });
  }

  void _handleCategoryPress() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
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
            ..._categories.asMap().entries.map((entry) {
              final cat = entry.value;
              final isLast = entry.key == _categories.length - 1;
              return GestureDetector(
                onTap: () => _handleCategorySelect(cat['name']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: _category == cat['name'] ? const Color(0xFFF8F8FA) : Colors.transparent,
                    border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : const Color(0xFFF8F8FA))),
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
                              child: Text(
                                cat['emoji'],
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            cat['name'],
                            style: const TextStyle(fontSize: 16, color: Color(0xFF2C3E50), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (_category == cat['name'])
                        const Text(
                          '✓',
                          style: TextStyle(fontSize: 16, color: Color(0xFFB7DBAF), fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              );
            }),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Add Transaction',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Amount',
                                style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
                              ),
                              const SizedBox(height: 12),
                              Container(
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
                                        autofocus: true,
                                      ),
                                    ),
                                  ],
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
                                  children: _currencies
                                      .map((curr) => Expanded(
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
                                            ),
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
                                  ))
                                      .toList(),
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
                                  children: _transactionTypes
                                      .map((type) => Expanded(
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
                                            ),
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
                                            fontWeight:
                                            _transactionType == type ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_transactionType == 'Expense')
                          Container(
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
                                  onTap: _handleCategoryPress,
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
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEFEFF),
                  ),
                  child: GestureDetector(
                    onTap: _handleAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _amount.isEmpty || double.tryParse(_amount) == null || double.parse(_amount) <= 0
                            ? const Color(0xFFF8F8FA)
                            : const Color(0xFFB7DBAF),
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
                ),
              ],
            ),
          ),
        ),
        if (_showSuccess && _successData != null)
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_slideAnimation),
                child: Stack(
                  children: [
                    Container(
                      color: Colors.black.withOpacity(0.6),
                    ),
                    Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        constraints: const BoxConstraints(maxWidth: 380),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFB7DBAF), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(0, 8),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFFB7DBAF).withOpacity(0.3),
                                          width: 2
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFB7DBAF),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFB7DBAF).withOpacity(0.3),
                                          offset: const Offset(0, 4),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        _successData!['type'] == 'Income' ? '💰' : '✅',
                                        style: const TextStyle(fontSize: 32),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '${_successData!['type']} Added Successfully!',
                              style: const TextStyle(
                                fontSize: 22,
                                color: Color(0xFF2C3E50),
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F8FA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Amount:',
                                        style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                                      ),
                                      Text(
                                        '${_successData!['currency'] == 'USD' ? '\$' : '៛'} ${double.parse(_successData!['amount']).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF2C3E50),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_successData!['type'] == 'Expense')
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F8FA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Category:',
                                          style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              _getCurrentCategory()['emoji'],
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _successData!['category'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF2C3E50),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.only(top: 16),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                              ),
                              child: const Text(
                                'Redirecting to home...',
                                style: TextStyle(fontSize: 14, color: Color(0xFF999999), fontStyle: FontStyle.italic),
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
          ),
      ],
    );
  }
}