import 'package:flutter/material.dart';
import 'package:ponto_salario/screens/home_page.dart';
import 'package:ponto_salario/screens/settings_page.dart';
import 'package:ponto_salario/screens/documents_page.dart';
import 'package:ponto_salario/screens/finance_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ponto Salário App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}