/// Optional payer details pre-filled in Wompi Web Checkout.
class WompiCustomerData {
  /// Creates optional customer information for Wompi Web Checkout.
  const WompiCustomerData({
    this.email,
    this.fullName,
    this.phoneNumber,
    this.phoneNumberPrefix = '+57',
    this.legalId,
    this.legalIdType,
  });

  /// Customer email address.
  final String? email;

  /// Customer full name.
  final String? fullName;

  /// Customer local phone number without country code.
  final String? phoneNumber;

  /// International dialing prefix (defaults to `+57`).
  final String? phoneNumberPrefix;

  /// National identification number.
  final String? legalId;

  /// Identification document type (e.g. `CC`, `CE`, `NIT`, `PP`).
  final String? legalIdType;
}

/// Transaction payload required to open Wompi Web Checkout.
class WompiCheckoutRequest {
  /// Creates a checkout request for a unique [reference] and [amountInCents].
  const WompiCheckoutRequest({
    required this.reference,
    required this.amountInCents,
    this.customerData,
  });

  /// Unique merchant order reference for this payment attempt.
  final String reference;

  /// Total amount in cents (for example, `5000000` represents 50,000.00 COP).
  final int amountInCents;

  /// Optional customer fields pre-filled in Wompi's checkout form.
  final WompiCustomerData? customerData;
}
