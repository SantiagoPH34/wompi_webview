/// Outcome reported when the Wompi checkout WebView closes.
enum WompiWebViewOutcome {
  /// Wompi redirected back to the configured `redirect-url`.
  redirected,

  /// The user closed or cancelled the checkout before reaching `redirect-url`.
  cancelled,

  /// A main-frame WebView error prevented the checkout from loading.
  error,
}

/// Result captured when closing the Wompi checkout WebView.
class WompiPaymentResult {
  /// Creates a [WompiPaymentResult] describing how the WebView flow ended.
  const WompiPaymentResult({
    required this.outcome,
    required this.reference,
    required this.amountInCents,
    required this.currency,
    this.transactionId,
    this.environment,
    this.redirectUri,
    this.errorMessage,
  });

  /// How the checkout WebView session terminated.
  final WompiWebViewOutcome outcome;

  /// Merchant reference sent to Wompi.
  final String reference;

  /// Transaction amount in cents sent to Wompi.
  final int amountInCents;

  /// Currency code sent to Wompi.
  final String currency;

  /// Wompi transaction ID extracted from the `?id=` query parameter on redirect.
  final String? transactionId;

  /// Wompi environment query parameter (`test` or `prod`), when provided.
  final String? environment;

  /// Intercepted redirect [Uri] when [outcome] is [WompiWebViewOutcome.redirected].
  final Uri? redirectUri;

  /// Error description when [outcome] is [WompiWebViewOutcome.error].
  final String? errorMessage;
}
