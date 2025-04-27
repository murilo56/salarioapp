import 'package:flutter/material.dart';
import '../models/expense.dart';

class ExpensesList extends StatelessWidget {
  final List<Expense> expenses;

  const ExpensesList({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (ctx, i) => ListTile(
        title: Text(expenses[i].name),
        subtitle: Text('R\$ ${expenses[i].value.toStringAsFixed(2)}'),
        trailing: Text(expenses[i].date.toString().substring(0, 10)),
      ),
    );
  }
}