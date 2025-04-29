import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FinancePage extends StatefulWidget {
  final double monthlyEarnings;

  const FinancePage({Key? key, required this.monthlyEarnings}) : super(key: key);

  @override
  _FinancePageState createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  List<Expense> _expenses = [];
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _selectedEndDate;
  ExpenseType _selectedType = ExpenseType.variable;
  double _remainingBalance = 0;
  double _totalExpenses = 0;
  bool _expenseClosingFollowsTimesheet = true;
  DateTime _currentPeriodStart = DateTime.now();
  DateTime _currentPeriodEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadExpenses().then((_) {
      _checkForMonthReset();
    });
    _remainingBalance = widget.monthlyEarnings;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _expenseClosingFollowsTimesheet = prefs.getBool('expenseClosingFollowsTimesheet') ?? true;
      
      if (_expenseClosingFollowsTimesheet) {
        _currentPeriodStart = DateTime.parse(prefs.getString('startDate') ?? DateTime.now().toString());
        final autoClose = prefs.getBool('autoCloseEndOfMonth') ?? false;
        if (autoClose) {
          final now = DateTime.now();
          _currentPeriodEnd = DateTime(now.year, now.month + 1, 0);
        } else {
          _currentPeriodEnd = DateTime.parse(prefs.getString('endDate') ?? DateTime.now().toString());
        }
      } else {
        final now = DateTime.now();
        _currentPeriodStart = DateTime(now.year, now.month, 1);
        _currentPeriodEnd = DateTime(now.year, now.month + 1, 0);
      }
    });
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = prefs.getStringList('expenses') ?? [];
    
    final now = DateTime.now();
    final currentExpenses = expensesJson.map((json) => Expense.fromJson(jsonDecode(json)))
      .where((expense) {
        if (_expenseClosingFollowsTimesheet) {
          return expense.startDate.isAfter(_currentPeriodStart.subtract(Duration(days: 1))) &&
                 expense.startDate.isBefore(_currentPeriodEnd.add(Duration(days: 1)));
        } else {
          if (expense.type == ExpenseType.variable) {
            return expense.startDate.month == now.month && expense.startDate.year == now.year;
          } else {
            return true;
          }
        }
      })
      .toList();
    
    setState(() {
      _expenses = currentExpenses;
      _calculateTotals();
    });
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = _expenses.map((expense) => jsonEncode(expense.toJson())).toList();
    await prefs.setStringList('expenses', expensesJson);
  }

  void _calculateTotals() {
    double totalDeductions = 0;
    
    for (var expense in _expenses) {
      if (expense.type == ExpenseType.fixedTerm && expense.endDate != null) {
        final monthsTotal = _calculateMonthsBetween(expense.startDate, expense.endDate!);
        final currentMonth = DateTime.now().month;
        final currentYear = DateTime.now().year;
        
        if (currentYear == expense.startDate.year && currentMonth >= expense.startDate.month ||
            currentYear > expense.startDate.year) {
          if (currentYear < expense.endDate!.year || 
              (currentYear == expense.endDate!.year && currentMonth <= expense.endDate!.month)) {
            totalDeductions += expense.amount / monthsTotal;
          }
        }
      } else {
        totalDeductions += expense.amount;
      }
    }
    
    setState(() {
      _totalExpenses = totalDeductions;
      _remainingBalance = widget.monthlyEarnings - totalDeductions;
    });
  }

  void _checkForMonthReset() {
    final now = DateTime.now();
    final lastResetMonth = _currentPeriodEnd.month;
    final lastResetYear = _currentPeriodEnd.year;
    
    if (now.month != lastResetMonth || now.year != lastResetYear) {
      _transferDataToReports();
      _loadSettings();
      _loadExpenses();
    }
  }

  Future<void> _transferDataToReports() async {
    final prefs = await SharedPreferences.getInstance();
    
    double closingBalance = widget.monthlyEarnings;
    double totalExpenses = 0;
    
    for (var expense in _expenses) {
      if (expense.type == ExpenseType.fixedTerm && expense.endDate != null) {
        final monthsTotal = _calculateMonthsBetween(expense.startDate, expense.endDate!);
        totalExpenses += expense.amount / monthsTotal;
      } else {
        totalExpenses += expense.amount;
      }
    }
    
    closingBalance -= totalExpenses;
    
    final reportData = {
      'month': _currentPeriodEnd.month,
      'year': _currentPeriodEnd.year,
      'totalExpenses': totalExpenses,
      'closingBalance': closingBalance,
    };
    
    await prefs.setString('finance_report_${_currentPeriodEnd.month}_${_currentPeriodEnd.year}', 
        jsonEncode(reportData));
  }

  int _calculateMonthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month + 1;
  }

  String _formatTimeLeft(DateTime endDate) {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 'Finalizado';
    
    final difference = endDate.difference(now);
    final months = difference.inDays ~/ 30;
    final days = difference.inDays % 30;
    
    return '$months ${months == 1 ? 'mês' : 'meses'} e $days ${days == 1 ? 'dia' : 'dias'}';
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedEndDate = picked);
    }
  }

  void _addExpense() {
    if (_formKey.currentState!.validate()) {
      if (_selectedType == ExpenseType.fixedTerm) {
        if (_selectedEndDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selecione uma data final para compras parceladas'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        if (_selectedEndDate!.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('A data final não pode ser anterior à data atual'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final expense = Expense(
        type: _selectedType,
        description: _descriptionController.text,
        amount: double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0,
        startDate: DateTime.now(),
        endDate: _selectedType == ExpenseType.fixedTerm ? _selectedEndDate : null,
      );

      setState(() {
        _expenses.add(expense);
        _saveExpenses();
        _calculateTotals();
        _clearForm();
      });
      Navigator.pop(context);
    }
  }

  void _clearForm() {
    _descriptionController.clear();
    _amountController.clear();
    _selectedEndDate = null;
    _selectedType = ExpenseType.variable;
  }

  void _showAddExpenseDialog() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Adicionar Despesa',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Período: ${DateFormat('dd/MM/yy').format(_currentPeriodStart)} - ${DateFormat('dd/MM/yy').format(_currentPeriodEnd)}',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<ExpenseType>(
                  value: _selectedType,
                  items: ExpenseType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName, style: TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                      if (_selectedType == ExpenseType.fixedTerm) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _selectEndDate().then((_) {
                            if (mounted) setState(() {});
                          });
                        });
                      }
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  ),
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    prefixIcon: Icon(Icons.description, size: 20),
                  ),
                  validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Valor (¥)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    prefixIcon: Icon(Icons.attach_money, size: 20),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return 'Campo obrigatório';
                    if (double.tryParse(value.replaceAll(',', '.')) == null) {
                      return 'Valor inválido';
                    }
                    return null;
                  },
                ),
                if (_selectedType == ExpenseType.fixedTerm) ...[
                  SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _selectedEndDate == null
                          ? 'Selecione data final *'
                          : 'Validade: ${DateFormat('dd/MM/yy').format(_selectedEndDate!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedEndDate == null ? Colors.red : null,
                      ),
                    ),
                    trailing: Icon(Icons.calendar_month, size: 20),
                    onTap: _selectEndDate,
                  ),
                  if (_selectedEndDate != null) ...[
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Parcelas:', style: TextStyle(fontSize: 13)),
                        Text(
                          '${_calculateMonthsBetween(DateTime.now(), _selectedEndDate!)}x',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mensal:', style: TextStyle(fontSize: 13)),
                        Text(
                          '¥${(_amountController.text.isNotEmpty ? ((double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0) / _calculateMonthsBetween(DateTime.now(), _selectedEndDate!)).toStringAsFixed(0) : '0')}',
                          style: TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addExpense,
                    child: Text('Adicionar', style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 60 : 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String title, double value, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Card(
  color: Theme.of(context).cardColor,
  elevation: 1,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
  child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForBalance(title),
                color: color,
                size: 20,
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                '¥${NumberFormat('#,##0', 'pt_BR').format(value)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForBalance(String title) {
    switch (title) {
      case 'Recebido':
        return Icons.attach_money;
      case 'Gastos':
        return Icons.money_off;
      case 'Disponível':
        return Icons.account_balance_wallet;
      default:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Finanças', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, size: 24),
            onPressed: _showAddExpenseDialog,
            tooltip: 'Adicionar despesa',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildBalanceCard('Recebido', widget.monthlyEarnings, Colors.green),
                      _buildBalanceCard('Gastos', _totalExpenses, Colors.red),
                      _buildBalanceCard(
                        'Disponível',
                        _remainingBalance,
                        _remainingBalance >= 0 ? Colors.blue : Colors.orange,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Período: ${DateFormat('dd/MM').format(_currentPeriodStart)} - ${DateFormat('dd/MM').format(_currentPeriodEnd)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.money_off, size: 40, color: Colors.grey[400]),
                          SizedBox(height: 8),
                          Text(
                            'Sem despesas registradas',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: 16),
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return ExpenseTile(
                          expense: expense,
                          onDelete: () {
                            setState(() {
                              _expenses.removeAt(index);
                              _saveExpenses();
                              _calculateTotals();
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDelete;

  const ExpenseTile({Key? key, required this.expense, required this.onDelete}) : super(key: key);

  int _calculateMonthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month + 1;
  }

  double _calculateRemaining(Expense expense) {
    if (expense.type != ExpenseType.fixedTerm || expense.endDate == null) return 0;
    
    final totalMonths = _calculateMonthsBetween(expense.startDate, expense.endDate!);
    final now = DateTime.now();
    int monthsPassed = _calculateMonthsBetween(expense.startDate, now);
    
    if (now.isAfter(expense.endDate!)) {
      return 0;
    }
    
    monthsPassed = monthsPassed.clamp(0, totalMonths);
    final monthly = expense.amount / totalMonths;
    final remaining = expense.amount - (monthly * monthsPassed);
    
    return remaining > 0 ? remaining : 0;
  }

  @override
Widget build(BuildContext context) {
  final int monthsTotal = expense.type == ExpenseType.fixedTerm && expense.endDate != null
      ? _calculateMonthsBetween(expense.startDate, expense.endDate!)
      : 0;
  final double remaining = _calculateRemaining(expense);

  return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        elevation: 1,
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 12),
          leading: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getColorByType().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getIconByType(), color: _getColorByType(), size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  expense.description,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Chip(
                label: Text(
                  '¥${expense.amount.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: _getColorByType()),
                ),
                backgroundColor: _getColorByType().withOpacity(0.1),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
          subtitle: Text(
            DateFormat('dd/MM/yyyy').format(expense.startDate),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
            onPressed: onDelete,
          ),
          children: expense.type == ExpenseType.fixedTerm && expense.endDate != null
        ? [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                children: [
                  _buildDetailRow('Data Final:', DateFormat('dd/MM/yyyy').format(expense.endDate!)),
                  _buildDetailRow('Parcelas:', '$monthsTotal meses'),
                  _buildDetailRow('Mensal:', '¥${(expense.amount / monthsTotal).toStringAsFixed(0)}'),
                  _buildDetailRow('Restante:', '¥${remaining.toStringAsFixed(0)}'),
                      ],
                    ),
                  )
                ]
              : [],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  IconData _getIconByType() {
    switch (expense.type) {
      case ExpenseType.fixedTerm:
        return Icons.credit_card;
      case ExpenseType.fixed:
        return Icons.calendar_today;
      default:
        return Icons.shopping_bag;
    }
  }

  Color _getColorByType() {
    switch (expense.type) {
      case ExpenseType.fixedTerm:
        return Colors.purple;
      case ExpenseType.fixed:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}

class Expense {
  final ExpenseType type;
  final String description;
  final double amount;
  final DateTime startDate;
  final DateTime? endDate;

  Expense({
    required this.type,
    required this.description,
    required this.amount,
    required this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'description': description,
    'amount': amount,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      type: ExpenseType.values[json['type']],
      description: json['description'],
      amount: json['amount'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    );
  }
}

enum ExpenseType {
  variable('Variável'),
  fixed('Fixo'),
  fixedTerm('Compra Parcelada');

  final String displayName;
  const ExpenseType(this.displayName);
}