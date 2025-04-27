import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/preferences_service.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _autoClose = false;
  final _prefsService = PreferencesService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final data = await _prefsService.loadUserData();
    setState(() {
      _nameController.text = data['name'];
      _hourlyRateController.text = data['hourlyRate'];
      _startDate = data['startDate'];
      _endDate = data['endDate'];
      _autoClose = data['autoClose'];
    });
  }

  Future<void> _saveSettings() async {
    await _prefsService.saveUserData(
      name: _nameController.text,
      hourlyRate: _hourlyRateController.text,
      startDate: _startDate,
      endDate: _endDate,
      autoClose: _autoClose,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configurações salvas!'))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configurações')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Nome'),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _hourlyRateController,
            decoration: InputDecoration(labelText: 'Valor por hora (¥)'),
            keyboardType: TextInputType.number,
          ),
          _buildDateTile('Início do cartão', _startDate, true),
          _buildDateTile('Fechamento do cartão', _endDate, false),
          SwitchListTile(
            title: Text('Fechar automaticamente'),
            value: _autoClose,
            onChanged: (value) => setState(() => _autoClose = value),
          ),
          ElevatedButton(
            onPressed: _saveSettings,
            child: Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile(String title, DateTime date, bool isStartDate) {
    return ListTile(
      title: Text('$title: ${DateFormat('dd/MM/yyyy').format(date)}'),
      trailing: Icon(Icons.calendar_today),
      onTap: () => _selectDate(isStartDate),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }
}