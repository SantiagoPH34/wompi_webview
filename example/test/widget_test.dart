import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wompi_webview/wompi_webview.dart';
import 'package:wompi_webview_example/app_theme.dart';
import 'package:wompi_webview_example/checkout_setup_page.dart';
import 'package:wompi_webview_example/checkout_view_model.dart';

void main() {
  testWidgets(
    'launches checkout with configured Sandbox keys and confirms payment status',
    (WidgetTester tester) async {
      final verificationService = WompiSandboxVerificationService(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'data': {
                'id': '999-888-777',
                'status': 'APPROVED',
                'reference': 'ORD-TEST',
                'amount_in_cents': 7500000,
                'currency': 'COP',
                'payment_method_type': 'CARD',
              },
            }),
            200,
          );
        }),
      );
      final viewModel = CheckoutViewModel(
        verificationService: verificationService,
        initialPublicKey: 'pub_test_example',
        initialIntegritySecret: 'test_integrity_example',
        initialSandboxPrivateKey: 'prv_test_example',
      );
      PreparedWompiCheckout? launchedCheckout;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CheckoutSetupPage(
            viewModel: viewModel,
            onLaunchCheckout: (context, checkout) async {
              launchedCheckout = checkout;
              return WompiPaymentResult(
                outcome: WompiWebViewOutcome.redirected,
                reference: checkout.request.reference,
                amountInCents: checkout.request.amountInCents,
                currency: checkout.config.currency,
                transactionId: '999-888-777',
                environment: 'test',
              );
            },
          ),
        ),
      );

      expect(find.byKey(const Key('public_key_field')), findsNothing);
      expect(find.byKey(const Key('integrity_secret_field')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('amount_cop_field')),
        '75000',
      );
      await tester.pump();
      expect(find.text('amount-in-cents: 7500000'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('pay_with_wompi_button')),
      );
      await tester.tap(find.byKey(const Key('pay_with_wompi_button')));
      await tester.pumpAndSettle();

      expect(launchedCheckout, isNotNull);
      expect(
        launchedCheckout!.checkoutUri.queryParameters['amount-in-cents'],
        '7500000',
      );
      expect(find.byKey(const Key('payment_result_card')), findsOneWidget);
      expect(find.text('ID Transacción Wompi: 999-888-777'), findsOneWidget);
      expect(find.byKey(const Key('verified_transaction_box')), findsOneWidget);
      expect(
        find.text('Estado confirmado (Sandbox): APPROVED'),
        findsOneWidget,
      );
    },
  );
}
