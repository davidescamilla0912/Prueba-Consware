// Pruebas del lado cliente: modelo y validación del formulario.
// No tocan la red: la política de negocio vive en el backend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/models/reimbursement.dart';
import 'package:mobile/screens/create_reimbursement_screen.dart';

void main() {
  group('Reimbursement.fromJson', () {
    final reimbursement = Reimbursement.fromJson(const {
      'id': 7,
      'employeeName': 'Empleado Demo',
      'amount': 650000,
      'category': 'Alimentación',
      'description': 'Almuerzo con un cliente',
      'status': 'Rejected',
      'rejectionReason': 'No cumple la política de gastos.',
      'createdAtUtc': '2026-10-29T14:30:00Z',
      'decidedAtUtc': '2026-10-29T15:00:00Z',
    });

    test('lee todos los campos del JSON de la API', () {
      expect(reimbursement.id, 7);
      expect(reimbursement.amount, 650000);
      expect(reimbursement.status, 'Rejected');
      expect(reimbursement.rejectionReason, 'No cumple la política de gastos.');
      expect(reimbursement.isRejected, isTrue);
      expect(reimbursement.isPending, isFalse);
    });

    test('formatea el monto en pesos con separador de miles', () {
      expect(reimbursement.formattedAmount, r'$650.000 COP');
      expect(
        Reimbursement.fromJson(const {'amount': 500000, 'status': 'Approved'})
            .formattedAmount,
        r'$500.000 COP',
      );
    });

    test('traduce el estado a español', () {
      expect(reimbursement.statusLabel, 'Rechazada');
      expect(
        Reimbursement.fromJson(const {'status': 'Pending'}).statusLabel,
        'Pendiente',
      );
      expect(
        Reimbursement.fromJson(const {'status': 'Approved'}).statusLabel,
        'Aprobada',
      );
    });
  });

  group('Formulario de nueva solicitud', () {
    testWidgets('no envía el formulario con campos vacíos',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CreateReimbursementScreen(),
      ));

      await tester.tap(find.text('Guardar solicitud'));
      await tester.pump();

      expect(find.text('Ingresa un monto numérico.'), findsOneWidget);
      expect(find.text('La descripción es obligatoria.'), findsOneWidget);
    });

    testWidgets('rechaza montos no positivos', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CreateReimbursementScreen(),
      ));

      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.text('Guardar solicitud'));
      await tester.pump();

      expect(find.text('El monto debe ser mayor a cero.'), findsOneWidget);
    });
  });
}
