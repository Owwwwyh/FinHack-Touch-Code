import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tng_clone_flutter/app/app.dart';
import 'package:tng_clone_flutter/core/crypto/device_identity_service.dart';
import 'package:tng_clone_flutter/core/nfc/offline_nfc_bridge.dart';
import 'package:tng_clone_flutter/domain/models/payment_request.dart';
import 'package:tng_clone_flutter/domain/services/offline_pay_policy.dart';
import 'package:tng_clone_flutter/features/offline/offline_payment_controller.dart';

void main() {
  late FakeOfflineNfcBridge bridge;
  late FakeSigningService signingService;

  setUp(() {
    bridge = FakeOfflineNfcBridge();
    signingService = FakeSigningService();
  });

  tearDown(() {
    bridge.dispose();
  });

  testWidgets('App renders splash then onboarding',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(bridge, signingService));

    expect(find.text('Initializing offline wallet'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('Offline Wallet Setup'), findsOneWidget);
    expect(find.text('Continue to Home'), findsOneWidget);
  });

  testWidgets('Home screen shows Day 2 request and inbox actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(bridge, signingService));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Request Payment'), 200);

    expect(find.text('Offline Wallet Home'), findsOneWidget);
    expect(find.text('Latest cached balance'), findsOneWidget);
    expect(find.text('AI SAFE BALANCE'), findsOneWidget);
    expect(find.text('Get latest balance'), findsOneWidget);
    expect(find.text('Request Payment'), findsOneWidget);
    expect(find.text('Receive Inbox'), findsOneWidget);
    expect(find.text('RM 120.00'), findsWidgets);
  });

  testWidgets('Home screen flips to offline state and shows safe balance first',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(bridge, signingService));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go offline'));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Offline · last sync 0 min ago'), findsOneWidget);
    expect(find.text('Safe offline balance'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Reconnect to refresh'), 200);
    expect(find.text('Reconnect to refresh'), findsOneWidget);
  });

  testWidgets('Merchant tap 1 sends request and opens waiting screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(bridge, signingService));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Request Payment'), 200);
    await tester.tap(find.text('Request Payment'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('request-amount-field')), '8.50');
    await tester.enterText(
        find.byType(TextField).last, 'Nasi lemak + teh tarik');
    await tester.tap(find.text('Tap payer phone'));
    await tester.pumpAndSettle();

    expect(bridge.lastSentRequest, isNotNull);
    expect(bridge.lastSentRequest!.amountCents, 850);
    expect(find.text('Waiting for payment'), findsWidgets);
    expect(find.text('RM 8.50'), findsOneWidget);
  });

  testWidgets('Incoming request auto-opens confirm and completes tap 2',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(bridge, signingService));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();

    bridge.emitPaymentRequest(_samplePaymentRequest(amountCents: 850));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Pay Confirm'), findsOneWidget);
    expect(find.text('Payment Request Received'), findsOneWidget);

    await tester.tap(find.text('Authorize payment'));
    await tester.pumpAndSettle();

    expect(find.text('Tap back to pay'), findsOneWidget);

    await tester.tap(find.text('Tap back to pay'));
    await tester.pumpAndSettle();

    expect(bridge.lastCompletedJws, equals('header.payload.signature'));
    expect(find.text('Payment sent'), findsWidgets);
    expect(find.textContaining('Pending settlement'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Offline Wallet Home'), findsOneWidget);
    expect(find.text('RM 111.50'), findsWidgets);
  });

  testWidgets('Pay confirm disables authorization above safe balance',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp(bridge, signingService));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();

    bridge.emitPaymentRequest(_samplePaymentRequest(amountCents: 12001));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
        find.text('Amount exceeds your safe offline balance.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Authorize payment'),
    );
    expect(button.onPressed, isNull);
  });
}

Widget _buildApp(
  FakeOfflineNfcBridge bridge,
  FakeSigningService signingService,
) {
  return ProviderScope(
    overrides: [
      offlineNfcBridgeProvider.overrideWithValue(bridge),
      offlineSigningServiceProvider.overrideWithValue(signingService),
      offlinePayPolicyProvider.overrideWithValue(const OfflinePayPolicy()),
    ],
    child: const TngOfflineWalletApp(),
  );
}

PaymentRequest _samplePaymentRequest({required int amountCents}) {
  final now = DateTime.now();
  return PaymentRequest(
    requestId: '01TESTREQUEST',
    receiver: PaymentRequestParty(
      kid: 'did:tng:device:MERCHANT001',
      publicKey: Uint8List.fromList(List<int>.generate(32, (index) => index)),
      displayName: 'Aida Stall',
    ),
    amountCents: amountCents,
    memo: 'Nasi lemak + teh tarik',
    issuedAt: now,
    expiresAt: now.add(const Duration(minutes: 5)),
  );
}

class FakeOfflineNfcBridge implements OfflineNfcBridge {
  final StreamController<PaymentRequest> _requests =
      StreamController<PaymentRequest>.broadcast();
  final StreamController<ReceivedOfflineToken> _tokens =
      StreamController<ReceivedOfflineToken>.broadcast();

  PaymentRequest? lastSentRequest;
  String? lastCompletedJws;
  Uint8List? lastExpectedReceiverPublicKey;
  bool _disposed = false;

  @override
  Stream<PaymentRequest> get paymentRequests => _requests.stream;

  @override
  Stream<ReceivedOfflineToken> get receivedTokens => _tokens.stream;

  @override
  Future<Uint8List> sendPaymentRequest(PaymentRequest request) async {
    lastSentRequest = request;
    return Uint8List.fromList(List<int>.generate(32, (index) => 255 - index));
  }

  @override
  Future<Uint8List> completePaymentTap({
    required String jws,
    required Uint8List expectedReceiverPublicKey,
  }) async {
    lastCompletedJws = jws;
    lastExpectedReceiverPublicKey = expectedReceiverPublicKey;
    return Uint8List.fromList(List<int>.generate(64, (index) => index));
  }

  @override
  Future<void> stopReaderMode() async {}

  void emitPaymentRequest(PaymentRequest request) {
    _requests.add(request);
  }

  void emitReceivedToken({
    required String txId,
    required String senderKid,
    required int amountCents,
  }) {
    final payload = {
      'tx_id': txId,
      'sender': {
        'kid': senderKid,
        'user_id': 'payer_local',
      },
      'amount': {
        'value': (amountCents / 100).toStringAsFixed(2),
      },
    };
    final header =
        base64Url.encode(utf8.encode('{"alg":"EdDSA"}')).replaceAll('=', '');
    final body =
        base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
    _tokens.add(
      ReceivedOfflineToken(
        jws: '$header.$body.signature',
        ackSignature: 'ack-signature',
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _requests.close();
    _tokens.close();
  }
}

class FakeSigningService implements OfflineSigningService {
  final DeviceIdentity identity = DeviceIdentity(
    kid: 'did:tng:device:FAKEPAYER001',
    publicKey: Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
  );

  @override
  Future<DeviceIdentity> ensureIdentity() async => identity;

  @override
  Future<SignedPaymentToken> signPayment({
    required PaymentRequest request,
    required OfflinePayPolicy policy,
  }) async {
    return const SignedPaymentToken(
      txId: '01SIGNEDTOKEN001',
      jws: 'header.payload.signature',
      senderKid: 'did:tng:device:FAKEPAYER001',
    );
  }
}
