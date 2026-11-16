## 0.1.0

* Initial release of `wompi_webview`.
* Built-in `WompiCheckoutPage` and `WompiCheckout.open` powered by `webview_flutter`.
* Signed checkout URL builder (`WompiCheckoutUrlBuilder`) with support for Colombia and Panama regions.
* Security guards enforcing `WompiConfig.backendSigned` for production and preventing `prod_integrity_` / `prv_prod_` keys on the client.
* Automatic `redirect-url` interception and `WompiPaymentResult` parsing.
* Optional `WompiSandboxVerificationService` for confirming Sandbox test transactions (`prv_test_...` only).
