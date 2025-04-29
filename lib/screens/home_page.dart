import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'documents_page.dart';
import 'finance_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  DateTime _currentDisplayedMonth = DateTime.now();
  String _hourlyRate = '';
  final DateFormat _dateFormat = DateFormat('d/M');
  List<Map<String, dynamic>> _tableData = [];
  int _remainingPaidLeave = 0;
  Set<DateTime> _usedLeaveDates = {};
  Set<DateTime> _absentDates = {};
  bool _autoFillRestTime = false;
  int _restMinutes = 0;
  List<Map<String, String>> _shifts = [];
  String _userName = '';
  bool _showCongrats = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _loadSavedData();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('name') ?? '';
    });
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('pt_BR', null);
    _generateTableData();
  }

  void _generateTableData() {
    setState(() {
      _tableData = _generateDaysOfMonth(_currentDisplayedMonth);
    });
  }

  List<Map<String, dynamic>> _generateDaysOfMonth(DateTime month) {
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return List.generate(daysInMonth, (index) {
      DateTime day = DateTime(month.year, month.month, index + 1);
      return {
        "date": day,
        "data": _dateFormat.format(day),
        "entrada": "",
        "saida": "",
        "descanso": "",
        "horas": "",
        "valor": "",
        "isPaidLeave": _usedLeaveDates.contains(day),
        "isAbsent": _absentDates.contains(day),
      };
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hourlyRate = prefs.getString('hourlyRate') ?? '';
      _remainingPaidLeave = prefs.getInt('paidLeaveDays') ?? 0;
      _autoFillRestTime = prefs.getBool('autoFillRestTime') ?? false;
      _restMinutes = prefs.getInt('restMinutes') ?? 0;

      final savedLeaveDates = prefs.getStringList('usedLeaveDates') ?? [];
      _usedLeaveDates = savedLeaveDates.map((dateStr) {
        try {
          return DateTime.parse(dateStr);
        } catch (e) {
          return DateTime.now();
        }
      }).where((date) => date != null).cast<DateTime>().toSet();

      final savedAbsentDates = prefs.getStringList('absentDates') ?? [];
      _absentDates = savedAbsentDates.map((dateStr) {
        try {
          return DateTime.parse(dateStr);
        } catch (e) {
          return DateTime.now();
        }
      }).where((date) => date != null).cast<DateTime>().toSet();

      final savedShifts = prefs.getString('shifts') ?? '[]';
      _shifts = (json.decode(savedShifts) as List)
          .map((item) => Map<String, String>.from(item))
          .toList();

      final savedTable = prefs.getString('tableData_${_currentDisplayedMonth.month}_${_currentDisplayedMonth.year}');
      if (savedTable != null) {
        final List<dynamic> decodedData = json.decode(savedTable);
        _tableData = decodedData.map<Map<String, dynamic>>((item) {
          final dateStr = item['date'] as String?;
          DateTime date;
          try {
            date = DateTime.parse(dateStr ?? '');
          } catch (e) {
            date = DateTime.now();
          }
          return {
            "date": date,
            "data": item['data'] as String? ?? '',
            "entrada": item['entrada'] as String? ?? '',
            "saida": item['saida'] as String? ?? '',
            "descanso": item['descanso'] as String? ?? '',
            "horas": item['horas'] as String? ?? '',
            "valor": item['valor'] as String? ?? '',
            "isPaidLeave": item['isPaidLeave'] as bool? ?? false,
            "isAbsent": item['isAbsent'] as bool? ?? false,
          };
        }).toList();
      }
    });
  }

  Future<void> _saveTableData() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedData = json.encode(_tableData.map((item) {
      return {
        'date': item['date'].toString(),
        'data': item['data'],
        'entrada': item['entrada'],
        'saida': item['saida'],
        'descanso': item['descanso'],
        'horas': item['horas'],
        'valor': item['valor'],
        'isPaidLeave': item['isPaidLeave'],
        'isAbsent': item['isAbsent'],
      };
    }).toList());
    await prefs.setString('tableData_${_currentDisplayedMonth.month}_${_currentDisplayedMonth.year}', encodedData);
  }

  void _navigateToPage(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsPage()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (context) => FinancePage()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (context) => DocumentsPage()));
        break;
      case 4:
        Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()));
        break;
    }
  }

  Color _getRowColor(Map<String, dynamic> dayData) {
    if (dayData['isPaidLeave'] == true) {
      return Colors.blue!;
    } else if (dayData['isAbsent'] == true) {
      return Colors.red!;
    } else if (dayData['entrada'].toString().isEmpty || dayData['saida'].toString().isEmpty) {
      return Colors.grey!;
    }
    return Colors.white;
  }

  Widget _buildHeaderCell(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  TableRow _buildTableRow(Map<String, dynamic> dayData) {
    Color rowColor = _getRowColor(dayData);
    
    return TableRow(
      decoration: BoxDecoration(color: rowColor),
      children: [
        _buildDataCell(dayData['data'].toString()),
        _buildDataCell(dayData['entrada'].toString()),
        _buildDataCell(dayData['saida'].toString()),
        _buildDataCell(dayData['descanso'].toString()),
        _buildDataCell(dayData['horas'].toString()),
        _buildDataCell(dayData['valor'].toString()),
      ],
    );
  }

  Widget _buildOptimizedTable() {
    return Expanded(
      child: Column(
        children: [
          Table(
            border: TableBorder.all(color: Colors.grey, width: 0.5),
            columnWidths: const {
              0: FixedColumnWidth(40),
              1: FixedColumnWidth(70),
              2: FixedColumnWidth(70),
              3: FixedColumnWidth(60),
              4: FixedColumnWidth(60),
              5: FixedColumnWidth(70),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey),
                children: [
                  _buildHeaderCell('Dia'),
                  _buildHeaderCell('Entr.'),
                  _buildHeaderCell('Saída'),
                  _buildHeaderCell('Desc.'),
                  _buildHeaderCell('Horas'),
                  _buildHeaderCell('Valor'),
                ],
              ),
            ],
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Colors.grey, width: 0.5),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(70),
                  2: FixedColumnWidth(70),
                  3: FixedColumnWidth(60),
                  4: FixedColumnWidth(60),
                  5: FixedColumnWidth(70),
                },
                children: _tableData.map((dayData) => _buildTableRow(dayData)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Controle de Ponto - ${DateFormat('MMMM yyyy', 'pt_BR').format(_currentDisplayedMonth)}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _currentDisplayedMonth = DateTime(_currentDisplayedMonth.year, _currentDisplayedMonth.month - 1);
                      _generateTableData();
                    });
                  },
                ),
                Text(
                  'Férias restantes: $_remainingPaidLeave dias',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: () {
                    setState(() {
                      _currentDisplayedMonth = DateTime(_currentDisplayedMonth.year, _currentDisplayedMonth.month + 1);
                      _generateTableData();
                    });
                  },
                ),
              ],
            ),
          ),
          
          _buildOptimizedTable(),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _saveTableData();
                      _showCongrats = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dados salvos com sucesso!')),
                    );
                  },
                  child: Text('Salvar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _tableData = _generateDaysOfMonth(_currentDisplayedMonth);
                    });
                  },
                  child: Text('Limpar'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Relatórios'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Financeiro'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Documentos'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Configurações'),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _navigateToPage(index);
        },
      ),
    );
  }
}