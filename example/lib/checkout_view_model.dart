import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wompi_webview/wompi_webview.dart';

class PreparedWompiCheckout {
  const PreparedWompiCheckout({
    required this.config,
    required this.request,
    required this.checkoutUri,
  });

  final WompiConfig config;
  final WompiCheckoutRequest request;
  final Uri checkoutUri;
}

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel({
    this.urlBuilder = const WompiCheckoutUrlBuilder(),
    WompiSandboxVerificationService? verificationService,
    String initialPublicKey = const String.fromEnvironment('WOMPI_PUBLIC_KEY'),
    String initialIntegritySecret = const String.fromEnvironment(
      'WOMPI_INTEGRITY_SECRET',
    ),
    String initialSandboxPrivateKey = const String.fromEnvironment(
      'WOMPI_SANDBOX_PRIVATE_KEY',
    ),
  }) : _verificationService =
           verificationService ?? WompiSandboxVerificationService(),
       _publicKey = initialPublicKey,
       _integritySecret = initialIntegritySecret,
       _sandboxPrivateKey = initialSandboxPrivateKey {
    _reference = generateReference();
  }

  final WompiCheckoutUrlBuilder urlBuilder;
  final WompiSandboxVerificationService _verificationService;

  WompiSignatureMode _signatureMode = WompiSignatureMode.localSandboxSecret;
  WompiSignatureMode get signatureMode => _signatureMode;

  String _publicKey;
  String _integritySecret;
  String _precomputedSignature = '';
  String _sandboxPrivateKey;
  String _currency = 'COP';
  String _amountCopText = '50000';
  late String _reference;
  String _redirectUrl = 'https://checkout.example.com/wompi/resultado';
  String _customerEmail = '';
  String _customerFullName = '';
  String _customerPhone = '';

  String? _validationError;
  String? get validationError => _validationError;

  WompiPaymentResult? _lastResult;
  WompiPaymentResult? get lastResult => _lastResult;

  bool _isVerifyingTransaction = false;
  bool get isVerifyingTransaction => _isVerifyingTransaction;

  WompiTransactionStatus? _verifiedTransaction;
  WompiTransactionStatus? get verifiedTransaction => _verifiedTransaction;

  String? _verificationError;
  String? get verificationError => _verificationError;

  String get publicKey => _publicKey;
  String get integritySecret => _integritySecret;
  String get precomputedSignature => _precomputedSignature;
  String get sandboxPrivateKey => _sandboxPrivateKey;
  String get reference => _reference;
  String get redirectUrl => _redirectUrl;
  String get amountCopText => _amountCopText;
  String get currency => _currency;
  bool get isSandbox => _publicKey.trim().startsWith('pub_test_');
  bool get hasSandboxPrivateKey =>
      _sandboxPrivateKey.trim().startsWith('prv_test_');
  bool get hasCheckoutCredentials =>
      _publicKey.trim().isNotEmpty &&
      (_signatureMode == WompiSignatureMode.backendPrecomputed
          ? _precomputedSignature.trim().isNotEmpty
          : _integritySecret.trim().isNotEmpty);

  static String generateReference([DateTime? now]) {
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return 'ORD-$timestamp';
  }

  void regenerateReference() {
    _reference = generateReference();
    _validationError = null;
    notifyListeners();
  }

  void setSignatureMode(WompiSignatureMode mode) {
    if (_signatureMode == mode) return;
    _signatureMode = mode;
    _validationError = null;
    notifyListeners();
  }

  void updatePublicKey(String value) {
    _publicKey = value;
    notifyListeners();
  }

  void updateIntegritySecret(String value) {
    _integritySecret = value;
    notifyListeners();
  }

  void updatePrecomputedSignature(String value) {
    _precomputedSignature = value;
    notifyListeners();
  }

  void updateSandboxPrivateKey(String value) {
    _sandboxPrivateKey = value;
    notifyListeners();
  }

  void updateCurrency(String value) => _currency = value;
  void updateAmountCop(String value) => _amountCopText = value;
  void updateReference(String value) => _reference = value;
  void updateRedirectUrl(String value) => _redirectUrl = value;
  void updateCustomerEmail(String value) => _customerEmail = value;
  void updateCustomerFullName(String value) => _customerFullName = value;
  void updateCustomerPhone(String value) => _customerPhone = value;

  int? parseAmountInCents() {
    final sanitized = _amountCopText.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized.isEmpty) return null;
    final amountCop = int.tryParse(sanitized);
    if (amountCop == null || amountCop <= 0) return null;
    return amountCop * 100;
  }

  PreparedWompiCheckout? prepareCheckout() {
    final amountInCents = parseAmountInCents();
    if (amountInCents == null) {
      _validationError = 'Ingresa un monto válido en COP mayor a 0.';
      notifyListeners();
      return null;
    }

    final hasCustomerInfo =
        _customerEmail.trim().isNotEmpty ||
        _customerFullName.trim().isNotEmpty ||
        _customerPhone.trim().isNotEmpty;

    final request = WompiCheckoutRequest(
      reference: _reference.trim(),
      amountInCents: amountInCents,
      customerData: hasCustomerInfo
          ? WompiCustomerData(
              email: _customerEmail,
              fullName: _customerFullName,
              phoneNumber: _customerPhone,
            )
          : null,
    );

    try {
      final config = _signatureMode == WompiSignatureMode.backendPrecomputed
          ? WompiConfig.backendSigned(
              publicKey: _publicKey,
              currency: _currency,
              redirectUrl: _redirectUrl,
              signatureIntegrity: _precomputedSignature,
            )
          : WompiConfig.sandboxLocal(
              publicKey: _publicKey,
              currency: _currency,
              redirectUrl: _redirectUrl,
              integritySecret: _integritySecret,
            );

      final uri = urlBuilder.buildCheckoutUri(config: config, request: request);
      _validationError = null;
      notifyListeners();
      return PreparedWompiCheckout(
        config: config,
        request: request,
        checkoutUri: uri,
      );
    } on ArgumentError catch (e) {
      _validationError = e.message?.toString() ?? 'Datos de pago inválidos.';
      notifyListeners();
      return null;
    }
  }

  void setPaymentResult(WompiPaymentResult result) {
    _lastResult = result;
    _verifiedTransaction = null;
    _verificationError = null;
    if (result.outcome == WompiWebViewOutcome.redirected) {
      _reference = generateReference();
    }
    notifyListeners();

    if (result.outcome == WompiWebViewOutcome.redirected &&
        (result.transactionId?.isNotEmpty ?? false) &&
        hasSandboxPrivateKey) {
      unawaited(verifyLastTransaction());
    }
  }

  Future<void> verifyLastTransaction() async {
    final transactionId = _lastResult?.transactionId;
    if (transactionId == null || transactionId.isEmpty) return;

    _isVerifyingTransaction = true;
    _verificationError = null;
    notifyListeners();

    try {
      _verifiedTransaction = await _verificationService.fetchTransactionStatus(
        transactionId: transactionId,
        sandboxPrivateKey: _sandboxPrivateKey,
      );
    } catch (e) {
      _verificationError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isVerifyingTransaction = false;
      notifyListeners();
    }
  }
}
