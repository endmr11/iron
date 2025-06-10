import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iron/iron.dart';
import 'package:mocktail/mocktail.dart';

class MockSagaProcessor extends Mock implements SagaProcessor {}

class MockInterceptorRegistry extends Mock implements InterceptorRegistry {}

class FakeIronCore extends Fake implements IronCore<IronEvent, dynamic> {}

class FakeIronEvent extends Fake implements IronEvent {}

class FakeAsyncValue extends Fake implements AsyncValue<dynamic> {}

class FakeStackTrace extends Fake implements StackTrace {}

class FakeIronEffect extends Fake implements IronEffect {}

class TestEvent extends IronEvent {
  final int value;
  const TestEvent(this.value);
}

class TestState {
  final int count;
  TestState(this.count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TestState && runtimeType == other.runtimeType && count == other.count;

  @override
  int get hashCode => count.hashCode;
}

class TestCore extends IronCore<TestEvent, TestState> {
  TestCore(super.initialState);
  TestCore.loading() : super.loading();

  Future<void> increment(int value) {
    final currentData = state.dataOrNull;
    final int currentCount = currentData?.count ?? 0;
    return runAndUpdate(() async {
      return TestState(currentCount + value);
    });
  }

  void causeError() {
    runAndUpdate(() async {
      throw Exception('Test Error');
    });
  }

  void testCompute(int value) {
    final currentData = state.dataOrNull;
    final int currentCount = currentData?.count ?? 0;
    computeAndUpdateState<int>((message) async {
      return TestState(currentCount + message);
    }, value);
  }

