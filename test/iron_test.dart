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

  void increment(int value) {
    final currentData = state.dataOrNull;
    final int currentCount = currentData?.count ?? 0;
    runAndUpdate(() async {
      await Future.delayed(Duration.zero);
      return TestState(currentCount + value);
    });
  }

  void causeError() {
    runAndUpdate(() async {
      await Future.delayed(Duration.zero);
      throw Exception('Test Error');
    });
  }

  void testCompute(int value) {
    final currentData = state.dataOrNull;
    final int currentCount = currentData?.count ?? 0;
    computeAndUpdateState<int>((message) async {
      await Future.delayed(Duration.zero);
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
}
