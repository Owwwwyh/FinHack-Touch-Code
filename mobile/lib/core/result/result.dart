/// Unified result type for use cases.
sealed class Result<T> {
  const Result();
  factory Result.ok(T value) = Ok._;
  factory Result.error(AppError error) = Err._;
  bool get isOk;
  bool get isError;
  T get value;
  AppError get error;
}

class Ok<T> extends Result<T> {
  final T _value;
  const Ok._(this._value);
  @override bool get isOk => true;
  @override bool get isError => false;
  @override T get value => _value;
  @override AppError get error => throw StateError('Result is Ok');
}

class Err<T> extends Result<T> {
  final AppError _error;
  const Err._(this._error);
  @override bool get isOk => false;
  @override bool get isError => true;
  @override T get value => throw StateError('Result is Err');
  @override AppError get error => _error;
}

class AppError implements Exception {
  final String code;
  final String message;
  const AppError(this.code, this.message);
  @override
  String toString() => 'AppError($code): $message';
}

// Common errors
class InsufficientSafeBalance extends AppError {
  final int requestedCents;
  final int availableCents;
  InsufficientSafeBalance(this.requestedCents, this.availableCents)
      : super('INSUFFICIENT_SAFE_BALANCE',
            'Requested ${requestedCents / 100} but safe offline is ${availableCents / 100}');
}

class NfcUnavailable extends AppError {
  NfcUnavailable() : super('NFC_UNAVAILABLE', 'NFC is not available or not enabled');
}

class NetworkRequired extends AppError {
  NetworkRequired() : super('NETWORK_REQUIRED', 'This operation requires network connectivity');
}

class BiometricFailed extends AppError {
  BiometricFailed() : super('BIOMETRIC_FAILED', 'Biometric authentication failed');
}

class TokenExpired extends AppError {
  TokenExpired() : super('TOKEN_EXPIRED', 'The transaction token has expired');
}
