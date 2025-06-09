/// A simple dependency injection locator for Dart/Flutter applications.
class IronLocator {
  IronLocator._();
  static final IronLocator instance = IronLocator._();
  final List<Map<Type, dynamic>> _scopes = [{}];

  void pushScope() => _scopes.add({});
  void popScope() => _scopes.length > 1 ? _scopes.removeLast() : null;

  /// Registers a singleton instance of type [T].
  /// If [global] is true, the instance will be registered in the global scope.
  /// Otherwise, it will be registered in the current scope.
  void registerSingleton<T extends Object>(T instance, {bool global = false}) {
    final scope = global ? _scopes.first : _scopes.last;
    scope[T] = instance;
  }

  /// Registers a lazy singleton factory for type [T].
  /// If [global] is true, the factory will be registered in the global scope.
  /// Otherwise, it will be registered in the current scope.
  void registerLazySingleton<T extends Object>(T Function() factory, {bool global = false}) {
    final scope = global ? _scopes.first : _scopes.last;
    scope[T] = _LazySingleton(factory);
  }

  /// Registers a factory function for type [T].
  /// If [global] is true, the factory will be registered in the global scope.
  /// Otherwise, it will be registered in the current scope.
  /// The factory function will be called each time an instance of type [T] is requested.
  /// This is useful for creating new instances of a class each time it is requested.
  void registerFactory<T extends Object>(T Function() factory, {bool global = false}) {
    final scope = global ? _scopes.first : _scopes.last;
    scope[T] = factory;
  }

  /// Finds an instance of type [T] in the current scope or any parent scopes.
  /// If no instance is found, it throws an exception.
  /// If the instance is a lazy singleton, it returns the instance after initializing it.
  /// If the instance is a factory function, it calls the function to get the instance.
  /// If the instance is a regular singleton, it returns the instance directly.
  /// This method allows for dependency injection and retrieval of registered services.
  T find<T extends Object>() {
    for (final scope in _scopes.reversed) {
      if (scope.containsKey(T)) {
        final instanceOrFactory = scope[T];
        if (instanceOrFactory is _LazySingleton<T>) return instanceOrFactory.instance;
        if (instanceOrFactory is Function) return instanceOrFactory() as T;
        return instanceOrFactory as T;
      }
    }
    throw Exception('[IronLocator] No instance found for type $T');
  }
}

class _LazySingleton<T> {
  T? _instance;
  final T Function() _factory;
  _LazySingleton(this._factory);
  T get instance => _instance ??= _factory();
}
