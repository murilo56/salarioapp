import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _loadSavedData();
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
      };
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hourlyRate = prefs.getString('hourlyRate') ?? '';
      _remainingPaidLeave = prefs.getInt('paidLeaveDays') ?? 0;
      
      final savedLeaveDates = prefs.getStringList('usedLeaveDates') ?? [];
      _usedLeaveDates = savedLeaveDates.map((dateStr) {
        try {
          return DateTime.parse(dateStr);
        } catch (e) {
          return DateTime.now();
        }
      }).where((date) => date != null).cast<DateTime>().toSet();

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
          };
        }).toList();
      } else {
        _tableData = _generateDaysOfMonth(_currentDisplayedMonth);
      }
    });
  }

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hourlyRate', _hourlyRate);
    
    final tableDataToSave = _tableData.map((item) => {
      "date": (item["date"] as DateTime).toIso8601String(),
      "data": item["data"],
      "entrada": item["entrada"],
      "saida": item["saida"],
      "descanso": item["descanso"],
      "horas": item["horas"],
      "valor": item["valor"],
      "isPaidLeave": item["isPaidLeave"],
    }).toList();
    
    await prefs.setString(
      'tableData_${_currentDisplayedMonth.month}_${_currentDisplayedMonth.year}',
      json.encode(tableDataToSave)
    );
    
    await prefs.setStringList(
      'usedLeaveDates', 
      _usedLeaveDates.map((date) => date.toIso8601String()).toList()
    );
  }

  Future<void> _selectTime(BuildContext context, String timeField, int index) async {
    TimeOfDay initialTime = _tableData[index][timeField]!.isEmpty
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: int.parse(_tableData[index][timeField]!.split(":")[0]),
            minute: int.parse(_tableData[index][timeField]!.split(":")[1]),
          );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        _tableData[index][timeField] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _tableData[index]["horas"] = _calculateHours(index);
        _tableData[index]["valor"] = _calculateDailyValue(index);
        _saveAllData();
      });
    }
  }

  String _calculateHours(int index) {
    if (_tableData[index]["entrada"]!.isEmpty || _tableData[index]["saida"]!.isEmpty) {
      return "";
    }

    try {
      final entradaParts = _tableData[index]["entrada"]!.split(':');
      final saidaParts = _tableData[index]["saida"]!.split(':');
      final descansoParts = _tableData[index]["descanso"]!.isEmpty 
          ? ['0', '0'] 
          : _tableData[index]["descanso"]!.split(':');

      final entradaHour = int.parse(entradaParts[0]);
      final entradaMinute = int.parse(entradaParts[1]);
      final saidaHour = int.parse(saidaParts[0]);
      final saidaMinute = int.parse(saidaParts[1]);
      final descansoHour = int.parse(descansoParts[0]);
      final descansoMinute = int.parse(descansoParts[1]);

      int totalMinutes;

      if (saidaHour < entradaHour || (saidaHour == entradaHour && saidaMinute < entradaMinute)) {
        totalMinutes = ((24 * 60) - (entradaHour * 60 + entradaMinute)) + 
            (saidaHour * 60 + saidaMinute) - 
            (descansoHour * 60 + descansoMinute);
      } else {
        totalMinutes = (saidaHour * 60 + saidaMinute) - 
            (entradaHour * 60 + entradaMinute) - 
            (descansoHour * 60 + descansoMinute);
      }

      if (totalMinutes <= 0) return "0:00";
      
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      
      return '$hours:${minutes.toString().padLeft(2, '0')}';
    } catch (e) {
      return "0:00";
    }
  }

  String _calculateDailyValue(int index) {
    if (_tableData[index]["horas"]!.isEmpty || _hourlyRate.isEmpty) {
      return "";
    }

    try {
      final hoursParts = _tableData[index]["horas"]!.split(':');
      final hours = int.parse(hoursParts[0]);
      final minutes = int.parse(hoursParts[1]);
      final totalHours = hours + (minutes / 60);
      final baseRate = double.parse(_hourlyRate);

      double nightHours = 0;
      double normalHours = totalHours;

      if (_tableData[index]["entrada"]!.isNotEmpty && _tableData[index]["saida"]!.isNotEmpty) {
        final entradaParts = _tableData[index]["entrada"]!.split(':');
        final saidaParts = _tableData[index]["saida"]!.split(':');
        
        final entradaHour = int.parse(entradaParts[0]);
        final saidaHour = int.parse(saidaParts[0]);

        if (saidaHour >= 22 || entradaHour < 5 || saidaHour < 5) {
          nightHours = totalHours;
          normalHours = 0;
        }
      }

      double value = (normalHours * baseRate) + (nightHours * baseRate * 1.25);
      return '¥${value.toStringAsFixed(0)}';
    } catch (e) {
      return "¥0";
    }
  }

  void _showPaidLeaveDialog(DateTime date, bool isAdding) async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = prefs.getInt('paidLeaveDays') ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAdding ? 'Usar folga remunerada?' : 'Remover folga remunerada?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dias restantes: ${isAdding ? remaining : remaining + 1}'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _togglePaidLeave(date, isAdding);
                    prefs.setInt('paidLeaveDays', remaining + (isAdding ? -1 : 1));
                    Navigator.pop(context);
                  },
                  child: Text(isAdding ? 'Confirmar' : 'Remover'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _togglePaidLeave(DateTime date, bool isAdding) {
    setState(() {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (isAdding) {
        _usedLeaveDates.add(normalizedDate);
        _remainingPaidLeave--;
      } else {
        _usedLeaveDates.remove(normalizedDate);
        _remainingPaidLeave++;
      }
      
      _tableData = _tableData.map((day) {
        final dayDate = day["date"] as DateTime;
        if (dayDate.year == normalizedDate.year &&
            dayDate.month == normalizedDate.month &&
            dayDate.day == normalizedDate.day) {
          return {...day, "isPaidLeave": isAdding};
        }
        return day;
      }).toList();
    });
    _saveAllData();
  }

  Widget _buildHeader(String text, double width) {
  return Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border(right: BorderSide(color: Colors.grey[600]!, width: 1)),
    ), // Faltava este parêntese
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.white),
    ),
  );
}

