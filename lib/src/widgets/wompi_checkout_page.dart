import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wompi_webview/src/models/wompi_checkout_request.dart';
import 'package:wompi_webview/src/models/wompi_config.dart';
import 'package:wompi_webview/src/models/wompi_payment_result.dart';
import 'package:wompi_webview/src/services/wompi_checkout_url_builder.dart';

/// Convenience entry point for opening Wompi Web Checkout in a modal route.
class WompiCheckout {
  const WompiCheckout._();

  /// Builds the signed checkout URI from [config] and [request], opens
  /// [WompiCheckoutPage], and returns the resulting [WompiPaymentResult].
  ///
  /// Returns `null` if the route is popped externally without a result.
  static Future<WompiPaymentResult?> open(
    BuildContext context, {
    required WompiConfig config,
    required WompiCheckoutRequest request,
    WompiCheckoutUrlBuilder urlBuilder = const WompiCheckoutUrlBuilder(),
    String title = 'Wompi Checkout',
    bool confirmExitOnCancel = true,
  }) {
    final checkoutUri = urlBuilder.buildCheckoutUri(
      config: config,
      request: request,
    );

    return Navigator.of(context).push<WompiPaymentResult>(
      MaterialPageRoute<WompiPaymentResult>(
        builder: (_) => WompiCheckoutPage(
          checkoutUri: checkoutUri,
          redirectUrl: config.redirectUrl,
          request: request,
          currency: config.currency.trim().toUpperCase(),
          title: title,
          confirmExitOnCancel: confirmExitOnCancel,
        ),
      ),
    );
  }
}

/// Embedded WebView screen that loads Wompi Web Checkout and intercepts
/// navigation back to [redirectUrl].
class WompiCheckoutPage extends StatefulWidget {
  /// Creates a [WompiCheckoutPage] from a pre-built [checkoutUri].
  const WompiCheckoutPage({
    super.key,
    required this.checkoutUri,
    required this.redirectUrl,
    required this.request,
    required this.currency,
    this.title = 'Wompi Checkout',
    this.confirmExitOnCancel = true,
    this.confirmCancelTitle = '¿Cancelar pago?',
    this.confirmCancelMessage =
        'Si cierras esta pantalla antes de completar el pago, deberás verificar el estado en tu backend o iniciar un nuevo intento.',
  });

  /// Signed `checkout.wompi.co` or `checkout.wompi.pa` URI to load.
  final Uri checkoutUri;

  /// Callback URL intercepted by the WebView when payment finishes.
  final String redirectUrl;

  /// Checkout request metadata associated with this session.
  final WompiCheckoutRequest request;

  /// ISO 4217 currency code associated with [request].
  final String currency;

  /// Title displayed in the default [AppBar].
  final String title;

  /// Whether to prompt for confirmation before cancelling the checkout.
  final bool confirmExitOnCancel;

  /// Dialog title shown when [confirmExitOnCancel] is `true`.
  final String confirmCancelTitle;

  /// Dialog body message shown when [confirmExitOnCancel] is `true`.
  final String confirmCancelMessage;

  @override
  State<WompiCheckoutPage> createState() => _WompiCheckoutPageState();
}

class _WompiCheckoutPageState extends State<WompiCheckoutPage> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  String? _mainFrameError;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _mainFrameError = null;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _mainFrameError = error.description.isNotEmpty
                  ? error.description
                  : 'No fue posible cargar la pasarela de Wompi.';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (WompiCheckoutUrlBuilder.isRedirectMatch(
              request.url,
              widget.redirectUrl,
            )) {
              _completeWithRedirect(request.url);
              return NavigationDecision.prevent;
            }

            if (!WompiCheckoutUrlBuilder.isAllowedNavigationUrl(
              request.url,
              widget.redirectUrl,
            )) {
              _showBlockedNavigationNotice(request.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(widget.checkoutUri);
  }

  void _completeWithRedirect(String url) {
    if (_hasCompleted || !mounted) return;
    _hasCompleted = true;

    final result = WompiCheckoutUrlBuilder.parseRedirectResult(
      url: url,
      request: widget.request,
      currency: widget.currency,
    );
    Navigator.of(context).pop(result);
  }

  void _showBlockedNavigationNotice(String blockedUrl) {
    if (!mounted) return;
    final scheme = Uri.tryParse(blockedUrl)?.scheme ?? 'desconocido';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Por seguridad se bloqueó una navegación no permitida ($scheme://).',
        ),
      ),
    );
  }

  Future<void> _handleCancel() async {
    if (_hasCompleted || !mounted) return;

    var shouldClose = !widget.confirmExitOnCancel;
    if (widget.confirmExitOnCancel) {
      final decision = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.confirmCancelTitle),
          content: Text(widget.confirmCancelMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continuar pagando'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      shouldClose = decision == true;
    }

    if (shouldClose && mounted && !_hasCompleted) {
      _hasCompleted = true;
      Navigator.of(context).pop(
        WompiPaymentResult(
          outcome: WompiWebViewOutcome.cancelled,
          reference: widget.request.reference,
          amountInCents: widget.request.amountInCents,
          currency: widget.currency,
        ),
      );
    }
  }

  void _retryLoad() {
    setState(() {
      _mainFrameError = null;
      _loadingProgress = 0;
    });
    _controller.loadRequest(widget.checkoutUri);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return;
        }
        await _handleCancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancelar pago',
            onPressed: _handleCancel,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: _retryLoad,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _loadingProgress < 100
                ? LinearProgressIndicator(
                    value: _loadingProgress / 100,
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                  )
                : const SizedBox(height: 3),
          ),
        ),
        body: _mainFrameError != null
            ? _WebViewErrorView(
                message: _mainFrameError!,
                onRetry: _retryLoad,
                onCancel: _handleCancel,
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _WebViewErrorView extends StatelessWidget {
  const _WebViewErrorView({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error cargando Wompi',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cerrar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
