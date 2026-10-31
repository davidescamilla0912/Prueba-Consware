import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/reimbursement.dart';
import '../services/reimbursement_api_service.dart';
import '../widgets/status_badge.dart';
import 'create_reimbursement_screen.dart';

/// Listado de solicitudes del empleado con sus estados visibles (guía §8.5).
class MyReimbursementsScreen extends StatefulWidget {
  const MyReimbursementsScreen({super.key});

  @override
  State<MyReimbursementsScreen> createState() => _MyReimbursementsScreenState();
}

class _MyReimbursementsScreenState extends State<MyReimbursementsScreen> {
  final _service = ReimbursementApiService();
  late Future<List<Reimbursement>> _future = _load();

  Future<List<Reimbursement>> _load() =>
      _service.getMyReimbursements(ApiConfig.employeeName);

  void _reload() {
    // El Future se crea fuera de setState y el callback usa cuerpo de bloque:
    // un `() => asignación` devolvería el Future y dispararía el assertion.
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateReimbursementScreen()),
    );
    if (created == true) _reload();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reembolsos'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Nueva solicitud'),
      ),
      body: FutureBuilder<List<Reimbursement>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is ReimbursementApiException
                ? error.message
                : 'No se pudo cargar la información.';
            return _ErrorState(message: message, onRetry: _reload);
          }

          final items = snapshot.data ?? const <Reimbursement>[];
          if (items.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) => _RequestCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});

  final Reimbursement item;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.isRejected
        ? '${item.description}\nMotivo: ${item.rejectionReason ?? ''}'
        : item.description;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.formattedAmount} · ${item.category}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusBadge(item.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(
              'Creada: ${_formatDate(item.createdAtUtc)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Aún no tienes solicitudes.'),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}
