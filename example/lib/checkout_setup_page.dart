import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wompi_webview/wompi_webview.dart';
import 'package:wompi_webview_example/checkout_view_model.dart';

typedef CheckoutLauncher = Future<WompiPaymentResult?> Function(
  BuildContext context,
  PreparedWompiCheckout checkout,
);

class CheckoutSetupPage extends StatefulWidget {
  const CheckoutSetupPage({
    super.key,
    required this.viewModel,
    this.onLaunchCheckout,
  });

  final CheckoutViewModel viewModel;
  final CheckoutLauncher? onLaunchCheckout;

  @override
  State<CheckoutSetupPage> createState() => _CheckoutSetupPageState();
}

class _CheckoutSetupPageState extends State<CheckoutSetupPage> {
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _referenceController;
  late final TextEditingController _emailController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final vm = widget.viewModel;
    _amountController = TextEditingController(text: vm.amountCopText);
    _currencyController = TextEditingController(text: vm.currency);
    _referenceController = TextEditingController(text: vm.reference);
    _emailController = TextEditingController();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    _referenceController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _syncReferenceFromViewModel() {
    if (_referenceController.text != widget.viewModel.reference) {
      _referenceController.text = widget.viewModel.reference;
    }
  }

  Future<void> _startPayment() async {
    final prepared = widget.viewModel.prepareCheckout();
    if (prepared == null) return;

    final launcher = widget.onLaunchCheckout ?? _defaultLaunchWebView;
    final result = await launcher(context, prepared);
    if (!mounted || result == null) return;

    widget.viewModel.setPaymentResult(result);
    _syncReferenceFromViewModel();
  }

  Future<WompiPaymentResult?> _defaultLaunchWebView(
    BuildContext context,
    PreparedWompiCheckout prepared,
  ) {
    return WompiCheckout.open(
      context,
      config: prepared.config,
      request: prepared.request,
      urlBuilder: widget.viewModel.urlBuilder,
    );
  }