  void dispatchEffect(IronEffect effect) {
    addEffect(effect);
  }
}

class TestEffect extends IronEffect {
  final String message;
  const TestEffect(this.message);
}

void main() {
  late MockSagaProcessor mockSagaProcessor;
  late MockInterceptorRegistry mockInterceptorRegistry;

  setUpAll(() {
    registerFallbackValue(FakeIronCore());
    registerFallbackValue(FakeIronEvent());
    registerFallbackValue(FakeAsyncValue());
    registerFallbackValue(FakeStackTrace());
    registerFallbackValue(FakeIronEffect());
    mockSagaProcessor = MockSagaProcessor();
    mockInterceptorRegistry = MockInterceptorRegistry();

    when(() => mockSagaProcessor.registerCore(any())).thenReturn(null);
    when(() => mockSagaProcessor.effectStream).thenAnswer((_) => Stream<IronEffect>.empty());
    when(() => mockInterceptorRegistry.notifyEvent(any(), any())).thenReturn(null);
    when(() => mockInterceptorRegistry.notifyStateChange(any(), any(), any())).thenReturn(null);
    when(() => mockInterceptorRegistry.notifyError(any(), any(), any())).thenReturn(null);
    when(() => mockInterceptorRegistry.notifyEffect(any(), any())).thenReturn(null);

    IronLocator.instance.registerSingleton<SagaProcessor>(mockSagaProcessor);
    IronLocator.instance.registerSingleton<InterceptorRegistry>(mockInterceptorRegistry);
  });

  group('IronCore Tests', () {
    test('Initial state is set correctly', () {
      final initialState = TestState(0);
      final core = TestCore(initialState);
      expect(core.state, AsyncData(initialState));
    });

    test('Loading constructor sets state to AsyncLoading', () {
      final core = TestCore.loading();
      expect(core.state, isA<AsyncLoading<TestState>>());
    });

    test('Event handler is called when event is added', () async {
      final core = TestCore(TestState(0));
      bool handlerCalled = false;
      const testEvent = TestEvent(5);

      core.on<TestEvent>((event) {
        handlerCalled = true;
        expect(event, testEvent);
      });

      core.add(testEvent);
      expect(handlerCalled, isTrue);
    });

    test('runAndUpdate updates state to AsyncLoading then AsyncData on success', () async {
      final core = TestCore(TestState(0));
      final expectedStates = [const AsyncLoading<TestState>(), AsyncData(TestState(5))];
      expectLater(core.stateStream, emitsInOrder(expectedStates));
      core.increment(5);
    });

    test('runAndUpdate updates state to AsyncLoading then AsyncError on failure', () async {
      final core = TestCore(TestState(0));
      final expectedStates = [const AsyncLoading<TestState>(), isA<AsyncError<TestState>>()];
      expectLater(core.stateStream, emitsInOrder(expectedStates));
      core.causeError();
    });

    test('computeAndUpdateState updates state correctly', () async {
      final core = TestCore(TestState(10));
      final expectedStates = [const AsyncLoading<TestState>(), AsyncData(TestState(15))];
      expectLater(core.stateStream, emitsInOrder(expectedStates));
      core.testCompute(5);
    });

    test('addEffect emits effect through effectStream', () {
      final core = TestCore(TestState(0));
      const effect = TestEffect('Test Effect Message');
      expectLater(core.effectStream, emits(effect));
      core.dispatchEffect(effect);
    });

    test('onDebounced only calls handler after delay', () async {
      final core = TestCore(TestState(0));
      int handlerCallCount = 0;
      const delay = Duration(milliseconds: 100);

      core.onDebounced<TestEvent>((event) {
        handlerCallCount++;
      }, delay);

      core.add(const TestEvent(1));
      core.add(const TestEvent(2));
      core.add(const TestEvent(3));

      expect(handlerCallCount, 0);
      await Future.delayed(delay * 2);
      expect(handlerCallCount, 1);
    });

    test('onThrottled calls handler immediately then ignores subsequent calls within delay', () async {
      final core = TestCore(TestState(0));
      int handlerCallCount = 0;
      const delay = Duration(milliseconds: 100);

      core.onThrottled<TestEvent>((event) {
        handlerCallCount++;
      }, delay);

      core.add(const TestEvent(1));
      expect(handlerCallCount, 1);

      core.add(const TestEvent(2));
      expect(handlerCallCount, 1);

      await Future.delayed(delay * 2);

      core.add(const TestEvent(3));
      expect(handlerCallCount, 2);
    });

    test('dispose closes streams', () {
      final core = TestCore(TestState(0));
      core.on<TestEvent>((event) {});
      core.dispose();
      expect(() => core.add(const TestEvent(1)), throwsA(isA<StateError>()));
      expect(() => core.updateState(AsyncData(TestState(1))), throwsA(isA<StateError>()));
      expect(() => core.dispatchEffect(const TestEffect("disposed")), throwsA(isA<StateError>()));
    });
  });

  group('IronProvider Tests', () {
    testWidgets('IronProvider provides core to descendants', (WidgetTester tester) async {
      final initialState = TestState(10);
      final core = TestCore(initialState);
      late TestCore? providedCore;

      await tester.pumpWidget(
        IronProvider<TestCore, TestState>(
          core: core,
          child: Builder(
            builder: (context) {
              providedCore = IronProvider.of<TestCore, TestState>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(providedCore, core);
      expect(providedCore?.state, AsyncData(initialState));
    });

    testWidgets('IronProvider.maybeOf returns core if found', (WidgetTester tester) async {
      final core = TestCore(TestState(0));
      late TestCore? providedCore;

      await tester.pumpWidget(
        IronProvider<TestCore, TestState>(
          core: core,
          child: Builder(
            builder: (context) {
              providedCore = IronProvider.maybeOf<TestCore, TestState>(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(providedCore, core);
    });

    testWidgets('IronProvider.maybeOf returns null if not found', (WidgetTester tester) async {
      late TestCore? providedCore;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            providedCore = IronProvider.maybeOf<TestCore, TestState>(context);
            return const SizedBox();
          },
        ),
      );
      expect(providedCore, isNull);
    });

    testWidgets('IronProvider.of throws if not found', (WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(() => IronProvider.of<TestCore, TestState>(context), throwsA(isA<AssertionError>()));
            return const SizedBox();
          },
        ),
      );
    });
  });

  group('IronConsumer Tests', () {
    testWidgets('IronConsumer rebuilds on state change and listens to effects', (WidgetTester tester) async {
      final core = TestCore(TestState(0));
      final List<AsyncValue<TestState>> builtStates = [];
      final List<TestEffect> receivedEffects = [];
      const testEffect = TestEffect('Consumer Effect');

      final effectController = StreamController<IronEffect>.broadcast();
      when(() => mockSagaProcessor.effectStream).thenAnswer((_) => effectController.stream);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IronProvider<TestCore, TestState>(
            core: core,
            child: IronConsumer<TestCore, TestState, TestEffect>(
              builder: (context, state) {
                builtStates.add(state);
                return Text(state.dataOrNull?.count.toString() ?? 'loading');
              },
              effectListener: (context, effect) {
                receivedEffects.add(effect);
              },
            ),
          ),
        ),
      );

      expect(builtStates.length, 1);
      expect(builtStates.first, isA<AsyncData<TestState>>());
      expect((builtStates.first as AsyncData<TestState>).data.count, 0);
      expect(find.text('0'), findsOneWidget);

      await core.increment(5);
      await tester.pump();
      await tester.pump();

      expect(builtStates.length, anyOf(2, 3));
      if (builtStates.length == 3) {
        expect(builtStates[1], isA<AsyncLoading<TestState>>());
        expect(builtStates[2], isA<AsyncData<TestState>>());
        expect((builtStates[2] as AsyncData<TestState>).data.count, 5);
      } else {
        expect(builtStates[1], isA<AsyncData<TestState>>());
        expect((builtStates[1] as AsyncData<TestState>).data.count, 5);
      }
      expect(find.text('5'), findsOneWidget);

      core.dispatchEffect(testEffect);
      effectController.add(testEffect);
      await tester.pumpAndSettle();

      expect(receivedEffects.length, 1);
      expect(receivedEffects.first, testEffect);
      await effectController.close();
    });
  });

  group('IronContextExtensions Tests', () {
    testWidgets('context.ironCore returns core from IronProvider', (WidgetTester tester) async {
      final core = TestCore(TestState(0));
      late TestCore? retrievedCore;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IronProvider<TestCore, TestState>(
            core: core,
            child: Builder(
              builder: (context) {
                retrievedCore = context.ironCore<TestCore, TestState>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(retrievedCore, core);
    });

    testWidgets('context.maybeIronCore returns core if present', (WidgetTester tester) async {
      final core = TestCore(TestState(0));
      late TestCore? retrievedCore;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IronProvider<TestCore, TestState>(
            core: core,
            child: Builder(
              builder: (context) {
                retrievedCore = context.maybeIronCore<TestCore, TestState>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(retrievedCore, core);
    });

    testWidgets('context.maybeIronCore returns null if not present', (WidgetTester tester) async {
      late TestCore? retrievedCore;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              retrievedCore = context.maybeIronCore<TestCore, TestState>();
              return const SizedBox();
            },
          ),
        ),
      );
      expect(retrievedCore, isNull);
    });

    testWidgets('context.watchIron returns current state and rebuilds widget', (WidgetTester tester) async {
      final core = TestCore(TestState(0));
      AsyncValue<TestState>? watchedState;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IronProvider<TestCore, TestState>(
            core: core,
            child: StreamBuilder<AsyncValue<TestState>>(
                stream: core.stateStream,
                initialData: core.state,
                builder: (context, snapshot) {
                  watchedState = context.watchIron<TestCore, TestState>();
                  return Text(watchedState?.dataOrNull?.count.toString() ?? 'N/A');
                }),
          ),
        ),
      );

      expect(watchedState, isA<AsyncData<TestState>>());
      expect((watchedState as AsyncData<TestState>).data.count, 0);
      expect(find.text('0'), findsOneWidget);

      core.increment(7);
      await tester.pumpAndSettle();

      expect(watchedState, isA<AsyncData<TestState>>());
      expect((watchedState as AsyncData<TestState>).data.count, 7);
      expect(find.text('7'), findsOneWidget);
    });
  });
}
