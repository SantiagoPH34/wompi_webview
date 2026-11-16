import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:wompi_webview/src/models/wompi_checkout_request.dart';
import 'package:wompi_webview/src/models/wompi_config.dart';
import 'package:wompi_webview/src/models/wompi_payment_result.dart';

/// Builds integrity-signed Wompi Web Checkout URIs, enforces WebView navigation
/// rules, and parses redirect callbacks.
class WompiCheckoutUrlBuilder {
  /// Creates a [WompiCheckoutUrlBuilder].
  const WompiCheckoutUrlBuilder();

  /// Computes the SHA-256 `signature:integrity` hash using Wompi's required
  /// concatenation order: `<reference><amountInCents><currency><integritySecret>`.
  static String computeIntegritySignature({
    required String reference,
    required int amountInCents,
    required String currency,
    required String integritySecret,
  }) {
    final payload = '$reference$amountInCents$currency$integritySecret';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Validates [config] and [request] and builds the signed Wompi checkout [Uri].
  ///
  /// Throws an [ArgumentError] if any required parameter is missing, invalid,
  /// or violates Sandbox-only security constraints.
  Uri buildCheckoutUri({
    required WompiConfig config,
    required WompiCheckoutRequest request,
  }) {
    final publicKey = config.publicKey.trim();
    final currency = config.currency.trim().toUpperCase();
    final redirectUrl = config.redirectUrl.trim();
    final reference = request.reference.trim();

    if (publicKey.isEmpty) {
      throw ArgumentError('La llave pública (public-key) es obligatoria.');
    }
    if (currency.isEmpty) {
      throw ArgumentError('La moneda (currency) es obligatoria.');
    }
    if (reference.isEmpty) {
      throw ArgumentError('La referencia de pago es obligatoria.');
    }
    if (request.amountInCents <= 0) {
      throw ArgumentError('El monto en centavos debe ser mayor que cero.');
    }

    _validateRedirectUrl(redirectUrl);

    final signature = _resolveSignature(
      config: config,
      publicKey: publicKey,
      reference: reference,
      amountInCents: request.amountInCents,
      currency: currency,
    );

    final queryParams = <String, String>{
      'public-key': publicKey,
      'currency': currency,
      'amount-in-cents': request.amountInCents.toString(),
      'reference': reference,
      'signature:integrity': signature,
      'redirect-url': redirectUrl,
    };

    _addCustomerParams(queryParams, request.customerData);

    return Uri.parse(
      config.region.checkoutBaseUrl,
    ).replace(queryParameters: queryParams);
  }

  void _validateRedirectUrl(String redirectUrl) {
    final parsedRedirect = Uri.tryParse(redirectUrl);
    if (redirectUrl.isEmpty ||
        parsedRedirect == null ||
        !parsedRedirect.hasScheme ||
        parsedRedirect.host.isEmpty) {
      throw ArgumentError(
        'La URL de redirección (redirect-url) debe incluir esquema y host válidos.',
      );
    }

    final scheme = parsedRedirect.scheme.toLowerCase();
    final host = parsedRedirect.host.toLowerCase();
    final isLocalHttp =
        scheme == 'http' && (host == 'localhost' || host == '127.0.0.1');

    if (scheme != 'https' && !isLocalHttp) {
      throw ArgumentError(
        'Por seguridad, redirect-url debe usar HTTPS (solo se permite HTTP en localhost).',
      );
    }
  }

  String _resolveSignature({
    required WompiConfig config,
    required String publicKey,
    required String reference,
    required int amountInCents,
    required String currency,
  }) {
    switch (config.signatureMode) {
      case WompiSignatureMode.localSandboxSecret:
        if (publicKey.startsWith('pub_prod_')) {
          throw ArgumentError(
            'Las llaves de producción deben usar WompiConfig.backendSigned.',
          );
        }
        final secret = config.integritySecret?.trim() ?? '';
        if (secret.isEmpty) {
          throw ArgumentError(
            'El secreto de integridad es obligatorio en modo Sandbox local.',
          );
        }
        if (secret.startsWith('prod_integrity_')) {
          throw ArgumentError(
            'Nunca incluyas un secreto prod_integrity_ en el código cliente.',
          );
        }
        return computeIntegritySignature(
          reference: reference,
          amountInCents: amountInCents,
          currency: currency,
          integritySecret: secret,
        );
      case WompiSignatureMode.backendPrecomputed:
        final precomputed = config.precomputedSignature?.trim() ?? '';
        if (precomputed.isEmpty) {
          throw ArgumentError(
            'La firma SHA-256 generada por el backend es obligatoria.',
          );
        }
        return precomputed;
    }
  }

  void _addCustomerParams(
    Map<String, String> queryParams,
    WompiCustomerData? customer,
  ) {
    if (customer == null) return;

    void putIfNotEmpty(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        queryParams[key] = trimmed;
      }
    }

    putIfNotEmpty('customer-data:email', customer.email);
    putIfNotEmpty('customer-data:full-name', customer.fullName);
    putIfNotEmpty('customer-data:phone-number', customer.phoneNumber);
    if (customer.phoneNumber?.trim().isNotEmpty ?? false) {
      putIfNotEmpty(
        'customer-data:phone-number-prefix',
        customer.phoneNumberPrefix,
      );
    }
    putIfNotEmpty('customer-data:legal-id', customer.legalId);
    putIfNotEmpty('customer-data:legal-id-type', customer.legalIdType);
  }

