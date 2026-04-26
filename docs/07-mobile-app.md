---
name: 07-mobile-app
description: Flutter Android app — project layout, packages, screens, state machine, HCE service, key generation, offline queue, two-tap merchant-initiated payment flow
owner: Mobile
status: ready
depends-on: [02-user-flows, 03-token-protocol, 04-credit-score-ml]
last-updated: 2026-04-25
---

# Mobile App (Flutter, Android-first)

## 1. Toolchain

- Flutter `>=3.24` stable.
- Dart `>=3.5`.
- Android: `minSdkVersion 26` (HCE), `targetSdkVersion 34`.
- Kotlin `1.9` for the HCE service.

## 2. Project layout

```
mobile/
├── pubspec.yaml
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml
│   │   │   ├── kotlin/com/tng/finhack/
│   │   │   │   ├── MainActivity.kt
│   │   │   │   ├── hce/TngHostApduService.kt
│   │   │   │   ├── hce/ApduHandler.kt
│   │   │   │   ├── hce/PaymentRequestHandler.kt   # NEW: handles tap-1 incoming requests
│   │   │   │   ├── keystore/SigningKeyManager.kt
│   │   │   │   └── nfc/NfcReader.kt
│   │   │   └── res/xml/apduservice.xml         # AID + HCE config
│   │   └── build.gradle
│   └── build.gradle
├── lib/
│   ├── main.dart
│   ├── app.dart                                 # MaterialApp + routing
│   ├── core/
│   │   ├── theme/
│   │   ├── di/                                  # riverpod providers
│   │   ├── connectivity/connectivity_service.dart
│   │   ├── crypto/jws_signer.dart
│   │   ├── crypto/native_keystore.dart          # MethodChannel to Kotlin
│   │   ├── nfc/nfc_session.dart                 # high-level NFC API (reader side)
│   │   ├── nfc/payment_request.dart             # NEW: payment request model + parser
│   │   └── result.dart
│   ├── data/
│   │   ├── api/                                 # dio clients per resource
│   │   ├── api/wallet_api.dart
│   │   ├── api/devices_api.dart
│   │   ├── api/tokens_api.dart
│   │   ├── api/score_api.dart
│   │   ├── db/                                  # drift schemas
│   │   ├── db/app_db.dart
│   │   ├── db/outbox_dao.dart
│   │   ├── db/inbox_dao.dart
│   │   ├── db/balance_cache_dao.dart
│   │   └── ml/
│   │       └── credit_scorer.dart               # tflite_flutter wrapper
│   ├── domain/
│   │   ├── models/token.dart
│   │   ├── models/wallet.dart
│   │   ├── models/policy.dart
│   │   ├── models/payment_request.dart          # NEW: PaymentRequest domain model
│   │   └── usecases/
│   │       ├── pay_offline.dart
│   │       ├── request_payment.dart             # NEW: merchant builds + sends request
│   │       ├── receive_offline.dart
│   │       ├── settle_pending.dart
│   │       └── refresh_score.dart
│   └── features/
│       ├── splash/
│       ├── onboarding/
│       ├── home/
│       ├── pay/
│       │   ├── pay_screen.dart                  # payer: shows incoming request + confirm
│       │   └── pay_confirm_screen.dart          # biometric confirm before tap 2
│       ├── request/                             # NEW: merchant request flow
│       │   ├── request_screen.dart              # enter amount, tap to send
│       │   └── request_pending_screen.dart      # waiting for Faiz to tap back
│       ├── receive/
│       │   └── receive_screen.dart              # post-settlement receipt view
│       ├── pending/
│       ├── history/
│       ├── score/
│       └── settings/
└── assets/
    ├── models/credit-v1.tflite
    ├── images/
    └── fonts/
```

## 3. Package list (`pubspec.yaml` excerpt)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.0.0
  dio: ^5.4.3
  retrofit: ^4.1.0
  drift: ^2.18.0
  drift_flutter: ^0.1.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.3
  flutter_secure_storage: ^9.2.0
  cryptography: ^2.7.0           # Ed25519 helpers (verify side; signing via Keystore)
  tflite_flutter: ^0.10.4
  flutter_nfc_kit: ^3.5.0        # for reader-mode + APDU send
  connectivity_plus: ^6.0.3
  local_auth: ^2.2.0             # biometric prompts
  intl: ^0.19.0
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  uuid: ^4.4.0

