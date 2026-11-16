import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wompi_webview/wompi_webview.dart';

void main() {
  group('WompiSandboxVerificationService', () {
    test('rejects non-sandbox private keys', () async {
      final service = WompiSandboxVerificationService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => service.fetchTransactionStatus(
          transactionId: '1132-903100443-27458',
          sandboxPrivateKey: 'prv_prod_not_allowed',
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed transaction IDs to prevent path injection', () {
      final service = WompiSandboxVerificationService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => service.fetchTransactionStatus(
          transactionId: '../merchants/secret',
          sandboxPrivateKey: 'prv_test_demo_key',
        ),
        throwsArgumentError,
      );
    });

    test('fetches and parses sandbox transaction status', () async {
      late Uri requestedUri;
      late Map<String, String> requestedHeaders;

      final service = WompiSandboxVerificationService(
        client: MockClient((request) async {
          requestedUri = request.url;
          requestedHeaders = request.headers;
          return http.Response(
            jsonEncode({
              'data': {
                'id': '1132-903100443-27458',
                'status': 'APPROVED',
                'reference': 'ORD-100',
                'amount_in_cents': 5000000,
                'currency': 'COP',
                'payment_method_type': 'CARD',
                'status_message': null,
                'finalized_at': '2026-11-15T19:20:00.000Z',
              },
            }),
            200,
          );
        }),
      );

      final result = await service.fetchTransactionStatus(
        transactionId: '1132-903100443-27458',
        sandboxPrivateKey: 'prv_test_demo_key',
      );

      expect(
        requestedUri.toString(),
        'https://sandbox.wompi.co/v1/transactions/1132-903100443-27458',
      );
      expect(
        requestedHeaders[HttpHeaders.authorizationHeader],
        'Bearer prv_test_demo_key',
      );
      expect(result.status, 'APPROVED');
      expect(result.isApproved, isTrue);
      expect(result.paymentMethodType, 'CARD');
      expect(result.reference, 'ORD-100');
      expect(result.amountInCents, 5000000);
    });

    test('throws HttpException when Wompi returns non-200 status', () async {
      final service = WompiSandboxVerificationService(
        client: MockClient((_) async => http.Response('Unauthorized', 401)),
      );

      expect(
        () => service.fetchTransactionStatus(
          transactionId: '1132-903100443-27458',
          sandboxPrivateKey: 'prv_test_demo_key',
        ),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