DataCell _buildTimeCell(BuildContext context, String field, Map<String, dynamic> data) {
  return DataCell(
    GestureDetector(
      onTap: () => _selectTime(context, field, _tableData.indexOf(data)),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[600]!, width: 1)),
        ), // Faltava este parêntese
        child: Text(
          data[field]!.isEmpty ? "--:--" : data[field]!,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
      ),
    ),
  );
}

  DataRow _buildDataRow(BuildContext context, Map<String, dynamic> data) {
    final date = data["date"] as DateTime;
    final isPaidLeave = data["isPaidLeave"] as bool;

    return DataRow(
      cells: [
        DataCell(
          GestureDetector(
            onTap: () {
              if (isPaidLeave) {
                _showPaidLeaveDialog(date, false);
              } else {
                _showPaidLeaveDialog(date, true);
              }
            },
            child: Container(
              width: 60,
              alignment: Alignment.center,
              child: Text(
                data["data"],
                style: TextStyle(
                  fontSize: 12,
                  color: isPaidLeave ? Colors.blue : Colors.white,
                ),
              ),
            ),
          ),
        ),
        _buildTimeCell(context, "entrada", data),
        _buildTimeCell(context, "saida", data),
        _buildTimeCell(context, "descanso", data),
        DataCell(
          Container(
            width: 70,
            alignment: Alignment.center,
            child: Text(
              data["horas"]!.isEmpty ? "--:--" : data["horas"]!,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ),
        DataCell(
          Container(
            width: 70,
            alignment: Alignment.center,
            child: Text(
              data["valor"]!.isEmpty ? "¥0" : data["valor"]!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
      color: MaterialStateProperty.resolveWith<Color>((states) {
        if (isPaidLeave) return Colors.blue.withOpacity(0.2);
        return Colors.transparent;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    double monthlyEarnings = _tableData.fold<double>(0.0, (sum, day) {
      final valueStr = (day["valor"] as String).replaceAll('¥', '');
      return sum + (double.tryParse(valueStr) ?? 0);
    });

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () {
                setState(() {
                  _currentDisplayedMonth = DateTime(
                    _currentDisplayedMonth.year,
                    _currentDisplayedMonth.month - 1);
                  _loadSavedData();
                });
              },
            ),
            Text(
              DateFormat('MMMM y', 'pt_BR').format(_currentDisplayedMonth),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () {
                setState(() {
                  _currentDisplayedMonth = DateTime(
                    _currentDisplayedMonth.year,
                    _currentDisplayedMonth.month + 1);
                  _loadSavedData();
                });
              },
            ),
          ],
        ),
      ),
      body: Container(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 0,
              horizontalMargin: 0,
              headingRowHeight: 40,
              dataRowHeight: 40,
              columns: [
                DataColumn(label: _buildHeader('Data', 60)),
                DataColumn(label: _buildHeader('Entrada', 70)),
                DataColumn(label: _buildHeader('Saída', 70)),
                DataColumn(label: _buildHeader('Pausa', 70)),
                DataColumn(label: _buildHeader('Horas', 70)),
                DataColumn(label: _buildHeader('Valor', 70)),
              ],
              rows: _tableData.map((data) => _buildDataRow(context, data)).toList(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: const TextStyle(color: Colors.blue),
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsPage()));
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FinancePage(monthlyEarnings: monthlyEarnings),
              ),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportsPage(monthlyEarnings: monthlyEarnings),
              ),
            );
          } else if (index == 4) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()))
              .then((_) => _loadSavedData());
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Documentos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Finanças',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Relatórios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configurações',
          ),
        ],
      ),
    );
  }
}