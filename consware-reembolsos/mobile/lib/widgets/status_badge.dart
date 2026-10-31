import 'package:flutter/material.dart';

/// Indicador visual del estado de una solicitud: Pendiente / Aprobada / Rechazada.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final String status;

  Color get _color => switch (status) {
        'Approved' => Colors.green.shade700,
        'Rejected' => Colors.red.shade700,
        _ => Colors.orange.shade800,
      };

  String get _label => switch (status) {
        'Approved' => 'Aprobada',
        'Rejected' => 'Rechazada',
        _ => 'Pendiente',
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
