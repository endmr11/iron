import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:iron/src/core/iron_core_base.dart';
import 'package:iron/src/core/iron_events_effects.dart';
import 'package:iron/src/core/iron_interceptor.dart';
import 'package:iron/src/di/iron_locator.dart';

/// A processor for managing sagas in the Iron architecture.
/// It handles the registration of IronCore instances and processes effects.
/// It provides a stream of effects that can be listened to by sagas.
/// The processor is responsible for notifying the InterceptorRegistry about effects and errors.
/// It allows sagas to add effects that can be processed by the system.
/// The SagaProcessor is designed to work with the Iron architecture, allowing for easy integration with other components.
/// It is used to centralize the management of sagas and their effects, making it easier to handle side effects in a reactive manner.
///  The SagaProcessor can be used to register core instances, listen to their effects, and add new effects.
/// It is a key component in the Iron architecture, enabling the reactive processing of effects and events.
/// It is designed to be used with the Iron architecture, allowing for easy integration with other components.
class SagaProcessor {
  final StreamController<IronEffect> _effectController = StreamController.broadcast();
  Stream<IronEffect> get effectStream => _effectController.stream;
  late final InterceptorRegistry _registry;

  SagaProcessor() {
    _registry = IronLocator.instance.find<InterceptorRegistry>();
  }

  void registerCore(IronCore core) => core.effectStream.listen((effect) {
    _registry.notifyEffect(core.runtimeType, effect);
    _effectController.add(effect);
  });
  void addEffect(IronEffect effect) {
    _registry.notifyEffect(null, effect);
    _effectController.add(effect);
  }
}

/// Base class for sagas in the Iron architecture.
/// Sagas are used to handle side effects in response to events or state changes.
/// This class provides a mechanism to bind a SagaProcessor and listen to its effect stream.
/// It allows sagas to process effects and add new effects to the processor.
/// Sagas can be used to implement complex business logic that involves asynchronous operations or side effects.
/// The IronSaga class is designed to be extended by specific saga implementations.
/// It provides a way to centralize the handling of side effects in a reactive manner.
/// Sagas can be used to manage complex workflows, handle API calls, or perform other side effects in response to events.
abstract class IronSaga {
  late final SagaProcessor _processor;
  StreamSubscription? _subscription;
  late final InterceptorRegistry _registry;

  void bind(SagaProcessor processor) {
    _processor = processor;
    _registry = IronLocator.instance.find<InterceptorRegistry>();
    _subscription = processor.effectStream.listen((effect) {
      try {
        _registry.notifyEffect(runtimeType, effect);
        processEffect(effect);
      } catch (e, s) {
        debugPrint(
          '[IronSaga] Error processing effect ${effect.runtimeType} in $runtimeType. Error: $e. StackTrace: $s',
        );
        _registry.notifyError(this, e, s);
      }
    });
  }

  void processEffect(IronEffect effect);
  void addEffect(IronEffect effect) => _processor.addEffect(effect);
  void dispose() => _subscription?.cancel();
}