dev_dependencies:
  build_runner: ^2.4.10
  drift_dev: ^2.18.0
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  retrofit_generator: ^8.1.0
  mocktail: ^1.0.3
  flutter_test:
    sdk: flutter
```

## 4. Android manifest excerpts

```xml
<uses-permission android:name="android.permission.NFC"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-feature android:name="android.hardware.nfc.hce" android:required="true"/>

<service
    android:name=".hce.TngHostApduService"
    android:exported="true"
    android:permission="android.permission.BIND_NFC_SERVICE">
  <intent-filter>
    <action android:name="android.nfc.cardemulation.action.HOST_APDU_SERVICE"/>
  </intent-filter>
  <meta-data
      android:name="android.nfc.cardemulation.host_apdu_service"
      android:resource="@xml/apduservice"/>
</service>
```

`res/xml/apduservice.xml`:
```xml
<host-apdu-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/tng_aid_label"
    android:requireDeviceUnlock="false">
    <aid-group android:description="@string/tng_aid_group" android:category="other">
        <aid-filter android:name="F0544E47504159"/>  <!-- canonical AID, see docs/03-token-protocol.md §5.1 -->
    </aid-group>
</host-apdu-service>
```

## 5. State machine — connectivity

```
       ┌────────────┐
       │  ONLINE    │◀────────── network back, sync OK
       │            │
       └─────┬──────┘
             │ network lost OR sync 3x fail
             ▼
       ┌────────────┐
       │  STALE     │  (cache 0–10 min)
       │  (tier 1)  │  show synced balance, "Online · synced N min"
       └─────┬──────┘
             │ 10 min reached
             ▼
       ┌────────────┐
       │  OFFLINE   │  (cache > 10 min OR no network)
       │            │  show safe_offline_balance from TF Lite
       └────────────┘
```

Driven by `ConnectivityService` + a periodic `BalanceSyncWorker` (WorkManager via
`flutter_workmanager`) every 10 minutes when online.

## 6. State machine — payer NFC flow (Faiz)

```
       ┌──────────────────────┐
       │  IDLE                │  Home screen, HCE active in background
       └──────────┬───────────┘
                  │ incoming tap-1 (PUT-REQUEST APDU detected by HCE)
                  ▼
       ┌──────────────────────┐
       │  REQUEST_RECEIVED    │  Pay confirm screen shown automatically
       │                      │  "Pay RM 8.50 to Aida Stall?"
       └──────────┬───────────┘
                  │ user authorizes biometric / PIN
                  ▼
       ┌──────────────────────┐
       │  BIOMETRIC_CLEARED   │  JWS built and held in memory
       │                      │  "Tap phone to Aida to complete payment"
       └──────────┬───────────┘
                  │ tap-2 NFC session opened (Faiz enters reader mode)
                  ▼
       ┌──────────────────────┐
       │  TAP2_IN_PROGRESS    │  JWS chunks sent; waiting for ack
       └──────────┬───────────┘
                  │ ack-signature received
                  ▼
       ┌──────────────────────┐
       │  PAYMENT_SENT        │  Outbox written; receipt shown; balance updated
       └──────────────────────┘
```

User can cancel at `REQUEST_RECEIVED` or `BIOMETRIC_CLEARED` — cancellation
discards the payment request and returns to IDLE. A 5-minute expiry on the
payment request also auto-returns to IDLE if Faiz does not complete tap 2.

## 7. NFC integration — two-tap merchant-initiated flow

The payment flow is **merchant-initiated**. Two NFC sessions occur with swapped roles.

### 7.1 Role overview

| Tap | Aida's role | Faiz's role | What moves |
|---|---|---|---|
| Tap 1 | Reader | HCE card | Payment request JSON (Aida → Faiz) |
| Tap 2 | HCE card | Reader | JWS payment token (Faiz → Aida) + ack-sig back |

Both phones always run `TngHostApduService` in the background. Role switching happens
at the app layer by which screen is open and which APDU instruction byte is issued.

### 7.2 Tap 1 implementation — Aida (reader), Faiz (HCE)

**Aida side** (`NfcSession.sendPaymentRequest()` in `nfc_session.dart`):
```dart
Future<Result<String>> sendPaymentRequest(PaymentRequest request) async {
  final session = await FlutterNfcKit.poll(timeout: const Duration(seconds: 30));
  // SELECT AID → get Faiz's pub from response
  final selectResp = await FlutterNfcKit.transceive(
    '00A404000'7F0544E47504159'00');
  final payerPub = selectResp.substring(0, 64);  // 32 bytes hex

  // Serialize and chunk the payment request JSON
  final requestBytes = utf8.encode(jsonEncode(request.toJson()));
  await _sendChunks(requestBytes, instructionByte: 0xE0); // PUT-REQUEST

  await FlutterNfcKit.finish();
  return Result.ok(payerPub);
}
```

**Faiz side** — `TngHostApduService.kt` handles via HCE:
```kotlin
// On SELECT AID: return Faiz's pub immediately, no user action needed
override fun processCommandApdu(apdu: ByteArray, extras: Bundle?): ByteArray {
    if (isSelectAid(apdu)) {
        val pub = signingKeyManager.getPublicKey()
        return pub + byteArrayOf(0x90.toByte(), 0x00)
    }
    return when (apdu[1]) {
        0xE0.toByte() -> handlePutRequest(apdu)  // tap 1: incoming payment request
        0xD0.toByte() -> handlePutData(apdu)      // tap 2: incoming JWS
        0xC0.toByte() -> handleGetAck(apdu)       // tap 2: ack request
        else -> byteArrayOf(0x6D.toByte(), 0x00)  // unsupported
    }
}

