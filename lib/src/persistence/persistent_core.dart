import 'package:flutter/foundation.dart'; // debugPrint için foundation.dart kullanılıyor
import 'package:iron/src/core/async_value.dart';
import 'package:iron/src/core/iron_core_base.dart';
import 'package:iron/src/persistence/adapters/adapter.dart';

/// Base class for persistent IronCore, which extends IronCore to include persistence capabilities.
/// This class manages the state persistence using a PersistenceAdapter.
/// It provides methods to load, save, and clear the state, and handles versioning of the state data.
/// It also includes methods to rehydrate the state from persistent storage and reset to the initial state if needed.
/// It is designed to be extended by specific persistent IronCore implementations.
/// This class is abstract and should not be instantiated directly.
/// Optional parameters include:
/// - `adapter`: The PersistenceAdapter used for saving and loading state.
/// - `fromJson`: A function to convert JSON data to the state type.
/// - `toJson`: A function to convert the state type to JSON data.
abstract class PersistentIronCore<TEvent extends IronEvent, TState> extends IronCore<TEvent, TState> {
  final PersistenceAdapter<TState>? adapter;
  final TState Function(Map<String, dynamic> json)? fromJson;
  final Map<String, dynamic> Function(TState state)? toJson;
  final TState Function() initialStateFactory;
  final int version;

  PersistentIronCore({
    this.adapter,
    this.fromJson,
    this.toJson,
    required this.initialStateFactory,
    this.version = 1,
  }) : super.loading() {
    if (adapter != null && (fromJson == null || toJson == null)) {
      throw ArgumentError('If adapter is provided, fromJson and toJson must also be provided.');
    }
    _rehydrate();
  }

  Future<void> _rehydrate() async {
    if (adapter == null || fromJson == null) {
      // Persistence is disabled or not fully configured for loading.
      _resetToInitial();
      return;
    }

    final json = await adapter!.load();
    if (json != null) {
      try {
        final savedVersion = json['@version'] as int? ?? 0;
        if (savedVersion != version) {
          debugPrint('State version mismatch. Expected: $version, Found: $savedVersion. Resetting state.');
          _resetToInitial();
        } else {
          // fromJson is guaranteed to be non-null here due to constructor check and adapter null check.
          updateState(AsyncData(fromJson!(json['data'])));
        }
      } catch (e, s) {
        debugPrint('Failed to rehydrate state for $runtimeType. Error: $e. StackTrace: $s. Resetting state.');
        _resetToInitial();
      }
    } else {
      _resetToInitial();
    }
  }

  void _resetToInitial() {
    updateState(AsyncData(initialStateFactory()));
  }

  @override
  void updateState(AsyncValue<TState> newState) {
    super.updateState(newState);
    if (adapter != null && toJson != null && newState is AsyncData<TState>) {
      // toJson and adapter are guaranteed to be non-null here.
      final stateJson = {'@version': version, 'data': toJson!(newState.data)};
      adapter!.save(stateJson);
    }
  }

  Future<void> clear() async {
    if (adapter != null) {
      await adapter!.clear();
    }
    _resetToInitial();
  }
}
