import 'dart:async';

/// A list of records that replays its current contents to every new
/// listener and pushes each later change, the way a live query does.
class InMemoryStore<T> {
  InMemoryStore(Iterable<T> seed) : _items = List<T>.of(seed);

  List<T> _items;
  final _changes = StreamController<List<T>>.broadcast(sync: true);

  List<T> get items => List<T>.unmodifiable(_items);

  Stream<List<T>> watch() {
    late final StreamController<List<T>> controller;
    StreamSubscription<List<T>>? subscription;
    controller = StreamController<List<T>>(
      onListen: () {
        controller.add(items);
        subscription = _changes.stream.listen(controller.add);
      },
      onCancel: () {
        subscription?.cancel();
      },
    );
    return controller.stream;
  }

  void _emit() => _changes.add(items);

  void replaceAll(Iterable<T> values) {
    _items = List<T>.of(values);
    _emit();
  }

  void add(T value) {
    _items = [..._items, value];
    _emit();
  }

  /// Replaces the first record [matches], or appends when none does.
  void upsert(bool Function(T existing) matches, T value) {
    final index = _items.indexWhere(matches);
    if (index < 0) {
      _items = [..._items, value];
    } else {
      _items = [..._items]..[index] = value;
    }
    _emit();
  }

  void removeWhere(bool Function(T existing) matches) {
    _items = _items.where((e) => !matches(e)).toList();
    _emit();
  }
}

/// A single value with the same replay-then-push behaviour.
class InMemoryValue<T> {
  InMemoryValue(this._value);

  T _value;
  final _changes = StreamController<T>.broadcast(sync: true);

  T get value => _value;

  set value(T next) {
    _value = next;
    _changes.add(next);
  }

  Stream<T> watch() {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(_value);
        subscription = _changes.stream.listen(controller.add);
      },
      onCancel: () {
        subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
