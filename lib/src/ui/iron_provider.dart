
import 'package:flutter/widgets.dart';
import 'package:iron/iron.dart';

/// A widget that provides an [IronCore] to its descendants.
///
/// This widget is used to make an [IronCore] instance available to any widget
/// in its subtree. It uses [InheritedWidget] to achieve this.
///
/// Type arguments:
///   `C`: The type of the [IronCore].
///   `S`: The type of the state managed by the [IronCore].
class IronProvider<C extends IronCore<IronEvent, S>, S> extends InheritedWidget {
  /// The [IronCore] instance to provide.
  final C core;

  /// Creates an [IronProvider] widget.
  ///
  /// The [core] and [child] arguments must not be null.
  const IronProvider({
    super.key,
    required this.core,
    required super.child,
  });

  /// Returns the [IronCore] instance provided by the nearest [IronProvider]
  /// ancestor.
  ///
  /// If no [IronProvider] ancestor is found, this method will throw an error.
  /// It is recommended to use [maybeOf] if the core might not be available.
  static C of<C extends IronCore<IronEvent, S>, S>(BuildContext context) {
    final IronProvider<C, S>? result = context.dependOnInheritedWidgetOfExactType<IronProvider<C, S>>();
    assert(result != null, 'No IronProvider found in context');
    return result!.core;
  }

  /// Returns the [IronCore] instance provided by the nearest [IronProvider]
  /// ancestor, or null if no such ancestor is found.
  static C? maybeOf<C extends IronCore<IronEvent, S>, S>(BuildContext context) {
    final IronProvider<C, S>? result = context.dependOnInheritedWidgetOfExactType<IronProvider<C, S>>();
    return result?.core;
  }

  @override
  bool updateShouldNotify(IronProvider<C, S> oldWidget) {
    return core != oldWidget.core;
  }
}