  /// Checks whether [navigatedUrl] is safe to load inside the checkout WebView.
  ///
  /// Allows `https://` pages (Wompi checkout, PSE, and 3DS bank pages),
  /// `about:blank`, and the configured [configuredRedirectUrl]. Blocks insecure
  /// `http://` pages, `file://`, `javascript:`, `content:`, and custom external
  /// app schemes.
  static bool isAllowedNavigationUrl(
    String navigatedUrl,
    String configuredRedirectUrl,
  ) {
    if (isRedirectMatch(navigatedUrl, configuredRedirectUrl)) {
      return true;
    }
    final uri = Uri.tryParse(navigatedUrl);
    if (uri == null) return false;

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') return true;
    if (navigatedUrl == 'about:blank') return true;
    return false;
  }

  /// Checks whether [navigatedUrl] matches [configuredRedirectUrl] by scheme,
  /// host, port, and normalized path prefix.
  static bool isRedirectMatch(
    String navigatedUrl,
    String configuredRedirectUrl,
  ) {
    final target = Uri.tryParse(navigatedUrl);
    final configured = Uri.tryParse(configuredRedirectUrl.trim());
    if (target == null || configured == null) return false;
    if (!target.hasScheme || !configured.hasScheme) return false;

    final sameOrigin =
        target.scheme.toLowerCase() == configured.scheme.toLowerCase() &&
        target.host.toLowerCase() == configured.host.toLowerCase() &&
        target.port == configured.port;
    if (!sameOrigin) return false;

    final targetPath = _normalizePath(target.path);
    final configuredPath = _normalizePath(configured.path);
    if (configuredPath.isEmpty) return true;
    return targetPath == configuredPath ||
        targetPath.startsWith('$configuredPath/');
  }

  static String _normalizePath(String path) {
    return path.replaceAll(RegExp(r'/+$'), '');
  }

  /// Parses an intercepted redirect URL into a [WompiPaymentResult].
  static WompiPaymentResult parseRedirectResult({
    required String url,
    required WompiCheckoutRequest request,
    required String currency,
  }) {
    final uri = Uri.parse(url);
    return WompiPaymentResult(
      outcome: WompiWebViewOutcome.redirected,
      reference: request.reference,
      amountInCents: request.amountInCents,
      currency: currency,
      transactionId: uri.queryParameters['id'],
      environment: uri.queryParameters['env'],
      redirectUri: uri,
    );
  }
}
