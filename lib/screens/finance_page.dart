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

  @override
  void initState() {
    super.initState();
    _loadExpenses();
    _remainingBalance = widget.monthlyEarnings;
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = prefs.getStringList('expenses') ?? [];
    
    setState(() {
      _expenses = expensesJson.map((json) => Expense.fromJson(jsonDecode(json))).toList();
      _calculateTotals();
    });
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = _expenses.map((expense) => jsonEncode(expense.toJson())).toList();
    await prefs.setStringList('expenses', expensesJson);
  }

  void _calculateTotals() {
    double totalDeductions = _expenses.fold(0, (sum, expense) => sum + expense.amount);
    
    setState(() {
      _totalExpenses = totalDeductions;
      _remainingBalance = widget.monthlyEarnings - totalDeductions;
    });
  }

  int _calculateMonthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month;
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
    );
    
    if (picked != null) {
      setState(() => _selectedEndDate = picked);
    }
  }

  void _addExpense() {
    if (_formKey.currentState!.validate()) {
      if (_selectedType == ExpenseType.fixedTerm && _selectedEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selecione uma data final para gastos fixos com validade')),
        );
        return;
      }

      final expense = Expense(
        type: _selectedType,
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
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
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Adicionar Despesa',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<ExpenseType>(
                value: _selectedType,
                items: ExpenseType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                    if (_selectedType == ExpenseType.fixedTerm) {
                      _selectedEndDate = null;
                      WidgetsBinding.instance.addPostFrameCallback((_) => _selectEndDate());
                    }
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Tipo de Despesa',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Valor Total (¥)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
              ),
              if (_selectedType == ExpenseType.fixedTerm) ...[
                SizedBox(height: 15),
                ListTile(
                  title: Text(_selectedEndDate == null
                      ? 'Selecione a data final'
                      : 'Validade até: ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}'),
                  trailing: Icon(Icons.calendar_today),
                  onTap: _selectEndDate,
                ),
                if (_selectedEndDate != null) ...[
                  SizedBox(height: 10),
                  Text(
                    'Duração Total: ${_calculateMonthsBetween(DateTime.now(), _selectedEndDate!)} meses',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Comprometimento Mensal: ¥${(_amountController.text.isNotEmpty && _selectedEndDate != null) 
                        ? (double.parse(_amountController.text) / 
                           _calculateMonthsBetween(DateTime.now(), _selectedEndDate!)).toStringAsFixed(0)
                        : '0'}',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ],
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addExpense,
                child: Text('Adicionar Despesa'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String title, double value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        constraints: BoxConstraints(minWidth: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '¥${value.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.2,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Finanças'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddExpenseDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: _buildBalanceCard('Recebido', widget.monthlyEarnings, Colors.green)),
                  SizedBox(width: 8),
                  Expanded(child: _buildBalanceCard('Comprometido', _totalExpenses, Colors.red)),
                  SizedBox(width: 8),
                  Expanded(child: _buildBalanceCard(
                    'Saldo Disponível', 
                    _remainingBalance, 
                    _remainingBalance >= 0 ? Colors.blue : Colors.orange
                  )),
                ],
              ),
            ),
          ),
          Expanded(
            child: _expenses.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma despesa registrada',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
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
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDelete;

  const ExpenseTile({Key? key, required this.expense, required this.onDelete}) : super(key: key);

  int _calculateMonthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month;
  }

  @override
  Widget build(BuildContext context) {
    final monthsTotal = expense.endDate != null 
        ? _calculateMonthsBetween(expense.startDate, expense.endDate!) 
        : 0;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_getIconByType(), color: _getColorByType(), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(expense.startDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      constraints: BoxConstraints(minWidth: 80),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '¥${expense.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _getColorByType(),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            if (expense.type == ExpenseType.fixedTerm && expense.endDate != null) ...[
              Divider(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    _buildDetailRow('Data Final:', DateFormat('dd/MM/yyyy').format(expense.endDate!)),
                    SizedBox(height: 6),
                    _buildDetailRow('Duração Total:', '$monthsTotal meses'),
                    SizedBox(height: 6),
                    _buildDetailRow(
                      'Mensal:', 
                      '¥${(expense.amount / monthsTotal).toStringAsFixed(0)}'
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _getIconByType() {
    switch (expense.type) {
      case ExpenseType.fixedTerm:
        return Icons.date_range;
      case ExpenseType.fixed:
        return Icons.lock_clock;
      default:
        return Icons.money_off;
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
  fixedTerm('Gasto Fixo com Validade');

  final String displayName;
  const ExpenseType(this.displayName);
}