private fun handlePutRequest(apdu: ByteArray): ByteArray {
    requestBuffer.append(apdu)
    if (isLastChunk(apdu)) {
        val request = PaymentRequest.parse(requestBuffer.toBytes())
        requestBuffer.clear()
        // Notify Flutter layer via EventChannel
        paymentRequestEventSink?.success(request.toMap())
    }
    return byteArrayOf(0x90.toByte(), 0x00)
}
```

`PaymentRequestHandler` fires a Flutter `EventChannel` event that the Riverpod
`paymentRequestProvider` listens to. The provider triggers navigation to the Pay
confirm screen automatically.

### 7.3 Tap 2 implementation — Faiz (reader), Aida (HCE)

Only triggered after biometric is cleared. The JWS is pre-built from the payment
request data received in tap 1.

**Faiz side** (`PayOffline` use case drives this):
```dart
Future<Result<OutboxRow>> executeAfterBiometric(
    PaymentRequest request, String payerPub) async {
  // JWS was already built and signed after biometric cleared
  final jws = state.pendingJws!;

  final session = await FlutterNfcKit.poll(timeout: const Duration(seconds: 30));
  // SELECT AID → verify Aida's pub matches what we got in tap 1
  final selectResp = await FlutterNfcKit.transceive(selectAidApdu);
  final confirmedReceiverPub = selectResp.substring(0, 64);
  if (confirmedReceiverPub != request.receiver.pubHex) {
    await FlutterNfcKit.finish(iosAlertMessage: 'Device mismatch');
    return Result.error(ReceiverMismatch());
  }

  // Send JWS chunks
  await _sendChunks(utf8.encode(jws), instructionByte: 0xD0); // PUT-DATA

  // Request ack-signature
  final ackResp = await FlutterNfcKit.transceive('80C0000040');
  final ackSig = ackResp.substring(0, 128); // 64 bytes hex
  await FlutterNfcKit.finish();

  final row = OutboxRow(jws: jws, ackSig: ackSig,
      status: TxStatus.pendingSettlement, ...);
  await outboxDao.insert(row);
  state.decrementSafeBalance(request.amountCents);
  return Result.ok(row);
}
```

**Aida side** — `TngHostApduService.kt` `handlePutData` / `handleGetAck`:
```kotlin
private fun handlePutData(apdu: ByteArray): ByteArray {
    jwsBuffer.append(apdu)
    return if (isLastChunk(apdu)) byteArrayOf(0x90.toByte(), 0x01)
    else byteArrayOf(0x90.toByte(), 0x00)
}

