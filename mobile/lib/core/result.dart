/// A simple Result type for error handling in use cases.
sealed class Result<T> {
  const Result();
  factory Result.ok(T value) = Ok._;
  factory Result.error(Exception exception) = Err._;
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok._(this.value);
}

class Err<T> extends Result<T> {
  final Exception exception;
  const Err._(this.exception);
}
