import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _paidLeaveDays = 0;

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
      _endDate = DateTime.parse(prefs.getString('endDate') ?? DateTime.now().toString());
      _autoCloseEndOfMonth = prefs.getBool('autoCloseEndOfMonth') ?? false;
      _paidLeaveDays = prefs.getInt('paidLeaveDays') ?? 0;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
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
    }
  }

  Future<void> _saveSettings({bool showSnackbar = true}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameController.text);
    await prefs.setString('hourlyRate', _hourlyRateController.text);
    await prefs.setInt('restMinutes', int.tryParse(_restTimeController.text) ?? 0);
    await prefs.setString('startDate', _startDate.toString());
    await prefs.setString('endDate', _endDate.toString());
    await prefs.setBool('autoCloseEndOfMonth', _autoCloseEndOfMonth);
    await prefs.setInt('paidLeaveDays', _paidLeaveDays);

    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configurações salvas com sucesso!'))
      );
      Navigator.pop(context);
    }
  }

  Future<void> _saveLocalData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('restMinutes', int.tryParse(_restTimeController.text) ?? 0);
    await prefs.setInt('paidLeaveDays', _paidLeaveDays);
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
            ),
            SizedBox(height: 16),
            TextField(
              controller: _hourlyRateController,
              decoration: InputDecoration(
                labelText: 'Valor por hora (em ienes)',
                hintText: 'Ativo após reiniciar o app',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _restTimeController,
              decoration: InputDecoration(
                labelText: 'Tempo de descanso (minutos)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _saveLocalData(),
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Dias de folga remunerada'),
              trailing: DropdownButton<int>(
                value: _paidLeaveDays,
                items: List.generate(51, (index) => index)
                  .map((value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value dias'),
                  )).toList(),
                onChanged: (value) {
                  setState(() {
                    _paidLeaveDays = value!;
                  });
                  _saveLocalData();
                },
              ),
            ),
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
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Fechar automaticamente no final do mês'),
              value: _autoCloseEndOfMonth,
              onChanged: (bool value) {
                setState(() {
                  _autoCloseEndOfMonth = value;
                });
                _saveLocalData();
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _saveSettings(),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Salvar Todas as Configurações'),
            ),
          ],
        ),
      ),
    );
  }
}