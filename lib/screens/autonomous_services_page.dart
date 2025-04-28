import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutonomousServicesPage extends StatefulWidget {
  const AutonomousServicesPage({super.key});

  @override
  _AutonomousServicesPageState createState() => _AutonomousServicesPageState();
}

class _AutonomousServicesPageState extends State<AutonomousServicesPage> {
  final List<Map<String, dynamic>> _services = [];
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  String _filterStatus = 'Todos';
  String _filterCategory = 'Todas';
  String _sortField = 'Data';
  bool _sortAscending = true;

  // Variáveis para os totalizadores
  double _totalCombinado = 0;
  double _totalRecebido = 0;
  double _totalPendente = 0;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final prefs = await SharedPreferences.getInstance();
    final savedServices = prefs.getStringList('services') ?? [];
    
    setState(() {
      _services.clear();
      _totalCombinado = 0;
      _totalRecebido = 0;
      _totalPendente = 0;

      for (final serviceStr in savedServices) {
        final service = Map<String, dynamic>.from(json.decode(serviceStr));
        _services.add(service);
        
        final valor = double.tryParse(service['valor_combinado'].toString()) ?? 0;
        final recebido = double.tryParse(service['valor_recebido'].toString()) ?? 0;
        
        _totalCombinado += valor;
        _totalRecebido += recebido;
        _totalPendente += valor - recebido;
      }
    });
  }

  Future<void> _saveServices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'services',
      _services.map((s) => json.encode(s)).toList()
    );
  }

  void _addOrEditService({Map<String, dynamic>? service, int? index}) {
    final _descController = TextEditingController(text: service?['descricao']);
    final _clientController = TextEditingController(text: service?['cliente']);
    final _valorCombinadoController = TextEditingController(
      text: service?['valor_combinado']?.toStringAsFixed(2));
    final _valorRecebidoController = TextEditingController(
      text: service?['valor_recebido']?.toStringAsFixed(2));
    final _obsController = TextEditingController(text: service?['observacoes']);
    
    DateTime? _selectedDate = service?['data'] != null 
      ? DateTime.parse(service!['data'])
      : null;
    
    String _status = service?['status'] ?? 'Pendente';
    String _formaPagamento = service?['forma_pagamento'] ?? 'Dinheiro';
    String _categoria = service?['categoria'] ?? 'Geral';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? 'Novo Serviço' : 'Editar Serviço'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Data com DatePicker
                ListTile(
                  title: Text(_selectedDate == null 
                    ? 'Selecione a data' 
                    : _dateFormat.format(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Descrição*'),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                TextFormField(
                  controller: _clientController,
                  decoration: const InputDecoration(labelText: 'Cliente*'),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                // Valor Combinado
                TextFormField(
                  controller: _valorCombinadoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor Combinado*'),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  onChanged: (v) {
                    if (v.isNotEmpty) {
                      _valorCombinadoController.text = 
                        _formatCurrency(v.replaceAll(RegExp(r'[^0-9]'), ''));
                    }
                  },
                ),
                // Valor Recebido
                TextFormField(
                  controller: _valorRecebidoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor Recebido'),
                  onChanged: (v) {
                    if (v.isNotEmpty) {
                      _valorRecebidoController.text = 
                        _formatCurrency(v.replaceAll(RegExp(r'[^0-9]'), ''));
                    }
                  },
                ),
                // Dropdowns
                DropdownButtonFormField<String>(
                  value: _status,
                  items: ['Pago', 'Pendente', 'Parcial']
                    .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s),
                    )).toList(),
                  onChanged: (v) => _status = v!,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                DropdownButtonFormField<String>(
                  value: _formaPagamento,
                  items: ['Dinheiro', 'PIX', 'Cartão', 'Transferência']
                    .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s),
                    )).toList(),
                  onChanged: (v) => _formaPagamento = v!,
                  decoration: const InputDecoration(labelText: 'Forma de Pagamento'),
                ),
                DropdownButtonFormField<String>(
                  value: _categoria,
                  items: ['Geral', 'Tatuagem', 'Design', 'Consultoria']
                    .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s),
                    )).toList(),
                  onChanged: (v) => _categoria = v!,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                ),
                TextFormField(
                  controller: _obsController,
                  decoration: const InputDecoration(labelText: 'Observações'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate() && _selectedDate != null) {
                final newService = {
                  'data': _selectedDate!.toIso8601String(),
                  'descricao': _descController.text,
                  'cliente': _clientController.text,
                  'valor_combinado': _parseCurrency(_valorCombinadoController.text),
                  'valor_recebido': _parseCurrency(_valorRecebidoController.text),
                  'status': _status,
                  'forma_pagamento': _formaPagamento,
                  'categoria': _categoria,
                  'observacoes': _obsController.text,
                };

                setState(() {
                  if (index != null) {
                    _services[index] = newService;
                  } else {
                    _services.add(newService);
                  }
                  _saveServices();
                  _loadServices(); // Atualiza os totalizadores
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  double _parseCurrency(String value) {
    return double.tryParse(
      value.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim()
    ) ?? 0.0;
  }

  String _formatCurrency(String value) {
    if (value.isEmpty) return '';
    final number = int.parse(value);
    return _currencyFormat.format(number / 100);
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'Pago' => Colors.green,
      'Pendente' => Colors.red,
      'Parcial' => Colors.orange,
      _ => Colors.grey,
    };
  }

  List<Map<String, dynamic>> _getFilteredServices() {
    var filtered = _services.where((s) {
      final matchesSearch = _searchController.text.isEmpty ||
          s['descricao'].toLowerCase().contains(_searchController.text.toLowerCase()) ||
          s['cliente'].toLowerCase().contains(_searchController.text.toLowerCase());
      
      final matchesStatus = _filterStatus == 'Todos' || s['status'] == _filterStatus;
      final matchesCategory = _filterCategory == 'Todas' || s['categoria'] == _filterCategory;
      
      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();

    filtered.sort((a, b) {
      final aValue = a[_sortField.toLowerCase()];
      final bValue = b[_sortField.toLowerCase()];
      return _sortAscending 
          ? aValue.compareTo(bValue) 
          : bValue.compareTo(aValue);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = _getFilteredServices();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Área de Serviços'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: _ServiceSearchDelegate(_services),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Filtro de Status
                Expanded(
                  child: DropdownButton<String>(
                    value: _filterStatus,
                    items: ['Todos', 'Pago', 'Pendente', 'Parcial']
                      .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      )).toList(),
                    onChanged: (v) => setState(() => _filterStatus = v!),
                  ),
                ),
                // Filtro de Categoria
                Expanded(
                  child: DropdownButton<String>(
                    value: _filterCategory,
                    items: ['Todas', 'Geral', 'Tatuagem', 'Design', 'Consultoria']
                      .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      )).toList(),
                    onChanged: (v) => setState(() => _filterCategory = v!),
                  ),
                ),
              ],
            ),
          ),
          // Tabela
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Data')),
                  const DataColumn(label: Text('Descrição')),
                  const DataColumn(label: Text('Cliente')),
                  DataColumn(
                    label: const Text('Valor Combinado'),
                    onSort: (i, ascending) => setState(() {
                      _sortField = 'valor_combinado';
                      _sortAscending = ascending;
                    }),
                  ),
                  DataColumn(
                    label: const Text('Status'),
                    onSort: (i, ascending) => setState(() {
                      _sortField = 'status';
                      _sortAscending = ascending;
                    }),
                  ),
                  const DataColumn(label: Text('Ações')),
                ],
                rows: filteredServices.map((service) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_dateFormat.format(
                        DateTime.parse(service['data'])))),
                      DataCell(Text(service['descricao'])),
                      DataCell(Text(service['cliente'])),
                      DataCell(Text(_currencyFormat
                        .format(service['valor_combinado']))),
                      DataCell(
                        Chip(
                          label: Text(service['status']),
                          backgroundColor: _getStatusColor(service['status']),
                        ),
                      ),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _addOrEditService(
                              service: service,
                              index: _services.indexOf(service)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirmar exclusão'),
                                  content: const Text('Deseja excluir este serviço?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _services.remove(service);
                                          _saveServices();
                                          _loadServices();
                                        });
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          // Totalizadores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Total Combinado', 
                      style: TextStyle(color: Colors.white70)),
                    Text(_currencyFormat.format(_totalCombinado),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Total Recebido', 
                      style: TextStyle(color: Colors.white70)),
                    Text(_currencyFormat.format(_totalRecebido),
                      style: const TextStyle(
                        color: Colors.green, 
                        fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Total Pendente', 
                      style: TextStyle(color: Colors.white70)),
                    Text(_currencyFormat.format(_totalPendente),
                      style: const TextStyle(
                        color: Colors.red, 
                        fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditService(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ServiceSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> services;

  _ServiceSearchDelegate(this.services);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = services.where((s) =>
      s['descricao'].toLowerCase().contains(query.toLowerCase()) ||
      s['cliente'].toLowerCase().contains(query.toLowerCase())
    ).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final service = results[index];
        return ListTile(
          title: Text(service['descricao']),
          subtitle: Text(service['cliente']),
          trailing: Text(NumberFormat.currency(symbol: 'R\$')
            .format(service['valor_combinado'])),
          onTap: () => close(context, service),
        );
      },
    );
  }
}