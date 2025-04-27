import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/expenses_list.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Finanças')),
      body: ExpensesList(expenses: expenseProvider.expenses),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // Adicione a navegação para AddExpensePage
        child: const Icon(Icons.add),
      ),
    );
  }
}