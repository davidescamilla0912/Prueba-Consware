import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Emulador Android: 10.0.2.2. Si usas Chrome, cambia a http://localhost:5000/api/reimbursements
const baseUrl = 'http://localhost:5000/api/reimbursements';
const employee = 'Ana Perez';

class Reimbursement {
  final int id;
  final double amount;
  final String category, description, status;
  final String? rejectionReason;

  Reimbursement.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        amount = (j['amount'] as num).toDouble(),
        category = j['category'],
        description = j['description'],
        status = j['status'].toString(),
        rejectionReason = j['rejectionReason'];
}

class ApiService {
  static const _timeout = Duration(seconds: 8);

  static Future<List<Reimbursement>> list() async {
    final r = await http
        .get(Uri.parse('$baseUrl?employeeName=${Uri.encodeComponent(employee)}'))
        .timeout(_timeout);
    if (r.statusCode != 200) throw Exception('Error del servidor (${r.statusCode})');
    return (jsonDecode(r.body) as List).map((e) => Reimbursement.fromJson(e)).toList();
  }

  static Future<void> create(double amount, String category, String description) async {
    final r = await http
        .post(Uri.parse(baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'employeeName': employee,
              'amount': amount,
              'category': category,
              'description': description,
            }))
        .timeout(_timeout);
    if (r.statusCode != 201) {
      String msg = 'Error del servidor (${r.statusCode})';
      try {
        final body = jsonDecode(r.body);
        if (body is Map && body['error'] != null) msg = body['error'];
      } catch (_) {}
      throw Exception(msg);
    }
  }
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Reembolsos',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const MyReimbursementsScreen(),
      );
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Approved' => Colors.green,
      'Rejected' => Colors.red,
      _ => Colors.orange,
    };
    final text = switch (status) {
      'Approved' => 'Aprobado',
      'Rejected' => 'Rechazado',
      _ => 'Pendiente',
    };
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class MyReimbursementsScreen extends StatefulWidget {
  const MyReimbursementsScreen({super.key});
  @override
  State<MyReimbursementsScreen> createState() => _MyReimbursementsScreenState();
}

class _MyReimbursementsScreenState extends State<MyReimbursementsScreen> {
  late Future<List<Reimbursement>> _future = ApiService.list();

  void _reload() => setState(() => _future = ApiService.list());

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const CreateScreen()));
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reembolsos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Nueva solicitud'),
      ),
      body: FutureBuilder<List<Reimbursement>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off, size: 48),
                  const SizedBox(height: 12),
                  const Text('No se pudo conectar con el servidor.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Reintentar')),
                ]),
              ),
            );
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Aún no tienes solicitudes.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final x = items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text('\$${x.amount.toStringAsFixed(0)} · ${x.category}'),
                    subtitle: Text(x.status == 'Rejected'
                        ? '${x.description}\nMotivo: ${x.rejectionReason ?? ''}'
                        : x.description),
                    isThreeLine: x.status == 'Rejected',
                    trailing: StatusBadge(x.status),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String _category = 'Transporte';
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.create(
          double.parse(_amount.text.trim()), _category, _description.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monto (COP)'),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                return (n == null || n <= 0) ? 'Ingresa un monto mayor que 0' : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: ['Transporte', 'Alimentación', 'Hospedaje', 'Otros']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'La descripción es obligatoria' : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar solicitud'),
            ),
          ]),
        ),
      ),
    );
  }
}