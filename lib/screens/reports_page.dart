import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class ReportsPage extends StatefulWidget {
  final double monthlyEarnings;
  final List<Map<String, dynamic>> installmentPurchases;

  const ReportsPage({super.key, required this.monthlyEarnings, required this.installmentPurchases});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _notesController = TextEditingController();
  final List<Map<String, dynamic>> _goals = [];
  final _goalFormKey = GlobalKey<FormState>();
  String _totalHours = '0:00';
  int _paidLeaveDaysUsed = 0;
  int _absentDays = 0;
  DateTime _currentDisplayedMonth = DateTime.now();
  double _totalExpenses = 0;
  double _closingBalance = 0;
  List<Map<String, dynamic>> _installments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _installments = widget.installmentPurchases;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notesController.text = prefs.getString('notes') ?? '';
      final goals = prefs.getStringList('goals') ?? [];
      
      _goals.clear();
      _goals.addAll(goals.map((goal) {
        final map = json.decode(goal) as Map<String, dynamic>;
        return {
          'title': map['title'],
          'target': map['target'],
          'current': map['current'],
          'deadline': DateTime.parse(map['deadline']),
          'createdAt': DateTime.parse(map['createdAt']),
        };
      }));
      
      _totalHours = '0:00';
      _paidLeaveDaysUsed = 0;
      _absentDays = 0;

      final savedTable = prefs.getString('tableData_${_currentDisplayedMonth.month}_${_currentDisplayedMonth.year}');
      if (savedTable != null) {
        final List<dynamic> decodedData = json.decode(savedTable);
        double totalMinutes = 0;
        
        for (var day in decodedData) {
          if (day['horas'] != null && day['horas'].toString().isNotEmpty && day['horas'] != "--:--") {
            try {
              final parts = day['horas'].toString().split(':');
              final hours = int.parse(parts[0]);
              final minutes = int.parse(parts[1]);
              totalMinutes += hours * 60 + minutes;
            } catch (e) {}
          }
          
          if (day['isPaidLeave'] == true) {
            _paidLeaveDaysUsed++;
          }
          
          if (day['isAbsent'] == true) {
            _absentDays++;
          }
        }
        
        final totalHours = totalMinutes ~/ 60;
        final remainingMinutes = totalMinutes % 60;
        _totalHours = '$totalHours:${remainingMinutes.toString().padLeft(2, '0')}';
      }

      final financeData = prefs.getString('finance_report_${_currentDisplayedMonth.month}_${_currentDisplayedMonth.year}');
      if (financeData != null) {
        final data = json.decode(financeData);
        _totalExpenses = data['totalExpenses'] ?? 0;
        _closingBalance = data['closingBalance'] ?? 0;
      } else {
        _totalExpenses = 0;
        _closingBalance = 0;
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes', _notesController.text);
    
    await prefs.setStringList('goals', _goals.map((g) {
      final encodedGoal = {
        'title': g['title'],
        'target': g['target'],
        'current': g['current'],
        'deadline': (g['deadline'] as DateTime).toIso8601String(),
        'createdAt': (g['createdAt'] as DateTime).toIso8601String(),
      };
      return json.encode(encodedGoal);
    }).toList());
  }

  void _addGoal(String title, double target, DateTime deadline) {
    setState(() {
      _goals.add({
        'title': title,
        'target': target,
        'current': 0.0,
        'deadline': deadline,
        'createdAt': DateTime.now()
      });
    });
    _saveData();
  }

  void _updateGoalDeposit(int index, double amount) {
    setState(() {
      _goals[index]['current'] += amount;
    });
    _saveData();
  }

  void _deleteGoal(int index) {
    setState(() {
      _goals.removeAt(index);
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.monthlyEarnings;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios e Metas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummarySection(balance),
            const SizedBox(height: 20),
            _buildGoalsSection(),
            const SizedBox(height: 20),
            _buildInstallmentsSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(double balance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _currentDisplayedMonth = DateTime(
                        _currentDisplayedMonth.year,
                        _currentDisplayedMonth.month - 1);
                      _loadData();
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    'Resumo Mensal - ${DateFormat('MMMM y', 'pt_BR').format(_currentDisplayedMonth)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _currentDisplayedMonth = DateTime(
                        _currentDisplayedMonth.year,
                        _currentDisplayedMonth.month + 1);
                      _loadData();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSummaryItem('Horas trabalhadas', _totalHours, color: Colors.white),
            _buildSummaryItem('Ganhos totais', '¥${_currentDisplayedMonth.month == DateTime.now().month ? balance.toStringAsFixed(2) : "0.00"}', color: Colors.white),
            _buildSummaryItem('Despesas totais', '¥${_totalExpenses.toStringAsFixed(2)}', color: Colors.red),
            _buildSummaryItem('Folgas Remuneradas', '$_paidLeaveDaysUsed dia(s)', color: Colors.blue),
            _buildSummaryItem('Faltas', '$_absentDays dia(s)', color: Colors.red),
            _buildSummaryItem(
              'Saldo final', 
              '¥${_closingBalance.toStringAsFixed(2)}',
              color: _closingBalance >= 0 ? Colors.green : Colors.red
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(
            fontSize: 16,
            color: color
          )),
          Text(value, style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color
          )),
        ],
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Metas Financeiras', style: TextStyle(fontSize: 16)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ..._goals.asMap().entries.map((entry) => _buildGoalProgress(entry.key, entry.value)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _showAddGoalDialog(),
                  child: const Text('Adicionar Nova Meta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(int index, Map<String, dynamic> goal) {
    final progress = (goal['current'] / goal['target']).clamp(0.0, 1.0);
    final daysLeft = goal['deadline'].difference(DateTime.now()).inDays;

    return ListTile(
      leading: IconButton(
        icon: const Icon(Icons.savings, color: Colors.amber),
        onPressed: () => _showDepositDialog(index),
      ),
      title: Text(goal['title']),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => _deleteGoal(index),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 5),
          Text('¥${goal['current'].toStringAsFixed(2)} de ¥${goal['target'].toStringAsFixed(2)} '
               '(${(progress * 100).toStringAsFixed(1)}%)'),
          Text('Prazo: ${DateFormat('dd/MM/yyyy').format(goal['deadline'])} '
               '($daysLeft dias restantes)',
               style: TextStyle(color: daysLeft < 0 ? Colors.red : null)),
        ],
      ),
    );
  }

  Widget _buildInstallmentsSection() {
    if (_installments.isEmpty) return SizedBox.shrink();

    return Card(
      child: ExpansionTile(
        title: const Text('Compras Parceladas', style: TextStyle(fontSize: 16)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _installments.map((purchase) {
                final totalMonths = purchase['totalMonths'];
                final currentMonth = purchase['currentMonth'];
                final remainingMonths = totalMonths - currentMonth;
                final monthlyPayment = purchase['amount'] / totalMonths;
                final remainingAmount = purchase['amount'] - (monthlyPayment * currentMonth);

                return ListTile(
                  title: Text(purchase['description']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Valor total: ¥${purchase['amount'].toStringAsFixed(2)}'),
                      Text('Parcela mensal: ¥${monthlyPayment.toStringAsFixed(2)}'),
                      Text('Mês atual: $currentMonth/$totalMonths'),
                      Text('Valor restante: ¥${remainingAmount.toStringAsFixed(2)}'),
                      LinearProgressIndicator(
                        value: currentMonth / totalMonths,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Anotações', style: TextStyle(fontSize: 16)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _notesController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Escreva suas anotações aqui...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveData(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nova Meta Financeira'),
              content: Form(
                key: _goalFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Título da Meta'),
                        validator: (value) => value!.isEmpty ? 'Insira um título' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: targetController,
                        decoration: const InputDecoration(labelText: 'Valor Alvo (¥)'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira um valor';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Insira um valor válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        title: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    if (_goalFormKey.currentState!.validate()) {
                      final target = double.tryParse(targetController.text) ?? 0;
                      _addGoal(titleController.text, target, selectedDate);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDepositDialog(int index) {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Depositar Valor'),
        content: TextFormField(
          controller: amountController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Valor a depositar (¥)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                _updateGoalDeposit(index, amount);
                Navigator.pop(context);
              }
            },
            child: const Text('Depositar'),
          ),
        ],
      ),
    );
  }
}