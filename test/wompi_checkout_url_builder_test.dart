import 'package:flutter_test/flutter_test.dart';
import 'package:wompi_webview/wompi_webview.dart';

void main() {
  const builder = WompiCheckoutUrlBuilder();

  group('WompiCheckoutUrlBuilder.computeIntegritySignature', () {
    test('computes SHA-256 using Wompi concatenation order', () {
      final signature = WompiCheckoutUrlBuilder.computeIntegritySignature(
        reference: 'REF-1001',
        amountInCents: 5000000,
        currency: 'COP',
        integritySecret: 'test_integrity_abc',
      );

      expect(
        signature,
        '6e29c225ae6d54dffb0417cc917ee30803609b76daf20bc40089667cd833142f',
      );
    });
  });

  group('WompiConfig security guards', () {
    test('sandboxLocal rejects pub_prod_ keys', () {
      expect(
        () => WompiConfig.sandboxLocal(
          publicKey: 'pub_prod_12345',
          redirectUrl: 'https://checkout.example.com/callback',
          integritySecret: 'test_integrity_abc',
        ),
        throwsArgumentError,
      );
    });

    test('sandboxLocal rejects prod_integrity_ secrets', () {
      expect(
        () => WompiConfig.sandboxLocal(
          publicKey: 'pub_test_12345',
          redirectUrl: 'https://checkout.example.com/callback',
          integritySecret: 'prod_integrity_secret',
        ),
        throwsArgumentError,
      );
    });
  });

  group('WompiCheckoutUrlBuilder.buildCheckoutUri', () {
    test('builds checkout.wompi.co URI with sandboxLocal', () {
      final config = WompiConfig.sandboxLocal(
        publicKey: 'pub_test_12345',
        currency: 'cop',
        redirectUrl: 'https://checkout.example.com/wompi/resultado',
        integritySecret: 'test_integrity_abc',
      );
      const request = WompiCheckoutRequest(
        reference: 'REF-1001',
        amountInCents: 5000000,
        customerData: WompiCustomerData(
          email: 'cliente@correo.com',
          fullName: 'Ana Pérez',
          phoneNumber: '3001234567',
        ),
      );

      final uri = builder.buildCheckoutUri(config: config, request: request);

      expect(uri.scheme, 'https');
      expect(uri.host, 'checkout.wompi.co');
      expect(uri.path, '/p/');
      expect(uri.queryParameters['public-key'], 'pub_test_12345');
      expect(uri.queryParameters['currency'], 'COP');
      expect(uri.queryParameters['amount-in-cents'], '5000000');
      expect(uri.queryParameters['reference'], 'REF-1001');
      expect(
        uri.queryParameters['signature:integrity'],
        '6e29c225ae6d54dffb0417cc917ee30803609b76daf20bc40089667cd833142f',
      );
      expect(
        uri.queryParameters['redirect-url'],
        'https://checkout.example.com/wompi/resultado',
      );
      expect(uri.queryParameters['customer-data:email'], 'cliente@correo.com');
      expect(uri.queryParameters['customer-data:full-name'], 'Ana Pérez');
      expect(uri.queryParameters['customer-data:phone-number'], '3001234567');
      expect(uri.queryParameters['customer-data:phone-number-prefix'], '+57');
    });

    test('builds checkout.wompi.pa URI for Panama with backendSigned', () {
      const config = WompiConfig.backendSigned(
        publicKey: 'pub_prod_999',
        redirectUrl: 'https://mi-tienda.com/callback',
        signatureIntegrity: 'abc123backendhash',
        region: WompiRegion.panama,
      );
      const request = WompiCheckoutRequest(
        reference: 'ORD-900',
        amountInCents: 2500,
      );

      final uri = builder.buildCheckoutUri(config: config, request: request);

      expect(uri.host, 'checkout.wompi.pa');
      expect(uri.queryParameters['currency'], 'USD');
      expect(uri.queryParameters['signature:integrity'], 'abc123backendhash');
      expect(uri.queryParameters.containsKey('customer-data:email'), isFalse);
    });

    test('rejects insecure non-localhost HTTP redirect URLs', () {
      const config = WompiConfig.backendSigned(
        publicKey: 'pub_prod_999',
        redirectUrl: 'http://mi-tienda.com/callback',
        signatureIntegrity: 'abc123backendhash',
      );
      const request = WompiCheckoutRequest(
        reference: 'ORD-1',
        amountInCents: 100000,
      );

      expect(
        () => builder.buildCheckoutUri(config: config, request: request),
        throwsArgumentError,
      );
    });

    test('allows http://localhost redirect URL for local dev', () {
      const config = WompiConfig.backendSigned(
        publicKey: 'pub_test_999',
        redirectUrl: 'http://localhost:3000/callback',
        signatureIntegrity: 'abc123hash',
      );
      const request = WompiCheckoutRequest(
        reference: 'ORD-1',
        amountInCents: 100000,
      );

      final uri = builder.buildCheckoutUri(config: config, request: request);
      expect(
        uri.queryParameters['redirect-url'],
        'http://localhost:3000/callback',
      );
    });
  });

  group('Navigation security & redirect parsing', () {
    test('isAllowedNavigationUrl permits HTTPS and blocks unsafe schemes', () {
      const redirect = 'https://checkout.example.com/wompi/resultado';

      expect(
        WompiCheckoutUrlBuilder.isAllowedNavigationUrl(
          'https://checkout.wompi.co/p/',
          redirect,
        ),
        isTrue,
      );
      expect(
        WompiCheckoutUrlBuilder.isAllowedNavigationUrl('about:blank', redirect),
        isTrue,
      );
      expect(
        WompiCheckoutUrlBuilder.isAllowedNavigationUrl(
          'http://insecure.example.com/phish',
          redirect,
        ),
        isFalse,
      );
      expect(
        WompiCheckoutUrlBuilder.isAllowedNavigationUrl(
          'javascript:alert(1)',
          redirect,
        ),
        isFalse,
      );
      expect(
        WompiCheckoutUrlBuilder.isAllowedNavigationUrl(
          'file:///etc/passwd',
          redirect,
        ),
        isFalse,
      );
      expect(
        WompiCheckoutUrlBuilder.isAllowedNavigationUrl(
          'intent://scan/#Intent',
          redirect,
        ),
        isFalse,
      );
    });

    test('isRedirectMatch matches exact and sub-path with query params', () {
      expect(
        WompiCheckoutUrlBuilder.isRedirectMatch(
          'https://checkout.example.com/wompi/resultado?id=1132-123&env=test',
          'https://checkout.example.com/wompi/resultado',
        ),
        isTrue,
      );
      expect(
        WompiCheckoutUrlBuilder.isRedirectMatch(
          'https://checkout.wompi.co/p/?public-key=pub_test_1',
          'https://checkout.example.com/wompi/resultado',
        ),
        isFalse,
      );
    });

    test('parseRedirectResult extracts transaction id and environment', () {
      const request = WompiCheckoutRequest(
        reference: 'ORD-77',
        amountInCents: 4500000,
      );

      final result = WompiCheckoutUrlBuilder.parseRedirectResult(
        url:
            'https://checkout.example.com/wompi/resultado?id=12345-67890&env=test',
        request: request,
        currency: 'COP',
      );

      expect(result.outcome, WompiWebViewOutcome.redirected);
      expect(result.transactionId, '12345-67890');
      expect(result.environment, 'test');
      expect(result.reference, 'ORD-77');
      expect(result.amountInCents, 4500000);
      expect(result.currency, 'COP');
    });
  });
}
