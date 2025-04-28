import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AutonomousService {
  DateTime data;
  String descricao;
  String? cliente;
  double valorCombinado;
  double valorRecebido;
  String formaPagamento;
  String statusPagamento;
  String categoria;
  String? observacoes;

  AutonomousService({
    required this.data,
    required this.descricao,
    this.cliente,
    required this.valorCombinado,
    required this.valorRecebido,
    required this.formaPagamento,
    required this.statusPagamento,
    required this.categoria,
    this.observacoes,
  });
}

class AutonomousServicesPage extends StatefulWidget {
  @override
  _AutonomousServicesPageState createState() => _AutonomousServicesPageState();
}

class _AutonomousServicesPageState extends State<AutonomousServicesPage> {
  final List<AutonomousService> _services = [];
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _clienteController = TextEditingController();
  final _valorCombinadoController = TextEditingController();
  final _valorRecebidoController = TextEditingController();
  final _observacoesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedFormaPagamento = 'Dinheiro';
  String _selectedStatus = 'Pendente';
  String _selectedCategoria = 'Outros';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Serviços Autônomos')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildDataTable(),
            _buildAddServiceForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Data')),
        DataColumn(label: Text('Descrição')),
        DataColumn(label: Text('Cliente')),
        DataColumn(label: Text('Valor R\$')),
        DataColumn(label: Text('Status')),
      ],
      rows: _services.map((service) {
        return DataRow(cells: [
          DataCell(Text(DateFormat('dd/MM/yyyy').format(service.data))),
          DataCell(Text(service.descricao)),
          DataCell(Text(service.cliente ?? '')),
          DataCell(Text(service.valorCombinado.toStringAsFixed(2))),
          DataCell(
            Chip(
              label: Text(service.statusPagamento),
              backgroundColor: _getStatusColor(service.statusPagamento),
            ),
          ),
        ]);
      }).toList(),
    );
  }

  Widget _buildAddServiceForm() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDatePicker(),
            TextFormField(
              controller: _descricaoController,
              decoration: InputDecoration(labelText: 'Descrição do serviço*'),
              validator: (value) => value!.isEmpty ? 'Obrigatório' : null,
            ),
            TextFormField(
              controller: _clienteController,
              decoration: InputDecoration(labelText: 'Cliente'),
            ),
            TextFormField(
              controller: _valorCombinadoController,
              decoration: InputDecoration(labelText: 'Valor combinado*'),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Obrigatório' : null,
            ),
            TextFormField(
              controller: _valorRecebidoController,
              decoration: InputDecoration(labelText: 'Valor recebido*'),
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Obrigatório' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedFormaPagamento,
              decoration: InputDecoration(labelText: 'Forma de pagamento'),
              items: ['Dinheiro', 'Pix', 'Cartão', 'Transferência']
                  .map((forma) => DropdownMenuItem(
                        value: forma,
                        child: Text(forma),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFormaPagamento = value!;
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(labelText: 'Status do pagamento'),
              items: ['Pendente', 'Pago', 'Parcialmente Pago']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedCategoria,
              decoration: InputDecoration(labelText: 'Categoria'),
              items: ['Outros', 'Tatuagem', 'Design', 'Consultoria']
                  .map((categoria) => DropdownMenuItem(
                        value: categoria,
                        child: Text(categoria),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoria = value!;
                });
              },
            ),
            TextFormField(
              controller: _observacoesController,
              decoration: InputDecoration(labelText: 'Observações'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addService,
              child: Text('Adicionar Serviço'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Row(
      children: [
        Text(
          'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
          style: TextStyle(fontSize: 16),
        ),
        IconButton(
          icon: Icon(Icons.calendar_today),
          onPressed: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null && picked != _selectedDate) {
              setState(() {
                _selectedDate = picked;
              });
            }
          },
        ),
      ],
    );
  }

  void _addService() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _services.add(AutonomousService(
          data: _selectedDate,
          descricao: _descricaoController.text,
          cliente: _clienteController.text,
          valorCombinado: double.parse(_valorCombinadoController.text),
          valorRecebido: double.parse(_valorRecebidoController.text),
          formaPagamento: _selectedFormaPagamento,
          statusPagamento: _selectedStatus,
          categoria: _selectedCategoria,
          observacoes: _observacoesController.text,
        ));

        // Limpar campos depois de adicionar
        _descricaoController.clear();
        _clienteController.clear();
        _valorCombinadoController.clear();
        _valorRecebidoController.clear();
        _observacoesController.clear();
        _selectedFormaPagamento = 'Dinheiro';
        _selectedStatus = 'Pendente';
        _selectedCategoria = 'Outros';
        _selectedDate = DateTime.now();
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pago':
        return Colors.green;
      case 'Parcialmente Pago':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}
