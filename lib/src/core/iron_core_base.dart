import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iron/src/core/async_value.dart';
import 'package:iron/src/core/iron_events_effects.dart';
import 'package:iron/src/core/iron_interceptor.dart';
import 'package:iron/src/di/iron_locator.dart';
import 'package:iron/src/saga/iron_saga.dart';

/// Base class for IronCore, which is the core of the Iron architecture.
@immutable
abstract class IronEvent {
  const IronEvent();
}

/// Base class for IronEffect, which represents side effects in the Iron architecture.
/// This class is used to encapsulate effects that can be triggered by events or state changes.
/// It is designed to be extended by specific effect implementations.
abstract class IronCore<TEvent extends IronEvent, TState> {
  late AsyncValue<TState> _currentState;
  AsyncValue<TState> get state => _currentState;
  final StreamController<AsyncValue<TState>> _stateController = StreamController.broadcast();
  Stream<AsyncValue<TState>> get stateStream => _stateController.stream;

  final StreamController<IronEffect> _effectController = StreamController.broadcast();
  Stream<IronEffect> get effectStream => _effectController.stream;

  bool _isBusy = false;
  bool _isDisposed = false;

  final Map<Type, Function> _eventHandlers = {};
  late final InterceptorRegistry _registry;

  final Map<Type, Timer?> _debounceTimers = {};
  final Map<Type, bool> _throttleState = {};

  IronCore(TState initialState) {
    _currentState = AsyncData(initialState);
    _registry = IronLocator.instance.find<InterceptorRegistry>();
    _registerToSaga();
  }
  IronCore.loading() {
    _currentState = AsyncLoading<TState>();
    _registry = IronLocator.instance.find<InterceptorRegistry>();
    _registerToSaga();
  }

  void _registerToSaga() {
    IronLocator.instance.find<SagaProcessor>().registerCore(this);
  }

  void on<E extends TEvent>(FutureOr<void> Function(E event) handler) {
    _eventHandlers[E] = handler;
  }

  void onDebounced<E extends TEvent>(FutureOr<void> Function(E event) handler, Duration delay) {
    _eventHandlers[E] = (E event) {
      _debounceTimers[E]?.cancel();
      _debounceTimers[E] = Timer(delay, () {
        handler(event);
        _debounceTimers.remove(E);
      });
    };
  }

  void onThrottled<E extends TEvent>(FutureOr<void> Function(E event) handler, Duration delay) {
    _eventHandlers[E] = (E event) {
      if (_throttleState[E] ?? false) return;

      _throttleState[E] = true;
      handler(event);
      Timer(delay, () {
        _throttleState[E] = false;
      });
    };
  }

  /// Adds an event to the IronCore, triggering the appropriate handler if one exists.
  /// Throws a StateError if the IronCore has been disposed.
  void add(TEvent event) {
    if (_isDisposed) {
      throw StateError('Cannot add event to a disposed IronCore');
    }
    _registry.notifyEvent(this, event);
    final handler = _eventHandlers[event.runtimeType];
    if (handler != null) {
      handler(event);
    } else {
      debugPrint('[IronCore] No handler found for event ${event.runtimeType} in $runtimeType');
    }
  }

  /// Updates the state of the IronCore with a new AsyncValue.
  /// Throws a StateError if the IronCore has been disposed.
  /// This method notifies the InterceptorRegistry of the state change and updates the internal state.
  /// If the new state is the same as the current state, no action is taken.
  void updateState(AsyncValue<TState> newState) {
    if (_isDisposed) {
      throw StateError('Cannot update state on a disposed IronCore');
    }
    final previous = _currentState;
    if (newState == previous) return;
    _currentState = newState;
    _stateController.add(newState);
    _registry.notifyStateChange(this, previous, newState);
  }

  /// Runs a future and updates the state with the result.
  /// If the future completes successfully, the state is updated to AsyncData.
  /// If the future throws an error, the state is updated to AsyncError.
  /// If the IronCore is already busy, the method returns without doing anything.
  /// This method also handles errors by notifying the InterceptorRegistry.
  /// Throws a StateError if the IronCore has been disposed.
  Future<void> runAndUpdate(Future<TState> Function() future) async {
    if (_isBusy) return;
    _isBusy = true;
    updateState(AsyncLoading<TState>());
    await Future.microtask(() {}); // Loading state'in UI'ya yansımasını garanti et
    try {
      final newState = await future();
      updateState(AsyncData(newState));
    } catch (e, s) {
      updateState(AsyncError(e, s));
      _registry.notifyError(this, e, s);
    } finally {
      _isBusy = false;
    }
  }

  /// Computes a new state based on a message and updates the state.
  /// If the IronCore is already busy, the method returns without doing anything.
  /// This method allows for asynchronous computation of the state based on a message.
  /// It uses the `compute` function to run the computation in a separate isolate.
  /// Throws a StateError if the IronCore has been disposed.
  /// The computation function should return a new state of type TState.
  /// If the computation throws an error, the state is updated to AsyncError.
  /// The method also notifies the InterceptorRegistry of any errors that occur.
  /// The message parameter is of type Q, which allows for flexibility in the type of message used for computation.
  Future<void> computeAndUpdateState<Q>(FutureOr<TState> Function(Q message) computation, Q message) async {
    if (_isBusy) return;
    _isBusy = true;
    updateState(AsyncLoading<TState>());
    await Future.microtask(() {}); // Loading state'in UI'ya yansımasını garanti et
    try {
      final TState newState = await compute(computation, message);
      updateState(AsyncData(newState));
    } catch (e, s) {
      updateState(AsyncError(e, s));
      _registry.notifyError(this, e, s);
    } finally {
      _isBusy = false;
    }
  }

  /// Adds an effect to the IronCore, notifying the InterceptorRegistry.
  /// This method allows for side effects to be triggered in response to events or state changes.
  /// Throws a StateError if the IronCore has been disposed.
  /// The effect is added to the effect stream, which can be listened to by other components in the Iron architecture.
  /// This method is useful for handling side effects such as network requests, logging, or other asynchronous operations that should not block the main thread.
  void addEffect(IronEffect effect) {
    if (_isDisposed) {
      throw StateError('Cannot add effect to a disposed IronCore');
    }
    _registry.notifyEffect(runtimeType, effect);
    _effectController.add(effect);
  }

  /// Disposes of the IronCore, closing the state and effect streams.
  /// This method should be called when the IronCore is no longer needed to free up resources.
  /// Once disposed, the IronCore cannot be used again, and any further attempts to add events or effects will throw a StateError.
  /// The method also cancels any active debounce timers and clears the debounce state.
  /// Throws a StateError if the IronCore has already been disposed.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _stateController.close();
    _effectController.close();
    _debounceTimers.forEach((_, timer) => timer?.cancel());
    _debounceTimers.clear();
  }
}
