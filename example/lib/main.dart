import 'package:flutter/material.dart';
import 'package:iron/iron.dart';

void main() {
  IronLocator.instance.registerSingleton(InterceptorRegistry(), global: true);
  IronLocator.instance.registerSingleton(SagaProcessor(), global: true);
  IronLocator.instance.find<InterceptorRegistry>().register(LoggingInterceptor(openDebug: true));
  IronLocator.instance.registerLazySingleton(() => TodoCore(), global: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Iron Todo App',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const TodoPage(),
    );
  }
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _textController = TextEditingController();
  final _todoCore = IronLocator.instance.find<TodoCore>();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EffectListener<TodoDeletionSuccess>(
      onEffect: (effect) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Todo silindi.'),
              action: SnackBarAction(
                label: 'GERİ AL',
                onPressed: () {
                  _todoCore.add(TodoUndoDeletion(effect.deletedTodo));
                },
              ),
            ),
          );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Iron Todo')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(labelText: 'Ne yapılması gerekiyor?'),
                      onSubmitted: (value) {
                        _todoCore.add(TodoAdded(value));
                        _textController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _todoCore.add(TodoAdded(_textController.text));
                      _textController.clear();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const TodoFilterButtons(),
              const SizedBox(height: 16),
              Expanded(
                child: IronView<TodoCore, TodoState>(
                  core: _todoCore,
                  loadingBuilder: (context) => const Center(child: CircularProgressIndicator()),
                  errorBuilder: (context, error) => Center(child: Text('Bir hata oluştu: $error')),
                  builder: (context, state) {
                    final todos = state.filteredTodos;
                    if (todos.isEmpty) {
                      return const Center(child: Text('Görünüşe göre her şey tamam! 🎉'));
                    }
                    return ListView.builder(
                      itemCount: todos.length,
                      itemBuilder: (context, index) {
                        final todo = todos[index];
                        return TodoTile(todo: todo);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodoFilterButtons extends StatelessWidget {
  const TodoFilterButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final todoCore = IronLocator.instance.find<TodoCore>();
    return IronView<TodoCore, TodoState>(
      core: todoCore,
      buildWhen: (previous, current) => previous.filter != current.filter,
      builder: (context, state) {
        return SegmentedButton<TodoFilter>(
          segments: const [
            ButtonSegment(value: TodoFilter.all, label: Text('Tümü')),
            ButtonSegment(value: TodoFilter.active, label: Text('Aktif')),
            ButtonSegment(value: TodoFilter.completed, label: Text('Tamamlandı')),
          ],
          selected: {state.filter},
          onSelectionChanged: (newSelection) {
            todoCore.add(TodoFilterChanged(newSelection.first));
          },
        );
      },
    );
  }
}

class TodoTile extends StatelessWidget {
  final Todo todo;
  const TodoTile({super.key, required this.todo});

  @override
  Widget build(BuildContext context) {
    final todoCore = IronLocator.instance.find<TodoCore>();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Checkbox(value: todo.isCompleted, onChanged: (_) => todoCore.add(TodoToggled(todo.id))),
        title: Text(
          todo.description,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? Colors.grey : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => todoCore.add(TodoRemoved(todo.id)),
        ),
      ),
    );
  }
}

enum TodoFilter { all, active, completed }

@immutable
class Todo {
  final String id;
  final String description;
  final bool isCompleted;

  const Todo({required this.id, required this.description, this.isCompleted = false});

  Todo copyWith({String? description, bool? isCompleted}) {
    return Todo(id: id, description: description ?? this.description, isCompleted: isCompleted ?? this.isCompleted);
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      description: json['description'] as String,
      isCompleted: json['isCompleted'] as bool,
    );
  }
  Map<String, dynamic> toJson() => {'id': id, 'description': description, 'isCompleted': isCompleted};
}

@immutable
class TodoState {
  final List<Todo> todos;
  final TodoFilter filter;

  const TodoState({this.todos = const [], this.filter = TodoFilter.all});

  List<Todo> get filteredTodos {
    switch (filter) {
      case TodoFilter.active:
        return todos.where((todo) => !todo.isCompleted).toList();
      case TodoFilter.completed:
        return todos.where((todo) => todo.isCompleted).toList();
      case TodoFilter.all:
        return todos;
    }
  }

  TodoState copyWith({List<Todo>? todos, TodoFilter? filter}) {
    return TodoState(todos: todos ?? this.todos, filter: filter ?? this.filter);
  }

  factory TodoState.fromJson(Map<String, dynamic> json) {
    return TodoState(
      todos: (json['todos'] as List).map((i) => Todo.fromJson(i)).toList(),
      filter: TodoFilter.values.byName(json['filter'] as String),
    );
  }
  Map<String, dynamic> toJson() => {'todos': todos.map((t) => t.toJson()).toList(), 'filter': filter.name};
}

abstract class TodoEvent extends IronEvent {}

class TodoAdded extends TodoEvent {
  final String description;
  TodoAdded(this.description);
}

class TodoRemoved extends TodoEvent {
  final String id;
  TodoRemoved(this.id);
}

class TodoToggled extends TodoEvent {
  final String id;
  TodoToggled(this.id);
}

class TodoFilterChanged extends TodoEvent {
  final TodoFilter newFilter;
  TodoFilterChanged(this.newFilter);
}

class TodoUndoDeletion extends TodoEvent {
  final Todo todoToRestore;
  TodoUndoDeletion(this.todoToRestore);
}

abstract class TodoEffect extends IronEffect {
  const TodoEffect({super.origin});
}

class TodoDeletionSuccess extends TodoEffect {
  final Todo deletedTodo;
  const TodoDeletionSuccess(this.deletedTodo) : super(origin: TodoCore);
}

class TodoCore extends PersistentIronCore<TodoEvent, TodoState> {
  TodoCore()
    : super(
        adapter: LocalFileAdapter(fileName: 'todo_app_state.json'),
        initialStateFactory: () => const TodoState(),
        fromJson: (json) => TodoState.fromJson(json),
        toJson: (state) => state.toJson(),
      ) {
    on<TodoAdded>(_onTodoAdded);
    on<TodoRemoved>(_onTodoRemoved);
    on<TodoToggled>(_onTodoToggled);
    on<TodoFilterChanged>(_onTodoFilterChanged);
    on<TodoUndoDeletion>(_onTodoUndoDeletion);
  }

  void _onTodoAdded(TodoAdded event) {
    if (event.description.trim().isEmpty) return;

    final newTodo = Todo(id: DateTime.now().millisecondsSinceEpoch.toString(), description: event.description);

    final updatedTodos = List<Todo>.from(state.value.todos)..insert(0, newTodo);
    updateState(AsyncData(state.value.copyWith(todos: updatedTodos)));
  }

  void _onTodoRemoved(TodoRemoved event) {
    final todoToRemove = state.value.todos.firstWhere((t) => t.id == event.id);
    final updatedTodos = state.value.todos.where((t) => t.id != event.id).toList();

    updateState(AsyncData(state.value.copyWith(todos: updatedTodos)));
    addEffect(TodoDeletionSuccess(todoToRemove));
  }

  void _onTodoToggled(TodoToggled event) {
    final updatedTodos =
        state.value.todos.map((todo) {
          if (todo.id == event.id) {
            return todo.copyWith(isCompleted: !todo.isCompleted);
          }
          return todo;
        }).toList();
    updateState(AsyncData(state.value.copyWith(todos: updatedTodos)));
  }

  void _onTodoFilterChanged(TodoFilterChanged event) {
    updateState(AsyncData(state.value.copyWith(filter: event.newFilter)));
  }

  void _onTodoUndoDeletion(TodoUndoDeletion event) {
    final updatedTodos = List<Todo>.from(state.value.todos)..add(event.todoToRestore);
    updateState(AsyncData(state.value.copyWith(todos: updatedTodos)));
  }
}
