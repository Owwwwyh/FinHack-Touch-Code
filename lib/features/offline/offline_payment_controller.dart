import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/device_identity_service.dart';
import '../../core/nfc/offline_nfc_bridge.dart';
import '../../domain/models/offline_transfer.dart';
import '../../domain/models/payment_request.dart';
import '../../domain/services/offline_pay_policy.dart';
import '../home/offline/offline_score_provider.dart';

final offlinePayPolicyProvider = Provider<OfflinePayPolicy>((ref) {
  final score = ref.watch(baseOfflineScoreProvider);
  return OfflinePayPolicy(
    safeOfflineBalanceCents: score.safeOfflineBalanceCents,
    policyVersion: score.policyVersion,
  );
});

final offlineSigningServiceProvider = Provider<OfflineSigningService>((ref) {
  return NativeOfflineSigningService();
});

final offlineNfcBridgeProvider = Provider<OfflineNfcBridge>((ref) {
  final bridge = PlatformOfflineNfcBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

final offlineNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final offlinePaymentControllerProvider =
    StateNotifierProvider<OfflinePaymentController, OfflinePaymentState>((ref) {
  final controller = OfflinePaymentController(
    nfcBridge: ref.watch(offlineNfcBridgeProvider),
    signingService: ref.watch(offlineSigningServiceProvider),
    readPolicy: () => ref.read(offlinePayPolicyProvider),
    now: ref.watch(offlineNowProvider),
  );
  return controller;
});

class PendingMerchantRequest {
  const PendingMerchantRequest({
    required this.request,
    required this.payerPublicKey,
    required this.sentAt,
  });

  final PaymentRequest request;
  final List<int> payerPublicKey;
  final DateTime sentAt;
}

class OfflinePaymentState {
  const OfflinePaymentState({
    this.outgoingRequest,
    this.incomingRequest,
    this.readyToSendToken,
    this.outbox = const <OfflineTransfer>[],
    this.inbox = const <OfflineTransfer>[],
    this.latestOutgoingReceipt,
    this.latestIncomingReceipt,
    this.isSendingRequest = false,
    this.isSigning = false,
    this.isSendingPayment = false,
    this.errorMessage,
  });

  final PendingMerchantRequest? outgoingRequest;
  final PaymentRequest? incomingRequest;
  final SignedPaymentToken? readyToSendToken;
  final List<OfflineTransfer> outbox;
  final List<OfflineTransfer> inbox;
  final OfflineTransfer? latestOutgoingReceipt;
  final OfflineTransfer? latestIncomingReceipt;
  final bool isSendingRequest;
  final bool isSigning;
  final bool isSendingPayment;
  final String? errorMessage;

  bool get hasPendingTapBack =>
      readyToSendToken != null && incomingRequest != null;

  OfflinePaymentState copyWith({
    Object? outgoingRequest = _sentinel,
    Object? incomingRequest = _sentinel,
    Object? readyToSendToken = _sentinel,
    List<OfflineTransfer>? outbox,
    List<OfflineTransfer>? inbox,
    Object? latestOutgoingReceipt = _sentinel,
    Object? latestIncomingReceipt = _sentinel,
    bool? isSendingRequest,
    bool? isSigning,
    bool? isSendingPayment,
    Object? errorMessage = _sentinel,
  }) {
    return OfflinePaymentState(
      outgoingRequest: identical(outgoingRequest, _sentinel)
          ? this.outgoingRequest
          : outgoingRequest as PendingMerchantRequest?,
      incomingRequest: identical(incomingRequest, _sentinel)
          ? this.incomingRequest
          : incomingRequest as PaymentRequest?,
      readyToSendToken: identical(readyToSendToken, _sentinel)
          ? this.readyToSendToken
          : readyToSendToken as SignedPaymentToken?,
      outbox: outbox ?? this.outbox,
      inbox: inbox ?? this.inbox,
      latestOutgoingReceipt: identical(latestOutgoingReceipt, _sentinel)
          ? this.latestOutgoingReceipt
          : latestOutgoingReceipt as OfflineTransfer?,
      latestIncomingReceipt: identical(latestIncomingReceipt, _sentinel)
          ? this.latestIncomingReceipt
          : latestIncomingReceipt as OfflineTransfer?,
      isSendingRequest: isSendingRequest ?? this.isSendingRequest,
      isSigning: isSigning ?? this.isSigning,
      isSendingPayment: isSendingPayment ?? this.isSendingPayment,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class OfflinePaymentController extends StateNotifier<OfflinePaymentState> {
  OfflinePaymentController({
    required OfflineNfcBridge nfcBridge,
    required OfflineSigningService signingService,
    required OfflinePayPolicy Function() readPolicy,
    required DateTime Function() now,
  })  : _nfcBridge = nfcBridge,
        _signingService = signingService,
        _readPolicy = readPolicy,
        _now = now,
        super(const OfflinePaymentState()) {
    _requestSubscription = _nfcBridge.paymentRequests.listen(
      _handleIncomingRequest,
      onError: (Object error, StackTrace stackTrace) {
        state =
            state.copyWith(errorMessage: 'Failed to receive payment request.');
      },
    );
    _inboxSubscription = _nfcBridge.receivedTokens.listen(
      _handleIncomingToken,
      onError: (Object error, StackTrace stackTrace) {
        state =
            state.copyWith(errorMessage: 'Failed to receive payment token.');
      },
    );
  }

  final OfflineNfcBridge _nfcBridge;
  final OfflineSigningService _signingService;
  final OfflinePayPolicy Function() _readPolicy;
  final DateTime Function() _now;

  StreamSubscription<PaymentRequest>? _requestSubscription;
  StreamSubscription<ReceivedOfflineToken>? _inboxSubscription;

  Future<bool> sendPaymentRequest({
    required int amountCents,
    required String memo,
  }) async {
    state = state.copyWith(
      isSendingRequest: true,
      errorMessage: null,
      latestIncomingReceipt: null,
      latestOutgoingReceipt: null,
    );

    try {
      final identity = await _signingService.ensureIdentity();
      final issuedAt = _now();
      final request = PaymentRequest(
        requestId: _generateRequestId(issuedAt),
        receiver: PaymentRequestParty(
          kid: identity.kid,
          publicKey: identity.publicKey,
          displayName: 'Merchant device',
        ),
        amountCents: amountCents,
        memo: memo.trim(),
        issuedAt: issuedAt,
        expiresAt: issuedAt.add(const Duration(minutes: 5)),
      );

      final payerPublicKey = await _nfcBridge.sendPaymentRequest(request);

      state = state.copyWith(
        isSendingRequest: false,
        outgoingRequest: PendingMerchantRequest(
          request: request,
          payerPublicKey: payerPublicKey,
          sentAt: issuedAt,
        ),
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSendingRequest: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<bool> authorizeIncomingRequest() async {
    final request = state.incomingRequest;
    if (request == null) {
      return false;
    }

    if (request.isExpired(_now())) {
      state = state.copyWith(
        incomingRequest: null,
        readyToSendToken: null,
        errorMessage: 'Request expired. Ask the merchant to resend it.',
      );
      return false;
    }

    final policy = _readPolicy();
    final availableSafeBalanceCents = _availableSafeBalanceCents(policy);

    if (request.amountCents > availableSafeBalanceCents) {
      state = state.copyWith(
        errorMessage:
            'Amount exceeds your safe offline balance of ${_formatMyr(availableSafeBalanceCents)}.',
      );
      return false;
    }

    state = state.copyWith(
      isSigning: true,
      errorMessage: null,
      latestOutgoingReceipt: null,
    );

    try {
      final effectivePolicy = OfflinePayPolicy(
        safeOfflineBalanceCents: availableSafeBalanceCents,
        receiverKid: policy.receiverKid,
        policyVersion: policy.policyVersion,
      );
      final signedToken = await _signingService.signPayment(
        request: request,
        policy: effectivePolicy,
      );
      state = state.copyWith(
        isSigning: false,
        readyToSendToken: signedToken,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSigning: false,
        errorMessage: 'Authorization failed: $error',
      );
      return false;
    }
  }

  Future<bool> completeTapBack() async {
    final request = state.incomingRequest;
    final signedToken = state.readyToSendToken;
    if (request == null || signedToken == null) {
      return false;
    }

    state = state.copyWith(
      isSendingPayment: true,
      errorMessage: null,
    );

    try {
      final ackSignature = await _nfcBridge.completePaymentTap(
        jws: signedToken.jws,
        expectedReceiverPublicKey: request.receiver.publicKey,
      );
      final transfer = OfflineTransfer(
        txId: signedToken.txId,
        amountCents: request.amountCents,
        receiverKid: request.receiver.kid,
        createdAt: _now(),
        status: OfflineTransferStatus.pendingSettlement,
        counterpartyLabel: request.receiver.displayName,
        memo: request.memo,
        ackSignature: _base64UrlEncode(ackSignature),
      );
      state = state.copyWith(
        isSendingPayment: false,
        incomingRequest: null,
        readyToSendToken: null,
        outbox: <OfflineTransfer>[transfer, ...state.outbox],
        latestOutgoingReceipt: transfer,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSendingPayment: false,
        errorMessage: 'Tap 2 failed: $error',
      );
      return false;
    } finally {
      await _nfcBridge.stopReaderMode();
    }
  }

  void cancelIncomingRequest() {
    state = state.copyWith(
      incomingRequest: null,
      readyToSendToken: null,
      errorMessage: null,
    );
  }

  void clearOutgoingRequest() {
    state = state.copyWith(outgoingRequest: null);
  }

  void clearLatestOutgoingReceipt() {
    state = state.copyWith(latestOutgoingReceipt: null);
  }

  void clearLatestIncomingReceipt() {
    state = state.copyWith(latestIncomingReceipt: null);
  }

  void dismissError() {
    state = state.copyWith(errorMessage: null);
  }

  void _handleIncomingRequest(PaymentRequest request) {
    state = state.copyWith(
      incomingRequest: request,
      readyToSendToken: null,
      errorMessage: null,
      latestOutgoingReceipt: null,
    );
  }

  void _handleIncomingToken(ReceivedOfflineToken token) {
    final transfer = _transferFromJws(
      token.jws,
      token.ackSignature,
      _now(),
    );
    state = state.copyWith(
      outgoingRequest: null,
      inbox: <OfflineTransfer>[transfer, ...state.inbox],
      latestIncomingReceipt: transfer,
      errorMessage: null,
    );
  }

  OfflineTransfer _transferFromJws(
    String jws,
    String? ackSignature,
    DateTime createdAt,
  ) {
    final parts = jws.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid JWS payload');
    }

    final payloadJson = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    final sender = payload['sender'] as Map<String, dynamic>? ?? const {};
    final amount = payload['amount'] as Map<String, dynamic>? ?? const {};
    final amountValue = amount['value'] as String? ?? '0.00';

    return OfflineTransfer(
      txId: payload['tx_id'] as String? ?? 'unknown',
      amountCents: ((double.tryParse(amountValue) ?? 0) * 100).round(),
      receiverKid: sender['kid'] as String? ?? 'unknown',
      createdAt: createdAt,
      status: OfflineTransferStatus.pendingSettlement,
      counterpartyLabel: sender['user_id'] as String? ??
          _shortKid(sender['kid'] as String? ?? 'unknown'),
      memo: null,
      ackSignature: ackSignature,
    );
  }

  String _generateRequestId(DateTime timestamp) {
    final millis =
        timestamp.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return '01${millis.padLeft(10, '0')}REQ';
  }

  String _shortKid(String kid) {
    if (kid.length <= 6) {
      return kid;
    }
    return '…${kid.substring(kid.length - 6)}';
  }

  int _availableSafeBalanceCents(OfflinePayPolicy policy) {
    return (policy.safeOfflineBalanceCents - _pendingOutgoingCents())
        .clamp(0, policy.safeOfflineBalanceCents);
  }

  int _pendingOutgoingCents() {
    return state.outbox
        .where(
          (transfer) =>
              transfer.status != OfflineTransferStatus.rejected &&
              transfer.status != OfflineTransferStatus.settled,
        )
        .fold<int>(
          0,
          (total, transfer) => total + transfer.amountCents,
        );
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    _inboxSubscription?.cancel();
    super.dispose();
  }
}

String _formatMyr(int cents) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return 'RM $whole.$fraction';
}

String _base64UrlEncode(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

const Object _sentinel = Object();
