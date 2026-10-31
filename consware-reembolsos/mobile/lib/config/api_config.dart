import 'dart:io' show Platform;

/// Configuración de conexión con la API.
///
/// * Android Emulator -> `10.0.2.2` (dirección del equipo host).
/// * Windows / Linux / macOS -> `localhost`.
/// * Celular físico -> sustituir el host por la IP de LAN del equipo y revisar
///   el firewall de Windows (ver guía §8.3 y §10.1).
class ApiConfig {
  ApiConfig._();

  static const int port = 5000;
  static const String androidEmulatorHost = '10.0.2.2';
  static const String localHost = 'localhost';

  /// Identificación simplificada admitida por Consware; no hay login (guía §8.1).
  static const String employeeName = 'Empleado Demo';

  static String get baseUrl {
    final host = Platform.isAndroid ? androidEmulatorHost : localHost;
    return 'http://$host:$port/api/reimbursements';
  }
}
