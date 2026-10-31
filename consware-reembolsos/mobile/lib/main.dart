import 'package:flutter/material.dart';

import 'screens/my_reimbursements_screen.dart';

void main() => runApp(const ReimbursementsApp());

/// App del empleado: dos pantallas (crear y consultar) sobre una misma API.
class ReimbursementsApp extends StatelessWidget {
  const ReimbursementsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Reembolsos Consware',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const MyReimbursementsScreen(),
      );
}
