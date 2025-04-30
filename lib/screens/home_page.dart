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

final Color gridColor = Colors.grey[700]!;
final TextStyle cellTextStyle = TextStyle(
  fontSize: 10,
  color: Colors.white,
);

class _CompactHeader extends StatelessWidget {
  final String text;
  final double width;

  const _CompactHeader(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

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
      "isAbsent": item["isAbsent"],
    }).toList();

    await prefs.setString(
      'tableData_${_currentDisplayedMonth.month}_${_currentDisplayedMonth.year}',
      json.encode(tableDataToSave)
    );

    await prefs.setStringList(
      'usedLeaveDates', 
      _usedLeaveDates.map((date) => date.toIso8601String()).toList()
    );

    await prefs.setStringList(
      'absentDates',
      _absentDates.map((date) => date.toIso8601String()).toList()
    );
  }

  Future<void> _showMonthResetDialog() async {
    final monthName = DateFormat('MMMM y', 'pt_BR').format(_currentDisplayedMonth);
    
    final confirmReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resetar mês'),
        content: Text('Você deseja resetar o mês de $monthName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sim'),
          ),
        ],
      ),
    );

    if (confirmReset == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final TextEditingController resetController = TextEditingController();
          
          return AlertDialog(
            title: Text('Confirmar reset'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Digite "Resetar" para confirmar:'),
                SizedBox(height: 10),
                TextField(
                  controller: resetController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: resetController.text.trim() == 'Resetar' 
                    ? () => Navigator.pop(context, true)
                    : null,
                child: Text('Confirmar'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        setState(() {
          _tableData = _generateDaysOfMonth(_currentDisplayedMonth);
          _usedLeaveDates.removeWhere((date) => 
              date.year == _currentDisplayedMonth.year && 
              date.month == _currentDisplayedMonth.month);
          _absentDates.removeWhere((date) => 
              date.year == _currentDisplayedMonth.year && 
              date.month == _currentDisplayedMonth.month);
        });
        await _saveAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mês resetado com sucesso!'))
        );
      }
    }
  }

  Future<void> _showCongratsDialog(double monthlyEarnings) async {
    if (_showCongrats) return;
    
    final allDaysFilled = _tableData.every((day) => 
        day["isPaidLeave"] || day["isAbsent"] || 
        (day["entrada"].isNotEmpty && day["saida"].isNotEmpty));
    
    if (allDaysFilled && monthlyEarnings > 0) {
      setState(() {
        _showCongrats = true;
      });
      
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('🎉 Parabéns!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _userName.isNotEmpty 
                    ? '$_userName, você recebeu ¥${monthlyEarnings.toStringAsFixed(0)}!'
                    : 'Você recebeu ¥${monthlyEarnings.toStringAsFixed(0)}!',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
              Icon(Icons.attach_money, size: 50, color: Colors.amber),
              SizedBox(height: 10),
              Text(
                'Continue assim! 💪',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _selectTime(BuildContext context, String timeField, int index) async {
    if (_tableData[index]["isPaidLeave"] || _tableData[index]["isAbsent"]) {
      return;
    }

    TimeOfDay initial = _tableData[index][timeField]!.isEmpty
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: int.parse(_tableData[index][timeField]!.split(":")[0]),
            minute: int.parse(_tableData[index][timeField]!.split(":")[1]),
          );

    TimeOfDay selectedTime = initial;

    final hourController = FixedExtentScrollController(initialItem: initial.hour);
    final minuteController = FixedExtentScrollController(initialItem: initial.minute);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar Horário', textAlign: TextAlign.center),
        content: SizedBox(
          height: 200,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ListWheelScrollView(
                        controller: hourController,
                        itemExtent: 50,
                        physics: const FixedExtentScrollPhysics(),
                        children: List.generate(24, (hour) {
                          return Center(
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 20,
                                color: hour == selectedTime.hour 
                                    ? Colors.blue 
                                    : Colors.grey[600],
                              ),
                            ),
                          );
                        }),
                        onSelectedItemChanged: (hourIndex) {
                          setState(() {
                            selectedTime = selectedTime.replacing(hour: hourIndex);
                          });
                        },
                      ),
                    ),
                    const Text(':', style: TextStyle(fontSize: 24)),
                    Expanded(
                      child: ListWheelScrollView(
                        controller: minuteController,
                        itemExtent: 50,
                        physics: const FixedExtentScrollPhysics(),
                        children: List.generate(60, (minute) {
                          return Center(
                            child: Text(
                              '${minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 20,
                                color: minute == selectedTime.minute 
                                    ? Colors.blue 
                                    : Colors.grey[600],
                              ),
                            ),
                          );
                        }),
                        onSelectedItemChanged: (minuteIndex) {
                          setState(() {
                            selectedTime = selectedTime.replacing(minute: minuteIndex);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      setState(() {
        _tableData[index][timeField] = 
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
        
        if (_autoFillRestTime && _restMinutes > 0 && (timeField == 'entrada' || timeField == 'saida')) {
          final hours = _restMinutes ~/ 60;
          final minutes = _restMinutes % 60;
          _tableData[index]['descanso'] = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
        }

        _tableData[index]["horas"] = _calculateHours(index);
        _tableData[index]["valor"] = _calculateDailyValue(index);
        _saveAllData();
      });
    }
  }

  Future<void> _selectTimeAlternative(BuildContext context, String timeField, int index) async {
    if (_tableData[index]["isPaidLeave"] || _tableData[index]["isAbsent"]) {
      return;
    }

    TimeOfDay initialTime = _tableData[index][timeField]!.isEmpty
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: int.parse(_tableData[index][timeField]!.split(":")[0]),
            minute: int.parse(_tableData[index][timeField]!.split(":")[1]),
          );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: true,
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _tableData[index][timeField] = 
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        
        if (_autoFillRestTime && _restMinutes > 0 && (timeField == 'entrada' || timeField == 'saida')) {
          final hours = _restMinutes ~/ 60;
          final minutes = _restMinutes % 60;
          _tableData[index]['descanso'] = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
        }

        _tableData[index]["horas"] = _calculateHours(index);
        _tableData[index]["valor"] = _calculateDailyValue(index);
        _saveAllData();
      });
    }
  }

  String _calculateHours(int index) {
    if (_tableData[index]["isPaidLeave"]) {
      if (_shifts.isNotEmpty) {
        try {
          final startParts = _shifts[0]['start']!.split(':');
          final endParts = _shifts[0]['end']!.split(':');
          final restParts = _restMinutes > 0 
              ? '${(_restMinutes ~/ 60).toString().padLeft(2, '0')}:${(_restMinutes % 60).toString().padLeft(2, '0')}'
              : '00:00';
          final restPartsSplit = restParts.split(':');

          final startHour = int.parse(startParts[0]);
          final startMinute = int.parse(startParts[1]);
          final endHour = int.parse(endParts[0]);
          final endMinute = int.parse(endParts[1]);
          final restHour = int.parse(restPartsSplit[0]);
          final restMinute = int.parse(restPartsSplit[1]);

          int totalMinutes;
          
          if (endHour < startHour || (endHour == startHour && endMinute < startMinute)) {
            totalMinutes = ((24 * 60) - (startHour * 60 + startMinute)) + 
                (endHour * 60 + endMinute) - 
                (restHour * 60 + restMinute);
          } else {
            totalMinutes = (endHour * 60 + endMinute) - 
                (startHour * 60 + startMinute) - 
                (restHour * 60 + restMinute);
          }

          if (totalMinutes <= 0) return "0:00";
          
          int hours = totalMinutes ~/ 60;
          int minutes = totalMinutes % 60;
          
          return '$hours:${minutes.toString().padLeft(2, '0')}';
        } catch (e) {
          return "8:00";
        }
      }
      return "8:00";
    }
    if (_tableData[index]["isAbsent"]) {
      return "0:00";
    }
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
    if (_tableData[index]["isAbsent"]) {
      return "¥0";
    }
    if (_tableData[index]["isPaidLeave"]) {
      if (_hourlyRate.isEmpty) return "¥0";
      final baseRate = double.parse(_hourlyRate);
      final hours = _calculateHours(index);
      try {
        final hoursParts = hours.split(':');
        final workedHours = int.parse(hoursParts[0]) + (int.parse(hoursParts[1]) / 60);
        return '¥${(workedHours * baseRate).toStringAsFixed(0)}';
      } catch (e) {
        return '¥${(8 * baseRate).toStringAsFixed(0)}';
      }
    }
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

  void _showDateOptionsDialog(DateTime date, bool isPaidLeave, bool isAbsent) async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = prefs.getInt('paidLeaveDays') ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opções de Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPaidLeave && !isAbsent) ...[
              if (_shifts.isNotEmpty) ...[
                ElevatedButton(
                  onPressed: () {
                    if (remaining > 0) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Selecionar Turno'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _shifts.map((shift) {
                              return ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                  _applyPaidLeaveWithShift(date, shift);
                                  prefs.setInt('paidLeaveDays', remaining - 1);
                                },
                                child: Text('${shift['start']} - ${shift['end']}'),
                              );
                            }).toList(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Você não tem folgas remuneradas disponíveis')));
                    }
                  },
                  child: const Text('Usar Folga Remunerada'),
                ),
                SizedBox(height: 10),
              ],
              ElevatedButton(
                onPressed: () {
                  _toggleDateStatus(date, false, true);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Marcar Falta'),
              ),
            ] else if (isPaidLeave) ...[
              Text('Dias restantes: ${remaining + 1}'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _toggleDateStatus(date, false, false);
                  prefs.setInt('paidLeaveDays', remaining + 1);
                  Navigator.pop(context);
                },
                child: const Text('Remover Folga Remunerada'),
              ),
            ] else if (isAbsent) ...[
              ElevatedButton(
                onPressed: () {
                  _toggleDateStatus(date, false, false);
                  Navigator.pop(context);
                },
                child: const Text('Remover Falta'),
              ),
            ],
            SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyPaidLeaveWithShift(DateTime date, Map<String, String> shift) {
    setState(() {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      _usedLeaveDates.add(normalizedDate);
      _absentDates.remove(normalizedDate);
      _remainingPaidLeave--;

      final index = _tableData.indexWhere((day) => 
          day["date"].year == date.year &&
          day["date"].month == date.month &&
          day["date"].day == date.day);

      if (index != -1) {
        _tableData[index]["entrada"] = shift['start'] ?? '';
        _tableData[index]["saida"] = shift['end'] ?? '';
        
        if (_autoFillRestTime && _restMinutes > 0) {
          final hours = _restMinutes ~/ 60;
          final minutes = _restMinutes % 60;
          _tableData[index]['descanso'] = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
        }
        
        _tableData[index]["horas"] = _calculateHours(index);
        _tableData[index]["valor"] = _calculateDailyValue(index);
        _tableData[index]["isPaidLeave"] = true;
        _tableData[index]["isAbsent"] = false;
      }
    });
    _saveAllData();
  }

  void _toggleDateStatus(DateTime date, bool isPaidLeave, bool isAbsent) {
    setState(() {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      
      if (isPaidLeave) {
        _usedLeaveDates.add(normalizedDate);
        _absentDates.remove(normalizedDate);
        _remainingPaidLeave--;
        
        final index = _tableData.indexWhere((day) => 
            day["date"].year == date.year &&
            day["date"].month == date.month &&
            day["date"].day == date.day);
            
        if (index != -1) {
          if (_shifts.isNotEmpty) {
            _tableData[index]["entrada"] = _shifts[0]['start'] ?? '';
            _tableData[index]["saida"] = _shifts[0]['end'] ?? '';
            
            if (_autoFillRestTime && _restMinutes > 0) {
              final hours = _restMinutes ~/ 60;
              final minutes = _restMinutes % 60;
              _tableData[index]['descanso'] = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
            }
          }
          
          _tableData[index]["horas"] = _calculateHours(index);
          _tableData[index]["valor"] = _calculateDailyValue(index);
        }
      } else if (isAbsent) {
        _absentDates.add(normalizedDate);
        _usedLeaveDates.remove(normalizedDate);
      } else {
        if (_usedLeaveDates.contains(normalizedDate)) {
          _usedLeaveDates.remove(normalizedDate);
          _remainingPaidLeave++;
        }
        if (_absentDates.contains(normalizedDate)) {
          _absentDates.remove(normalizedDate);
        }
        
        final index = _tableData.indexWhere((day) => 
            day["date"].year == date.year &&
            day["date"].month == date.month &&
            day["date"].day == date.day);
            
        if (index != -1) {
          _tableData[index]["entrada"] = '';
          _tableData[index]["saida"] = '';
          _tableData[index]["descanso"] = '';
          _tableData[index]["horas"] = '';
          _tableData[index]["valor"] = '';
        }
      }
      
      _tableData = _tableData.map((day) {
        final dayDate = day["date"] as DateTime;
        if (dayDate.year == normalizedDate.year &&
            dayDate.month == normalizedDate.month &&
            dayDate.day == normalizedDate.day) {
          return {
            ...day,
            "isPaidLeave": isPaidLeave,
            "isAbsent": isAbsent,
          };
        }
        return day;
      }).toList();
    });
    _saveAllData();
  }

  Widget _buildHeader(String text, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: gridColor)),
        color: Colors.grey[900],
      ),
      child: Center(
        child: Text(
          text,
          style: cellTextStyle.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  DataCell _buildTimeCell(BuildContext context, String field, Map<String, dynamic> data) {
    return DataCell(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Selecionar método'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _selectTimeAlternative(context, field, _tableData.indexOf(data));
                    },
                    child: const Text('Seletor padrão (melhor para PC)'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _selectTime(context, field, _tableData.indexOf(data));
                    },
                    child: const Text('Seletor de rolagem (para touch)'),
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              data[field]!.isEmpty ? "--:--" : data[field]!,
              style: TextStyle(
                fontSize: 14,
                color: data["isAbsent"] ? Colors.red : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
    
  DataRow _buildDataRow(BuildContext context, Map<String, dynamic> data) {
    final date = data["date"] as DateTime;
    final isPaidLeave = data["isPaidLeave"] as bool;
    final isAbsent = data["isAbsent"] as bool;
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    return DataRow(
      cells: [
        DataCell(
          GestureDetector(
            onTap: () => _showDateOptionsDialog(date, isPaidLeave, isAbsent),
            child: Container(
              width: 50,
              child: Center(
                child: Text(
                  data["data"],
                  style: TextStyle(
                    fontSize: 12,
                    color: isWeekend
                        ? Colors.red
                        : isPaidLeave
                            ? Colors.blue
                            : isAbsent
                                ? Colors.red
                                : Colors.white,
                  ),
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
            width: 50,
            child: Center(
              child: Text(
                data["horas"]!.isEmpty ? "--:--" : data["horas"]!,
                style: TextStyle(
                  fontSize: 12,
                  color: isPaidLeave
                      ? Colors.blue
                      : isAbsent
                          ? Colors.red
                          : Colors.white,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            width: 60,
            child: Center(
              child: Text(
                data["valor"]!.isEmpty ? "¥0" : data["valor"]!,
                style: TextStyle(
                  fontSize: 12,
                  color: isPaidLeave
                      ? Colors.blue
                      : isAbsent
                          ? Colors.red
                          : Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
      color: MaterialStateProperty.resolveWith<Color>((states) {
        if (isPaidLeave) return Colors.blue.withOpacity(0.2);
        if (isAbsent) return Colors.red.withOpacity(0.2);
        return Colors.transparent;
      }),
    );
  }

  DataCell _buildCompactCell(String text, Map<String, dynamic> data) {
    return DataCell(
      GestureDetector(
        onTap: () {
          final date = data["date"] as DateTime;
          final isPaidLeave = data["isPaidLeave"] as bool;
          final isAbsent = data["isAbsent"] as bool;
          _showDateOptionsDialog(date, isPaidLeave, isAbsent);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey[800]!)),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: data["isPaidLeave"]
                    ? Colors.blue[300]
                    : data["isAbsent"]
                        ? Colors.red[300]
                        : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataCell _buildStyledCell(String text, double cellWidth, Map<String, dynamic> data) {
    return DataCell(
      Container(
        width: cellWidth,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[800]!)),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: data["isPaidLeave"]
                  ? Colors.blue
                  : data["isAbsent"]
                      ? Colors.red
                      : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double monthlyEarnings = _tableData.fold<double>(0.0, (sum, day) {
      final valueStr = (day["valor"] as String).replaceAll('¥', '');
      return sum + (double.tryParse(valueStr) ?? 0);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCongratsDialog(monthlyEarnings);
    });

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 24, color: Colors.white),
              onPressed: () {
                setState(() {
                  _currentDisplayedMonth = DateTime(
                    _currentDisplayedMonth.year,
                    _currentDisplayedMonth.month - 1,
                  );
                  _loadSavedData();
                });
              },
            ),
            GestureDetector(
              onTap: _showMonthResetDialog,
              child: Text(
                DateFormat('MMMM y', 'pt_BR').format(_currentDisplayedMonth),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 24, color: Colors.white),
              onPressed: () {
                setState(() {
                  _currentDisplayedMonth = DateTime(
                    _currentDisplayedMonth.year,
                    _currentDisplayedMonth.month + 1,
                  );
                  _loadSavedData();
                });
              },
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: DataTable(
                    columnSpacing: 0,
                    horizontalMargin: 0,
                    headingRowHeight: 40,
                    dataRowHeight: 40,
                    dividerThickness: 0.5,
                    headingTextStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white
                    ),
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey[800]!),
                      verticalInside: BorderSide(color: Colors.grey[800]!),
                      top: BorderSide(color: Colors.grey[800]!),
                      bottom: BorderSide(color: Colors.grey[800]!),
                    ),
                    columns: const [
                      DataColumn(label: _CompactHeader('Dia', 70)),
                      DataColumn(label: _CompactHeader('In', 90)),
                      DataColumn(label: _CompactHeader('Out', 90)),
                      DataColumn(label: _CompactHeader('Desc.', 90)),
                      DataColumn(label: _CompactHeader('Hrs', 70)),
                      DataColumn(label: _CompactHeader('', 40)),
                    ],
                    rows: _tableData.map<DataRow>((data) {
                      return DataRow(
                        color: MaterialStateProperty.all(Colors.black),
                        cells: [
                          _buildCompactCell(data["data"], data),
                          _buildTimeCell(context, "entrada", data),
                          _buildTimeCell(context, "saida", data),
                          _buildTimeCell(context, "descanso", data),
                          _buildCompactCell(
                            data["horas"]!.isEmpty ? "--:--" : data["horas"], 
                            data
                          ),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.info_outline, 
                                color: Colors.grey[400],
                                size: 20,
                              ),
                              onPressed: () => _showValueDialog(data["valor"]),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.grey[900],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsPage()));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FinancePage(monthlyEarnings: monthlyEarnings)));
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage(monthlyEarnings: monthlyEarnings, installmentPurchases: [])));
          } else if (index == 4) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage())).then((_) => _loadSavedData());
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Documentos'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Finanças'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Relatórios'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Configurações'),
        ],
      ),
    );
  }

  void _showValueDialog(String value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valor do Dia'),
        content: Text(value.isEmpty ? "¥0" : value),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}