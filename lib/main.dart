import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ponto Salário App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        colorScheme: ColorScheme.dark().copyWith(
          secondary: Colors.tealAccent,
          surface: Colors.grey[800],
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          bodyText2: TextStyle(color: Colors.white70),
        ),
      ),
      home: HomePage(),
    );
  }
}