private fun handleGetAck(apdu: ByteArray): ByteArray {
    val jws = jwsBuffer.toBytes()
    jwsBuffer.clear()
    // Notify Flutter of incoming JWS
    incomingJwsEventSink?.success(mapOf("jws" to Base64.encode(jws)))
    // Sign sha256(jws) with own key as ack
    val ackSig = signingKeyManager.sign(sha256(jws))
    return ackSig + byteArrayOf(0x90.toByte(), 0x00)
}
```

### 7.4 Between-tap window

After tap 1, Faiz's app shows the confirmation screen. The window between tap 1 and
tap 2 has **no NFC session open** — both phones are idle. Faiz uses this time to:
1. Review the amount and merchant name.
2. Authorize with biometric.
3. The JWS is signed during this window (Android Keystore call, ~5ms).

Aida's app shows "Request sent — waiting for Faiz to complete payment" with a
5-minute countdown. If the countdown expires, Aida can re-send the request (new
`request_id`, new `issued_at`).

## 8. Signing key — generation flow

Kotlin `SigningKeyManager.kt`:
```kotlin
fun ensureKey(): String {
  val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
  if (ks.containsAlias(ALIAS)) return ALIAS

  val spec = KeyGenParameterSpec.Builder(
        ALIAS,
        KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
    .setAlgorithmParameterSpec(ECGenParameterSpec("ed25519")) // API 33+ required
    .setDigests(KeyProperties.DIGEST_NONE)
    .setUserAuthenticationRequired(true)
    .setIsStrongBoxBacked(supportsStrongBox(context))
    .setAttestationChallenge(serverChallenge.toByteArray())
    .build()

  val gen = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
  gen.initialize(spec)
  gen.generateKeyPair()
  return ALIAS
}

fun sign(data: ByteArray): ByteArray {
  val key = (KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
              .getKey(ALIAS, null)) as PrivateKey
  return Signature.getInstance("Ed25519").run {
    initSign(key); update(data); sign()
  }
}

fun getPublicKey(): ByteArray {
  val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
  val cert = ks.getCertificate(ALIAS)
  // Return raw 32-byte Ed25519 public key
  return (cert.publicKey as BCEdDSAPublicKey).pointEncoding
}
```

> **Note:** Android Keystore Ed25519 support: API 33+. v1 is **EdDSA-only** —
> pre-API-33 devices are not supported in v1 (fail-closed at onboarding). For
> the demo, target Pixel devices on Android 14+.

Flutter side `native_keystore.dart` exposes:
- `Future<String> ensureKey()` → returns `kid`.
- `Future<Uint8List> sign(Uint8List data)`.
- `Future<Uint8List> getPublicKey()`.
- `Future<Uint8List> getAttestationChain()`.

## 9. Drift schema (offline outbox/inbox)

```dart
@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get txId => text()();
  TextColumn get jws => text()();
  IntColumn get amountCents => integer()();
  TextColumn get receiverKid => text()();
  IntColumn get createdAt => integer()();
  IntColumn get status => intEnum<TxStatus>()(); // PENDING_NFC, PENDING_SETTLEMENT, SETTLED, REJECTED
  TextColumn get rejectReason => text().nullable()();
  TextColumn get ackSig => text().nullable()();
  @override Set<Column> get primaryKey => {txId};
}

@DataClassName('InboxRow')
class Inbox extends Table {
  TextColumn get txId => text()();
  TextColumn get jws => text()();
  IntColumn get amountCents => integer()();
  TextColumn get senderKid => text()();
  IntColumn get receivedAt => integer()();
  IntColumn get status => intEnum<TxStatus>()();
  @override Set<Column> get primaryKey => {txId};
}

@DataClassName('BalanceCacheRow')
class BalanceCache extends Table {
  TextColumn get userId => text()();
  IntColumn get balanceCents => integer()();
  IntColumn get safeOfflineCents => integer()();
  IntColumn get syncedAt => integer()();
  TextColumn get policyVersion => text()();
  @override Set<Column> get primaryKey => {userId};
}
```

DB file lives in `getApplicationDocumentsDirectory()`. SQLCipher *not* used in MVP
(token bodies are already cryptographically authenticated; balances are
non-sensitive cache).

## 10. Use cases (domain)

### `request_payment.dart` (Aida's side — NEW)
```dart
class RequestPayment {
  Future<Result<PaymentRequest>> call({
    required int amountCents,
    required String memo,
  }) async {
    final myPub = await nativeKeystore.getPublicKey();
    final myKid = await nativeKeystore.ensureKey();
    final request = PaymentRequest(
      requestId: UuidV7.generate(),
      receiver: ReceiverInfo(kid: myKid, pub: myPub, displayName: profile.displayName),
      amountCents: amountCents,
      memo: memo,
      issuedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      expiresAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 300, // 5 min
    );
    final payerPub = await nfcSession.sendPaymentRequest(request);
    // payerPub is stored temporarily; used to verify tap-2 SELECT response
    state.setPendingPayerPub(payerPub);
    return Result.ok(request);
  }
}
```

### `pay_offline.dart` (Faiz's side — updated)

Two-stage: first stage handles the incoming request (called by HCE event); second stage
executes after biometric.

```dart
class PayOffline {
  // Stage 1: called when HCE receives payment request (tap 1)
  void onPaymentRequestReceived(PaymentRequest request) {
    if (request.amountCents > state.safeOfflineBalanceCents) {
      state.setError(InsufficientSafeBalance());
      return;
    }
    if (request.expiresAt < nowSeconds()) {
      state.setError(PaymentRequestExpired());
      return;
    }
    state.setPendingRequest(request);
    // Navigation to confirm screen is triggered here
    router.push('/pay/confirm', extra: request);
  }

