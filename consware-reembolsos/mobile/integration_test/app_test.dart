// Prueba end-to-end (guía §10 / matriz T18):
// Flutter (emulador) -> API ASP.NET Core -> SQL Server -> respuesta a la UI.
//
// Ejecutar con la API en marcha:
//   flutter test integration_test -d emulator-5554

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:mobile/config/api_config.dart';
import 'package:mobile/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear, autoprobar, rechazar con motivo y verlo en la app',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ReimbursementsApp());
    await tester.pump(const Duration(seconds: 2));

    // ---------------------------------------------------------------
    // 1) Monto <= 500.000 COP: la API lo aprueba automáticamente (T01/T02)
    // ---------------------------------------------------------------
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '150000');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Taxi a reunión de trabajo (integración)',
    );
    await tester.tap(find.text('Guardar solicitud'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aprobada'), findsWidgets,
        reason: 'Debe confirmarse el guardado con estado Aprobada');

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    // Título exacto de la tarjeta (el SnackBar también menciona el monto).
    expect(find.text(r'$150.000 COP · Transporte'), findsOneWidget,
        reason: 'La lista debe reflejar el registro creado (T18)');

    // ---------------------------------------------------------------
    // 2) Monto > 500.000 COP: queda Pendiente (T03)
    // ---------------------------------------------------------------
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '640000');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Hotel para viaje a Bogotá (integración)',
    );
    await tester.tap(find.text('Guardar solicitud'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    final pendingCard = find.ancestor(
      of: find.text(r'$640.000 COP · Transporte'),
      matching: find.byType(Card),
    );
    expect(pendingCard, findsOneWidget);
    expect(
      find.descendant(of: pendingCard, matching: find.text('Pendiente')),
      findsOneWidget,
    );

    // ---------------------------------------------------------------
    // 3) El aprobador lo rechaza desde otro cliente (Angular/API)
    // ---------------------------------------------------------------
    final id = await _findRequestId(
        'Hotel para viaje a Bogotá (integración)');
    expect(id, isNotNull, reason: 'La solicitud creada debe existir en la API');

    final reject = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/$id/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reason': 'No cumple la política de gastos.'}),
    );
    expect(reject.statusCode, 200,
        reason: 'PATCH reject debe devolver 200');

    // ---------------------------------------------------------------
    // 4) La app muestra Rechazada y el motivo (guía §8.5)
    // ---------------------------------------------------------------
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    final rejectedCard = find.ancestor(
      of: find.text(r'$640.000 COP · Transporte'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: rejectedCard, matching: find.text('Rechazada')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: rejectedCard,
          matching: find.textContaining('Motivo: No cumple la política')),
      findsOneWidget,
      reason: 'Debe verse el rejectionReason bajo la solicitud',
    );
  });
}

/// Localiza en la API la solicitud recién creada por la prueba.
Future<int?> _findRequestId(String description) async {
  final uri = Uri.parse(ApiConfig.baseUrl).replace(queryParameters: {
    'employeeName': ApiConfig.employeeName,
  });
  final response = await http.get(uri).timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) return null;

  final list = jsonDecode(response.body) as List<dynamic>;
  for (final item in list) {
    if (item is Map<String, dynamic> && item['description'] == description) {
      return (item['id'] as num).toInt();
    }
  }
  return null;
}
