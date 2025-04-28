import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Document {
  final String title;
  final DateTime expirationDate;
  final DateTime creationDate;

  Document({
    required this.title,
    required this.expirationDate,
    required this.creationDate,
  });

  factory Document.fromJson(String json) {
    final data = json.split('|');
    return Document(
      title: data[0],
      expirationDate: DateTime.parse(data[1]),
      creationDate: DateTime.parse(data[2]),
    );
  }

  String toJson() {
    return '$title|${expirationDate.toIso8601String()}|${creationDate.toIso8601String()}';
  }

  int get daysRemaining => expirationDate.difference(DateTime.now()).inDays;
  bool get isExpired => daysRemaining < 0;
  Color get statusColor {
    if (isExpired) return Colors.red;
    if (daysRemaining <= 90) return Colors.red;
    if (daysRemaining <= 180) return Colors.orange;
    return Colors.green;
  }
}

class DocumentsPage extends StatefulWidget {
  @override
  _DocumentsPageState createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<Document> _documents = [];
  final TextEditingController _titleController = TextEditingController();
  DateTime _expirationDate = DateTime.now().add(Duration(days: 365));

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? docsData = prefs.getStringList('documents');
    
    if (docsData != null) {
      setState(() {
        _documents = docsData.map((e) => Document.fromJson(e)).toList();
        _sortDocuments();
      });
    }
  }

  void _sortDocuments() {
    _documents.sort((a, b) {
      if (a.isExpired != b.isExpired) return a.isExpired ? 1 : -1;
      return a.daysRemaining.compareTo(b.daysRemaining);
    });
  }

  Future<void> _saveDocuments() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> docsData = _documents.map((e) => e.toJson()).toList();
    await prefs.setStringList('documents', docsData);
  }

  Future<void> _selectExpirationDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    
    if (pickedDate != null) {
      setState(() => _expirationDate = pickedDate);
    }
  }

  void _addDocument() {
    if (_titleController.text.isEmpty) return;

    final newDoc = Document(
      title: _titleController.text,
      expirationDate: _expirationDate,
      creationDate: DateTime.now(),
    );

    setState(() {
      _documents.add(newDoc);
      _sortDocuments();
      _saveDocuments();
    });

    Navigator.pop(context);
    _titleController.clear();
    _expirationDate = DateTime.now().add(Duration(days: 365));
  }

  void _deleteDocument(int index) {
    setState(() {
      _documents.removeAt(index);
      _saveDocuments();
    });
  }

  void _showAddDocumentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Novo Documento', style: TextStyle(color: Colors.tealAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Nome do Documento',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Data de Validade: ${DateFormat('dd/MM/yyyy').format(_expirationDate)}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () => _selectExpirationDate(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _addDocument,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Document doc, int index) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Card(
        color: doc.statusColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: doc.statusColor.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[300]),
                    onPressed: () => _deleteDocument(index),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[400]),
                  SizedBox(width: 8),
                  Text(
                    'Validade: ${DateFormat('dd/MM/yyyy').format(doc.expirationDate)}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.grey[400]),
                  SizedBox(width: 8),
                  Text(
                    doc.isExpired 
                        ? 'Documento Expirado'
                        : 'Dias restantes: ${doc.daysRemaining}',
                    style: TextStyle(
                      color: doc.isExpired ? Colors.red[300] : Colors.grey[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: doc.isExpired ? 1.0 : 1 - (doc.daysRemaining / 365),
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(doc.statusColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gerenciar Documentos'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddDocumentDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: Icon(Icons.add),
        onPressed: _showAddDocumentDialog,
      ),
      body: _documents.isEmpty
          ? Center(
              child: Text(
                'Nenhum documento registrado\nToque no + para adicionar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: _documents.length,
              itemBuilder: (context, index) => _buildDocumentCard(_documents[index], index),
            ),
    );
  }
}