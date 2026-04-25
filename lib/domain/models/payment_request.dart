import 'dart:convert';
import 'dart:typed_data';

class PaymentRequestParty {
  const PaymentRequestParty({
    required this.kid,
    required this.publicKey,
    required this.displayName,
  });

  final String kid;
  final Uint8List publicKey;
  final String displayName;

  Map<String, dynamic> toJson() {
    return {
      'kid': kid,
      'pub': _base64UrlEncode(publicKey),
      'display_name': displayName,
    };
  }

  factory PaymentRequestParty.fromJson(Map<String, dynamic> json) {
    return PaymentRequestParty(
      kid: json['kid'] as String? ?? '',
      publicKey: _base64UrlDecode(json['pub'] as String? ?? ''),
      displayName: json['display_name'] as String? ?? 'Merchant',
    );
  }
}

class PaymentRequest {
  const PaymentRequest({
    required this.requestId,
    required this.receiver,
    required this.amountCents,
    required this.memo,
    required this.issuedAt,
    required this.expiresAt,
    this.version = 1,
  });

  static const type = 'tng-payment-request+json';

  final String requestId;
  final PaymentRequestParty receiver;
  final int amountCents;
  final String memo;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int version;

  String get amountLabel => _formatMyr(amountCents);

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  Duration remaining(DateTime now) {
    if (isExpired(now)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  Map<String, dynamic> toJson() {
    return {
      'typ': type,
      'ver': version,
      'request_id': requestId,
      'receiver': receiver.toJson(),
      'amount': {
        'value': (amountCents / 100).toStringAsFixed(2),
        'currency': 'MYR',
        'scale': 2,
      },
      'memo': memo,
      'issued_at': issuedAt.millisecondsSinceEpoch ~/ 1000,
      'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'] as Map<String, dynamic>? ?? const {};
    final amountValue = amount['value'] as String? ?? '0.00';

    return PaymentRequest(
      requestId: json['request_id'] as String? ?? '',
      receiver: PaymentRequestParty.fromJson(
        json['receiver'] as Map<String, dynamic>? ?? const {},
      ),
      amountCents: ((double.tryParse(amountValue) ?? 0) * 100).round(),
      memo: json['memo'] as String? ?? '',
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['issued_at'] as num?) ?? 0).toInt() * 1000,
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['expires_at'] as num?) ?? 0).toInt() * 1000,
      ),
      version: (json['ver'] as num?)?.toInt() ?? 1,
    );
  }

  factory PaymentRequest.fromJsonString(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return PaymentRequest.fromJson(decoded);
  }
}

String _formatMyr(int cents) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return 'RM $whole.$fraction';
}

String _base64UrlEncode(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

Uint8List _base64UrlDecode(String value) {
  final normalized = base64Url.normalize(value);
  return Uint8List.fromList(base64Url.decode(normalized));
}
