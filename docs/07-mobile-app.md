---
name: 07-mobile-app
description: Flutter Android app — project layout, packages, screens, state machine, HCE service, key generation, offline queue
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
│   │   ├── nfc/nfc_session.dart                 # high-level NFC API
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
│   │   └── usecases/
│   │       ├── pay_offline.dart
│   │       ├── receive_offline.dart
│   │       ├── settle_pending.dart
│   │       └── refresh_score.dart
│   └── features/
│       ├── splash/
│       ├── onboarding/
│       ├── home/
│       ├── pay/
│       ├── receive/
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

## 6. Signing key — generation flow

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
```

> **Note:** Android Keystore Ed25519 support: API 33+. v1 is **EdDSA-only** —
> pre-API-33 devices are not supported in v1 (fail-closed at onboarding). For
> the demo, target Pixel devices on Android 14+.

Flutter side `native_keystore.dart` exposes:
- `Future<String> ensureKey()` → returns `kid`.
- `Future<Uint8List> sign(Uint8List data)`.
- `Future<Uint8List> getPublicKey()`.
- `Future<Uint8List> getAttestationChain()`.

## 7. NFC integration

Two roles per app instance, switched by the active screen:
- **Sender**: uses `flutter_nfc_kit` reader mode → SELECT-AID against peer's HCE,
  pushes JWS chunks.
- **Receiver**: HCE service handles APDUs in Kotlin, returns `receiver_pub`, accepts
  chunks, verifies, returns ack.

`hce/TngHostApduService.kt` keeps state per session (chunk reassembly buffer); state
purges on `onDeactivated`.

`nfc/nfc_session.dart` (Dart) wraps the sender side with timeouts + retry counts.

## 8. Drift schema (offline outbox/inbox)

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

## 9. Use cases (domain)

### `pay_offline.dart`
```dart
class PayOffline {
  Future<Result<OutboxRow>> call({
    required int amountCents,
    required Duration tapTimeout,
  }) async {
    if (amountCents > state.safeOfflineBalanceCents) {
      return Result.error(InsufficientSafeBalance());
    }
    final receiverPub = await nfc.selectAid();         // phase A+B
    final payload = buildPayload(amountCents, receiverPub);
    final jws = await jwsSigner.sign(payload);          // Keystore sign
    final ack = await nfc.sendChunks(jws, timeout: tapTimeout);
    final row = OutboxRow(jws: jws, ackSig: ack, status: PENDING_SETTLEMENT, ...);
    await outboxDao.insert(row);
    state.decrementSafeBalance(amountCents);
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

## 10. UX details to honor

- Offline indicator must be visible **above** balance card (the inclusion wedge).
- Safe offline balance always shows even when online — sets the user's *expectation*.
- Receipts must be viewable offline; saved JWS = the receipt.
- Pending tokens listed with sender/receiver `kid` shorthand: last 4 chars in
  monospace tag.
- Color: TNG brand blue (`#0061A8`), but offline state shifts to muted/grey to set
  expectation; don't use red (alarming) for "offline" — it's a feature.

## 11. Build & run

```bash
cd mobile/
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d <android-device-id>
```

For the two-phone demo, install on two Pixel devices. NFC must be enabled on both.

## 12. Testing

- Widget tests for each screen — state-driven golden tests for online/offline
  variants.
- Unit tests for `pay_offline` / `settle_pending` use cases with mocked NFC + API.
- Integration test on real device: NFC peer pair scripted via ADB to enter pay/receive
  modes; one phone airplane-mode toggled mid-test.

See [docs/11-demo-and-test-plan.md](11-demo-and-test-plan.md).

## 13. Known constraints

- Android Keystore Ed25519: API 33+. **Demo decision:** EdDSA-only; older devices are
  out-of-scope for v1 and the app refuses onboarding on API < 33 (clear "device not
  supported" page). Pre-API-33 device coverage is a v1.1 work item — would require
  introducing ES256 support across protocol, server verifier, and test vectors.
- HCE on Android requires NFC chip + lockscreen unlocked OR `requireDeviceUnlock=false`
  in service config (we set false to enable taps from lock screen for hawker speed).
- Cannot run two HCE services with the same AID; uninstall any prior TNG dev build
  before installing demo build.
