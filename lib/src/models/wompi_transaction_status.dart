/// Transaction status returned by Wompi's `/v1/transactions/{id}` endpoint.
class WompiTransactionStatus {
  /// Creates a [WompiTransactionStatus] instance.
  const WompiTransactionStatus({
    required this.id,
    required this.status,
    required this.reference,
    required this.amountInCents,
    required this.currency,
    this.paymentMethodType,
    this.statusMessage,
    this.finalizedAt,
  });

  /// Parses a transaction payload returned by Wompi's REST API.
  factory WompiTransactionStatus.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return WompiTransactionStatus(
      id: (data['id'] ?? '').toString(),
      status: (data['status'] ?? 'UNKNOWN').toString(),
      reference: (data['reference'] ?? '').toString(),
      amountInCents: (data['amount_in_cents'] as num?)?.toInt() ?? 0,
      currency: (data['currency'] ?? 'COP').toString(),
      paymentMethodType: data['payment_method_type']?.toString(),
      statusMessage: data['status_message']?.toString(),
      finalizedAt: data['finalized_at']?.toString(),
    );
  }

  /// Unique Wompi transaction identifier.
  final String id;

  /// Transaction status (e.g. `APPROVED`, `DECLINED`, `PENDING`, `ERROR`, `VOIDED`).
  final String status;

  /// Merchant reference associated with this transaction.
  final String reference;

  /// Transaction amount in cents.
  final int amountInCents;

  /// ISO 4217 currency code.
  final String currency;

  /// Payment method used (e.g. `CARD`, `NEQUI`, `PSE`, `BANCOLOMBIA_TRANSFER`).
  final String? paymentMethodType;

  /// Optional status detail returned by Wompi or the processor.
  final String? statusMessage;

  /// ISO-8601 timestamp when the transaction reached a final state.
  final String? finalizedAt;

  /// Whether the transaction was approved (`APPROVED`).
  bool get isApproved => status.toUpperCase() == 'APPROVED';

  /// Whether the transaction is still pending confirmation (`PENDING`).
  bool get isPending => status.toUpperCase() == 'PENDING';
}
