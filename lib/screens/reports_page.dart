import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ReportsPage extends StatefulWidget {
  final double monthlyEarnings;

  const ReportsPage({super.key, required this.monthlyEarnings});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _notesController = TextEditingController();
  final List<Map<String, dynamic>> _goals = [];
  final _goalFormKey = GlobalKey<FormState>();
  double _variableExpenses = 0;
  String _totalHours = '0';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _variableExpenses = prefs.getDouble('variableExpenses') ?? 0;
      _notesController.text = prefs.getString('notes') ?? '';
      final goals = prefs.getStringList('goals') ?? [];
      
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
      
      _totalHours = prefs.getString('totalHours') ?? '0';
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('variableExpenses', _variableExpenses);
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
    
    await prefs.setString('totalHours', _totalHours);
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

  @override
  Widget build(BuildContext context) {
    final totalExpenses = _variableExpenses;
    final balance = widget.monthlyEarnings - totalExpenses;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios e Metas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummarySection(balance, totalExpenses),
            const SizedBox(height: 20),
            _buildGoalsSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(double balance, double totalExpenses) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Resumo Mensal', style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Colors.white
            )),
            const SizedBox(height: 10),
            _buildSummaryItem('Horas trabalhadas', '$_totalHours horas', color: Colors.white),
            _buildSummaryItem('Ganhos totais', '¥${widget.monthlyEarnings.toStringAsFixed(2)}', color: Colors.white),
            _buildSummaryItem('Gastos Variáveis', '¥${_variableExpenses.toStringAsFixed(2)}', color: Colors.red),
            _buildSummaryItem('Gastos totais', '¥${totalExpenses.toStringAsFixed(2)}', color: Colors.red),
            _buildSummaryItem(
              'Saldo disponível', 
              '¥${balance.toStringAsFixed(2)}',
              color: balance >= 0 ? Colors.green : Colors.red
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
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Insira um valor' : null,
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
          keyboardType: TextInputType.number,
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