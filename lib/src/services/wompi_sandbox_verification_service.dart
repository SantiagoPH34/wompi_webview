import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:wompi_webview/src/models/wompi_transaction_status.dart';

/// Queries Wompi's Sandbox API to confirm the status of a test transaction.
///
/// Only accepts Sandbox private keys (`prv_test_...`). In production, always
/// verify transaction status on your backend server using Webhooks or
/// `GET /v1/transactions/{id}`.
class WompiSandboxVerificationService {
  /// Creates a [WompiSandboxVerificationService] with an optional HTTP [client].
  WompiSandboxVerificationService({http.Client? client})
    : _client = client ?? http.Client();

  static const String _sandboxBaseUrl = 'https://sandbox.wompi.co/v1';
  static final RegExp _safeTransactionIdPattern = RegExp(r'^[A-Za-z0-9\-_]+$');

  final http.Client _client;

  /// Fetches the current status of [transactionId] from Wompi Sandbox using
  /// [sandboxPrivateKey] (`prv_test_...`).
  ///
  /// Throws an [ArgumentError] if [transactionId] has invalid characters or if
  /// [sandboxPrivateKey] does not start with `prv_test_`. Throws an
  /// [HttpException] if Wompi returns a non-200 HTTP status.
  Future<WompiTransactionStatus> fetchTransactionStatus({
    required String transactionId,
    required String sandboxPrivateKey,
  }) async {
    final cleanId = transactionId.trim();
    final cleanKey = sandboxPrivateKey.trim();

    if (cleanId.isEmpty || !_safeTransactionIdPattern.hasMatch(cleanId)) {
      throw ArgumentError('El ID de transacción tiene un formato inválido.');
    }
    if (!cleanKey.startsWith('prv_test_')) {
      throw ArgumentError(
        'Solo se permiten llaves privadas de pruebas (prv_test_...) en la app. En producción confirma desde tu backend.',
      );
    }

    final uri = Uri.parse('$_sandboxBaseUrl/transactions/$cleanId');
    final response = await _client.get(
      uri,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $cleanKey',
        HttpHeaders.acceptHeader: 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Error consultando transacción en Wompi Sandbox (HTTP ${response.statusCode}).',
        uri: uri,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return WompiTransactionStatus.fromJson(decoded);
  }
}