  void _openAdvancedSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AdvancedSettingsSheet(viewModel: widget.viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Wompi'),
        actions: [
          IconButton(
            key: const Key('open_settings_button'),
            tooltip: 'Configuración técnica (llaves / redirect-url)',
            icon: const Icon(Icons.tune),
            onPressed: _openAdvancedSettingsSheet,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;
          final cents = vm.parseAmountInCents();

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EnvironmentBanner(
                        hasCredentials: vm.hasCheckoutCredentials,
                        isSandbox: vm.isSandbox,
                        hasVerificationKey: vm.hasSandboxPrivateKey,
                        onConfigurePressed: _openAdvancedSettingsSheet,
                      ),
                      const SizedBox(height: 12),
                      const _SandboxTestCardsBanner(),
                      if (vm.lastResult != null) ...[
                        const SizedBox(height: 16),
                        _PaymentResultCard(
                          result: vm.lastResult!,
                          isVerifying: vm.isVerifyingTransaction,
                          verifiedTransaction: vm.verifiedTransaction,
                          verificationError: vm.verificationError,
                          canVerify: vm.hasSandboxPrivateKey,
                          onVerifyPressed: vm.verifyLastTransaction,
                        ),
                      ],
                      if (vm.validationError != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(message: vm.validationError!),
                      ],
                      const SizedBox(height: 16),
                      _PaymentDetailsCard(
                        amountController: _amountController,
                        currencyController: _currencyController,
                        referenceController: _referenceController,
                        amountInCents: cents,
                        onAmountChanged: (value) {
                          vm.updateAmountCop(value);
                          setState(() {});
                        },
                        onCurrencyChanged: vm.updateCurrency,
                        onReferenceChanged: vm.updateReference,
                        onRegenerateReference: () {
                          vm.regenerateReference();
                          _syncReferenceFromViewModel();
                        },
                      ),
                      const SizedBox(height: 16),
                      _CustomerDataCard(
                        emailController: _emailController,
                        fullNameController: _fullNameController,
                        phoneController: _phoneController,
                        onEmailChanged: vm.updateCustomerEmail,
                        onFullNameChanged: vm.updateCustomerFullName,
                        onPhoneChanged: vm.updateCustomerPhone,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('pay_with_wompi_button'),
                        onPressed: _startPayment,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Pagar con Wompi'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EnvironmentBanner extends StatelessWidget {
  const _EnvironmentBanner({
    required this.hasCredentials,
    required this.isSandbox,
    required this.hasVerificationKey,
    required this.onConfigurePressed,
  });

  final bool hasCredentials;
  final bool isSandbox;
  final bool hasVerificationKey;
  final VoidCallback onConfigurePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!hasCredentials) {
      return Card(
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.key_outlined, color: Colors.amber.shade900),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ejecuta con --dart-define-from-file=wompi_sandbox.local.json o configura tus llaves en ajustes.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: onConfigurePressed,
                child: const Text('Configurar'),
              ),
            ],
          ),
        ),
      );
    }

    final statusText = isSandbox
        ? (hasVerificationKey
              ? 'Sandbox listo: llaves cargadas y confirmación automática activa.'
              : 'Sandbox listo: llaves de checkout cargadas.')
        : 'Modo Producción (firma backend) listo.';

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SandboxTestCardsBanner extends StatelessWidget {
  const _SandboxTestCardsBanner();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ExpansionTile(
        leading: Icon(Icons.credit_card_outlined),
        title: Text(
          'Tarjetas de prueba en Sandbox',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text('Úsalas dentro del WebView de Wompi'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Aprobada (APPROVED): 4242 4242 4242 4242'),
                SizedBox(height: 4),
                Text('• Declinada (DECLINED): 4111 1111 1111 1111'),
                SizedBox(height: 4),
                Text('• Error (ERROR): cualquier otro número válido'),
                SizedBox(height: 6),
                Text(
                  'Fecha futura (ej. 12/28) y CVC de 3 dígitos (ej. 123).',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('validation_error_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDetailsCard extends StatelessWidget {
  const _PaymentDetailsCard({
    required this.amountController,
    required this.currencyController,
    required this.referenceController,
    required this.amountInCents,
    required this.onAmountChanged,
    required this.onCurrencyChanged,
    required this.onReferenceChanged,
    required this.onRegenerateReference,
  });

  final TextEditingController amountController;
  final TextEditingController currencyController;
  final TextEditingController referenceController;
  final int? amountInCents;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onReferenceChanged;
  final VoidCallback onRegenerateReference;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos del pago',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: const Key('amount_cop_field'),
                    controller: amountController,
                    onChanged: onAmountChanged,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Monto (COP)',
                      helperText: amountInCents != null
                          ? 'amount-in-cents: $amountInCents'
                          : 'Ingresa un valor entero > 0',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextField(
                    key: const Key('currency_field'),
                    controller: currencyController,
                    onChanged: onCurrencyChanged,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Moneda'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reference_field'),
              controller: referenceController,
              onChanged: onReferenceChanged,
              decoration: InputDecoration(
                labelText: 'Referencia única',
                suffixIcon: IconButton(
                  key: const Key('regenerate_reference_button'),
                  tooltip: 'Generar nueva referencia',
                  icon: const Icon(Icons.autorenew),
                  onPressed: onRegenerateReference,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDataCard extends StatelessWidget {
  const _CustomerDataCard({
    required this.emailController,
    required this.fullNameController,
    required this.phoneController,
    required this.onEmailChanged,
    required this.onFullNameChanged,
    required this.onPhoneChanged,
  });

  final TextEditingController emailController;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onFullNameChanged;
  final ValueChanged<String> onPhoneChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text(
          'Datos del cliente (opcional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Pre-carga correo, nombre y teléfono en Wompi'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextField(
            key: const Key('customer_email_field'),
            controller: emailController,
            onChanged: onEmailChanged,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_name_field'),
            controller: fullNameController,
            onChanged: onFullNameChanged,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer_phone_field'),
            controller: phoneController,
            onChanged: onPhoneChanged,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono (+57)',
              hintText: '3001234567',
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentResultCard extends StatelessWidget {
  const _PaymentResultCard({
    required this.result,
    required this.isVerifying,
    required this.verifiedTransaction,
    required this.verificationError,
    required this.canVerify,
    required this.onVerifyPressed,
  });

  final WompiPaymentResult result;
  final bool isVerifying;
  final WompiTransactionStatus? verifiedTransaction;
  final String? verificationError;
  final bool canVerify;
  final VoidCallback onVerifyPressed;

  @override
  Widget build(BuildContext context) {
    final isRedirected = result.outcome == WompiWebViewOutcome.redirected;
    final icon = isRedirected
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;
    final accentColor = isRedirected
        ? const Color(0xFF0B7A53)
        : Colors.orange.shade800;
    final title = isRedirected
        ? 'Checkout finalizado (redirección capturada)'
        : 'Pago cancelado en el WebView';

    return Card(
      key: const Key('payment_result_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Referencia: ${result.reference}'),
            Text(
              'Monto: ${result.amountInCents ~/ 100} ${result.currency} (${result.amountInCents} centavos)',
            ),
            if (result.transactionId != null)
              Text('ID Transacción Wompi: ${result.transactionId}'),
            if (result.environment != null)
              Text('Ambiente: ${result.environment}'),
            if (isVerifying) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Confirmando transacción en Wompi Sandbox...'),
                ],
              ),
            ],
            if (verifiedTransaction != null) ...[
              const SizedBox(height: 12),
              _VerifiedStatusBox(transaction: verifiedTransaction!),
            ],
            if (verificationError != null) ...[
              const SizedBox(height: 10),
              Text(
                verificationError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            if (isRedirected &&
                (result.transactionId?.isNotEmpty ?? false) &&
                canVerify) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('verify_sandbox_button'),
                onPressed: isVerifying ? null : onVerifyPressed,
                icon: const Icon(Icons.sync),
                label: Text(
                  verifiedTransaction == null
                      ? 'Confirmar estado en Sandbox'
                      : 'Actualizar estado en Sandbox',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerifiedStatusBox extends StatelessWidget {
  const _VerifiedStatusBox({required this.transaction});

  final WompiTransactionStatus transaction;

  @override
  Widget build(BuildContext context) {
    final color = transaction.isApproved
        ? const Color(0xFF0B7A53)
        : (transaction.isPending ? Colors.amber.shade900 : Colors.red.shade700);

    return Container(
      key: const Key('verified_transaction_box'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado confirmado (Sandbox): ${transaction.status}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          if (transaction.paymentMethodType != null)
            Text('Método: ${transaction.paymentMethodType}'),
          if (transaction.statusMessage != null &&
              transaction.statusMessage!.isNotEmpty)
            Text('Detalle: ${transaction.statusMessage}'),
          if (transaction.finalizedAt != null)
            Text('Finalizado: ${transaction.finalizedAt}'),
        ],
      ),
    );
  }
}

class _AdvancedSettingsSheet extends StatefulWidget {
  const _AdvancedSettingsSheet({required this.viewModel});

  final CheckoutViewModel viewModel;

  @override
  State<_AdvancedSettingsSheet> createState() => _AdvancedSettingsSheetState();
}

class _AdvancedSettingsSheetState extends State<_AdvancedSettingsSheet> {
  late final TextEditingController _publicKeyController;
  late final TextEditingController _integritySecretController;
  late final TextEditingController _precomputedSignatureController;
  late final TextEditingController _sandboxPrivateKeyController;
  late final TextEditingController _redirectUrlController;

  @override
  void initState() {
    super.initState();
    final vm = widget.viewModel;
    _publicKeyController = TextEditingController(text: vm.publicKey);
    _integritySecretController = TextEditingController(
      text: vm.integritySecret,
    );
    _precomputedSignatureController = TextEditingController(
      text: vm.precomputedSignature,
    );
    _sandboxPrivateKeyController = TextEditingController(
      text: vm.sandboxPrivateKey,
    );
    _redirectUrlController = TextEditingController(text: vm.redirectUrl);
  }

  @override
  void dispose() {
    _publicKeyController.dispose();
    _integritySecretController.dispose();
    _precomputedSignatureController.dispose();
    _sandboxPrivateKeyController.dispose();
    _redirectUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configuración técnica de Wompi',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('public_key_field'),
                  controller: _publicKeyController,
                  onChanged: vm.updatePublicKey,
                  decoration: const InputDecoration(
                    labelText: 'Llave pública (public-key)',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<WompiSignatureMode>(
                  segments: const [
                    ButtonSegment<WompiSignatureMode>(
                      value: WompiSignatureMode.localSandboxSecret,
                      label: Text('Sandbox local'),
                      icon: Icon(Icons.science_outlined),
                    ),
                    ButtonSegment<WompiSignatureMode>(
                      value: WompiSignatureMode.backendPrecomputed,
                      label: Text('Firma backend'),
                      icon: Icon(Icons.verified_user_outlined),
                    ),
                  ],
                  selected: {vm.signatureMode},
                  onSelectionChanged: (selection) =>
                      vm.setSignatureMode(selection.first),
                ),
                const SizedBox(height: 12),
                if (vm.signatureMode == WompiSignatureMode.localSandboxSecret)
                  TextField(
                    key: const Key('integrity_secret_field'),
                    controller: _integritySecretController,
                    onChanged: vm.updateIntegritySecret,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Secreto de integridad (Sandbox)',
                    ),
                  )
                else
                  TextField(
                    key: const Key('precomputed_signature_field'),
                    controller: _precomputedSignatureController,
                    onChanged: vm.updatePrecomputedSignature,
                    decoration: const InputDecoration(
                      labelText: 'Firma SHA-256 (signature:integrity)',
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('sandbox_private_key_field'),
                  controller: _sandboxPrivateKeyController,
                  onChanged: vm.updateSandboxPrivateKey,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Llave privada Sandbox (prv_test_...)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('redirect_url_field'),
                  controller: _redirectUrlController,
                  onChanged: vm.updateRedirectUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL de redirección (redirect-url HTTPS)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Listo'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
