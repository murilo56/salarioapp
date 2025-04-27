import 'package:flutter/material.dart';

class FinancePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Finanças')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFinanceTile('Ganho Mensal', 2500, Colors.green),
            SizedBox(height: 20),
            Text('Histórico de Pagamentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView(
                children: [
                  _buildPaymentItem('Março 2024', 2500),
                  _buildPaymentItem('Fevereiro 2024', 2400),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceTile(String label, double value, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16)),
          Text('¥${value.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(String period, double value) {
    return ListTile(
      title: Text('Pagamento - $period'),
      trailing: Text('¥${value.toStringAsFixed(0)}',
          style: TextStyle(color: Colors.green)),
    );
  }
}