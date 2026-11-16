# wompi_webview

Paquete Flutter para integrar **Wompi Web Checkout** (`checkout.wompi.co` / `checkout.wompi.pa`) dentro de un `WebView` nativo con `webview_flutter`, incluyendo:

- Pantalla lista para usar (`WompiCheckoutPage` y `WompiCheckout.open`).
- Construcción de URL firmada (`signature:integrity` SHA-256) para Colombia y Panamá.
- Interceptación automática de `redirect-url` devolviendo `WompiPaymentResult` con el `transactionId`.
- Reglas de seguridad integradas (solo navegación HTTPS en WebView, `redirect-url` HTTPS, bloqueo de esquemas peligrosos y prevención de llaves de producción en cliente).
- Servicio opcional `WompiSandboxVerificationService` para confirmar pagos de prueba (`prv_test_...`).

## Instalación

```yaml
dependencies:
  wompi_webview:
    git:
      url: https://github.com/SantiagoPH34/wompi_webview.git
```

En Android asegúrate de tener permiso de internet en `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Flujo completo de pagos en producción (End-to-End)

`wompi_webview` cubre el **lado cliente en Flutter** (WebView seguro + interceptación de `redirect-url`). En producción, la firma de integridad y la confirmación real del dinero deben ocurrir en tu backend:

```text
[1] App Flutter ──(solicita pago)──────────────────────▶ [Tu Backend]
    App Flutter ◀─(reference + signature:integrity)─────  (calcula SHA-256 con prod_integrity_)

[2] App Flutter abre WompiCheckout.open(...) con WompiConfig.backendSigned
    Usuario paga en WebView ──▶ WebView intercepta redirect-url?id=TRANS_ID
    App Flutter recibe WompiPaymentResult(transactionId: "TRANS_ID")

[3] Wompi ─────────(Webhook POST transaction.updated)──▶ [Tu Backend]
                    (valida signature.checksum con        actualiza la orden en BD
                     prod_events_ y marca APPROVED)       a APPROVED / DECLINED

[4] App Flutter ──(consulta estado de la orden)────────▶ [Tu Backend]
    App Flutter ◀─(estado confirmado desde tu BD)────────
```

1. **Tu backend firma:** Crea la orden en estado `PENDING` y genera `signature:integrity` con `prod_integrity_...`.
2. **La app abre el WebView:** Usa `WompiConfig.backendSigned` y recibe el `transactionId` al interceptar `redirect-url`.
3. **Wompi notifica por Webhook:** Tu servidor valida el evento (`signature.checksum` / `X-Event-Checksum`) usando `prod_events_...` y actualiza la orden en tu base de datos.
4. **La app confirma con tu backend:** Consulta el estado final de la orden en tu propio servidor (nunca usando `prv_prod_...` desde Flutter).

## Uso en producción (firma generada por tu backend)

En producción **nunca** incluyas `prod_integrity_...` ni `prv_prod_...` en la app Flutter. Tu backend debe calcular `signature:integrity` y entregárselo a la app:

```dart
final result = await WompiCheckout.open(
  context,
  config: WompiConfig.backendSigned(
    publicKey: 'pub_prod_tu_llave_publica',
    redirectUrl: 'https://tu-tienda.com/wompi/resultado',
    signatureIntegrity: firmaGeneradaPorTuBackend,
  ),
  request: const WompiCheckoutRequest(
    reference: 'ORD-10023',
    amountInCents: 5000000,
    customerData: WompiCustomerData(
      email: 'cliente@correo.com',
      fullName: 'Ana Pérez',
    ),
  ),
);

if (result?.outcome == WompiWebViewOutcome.redirected) {
  // Envía result?.transactionId a tu backend para confirmar el estado real
  // vía Webhooks (X-Event-Checksum) o GET /v1/transactions/{id}.
}
```

## Uso en pruebas Sandbox

```dart
final config = WompiConfig.sandboxLocal(
  publicKey: 'pub_test_...',
  redirectUrl: 'https://checkout.example.com/wompi/resultado',
  integritySecret: 'test_integrity_...',
);
```

`WompiConfig.sandboxLocal` lanza `ArgumentError` si intentas pasar `pub_prod_...` o `prod_integrity_...`.

## Medidas de seguridad implementadas

1. **Separación de llaves:** `WompiConfig.backendSigned` es el modo recomendado para producción; `WompiConfig.sandboxLocal` y `WompiSandboxVerificationService` rechazan llaves `pub_prod_`, `prod_integrity_` y `prv_prod_`.
2. **Navegación restringida en WebView:** Solo se permite tráfico `https://`, `about:blank` y el `redirect-url` configurado; se bloquean `http://` externos, `javascript:`, `file://`, `content://` y esquemas personalizados (`intent://`, etc.).
3. **`redirect-url` segura:** Exige `https://` (solo admite `http://` en `localhost` o `127.0.0.1` durante desarrollo).
4. **Sanitización de `transactionId`:** `WompiSandboxVerificationService` valida el formato del ID antes de construir la URL de consulta.
5. **Sin secretos en Git:** El proyecto incluye `.gitignore` para `*.local.json` y `wompi_sandbox.local.json`.

## Ejecutar la app de ejemplo (`example/`)

```bash
cd example
flutter pub get
flutter run -d macos --dart-define-from-file=wompi_sandbox.local.json
```

*(Copia `example/wompi_sandbox.example.json` a `example/wompi_sandbox.local.json` si estás clonando el repositorio desde cero).*
