import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salarioapp/pages/home_page.dart';
import 'models/document.dart';
import 'models/expense.dart';
import 'providers/document_provider.dart';
import 'providers/expense_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => DocumentProvider()),
        ChangeNotifierProvider(create: (ctx) => ExpenseProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salario App',
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        '/add-document': (ctx) => AddDocumentPage(),
        '/settings': (ctx) => SettingsPage(),
      },
      home: HomePage(),
    );
  }
}