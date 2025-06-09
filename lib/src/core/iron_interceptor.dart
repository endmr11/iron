import 'package:flutter/foundation.dart';
import 'package:iron/src/core/async_value.dart';
import 'package:iron/src/core/iron_core_base.dart';
import 'package:iron/src/core/iron_events_effects.dart';

/// Base class for interceptors in the Iron architecture.
/// Interceptors can listen to events, state changes, effects, and errors.
/// They can be used for logging, analytics, or other cross-cutting concerns.
/// This class provides methods that can be overridden to handle specific events.
abstract class IronInterceptor {
  void onEvent(IronCore core, IronEvent event) {}
  void onStateChange(IronCore core, AsyncValue<dynamic> previousState, AsyncValue<dynamic> nextState) {}
  void onEffect(Type? origin, IronEffect effect) {}
  void onError(dynamic source, Object error, StackTrace stackTrace) {}
}

/// A concrete implementation of IronInterceptor that logs events, state changes, effects, and errors.
/// It can be used for debugging purposes.
/// The `openDebug` parameter controls whether logging is enabled.
/// If `openDebug` is true, it will print debug information to the console.
/// This interceptor can be registered with the InterceptorRegistry to capture events and state changes.
class LoggingInterceptor extends IronInterceptor {
  final bool openDebug;

  LoggingInterceptor({this.openDebug = true});

  @override
  void onEvent(IronCore core, IronEvent event) {
    if (openDebug) {
      debugPrint('[Interceptor][EVENT] Core: ${core.runtimeType}, Event: ${event.runtimeType}');
    }
  }

  @override
  void onStateChange(IronCore core, AsyncValue<dynamic> previousState, AsyncValue<dynamic> nextState) {
    if (openDebug) {
      debugPrint('[Interceptor][STATE] Core: ${core.runtimeType}');
      debugPrint('  Previous: ${previousState.runtimeType}');
      previousState.when(
        loading: () => debugPrint('    State: Loading'),
        data: (d) => debugPrint('    Data: $d'),
        error: (e, s) => debugPrint('    Error: $e, StackTrace: $s'),
      );
      debugPrint('  Next: ${nextState.runtimeType}');
      nextState.when(
        loading: () => debugPrint('    State: Loading'),
        data: (d) => debugPrint('    Data: $d'),
        error: (e, s) => debugPrint('    Error: $e, StackTrace: $s'),
      );
    }
  }

  @override
  void onEffect(Type? origin, IronEffect effect) {
    if (openDebug) {
      String effectDetails = effect.toString();
      try {
        if (effect is PersistenceEffect) {
          effectDetails = effect.toJson().toString();
        }
      } catch (_) {
        effectDetails = effect.toString();
      }
      debugPrint(
        '[Interceptor][EFFECT] Origin: ${origin ?? "Unknown"}, Effect: ${effect.runtimeType}, Data: $effectDetails',
      );
    }
  }

  @override
  void onError(dynamic source, Object error, StackTrace stackTrace) {
    if (openDebug) {
      debugPrint('[Interceptor][ERROR] Source: ${source.runtimeType}, Error: $error');
      debugPrint('  StackTrace: $stackTrace');
    }
  }
}

/// Registry for managing IronInterceptors.
/// It allows registering and unregistering interceptors,
/// and notifying them of events, state changes, effects, and errors.
/// This registry can be used to centralize the management of interceptors in the Iron architecture.
class InterceptorRegistry {
  final List<IronInterceptor> _interceptors = [];

  void register(IronInterceptor interceptor) {
    _interceptors.add(interceptor);
  }

  void unregister(IronInterceptor interceptor) {
    _interceptors.remove(interceptor);
  }

  void notifyEvent(IronCore core, IronEvent event) {
    for (final interceptor in _interceptors) {
      try {
        interceptor.onEvent(core, event);
      } catch (e, s) {
        debugPrint('[InterceptorRegistry] Error in onEvent for ${interceptor.runtimeType}: $e, $s');
      }
    }
  }

  void notifyStateChange(IronCore core, AsyncValue<dynamic> previousState, AsyncValue<dynamic> nextState) {
    for (final interceptor in _interceptors) {
      try {
        interceptor.onStateChange(core, previousState, nextState);
      } catch (e, s) {
        debugPrint('[InterceptorRegistry] Error in onStateChange for ${interceptor.runtimeType}: $e, $s');
      }
    }
  }

  void notifyEffect(Type? origin, IronEffect effect) {
    for (final interceptor in _interceptors) {
      try {
        interceptor.onEffect(origin, effect);
      } catch (e, s) {
        debugPrint('[InterceptorRegistry] Error in onEffect for ${interceptor.runtimeType}: $e, $s');
      }
    }
  }

  void notifyError(dynamic source, Object error, StackTrace stackTrace) {
    for (final interceptor in _interceptors) {
      try {
        interceptor.onError(source, error, stackTrace);
      } catch (e, s) {
        debugPrint('[InterceptorRegistry] Error in onError for ${interceptor.runtimeType}: $e, $s');
      }
    }
  }
}