  // Stage 2: called after biometric cleared on confirm screen
  Future<Result<OutboxRow>> executePayment() async {
    final request = state.pendingRequest!;
    // Build JWS now — Keystore sign happens here
    final payload = buildPayload(request);
    final jws = await jwsSigner.sign(payload); // Keystore sign (biometric already cleared)
    state.setPendingJws(jws);

    // Tap 2: Faiz enters reader mode to deliver JWS
    return _executeTap2(request, jws);
  }

  Future<Result<OutboxRow>> _executeTap2(PaymentRequest request, String jws) async {
    final ackSig = await nfcSession.sendJws(jws,
        expectedReceiverPub: request.receiver.pubHex,
        timeout: const Duration(seconds: 30));
    final row = OutboxRow(jws: jws, ackSig: ackSig,
        status: TxStatus.pendingSettlement, ...);
    await outboxDao.insert(row);
    state.decrementSafeBalance(request.amountCents);
    state.clearPending();
    return Result.ok(row);
  }
}
```

### `settle_pending.dart`
Background worker invoked on connectivity-on or every 60s while online:
```dart
final batch = await outboxDao.takePending(limit: 50);
final res = await tokensApi.settle(batch);
await outboxDao.applyResults(res);
notifications.showSettlementResults(res);
```

## 11. UX details to honor

- Offline indicator must be visible **above** balance card (the inclusion wedge).
- Safe offline balance always shows even when online — sets the user's *expectation*.
- Receipts must be viewable offline; saved JWS = the receipt.
- Pending tokens listed with sender/receiver `kid` shorthand: last 4 chars in
  monospace tag.
- Color: TNG brand blue (`#0061A8`), but offline state shifts to muted/grey to set
  expectation; don't use red (alarming) for "offline" — it's a feature.
- The **pay confirm screen** (after tap 1) must show: merchant name, amount in large
  type, memo/item description, and the biometric prompt. Cancel is always visible.
- Aida's "Request sent" waiting screen shows a countdown timer and a resend button.

## 12. Build & run

```bash
cd mobile/
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d <android-device-id>
```

For the two-phone demo, install on two Pixel devices. NFC must be enabled on both.
Assign one device as "merchant" (Aida) and one as "payer" (Faiz) — the roles are
determined by which screen the user opens, not by device configuration.

## 13. Testing

- Widget tests for each screen — state-driven golden tests for online/offline
  variants, including the pay confirm screen.
- Unit tests for `request_payment` / `pay_offline` / `settle_pending` use cases
  with mocked NFC + API.
- Integration test on real device: tap-1 scripted via ADB to inject a payment
  request event into the HCE channel; verify confirm screen appears; approve
  biometric; tap-2 scripted to deliver JWS; verify inbox/outbox rows.

See [docs/11-demo-and-test-plan.md](11-demo-and-test-plan.md).

## 14. Known constraints

- Android Keystore Ed25519: API 33+. **Demo decision:** EdDSA-only; older devices are
  out-of-scope for v1 and the app refuses onboarding on API < 33 (clear "device not
  supported" page).
- HCE on Android requires NFC chip + lockscreen unlocked OR `requireDeviceUnlock=false`
  in service config (we set false to enable taps from lock screen for hawker speed).
- Cannot run two HCE services with the same AID; uninstall any prior TNG dev build
  before installing demo build.
- The HCE service must handle both instruction bytes (`0xE0` for payment requests,
  `0xD0` for JWS) within the same service class. The service must not assume which
  role the phone is playing — it responds to whichever instruction arrives.
- Between tap 1 and tap 2 there is no NFC session. The pending JWS is held in
  `PayOffline` state and survives app backgrounding via a Riverpod `keepAlive` provider.
  If the app is killed between taps, the JWS is lost and tap 2 must be restarted.
