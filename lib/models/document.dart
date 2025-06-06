import 'package:flutter/material.dart';

class Document {
  final String title;
  final DateTime expirationDate;
  final DateTime creationDate;

  Document({
    required this.title,
    required this.expirationDate,
    required this.creationDate,
  });

  factory Document.fromJson(String json) {
    final data = json.split('|');
    return Document(
      title: data[0],
      expirationDate: DateTime.parse(data[1]),
      creationDate: DateTime.parse(data[2]),
    );
  }

  String toJson() {
    return '$title|${expirationDate.toIso8601String()}|${creationDate.toIso8601String()}';
  }

  int get daysRemaining => expirationDate.difference(DateTime.now()).inDays;
  bool get isExpired => daysRemaining < 0;
  Color get statusColor {
    if (isExpired) return Colors.red;
    if (daysRemaining <= 90) return Colors.red;
    if (daysRemaining <= 180) return Colors.orange;
    return Colors.green;
  }
}