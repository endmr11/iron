import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iron/src/core/iron_events_effects.dart';
import 'package:iron/src/di/iron_locator.dart';
import 'package:iron/src/saga/iron_saga.dart';


/// A widget that listens for specific effects in the Iron architecture.
/// It allows you to react to effects of a specific type and execute a callback when such an effect occurs.
/// The `listenWhen` parameter can be used to filter effects based on custom conditions.
/// The `onEffect` callback is called whenever an effect of type `E` is emitted.
/// The `child` widget is the content that will be rendered by this listener.
/// This widget is useful for scenarios where you want to perform actions in response to specific effects,
/// such as showing dialogs, updating UI elements, or triggering other side effects.
/// It is designed to be used within the Iron architecture, allowing for easy integration with other components.
/// The `EffectListener` widget is a stateful widget that listens to the effect stream from the `SagaProcessor`.
/// It subscribes to the stream and calls the `onEffect` callback whenever an effect of type `E` is emitted.
/// The `listenWhen` function can be used to determine whether to react to a specific effect based on custom logic.
/// This widget is particularly useful for handling side effects in a reactive manner, allowing you to respond to changes in the application state or events.
/// It can be used to implement features like notifications, modals, or any other UI updates that depend on specific effects.
class EffectListener<E extends IronEffect> extends StatefulWidget {
  final bool Function(E effect)? listenWhen;
  final void Function(E effect) onEffect;
  final Widget child;

  const EffectListener({super.key, required this.onEffect, required this.child, this.listenWhen});

  @override
  State<EffectListener<E>> createState() => _EffectListenerState<E>();
}

class _EffectListenerState<E extends IronEffect> extends State<EffectListener<E>> {
  StreamSubscription? _subscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription?.cancel();
    _subscription = IronLocator.instance.find<SagaProcessor>().effectStream.listen((effect) {
      if (effect is E) {
        if (widget.listenWhen == null || widget.listenWhen!(effect)) {
          widget.onEffect(effect);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
