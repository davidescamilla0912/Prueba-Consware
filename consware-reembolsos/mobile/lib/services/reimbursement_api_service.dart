import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/reimbursement.dart';

/// Error de API con un mensaje listo para mostrar en pantalla.
class ReimbursementApiException implements Exception {
  ReimbursementApiException(this.message, {this.isConnectionError = false});

  final String message;
  final bool isConnectionError;

  @override
  String toString() => message;
}

/// Cliente HTTP de la API. No contiene reglas de negocio: solo transporte,
/// timeouts y traducción de errores del backend a mensajes humanos.
class ReimbursementApiService {
  ReimbursementApiService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 10);

  /// GET /api/reimbursements?employeeName=...
  Future<List<Reimbursement>> getMyReimbursements(String employeeName) async {
    final uri = Uri.parse(ApiConfig.baseUrl)
        .replace(queryParameters: {'employeeName': employeeName});

    final response = await _send(() => _client.get(uri));
    _ensureSuccess(response);

    final body = _decode(response);
    if (body is! List) {
      throw ReimbursementApiException(
          'El servidor devolvió una respuesta no válida.');
    }

    return body
        .whereType<Map<String, dynamic>>()
        .map(Reimbursement.fromJson)
        .toList();
  }

  /// POST /api/reimbursements
  Future<Reimbursement> createReimbursement({
    required String employeeName,
    required num amount,
    required String category,
    required String description,
  }) async {
    final response = await _send(() => _client.post(
          Uri.parse(ApiConfig.baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'employeeName': employeeName,
            'amount': amount,
            'category': category,
            'description': description,
          }),
        ));

    _ensureSuccess(response);

    final body = _decode(response);
    if (body is! Map<String, dynamic>) {
      throw ReimbursementApiException(
          'El servidor devolvió una respuesta no válida.');
    }
    return Reimbursement.fromJson(body);
  }

  void dispose() => _client.close();

  // ---------------------------------------------------------------------
  // Manejo de errores de red y de servidor (guía §8.4)
  // ---------------------------------------------------------------------

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ReimbursementApiException(
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        isConnectionError: true,
      );
    } on SocketException {
      throw ReimbursementApiException(
        'No se pudo conectar con el servidor.',
        isConnectionError: true,
      );
    } on http.ClientException {
      throw ReimbursementApiException(
        'No se pudo conectar con el servidor.',
        isConnectionError: true,
      );
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ReimbursementApiException(
        _serverMessage(response) ?? 'Error del servidor (${response.statusCode}).');
  }

  /// El backend responde errores como `{"message": "..."}` (guía §5.4).
  String? _serverMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] is String) {
        final message = (body['message'] as String).trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {
      // cuerpo no JSON: se usa el mensaje genérico
    }
    return null;
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ReimbursementApiException(
          'El servidor devolvió una respuesta no válida.');
    }
  }
}
