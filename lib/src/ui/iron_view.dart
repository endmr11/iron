import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iron/src/core/async_value.dart';
import 'package:iron/src/core/iron_core_base.dart';

/// A widget that listens to an IronCore instance and rebuilds when the state changes.
/// It provides a way to build UI based on the current state of the IronCore.
/// The `buildWhen` function can be used to determine whether to rebuild based on the previous and current state.
/// The `builder` function is called with the current state data to build the UI.
/// The `loadingBuilder` and `errorBuilder` functions can be used to customize the loading and error states.
/// This widget is useful for scenarios where you want to display data from an IronCore instance in a reactive manner.
class IronView<C extends IronCore, S> extends StatefulWidget {
  final C core;
  final bool Function(S previousData, S currentData)? buildWhen;
  final Widget Function(BuildContext context, S data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const IronView({
    super.key,
    required this.core,
    required this.builder,
    this.buildWhen,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<IronView<C, S>> createState() => _IronViewState<C, S>();
}

class _IronViewState<C extends IronCore, S> extends State<IronView<C, S>> {
  late StreamSubscription _subscription;
  late AsyncValue<S> _currentState;

  @override
  void initState() {
    super.initState();
    _currentState = widget.core.state as AsyncValue<S>;
    _subscription = widget.core.stateStream.listen((newState) {
      if (!mounted) return;

      final previousState = _currentState;
      _currentState = newState as AsyncValue<S>;

      if (widget.buildWhen != null && previousState is AsyncData<S> && _currentState is AsyncData<S>) {
        if (widget.buildWhen!((previousState).data, (_currentState as AsyncData<S>).data)) {
          setState(() {});
        }
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _currentState.when(
      loading: () => widget.loadingBuilder?.call(context) ?? const Center(child: CircularProgressIndicator()),
      data: (data) => widget.builder(context, data),
      error: (error, _) => widget.errorBuilder?.call(context, error) ?? Center(child: Text('Hata: $error')),
    );
  }
}
