import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'documents_page.dart';
import 'finance_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Widget _buildHeader(String text, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.grey[600]!,
            width: 1.0,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, String timeField, int index) async {
    TimeOfDay initialTime = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        _tableData[index][timeField] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  int _currentIndex = 0;
  String _name = '';
  String _hourlyRate = '';
  final DateFormat _dateFormat = DateFormat('d/M');
  List<Map<String, String>> _tableData = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _tableData = _generateDaysOfMonth();
  }

  List<Map<String, String>> _generateDaysOfMonth() {
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return List.generate(daysInMonth, (i) {
      DateTime day = DateTime(now.year, now.month, i + 1);
      return {
        "data": _dateFormat.format(day),
        "entrada": "",
        "saida": "",
        "descanso": "",
        "horas": "",
        "valor": "",
      };
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? '';
      _hourlyRate = prefs.getString('hourlyRate') ?? '';
    });
  }

  // [Métodos _selectTime, _calculateHours, _calculateDailyValue permanecem iguais]

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ponto Salário')),
      body: _buildMainContent(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildUserInfo(),
        Expanded(child: _buildTimeTable()),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nome: $_name', style: TextStyle(fontSize: 16)),
          SizedBox(height: 8),
          Text('Valor por hora: $_hourlyRate', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTimeTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columns: _buildTableColumns(),
          rows: _tableData.map(_buildTableRow).toList(),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    return [
      DataColumn(label: _buildHeader('Data', 70)),
      DataColumn(label: _buildHeader('Entrada', 80)),
      DataColumn(label: _buildHeader('Saída', 80)),
      DataColumn(label: _buildHeader('Pausa', 80)),
      DataColumn(label: _buildHeader('Horas', 80)),
      DataColumn(label: _buildHeader('Valor', 100)),
    ];
  }

  DataRow _buildTableRow(Map<String, String> data) {
    return DataRow(cells: [
      _buildDataCell(data["data"]!, false),
      _buildTimeCell("entrada", data),
      _buildTimeCell("saida", data),
      _buildTimeCell("descanso", data),
      _buildDataCell(data["horas"]!.isEmpty ? "--:--" : data["horas"]!, false),
      _buildDataCell(data["valor"]!.isEmpty ? "¥0" : data["valor"]!, true),
    ]);
  }

  DataCell _buildTimeCell(String field, Map<String, String> data) {
    return DataCell(
      GestureDetector(
        onTap: () => _selectTime(context, field, _tableData.indexOf(data)),
        child: Container(
          width: 80,
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            data[field]!.isEmpty ? "--:--" : data[field]!,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  DataCell _buildDataCell(String text, bool isValue) {
    return DataCell(
      Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: isValue ? TextStyle(color: Colors.amber, fontWeight: FontWeight.bold) : null,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
        BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Documentos'),
        BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Finanças'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Configurações'),
      ],
    );
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsPage()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => FinancePage()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
        break;
    }
  }
}