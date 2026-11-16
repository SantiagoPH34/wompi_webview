/// Supported Wompi checkout regions and their hosted checkout endpoints.
enum WompiRegion {
  /// Wompi Colombia (`https://checkout.wompi.co/p/`, default currency `COP`).
  colombia(
    checkoutBaseUrl: 'https://checkout.wompi.co/p/',
    defaultCurrency: 'COP',
  ),

  /// Wompi Panama (`https://checkout.wompi.pa/p/`, default currency `USD`).
  panama(
    checkoutBaseUrl: 'https://checkout.wompi.pa/p/',
    defaultCurrency: 'USD',
  );

  const WompiRegion({
    required this.checkoutBaseUrl,
    required this.defaultCurrency,
  });

  /// Hosted Wompi Web Checkout base URL for this region.
  final String checkoutBaseUrl;

  /// Default ISO 4217 currency code for this region.
  final String defaultCurrency;
}

/// Strategy used to provide the Wompi `signature:integrity` hash.
enum WompiSignatureMode {
  /// Uses a SHA-256 `signature:integrity` computed by your backend server.
  backendPrecomputed,

  /// Computes SHA-256 locally using a Sandbox integrity secret.
  localSandboxSecret,
}

/// Configuration for launching Wompi Web Checkout inside a WebView.
///
/// Use [WompiConfig.backendSigned] in production so secret integrity keys are
/// never embedded in the mobile application binary.
class WompiConfig {
  /// Creates a production-safe configuration with a backend-generated
  /// [signatureIntegrity] hash.
  const WompiConfig.backendSigned({
    required this.publicKey,
    required this.redirectUrl,
    required String signatureIntegrity,
    String? currency,
    this.region = WompiRegion.colombia,
  }) : signatureMode = WompiSignatureMode.backendPrecomputed,
       precomputedSignature = signatureIntegrity,
       integritySecret = null,
       currency = currency ?? (region == WompiRegion.colombia ? 'COP' : 'USD');

  /// Creates a Sandbox-only configuration that computes `signature:integrity`
  /// locally from [integritySecret].
  ///
  /// Throws an [ArgumentError] if [publicKey] starts with `pub_prod_` or if
  /// [integritySecret] starts with `prod_integrity_`.
  factory WompiConfig.sandboxLocal({
    required String publicKey,
    required String redirectUrl,
    required String integritySecret,
    String? currency,
    WompiRegion region = WompiRegion.colombia,
  }) {
    final cleanPublicKey = publicKey.trim();
    final cleanSecret = integritySecret.trim();

    if (cleanPublicKey.startsWith('pub_prod_')) {
      throw ArgumentError(
        'Production public keys (pub_prod_...) must use WompiConfig.backendSigned.',
      );
    }
    if (cleanSecret.startsWith('prod_integrity_')) {
      throw ArgumentError(
        'Production integrity secrets (prod_integrity_...) must never be placed in client code.',
      );
    }

    return WompiConfig._(
      publicKey: cleanPublicKey,
      redirectUrl: redirectUrl,
      currency: currency ?? region.defaultCurrency,
      region: region,
      signatureMode: WompiSignatureMode.localSandboxSecret,
      integritySecret: cleanSecret,
      precomputedSignature: null,
    );
  }

  const WompiConfig._({
    required this.publicKey,
    required this.redirectUrl,
    required this.currency,
    required this.region,
    required this.signatureMode,
    this.integritySecret,
    this.precomputedSignature,
  });

  /// Merchant public key (`pub_test_...` or `pub_prod_...`).
  final String publicKey;

  /// ISO 4217 currency code (e.g. `COP` or `USD`).
  final String currency;

  /// Hosted Wompi region endpoint.
  final WompiRegion region;

  /// Callback URL intercepted by the WebView when payment flow completes.
  final String redirectUrl;

  /// Strategy used to obtain `signature:integrity`.
  final WompiSignatureMode signatureMode;

  /// Sandbox integrity secret (`test_integrity_...`) for local hashing.
  final String? integritySecret;

  /// Precomputed SHA-256 hex digest supplied by your backend.
  final String? precomputedSignature;

  /// Whether [publicKey] belongs to Wompi's Sandbox environment.
  bool get isSandbox => publicKey.trim().startsWith('pub_test_');
}
