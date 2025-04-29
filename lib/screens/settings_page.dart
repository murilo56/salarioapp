import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';


class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();
  final TextEditingController _restTimeController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _autoCloseEndOfMonth = false;
  bool _autoFillRestTime = false;
  int _paidLeaveDays = 0;
  List<Map<String, String>> _shifts = [];
  int _selectedShiftIndex = -1;
  bool _expenseClosingFollowsTimesheet = true;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('name') ?? '';
      _hourlyRateController.text = prefs.getString('hourlyRate') ?? '';
      _restTimeController.text = prefs.getInt('restMinutes')?.toString() ?? '0';
      _startDate = DateTime.parse(prefs.getString('startDate') ?? DateTime.now().toString());
      
      _autoCloseEndOfMonth = prefs.getBool('autoCloseEndOfMonth') ?? false;
      if (_autoCloseEndOfMonth) {
        final now = DateTime.now();
        _endDate = DateTime(now.year, now.month + 1, 0);
      } else {
        _endDate = DateTime.parse(prefs.getString('endDate') ?? DateTime.now().toString());
      }
      
      _autoFillRestTime = prefs.getBool('autoFillRestTime') ?? false;
      _paidLeaveDays = prefs.getInt('paidLeaveDays') ?? 0;
      
      final shiftsString = prefs.getString('shifts') ?? '[]';
      _shifts = (json.decode(shiftsString) as List)
          .map((item) => Map<String, String>.from(item))
          .toList();

      _expenseClosingFollowsTimesheet = prefs.getBool('expenseClosingFollowsTimesheet') ?? true;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    if (!isStartDate && _autoCloseEndOfMonth) {
      return;
    }

    DateTime initialDate = isStartDate ? _startDate : _endDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != initialDate) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      await _saveSettings(showSnackbar: false);
    }
  }

  Future<void> _selectTime(BuildContext context, String field, int shiftIndex) async {
    TimeOfDay initialTime = TimeOfDay.now();
    if (_shifts[shiftIndex][field]?.isNotEmpty ?? false) {
      final parts = _shifts[shiftIndex][field]!.split(':');
      initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        _shifts[shiftIndex][field] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
      await _saveSettings(showSnackbar: false);
    }
  }

  Future<void> _saveSettings({bool showSnackbar = true}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameController.text);
    await prefs.setString('hourlyRate', _hourlyRateController.text);
    await prefs.setInt('restMinutes', int.tryParse(_restTimeController.text) ?? 0);
    await prefs.setString('startDate', _startDate.toString());
    
    if (_autoCloseEndOfMonth) {
      final now = DateTime.now();
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
      await prefs.setString('endDate', lastDayOfMonth.toString());
      setState(() {
        _endDate = lastDayOfMonth;
      });
    } else {
      await prefs.setString('endDate', _endDate.toString());
    }
    
    await prefs.setBool('autoCloseEndOfMonth', _autoCloseEndOfMonth);
    await prefs.setBool('autoFillRestTime', _autoFillRestTime);
    await prefs.setInt('paidLeaveDays', _paidLeaveDays);
    await prefs.setString('shifts', json.encode(_shifts));
    await prefs.setBool('expenseClosingFollowsTimesheet', _expenseClosingFollowsTimesheet);

    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configurações salvas com sucesso!'))
      );
      Navigator.pop(context);
    }
  }

  void _addShift() {
    setState(() {
      _shifts.add({
        'start': '',
        'end': '',
      });
    });
  }

  void _removeShift(int index) {
    setState(() {
      _shifts.removeAt(index);
    });
    _saveSettings(showSnackbar: false);
  }

  void _handleRestTimeChange(String value) {
    setState(() {
      _restTimeController.text = value;
    });
    if (_autoFillRestTime) {
      _saveSettings(showSnackbar: false);
    }
  }

  Future<void> _changeExpenseClosingSetting(bool newValue) async {
    if (!newValue && _expenseClosingFollowsTimesheet) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Alterar configuração de fechamento'),
          content: Text('Ao mudar para fechamento mensal tradicional, as despesas serão calculadas do dia 1 ao último dia do mês. Deseja continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Confirmar'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _expenseClosingFollowsTimesheet = newValue;
    });
    await _saveSettings(showSnackbar: false);
  }

  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final TextEditingController localResetController = TextEditingController();
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Resetar todos os dados',
                  style: TextStyle(color: Colors.red)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Esta ação é irreversível! Todos os dados serão perdidos.',
                      style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: localResetController,
                    decoration: const InputDecoration(
                      labelText: 'Digite "Apagar" para confirmar',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: localResetController.text.trim().toLowerCase() == 'apagar'
                            ? () => Navigator.pop(context, true)
                            : null,
                        child: const Text('Confirmar'),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      setState(() {
        _nameController.clear();
        _hourlyRateController.clear();
        _restTimeController.text = '0';
        _startDate = DateTime.now();
        _endDate = DateTime.now();
        _autoCloseEndOfMonth = false;
        _autoFillRestTime = false;
        _paidLeaveDays = 0;
        _shifts = [];
        _expenseClosingFollowsTimesheet = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todos os dados foram resetados!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildShiftCard(int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Turno ${index + 1}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeShift(index),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, 'start', index),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          _shifts[index]['start']?.isNotEmpty ?? false
                              ? _shifts[index]['start']!
                              : 'Selecionar entrada',
                          style: TextStyle(
                            color: _shifts[index]['start']?.isNotEmpty ?? false
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context, 'end', index),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          _shifts[index]['end']?.isNotEmpty ?? false
                              ? _shifts[index]['end']!
                              : 'Selecionar saída',
                          style: TextStyle(
                            color: _shifts[index]['end']?.isNotEmpty ?? false
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurações'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () => _saveSettings(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _saveSettings(showSnackbar: false),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _hourlyRateController,
              decoration: InputDecoration(
                labelText: 'Valor por hora (em ienes)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              onChanged: (value) => _saveSettings(showSnackbar: false),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _restTimeController,
              decoration: InputDecoration(
                labelText: 'Tempo de descanso (minutos)',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Informação'),
                        content: const Text('Este valor será usado para preencher automaticamente o tempo de descanso quando a opção estiver ativada.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _handleRestTimeChange,
            ),
            SwitchListTile(
              title: const Text('Preencher pausa automaticamente'),
              value: _autoFillRestTime,
              onChanged: (value) {
                setState(() {
                  _autoFillRestTime = value;
                });
                _saveSettings(showSnackbar: false);
              },
            ),
            SizedBox(height: 16),
            InkWell(
              onTap: () {
                setState(() {
                  _isDropdownOpen = !_isDropdownOpen;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dias de folga remunerada: $_paidLeaveDays dias'),
                    Icon(_isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            if (_isDropdownOpen) ...[
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: 51,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text('$index dias'),
                      onTap: () {
                        setState(() {
                          _paidLeaveDays = index;
                          _isDropdownOpen = false;
                        });
                        _saveSettings(showSnackbar: false);
                      },
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 16),
            ListTile(
              title: Text('Dia de início do cartão: ${DateFormat('dd/MM/yyyy').format(_startDate)}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, true),
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Dia de fechamento do cartão: ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, false),
              enabled: !_autoCloseEndOfMonth,
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Fechar automaticamente no final do mês'),
              value: _autoCloseEndOfMonth,
              onChanged: (bool value) {
                setState(() {
                  _autoCloseEndOfMonth = value;
                  if (value) {
                    final now = DateTime.now();
                    _endDate = DateTime(now.year, now.month + 1, 0);
                  }
                });
                _saveSettings(showSnackbar: false);
              },
            ),
            SizedBox(height: 24),
            Divider(color: Colors.grey[700]),
            SizedBox(height: 16),
            Text(
              'Fechamento de Despesas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Escolha como deseja calcular suas despesas no mês',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            RadioListTile<bool>(
              title: Text('Seguir fechamento do cartão de ponto'),
              subtitle: Text('As despesas serão calculadas no mesmo período do cartão'),
              value: true,
              groupValue: _expenseClosingFollowsTimesheet,
              onChanged: (bool? value) {
                if (value != null) {
                  _changeExpenseClosingSetting(value);
                }
              },
            ),
            RadioListTile<bool>(
              title: Text('Usar fechamento mensal tradicional (1º ao 30/31)'),
              subtitle: Text('As despesas serão calculadas do primeiro ao último dia do mês'),
              value: false,
              groupValue: _expenseClosingFollowsTimesheet,
              onChanged: (bool? value) {
                if (value != null) {
                  _changeExpenseClosingSetting(value);
                }
              },
            ),
            SizedBox(height: 24),
            Divider(color: Colors.grey[700]),
            SizedBox(height: 16),
            Text(
              'Configuração de Turnos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Configure os horários de trabalho para cálculo automático nas folgas remuneradas',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            ..._shifts.asMap().entries.map((entry) => _buildShiftCard(entry.key)),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Adicionar Turno'),
              onPressed: _addShift,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _saveSettings(),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Salvar Todas as Configurações'),
            ),
            SizedBox(height: 40),
            Divider(color: Colors.grey[700]),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.warning, color: Colors.red),
                label: const Text('Zerar todos os dados',
                    style: TextStyle(color: Colors.red)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _resetAllData,
              ),
            ),
          ],
        ),
      ),
    );
  }
}