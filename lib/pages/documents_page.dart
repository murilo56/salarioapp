import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';

class DocumentsPage extends StatefulWidget {
  @override
  _DocumentsPageState createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<Document> _documents = [];
  final _titleController = TextEditingController();
  DateTime _expirationDate = DateTime.now().add(Duration(days: 365));

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final docsData = prefs.getStringList('documents') ?? [];
    setState(() {
      _documents = docsData.map((json) {
        final parts = json.split('|');
        return Document(
          title: parts[0],
          expirationDate: DateTime.parse(parts[1]),
          creationDate: DateTime.parse(parts[2]),
        );
      }).toList();
      _sortDocuments();
    });
  }

  void _sortDocuments() {
    _documents.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
  }

  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('documents',
      _documents.map((doc) => '${doc.title}|${doc.expirationDate.toIso8601String()}|${doc.creationDate.toIso8601String()}').toList());
  }

  Future<void> _selectExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
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
  }

  void _showAddDialog() {
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
              title: Text('Validade: ${DateFormat('dd/MM/yyyy').format(_expirationDate)}'),
              trailing: Icon(Icons.calendar_today, color: Colors.teal),
              onTap: _selectExpirationDate,
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
    return Card(
      color: doc.statusColor.withOpacity(0.1),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: doc.statusColor.withOpacity(0.3)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(doc.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70)),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: () {
                    setState(() {
                      _documents.removeAt(index);
                      _saveDocuments();
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 
              'Validade: ${doc.formattedExpirationDate()}'),
            SizedBox(height: 8),
            _buildInfoRow(Icons.timer,
              doc.isExpired ? 'Documento Expirado' 
                : 'Dias restantes: ${doc.daysRemaining}',
              isExpired: doc.isExpired),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: doc.isExpired ? 1.0 : 1 - (doc.daysRemaining / 365),
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(doc.statusColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isExpired = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        SizedBox(width: 12),
        Text(text,
          style: TextStyle(
            color: isExpired ? Colors.red[300] : Colors.grey[400],
            fontSize: 14,
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Documentos'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _documents.isEmpty
          ? Center(
              child: Text('Nenhum documento registrado\nToque no + para adicionar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 16),
              itemCount: _documents.length,
              itemBuilder: (context, index) => _buildDocumentCard(_documents[index], index),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: _showAddDialog,
      ),
    );
  }
}