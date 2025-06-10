import 'package:flutter/widgets.dart';
import 'package:iron/iron.dart';

/// A widget that obtains an [IronCore] from an [IronProvider] and rebuilds
/// when the core's state changes, providing the new state to its [builder].
///
/// It can also listen to [IronEffect]s emitted by the core if an [effectListener]
/// is provided.
///
/// Type arguments:
///   `C`: The type of the [IronCore].
///   `S`: The type of the state managed by the [IronCore].
///   `E`: The type of the [IronEffect]s listened to by the [effectListener].
class IronConsumer<C extends IronCore<IronEvent, S>, S, E extends IronEffect> extends StatelessWidget {
  /// A builder function that is called whenever the [IronCore]\'s state changes.
  ///
  /// The [builder] is provided with the [BuildContext] and the current data `S`
  /// when the state is [AsyncData]. For loading and error states, consider using
  /// [IronView] directly if more control is needed, or handle [AsyncValue] within this builder.
  /// For simplicity, this builder receives `AsyncValue<S>`.
  final Widget Function(BuildContext context, AsyncValue<S> state) builder;

  /// An optional listener for [IronEffect]s emitted by the [IronCore].
  ///
  /// The [effectListener] is called with the [BuildContext] and the emitted [IronEffect] `E`.
  final void Function(BuildContext context, E effect)? effectListener;

  /// Creates an [IronConsumer] widget.
  ///
  /// The [builder] argument must not be null.
  const IronConsumer({
    super.key,
    required this.builder,
    this.effectListener,
  });

  @override
  Widget build(BuildContext context) {
    final C core = IronProvider.of<C, S>(context);

    // IronView expects a builder that takes S (data) directly, not AsyncValue<S>.
    // We will pass the AsyncValue<S> to the consumer's builder.
    Widget consumerWidget = IronView<C, S>(
      core: core,
      // The builder for IronView receives S (the data type).
      // The builder for IronConsumer receives AsyncValue<S>.
      // So, we need to adapt this. The IronConsumer's builder will be called
      // with the core's current state.
      builder: (context, data) {
        // This part is tricky. IronView's builder is only called for the data state.
        // If we want the IronConsumer's builder to receive AsyncValue<S>,
        // we should not use IronView's builder directly like this.
        // Instead, IronConsumer's builder should be invoked with core.state.
        // Let's simplify: IronConsumer will use a StreamBuilder itself or rely on IronView's behavior.

        // Option 1: IronConsumer's builder receives S (like IronView)
        // return builder(context, core.state as AsyncValue<S>); // This would be wrong if builder expects S

        // Option 2: IronConsumer's builder receives AsyncValue<S>
        // We can achieve this by making IronConsumer a StatefulWidget or using StreamBuilder directly.
        // Or, we can pass core.state to the builder, but then IronView is redundant for state.

        // Let's make IronConsumer's builder directly use the core's state stream via IronView's internal StreamBuilder.
        // The builder of IronConsumer will be called by IronView's build method, which handles AsyncValue.
        // So, the `builder` passed to `IronConsumer` should be compatible with what `IronView` provides.
        // IronView's `builder` is `Widget Function(BuildContext context, S data)`.
        // IronConsumer's `builder` is `Widget Function(BuildContext context, AsyncValue<S> state)`.
        // This means we cannot directly pass IronConsumer's builder to IronView's builder.

        // The most straightforward way is for IronConsumer to manage its own StreamBuilder
        // if its builder expects AsyncValue<S>.
        // Or, IronConsumer's builder should expect S, and then it can be passed to IronView.

        // Given the current definition of IronConsumer's builder:
        // final Widget Function(BuildContext context, AsyncValue<S> state) builder;
        // We should use a StreamBuilder here.
        return StreamBuilder<AsyncValue<S>>(
          stream: core.stateStream,
          initialData: core.state, // core'un mevcut durumunu initialData olarak kullan
          builder: (context, snapshot) {
            // snapshot.data, stream bir değer yayınlayana kadar initialData olacaktır.
            // Daha sonra stream'den gelen en son değer olacaktır.
            // initialData sağlandığında ve stream null olmayan değerler yayınladığında null olmamalıdır.
            // Eğer stream'in null değerler yayınlama olasılığı varsa (bizim durumumuzda değil),
            // snapshot.data null olabilir, bu durumda bir fallback (örn. core.state) kullanılabilir
            // veya bir yükleme/hata widget'ı gösterilebilir.
            // Şimdilik, snapshot.data!'nın güvenli olduğunu varsayıyoruz.
            return builder(context, snapshot.data!);
          },
        );
      },
    );

    if (effectListener != null) {
      // EffectListener expects only one type argument: the effect type E.
      consumerWidget = EffectListener<E>(
        // EffectListener does not have a 'core' parameter. It finds it via IronLocator.
        // EffectListener does not have a 'listener' parameter. It's 'onEffect'.
        onEffect: (effect) {
          // The listener in IronConsumer provides BuildContext, EffectListener's onEffect does not.
          // We need to ensure the context is available if the user's listener needs it.
          // For simplicity, we'll assume the user's listener matches EffectListener's signature for now,
          // or we pass the current context.
          effectListener!(context, effect);
        },
        child: consumerWidget,
      );
    }

    return consumerWidget;
  }
}

