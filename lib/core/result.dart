// lib/core/result.dart
//
// Simple Result<T> type to avoid throwing exceptions across layer boundaries.
// Use cases return Result.ok(value) or Result.error(failure).

sealed class Result<T> {
  const Result();

  factory Result.ok(T value) = Ok<T>;
  factory Result.error(Failure failure) = Err<T>;

  bool get isOk  => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T get value => (this as Ok<T>).value;
  Failure get failure => (this as Err<T>).failure;

  R fold<R>({required R Function(T) onOk, required R Function(Failure) onErr}) {
    return switch (this) {
      Ok(:final value)     => onOk(value),
      Err(:final failure)  => onErr(failure),
    };
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  @override final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  @override final Failure failure;
}

// ─── Failures ────────────────────────────────────────────────────────────────

sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class InsufficientSafeBalance extends Failure {
  const InsufficientSafeBalance() : super('Amount exceeds safe offline balance');
}

final class NfcNotAvailable extends Failure {
  const NfcNotAvailable() : super('NFC is not available on this device');
}

final class NfcTimeout extends Failure {
  const NfcTimeout() : super('NFC tap timed out — please try again');
}

final class NfcMidStreamDisconnect extends Failure {
  const NfcMidStreamDisconnect() : super('NFC connection lost mid-transfer');
}

final class SettlementError extends Failure {
  const SettlementError(String msg) : super(msg);
}

final class NetworkError extends Failure {
  const NetworkError(String msg) : super(msg);
}

final class KeystoreError extends Failure {
  const KeystoreError(String msg) : super(msg);
}

final class TokenExpired extends Failure {
  const TokenExpired() : super('Token has expired');
}
