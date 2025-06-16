import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  List<Map<String, dynamic>> _savingsGoals = [];
  bool _isLoading = true;

  // Colors matching HomeScreen exactly
  final Color _primaryColor = const Color(0xFF2C3E50);
  final Color _secondaryColor = const Color(0xFF95A5A6);
  final Color _backgroundColor = const Color(0xFFFEFEFF);
  final Color _cardColor = const Color(0xFFF8F8FA);
  final Color _accentColor = const Color(0xFF007AFF);
  final Color _incomeColor = const Color(0xFFB6DBAD);
  final Color _spentColor = const Color(0xFFFEB8A8);
  final Color _successColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _errorColor = const Color(0xFFEF4444);

  // Goal colors matching HomeScreen aesthetic
  final List<Color> _goalColors = [
    const Color(0xFFB6DBAD), // Matching income green
    const Color(0xFFA8C7EB), // Soft blue
    const Color(0xFFFEB8A8), // Matching spent color
    const Color(0xFFF5D7A1), // Soft yellow
    const Color(0xFFD4B8F5), // Soft purple
  ];

  @override
  void initState() {
    super.initState();
    _loadSavingsGoals();
  }

  Future<void> _loadSavingsGoals() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedGoals = prefs.getString('savings_goals');

    if (savedGoals != null) {
      final List<dynamic> decoded = jsonDecode(savedGoals);
      setState(() {
        _savingsGoals = decoded.map((goal) {
          return {
            'id': goal['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'title': goal['title'],
            'target': goal['target']?.toDouble() ?? 0.0,
            'saved': goal['saved']?.toDouble() ?? 0.0,
            'color': Color(goal['color'] ?? _goalColors[0].value),
            'icon': goal['icon'] ?? '💰',
            'deadline': DateTime.parse(goal['deadline']),
            'createdAt': DateTime.parse(goal['createdAt']),
          };
        }).toList();
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsToSave = _savingsGoals.map((goal) {
      return {
        'id': goal['id'],
        'title': goal['title'],
        'target': goal['target'],
        'saved': goal['saved'],
        'color': (goal['color'] as Color).value,
        'icon': goal['icon'],
        'deadline': (goal['deadline'] as DateTime).toIso8601String(),
        'createdAt': (goal['createdAt'] as DateTime).toIso8601String(),
      };
    }).toList();
    await prefs.setString('savings_goals', jsonEncode(goalsToSave));
  }

  Future<void> _addOrUpdateGoal(Map<String, dynamic> goal, [bool isUpdate = false]) async {
    if (isUpdate && goal['id'] != null) {
      setState(() {
        final index = _savingsGoals.indexWhere((g) => g['id'] == goal['id']);
        if (index != -1) {
          _savingsGoals[index] = goal;
        }
      });
    } else {
      setState(() {
        _savingsGoals.add({
          ...goal,
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'createdAt': DateTime.now(),
        });
      });
    }
    await _saveGoals();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteGoal(String id) async {
    setState(() {
      _savingsGoals.removeWhere((goal) => goal['id'] == id);
    });
    await _saveGoals();
  }

  Future<void> _showAddEditGoalDialog([Map<String, dynamic>? existingGoal]) async {
    final isEdit = existingGoal != null;
    final titleController = TextEditingController(text: isEdit ? existingGoal['title'] : '');
    final targetController = TextEditingController(
        text: isEdit ? existingGoal['target'].toStringAsFixed(2) : '');
    final savedController = TextEditingController(
        text: isEdit ? existingGoal['saved'].toStringAsFixed(2) : '0.00');
    DateTime deadline = isEdit ? existingGoal['deadline'] : DateTime.now().add(const Duration(days: 30));
    String icon = isEdit ? existingGoal['icon'] : '💰';
    Color selectedColor = isEdit ? existingGoal['color'] : _goalColors[0];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              backgroundColor: _backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEdit ? 'Edit Goal' : 'Add New Goal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Goal Name',
                        labelStyle: TextStyle(color: _secondaryColor),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Target Amount',
                        prefixText: '\$ ',
                        labelStyle: TextStyle(color: _secondaryColor),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: savedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount Saved',
                        prefixText: '\$ ',
                        labelStyle: TextStyle(color: _secondaryColor),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: deadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: _accentColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: _primaryColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          dialogSetState(() => deadline = pickedDate);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Deadline',
                              style: TextStyle(color: _secondaryColor),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy').format(deadline),
                              style: TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Icon',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: ['💰', '🏠', '🚗', '🎓', '🏖️', '💻', '📱', '👕', '🍎', '✈️']
                                .map((emoji) => GestureDetector(
                              onTap: () => dialogSetState(() => icon = emoji),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: icon == emoji
                                      ? selectedColor.withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: icon == emoji
                                      ? Border.all(
                                      color: selectedColor, width: 2)
                                      : Border.all(
                                      color: Colors.grey.withOpacity(0.2)),
                                ),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Color',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 50,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _goalColors
                                .map((color) => GestureDetector(
                              onTap: () =>
                                  dialogSetState(() => selectedColor = color),
                              child: Container(
                                width: 40,
                                height: 40,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: selectedColor == color
                                      ? Border.all(
                                    color: _accentColor,
                                    width: 3,
                                  )
                                      : Border.all(
                                    color: Colors.grey
                                        .withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: _secondaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (titleController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please enter a goal name')),
                                );
                                return;
                              }

                              final targetAmount =
                                  double.tryParse(targetController.text) ?? 0.0;
                              final savedAmount =
                                  double.tryParse(savedController.text) ?? 0.0;

                              if (targetAmount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                      Text('Please enter a valid target amount')),
                                );
                                return;
                              }

                              final newGoal = {
                                'title': titleController.text.trim(),
                                'target': targetAmount,
                                'saved': savedAmount,
                                'color': selectedColor,
                                'icon': icon,
                                'deadline': deadline,
                                if (isEdit) 'id': existingGoal['id'],
                                if (isEdit) 'createdAt': existingGoal['createdAt'],
                              };
                              _addOrUpdateGoal(newGoal, isEdit);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isEdit ? 'Update' : 'Add',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
      },
    );
  }

  Future<void> _showDeleteConfirmation(String id, String title) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Goal?',
          style: TextStyle(color: _primaryColor),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?',
          style: TextStyle(color: _secondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: _secondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteGoal(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  double _calculateTotalSaved() {
    return _savingsGoals.fold(
        0.0, (sum, goal) => sum + (goal['saved'] as double));
  }

  double _calculateTotalTarget() {
    return _savingsGoals.fold(
        0.0, (sum, goal) => sum + (goal['target'] as double));
  }

  double _calculateTotalProgress() {
    final totalSaved = _calculateTotalSaved();
    final totalTarget = _calculateTotalTarget();
    return totalTarget > 0 ? totalSaved / totalTarget : 0;
  }

  String _calculateDaysLeft(DateTime deadline) {
    final days = deadline.difference(DateTime.now()).inDays;
    return days > 0 ? '$days days left' : 'Overdue';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Savings Goals',
                        style: TextStyle(fontSize: 33, color: Color(0xFF2C3E50)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your financial goals',
                        style: TextStyle(
                          fontSize: 14,
                          color: _secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: _accentColor,
                      ),
                    ),
                    onPressed: () => _showAddEditGoalDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content Section
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(color: _accentColor),
              )
                  : RefreshIndicator(
                onRefresh: _loadSavingsGoals,
                color: _accentColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Total Savings Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Savings',
                              style: TextStyle(
                                fontSize: 16,
                                color: _secondaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${_calculateTotalSaved().toStringAsFixed(2)} of \$${_calculateTotalTarget().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 6,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: _calculateTotalProgress().clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(_calculateTotalProgress() * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _secondaryColor,
                                  ),
                                ),
                                Text(
                                  _calculateTotalSaved() >= _calculateTotalTarget()
                                      ? 'Goal Achieved! 🎉'
                                      : 'Remaining: \$${(_calculateTotalTarget() - _calculateTotalSaved()).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _calculateTotalSaved() >= _calculateTotalTarget()
                                        ? _successColor
                                        : _secondaryColor,
                                    fontWeight: _calculateTotalSaved() >= _calculateTotalTarget()
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Goals List Header
                      if (_savingsGoals.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Goals',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            Text(
                              '${_savingsGoals.length} ${_savingsGoals.length == 1 ? 'goal' : 'goals'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // Goals List or Empty State
                      if (_savingsGoals.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.savings_outlined,
                                size: 60,
                                color: _secondaryColor.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No savings goals yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to create your first goal',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _secondaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ..._savingsGoals.map((goal) {
                          final progress = (goal['target'] as double) > 0
                              ? (goal['saved'] as double) / (goal['target'] as double)
                              : 0.0;
                          final daysLeft = _calculateDaysLeft(goal['deadline']);
                          final isOverdue = daysLeft == 'Overdue';
                          final isCompleted = progress >= 1.0;

                          return Dismissible(
                            key: Key(goal['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: _errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: Icon(Icons.delete, color: _errorColor),
                            ),
                            confirmDismiss: (direction) async {
                              await _showDeleteConfirmation(
                                  goal['id'], goal['title']);
                              return false;
                            },
                            child: GestureDetector(
                              onTap: () => _showAddEditGoalDialog(goal),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: goal['color'],
                                            borderRadius:
                                            BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              goal['icon'],
                                              style:
                                              const TextStyle(fontSize: 24),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                goal['title'],
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: _primaryColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Target: \$${(goal['target'] as double).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _secondaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '\$${(goal['saved'] as double).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isCompleted
                                                    ? _successColor
                                                    : _primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              daysLeft,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isOverdue
                                                    ? _errorColor
                                                    : isCompleted
                                                    ? _successColor
                                                    : _secondaryColor,
                                                fontWeight: isOverdue
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 6,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: progress.clamp(0.0, 1.0),
                                          backgroundColor: Colors.grey.withOpacity(0.1),
                                          valueColor: AlwaysStoppedAnimation<Color>(goal['color']),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${(progress * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _secondaryColor,
                                          ),
                                        ),
                                        Text(
                                          isCompleted
                                              ? 'Completed! 🎉'
                                              : 'Remaining: \$${(goal['target'] - goal['saved']).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isCompleted
                                                ? _successColor
                                                : _secondaryColor,
                                            fontWeight: isCompleted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 20),
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