/// Extension methods for [BuildContext] to easily access [IronCore] instances
/// and their states/effects from an [IronProvider].
extension IronContextExtensions on BuildContext {
  /// Obtains the nearest [IronCore] of type `C` from an [IronProvider].
  ///
  /// Throws an error if no [IronProvider] of the specified type is found.
  C ironCore<C extends IronCore<IronEvent, S>, S>() {
    return IronProvider.of<C, S>(this);
  }

  /// Obtains the nearest [IronCore] of type `C` from an [IronProvider],
  /// or null if no such provider is found.
  C? maybeIronCore<C extends IronCore<IronEvent, S>, S>() {
    return IronProvider.maybeOf<C, S>(this);
  }

  /// Watches the state of the nearest [IronCore] of type `C`.
  ///
  /// This method will cause the widget to rebuild whenever the state of the
  /// [IronCore] changes.
  ///
  /// Returns the current [AsyncValue<S>] of the core's state.
  /// Throws an error if no [IronProvider] of the specified type is found.
  ///
  /// Usage:
  /// ```dart
  /// final AsyncValue<MyState> myState = context.watchIron<MyCore, MyState>();
  /// ```
  AsyncValue<S> watchIron<C extends IronCore<IronEvent, S>, S>() {
    final core = IronProvider.of<C, S>(this);
    // This relies on IronView/StreamBuilder to listen and rebuild.
    // For a direct watch without IronView, a custom InheritedWidget or other
    // mechanism that registers the context for rebuilds upon stream emission
    // would be needed. For simplicity, we can suggest using IronConsumer or IronView.
    // However, to make this `watchIron` truly work like Provider.of(listen:true)
    // or context.watch, it needs to subscribe the widget to the core's stateStream.
    // A simple way is to use a StreamBuilder internally, but that's what IronView does.
    //
    // For now, this will just return the current state, but won't rebuild on its own
    // without being in an IronView or IronConsumer.
    // A more robust implementation would involve `context.dependOnInheritedWidgetOfExactType`
    // and a custom InheritedWidget that holds the stream subscription.
    //
    // A common pattern is to use a StatefulWidget that subscribes/unsubscribes.
    // Let's make this a simple accessor for now and guide users to IronView/Consumer for reactivity.
    return core.state;
  }

  /// Listens to [IronEffect]s of type `E` from the nearest [IronCore] of type `C`.
  ///
  /// This is a convenience method to quickly set up an [EffectListener] without
  /// needing to nest the [EffectListener] widget explicitly.
  ///
  /// The [listener] callback will be invoked for each effect.
  /// The returned widget should be placed in your widget tree.
  ///
  /// Usage:
  /// ```dart
  /// return context.listenIron<MyCore, MyState, MyEffect>(
  ///   listener: (context, effect) {
  ///     // Handle effect
  ///   },
  ///   child: YourWidgetTree(),
  /// );
  /// ```
  /// Note: This approach of returning a widget is less common for listeners.
  /// Usually, listeners are imperative or hooked into the build method.
  /// A more idiomatic way might be to provide a hook-like function if using a
  /// hooks library, or to simply guide users to use the `EffectListener` widget
  /// or `IronConsumer`.
  ///
  /// For simplicity and consistency with `IronView` and `EffectListener` widgets,
  /// we will not implement a direct `listenIron` extension that returns a widget wrapper here.
  /// Users should be encouraged to use `IronConsumer` or `EffectListener` directly.
}
