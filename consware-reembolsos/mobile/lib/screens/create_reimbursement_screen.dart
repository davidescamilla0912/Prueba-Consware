import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/reimbursement_api_service.dart';

/// Alta de una solicitud: monto, categoría y descripción (guía §8.1).
class CreateReimbursementScreen extends StatefulWidget {
  const CreateReimbursementScreen({super.key});

  @override
  State<CreateReimbursementScreen> createState() =>
      _CreateReimbursementScreenState();
}

class _CreateReimbursementScreenState extends State<CreateReimbursementScreen> {
  static const List<String> _categories = [
    'Transporte',
    'Alimentación',
    'Hospedaje',
    'Material de oficina',
    'Otro',
  ];

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _service = ReimbursementApiService();

  String _category = _categories.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validación de formato en la UI; la política de negocio vive en el backend.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return; // evita el doble envío

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final created = await _service.createReimbursement(
        employeeName: ApiConfig.employeeName,
        amount: num.parse(_amountController.text.trim()),
        category: _category,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud guardada: ${created.formattedAmount} · '
              '${created.statusLabel}.'),
        ),
      );
      Navigator.pop(context, true);
    } on ReimbursementApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ocurrió un error inesperado. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto (COP)',
                  helperText: r'Hasta $500.000 se aprueba automáticamente.',
                  prefixText: r'$ ',
                ),
                enabled: !_saving,
                validator: (value) {
                  final amount = num.tryParse((value ?? '').trim());
                  if (amount == null) return 'Ingresa un monto numérico.';
                  if (amount <= 0) return 'El monto debe ser mayor a cero.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _category = value ?? _categories.first),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'La categoría es obligatoria.'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej. Almuerzo con un cliente',
                  counterText: '',
                ),
                enabled: !_saving,
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'La descripción es obligatoria.';
                  if (text.length > 500) {
                    return 'La descripción no puede superar 500 caracteres.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_saving ? 'Guardando…' : 'Guardar solicitud'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          ],
        ),
      );
}
