/// A simple implementation of an AsyncValue class that can represent loading, data, and error states.
/// This class is useful for managing asynchronous operations in a reactive programming style.
/// It provides methods to handle different states and retrieve data or errors in a type-safe manner.
abstract class AsyncValue<T> {
  const AsyncValue();

  /// Returns the current state of the AsyncValue.
  /// - `loading`: Indicates that the operation is in progress.
  /// - `data`: Contains the result of the operation.
  /// - `error`: Contains an error if the operation failed.
  R when<R>({
    required R Function() loading,
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
  });

  /// Returns the current state of the AsyncValue as a string.
  T? get dataOrNull => whenOrNull(data: (d) => d);

  /// Returns the current state of the AsyncValue as a string.
  /// If the state is loading or error, it returns null.
  /// If the state is data, it returns the data.
  T? whenOrNull({
    T? Function()? loading,
    T? Function(T data)? data,
    T? Function(Object error, StackTrace stackTrace)? error,
  }) {
    try {
      return when(loading: loading ?? () => null, data: data ?? (d) => d, error: error ?? (e, s) => null);
    } catch (_) {
      return null;
    }
  }

  T get value {
    return when(
      data: (data) => data,
      loading: () => throw StateError('AsyncValue is loading, has no value'),
      error: (e, s) => throw StateError('AsyncValue is an error, has no value. Error: $e'),
    );
  }
}

/// Concrete implementations of AsyncValue for different states: loading, data, and error.
/// - `AsyncLoading`: Represents a loading state.
/// - `AsyncData`: Represents a successful data state.
/// - `AsyncError`: Represents an error state with an error and stack trace.
/// These classes provide a way to handle asynchronous operations in a type-safe manner.
class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading();
  @override
  R when<R>({
    required R Function() loading,
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
  }) => loading();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncLoading<T> && runtimeType == other.runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Represents a successful data state in an asynchronous operation.
/// It contains the data of type `T` and provides methods to access and manipulate the data.
/// This class is useful for managing the result of asynchronous operations in a reactive programming style.
class AsyncData<T> extends AsyncValue<T> {
  final T data;
  const AsyncData(this.data);
  @override
  R when<R>({
    required R Function() loading,
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
  }) => data(this.data);

  AsyncData<T> copyWith(T Function(T data) updater) => AsyncData(updater(data));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncData<T> && other.data == data;
  }

  @override
  int get hashCode => data.hashCode;
}

/// Represents an error state in an asynchronous operation.
/// It contains the error object and the stack trace, providing
/// information about the failure of the operation.
/// This class is useful for handling errors in a type-safe manner in reactive programming.
class AsyncError<T> extends AsyncValue<T> {
  final Object error;
  final StackTrace stackTrace;
  const AsyncError(this.error, this.stackTrace);
  @override
  R when<R>({
    required R Function() loading,
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
  }) => error(this.error, this.stackTrace);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncError<T> && other.error == error && other.stackTrace == stackTrace;
  }

  @override
  int get hashCode => Object.hash(error, stackTrace);
}
