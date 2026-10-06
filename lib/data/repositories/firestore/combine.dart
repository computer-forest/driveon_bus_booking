import 'dart:async';

/// Emits whenever either stream does, once both have produced a value (or,
/// with [bMayFail], once the second has failed, which then counts as
/// [fallbackB]: data only some users may read).
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine, {
  B? fallbackB,
  bool bMayFail = false,
}) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? lastA;
  B? lastB;
  var hasA = false;
  var hasB = false;

  void emit() {
    if (hasA && hasB) controller.add(combine(lastA as A, lastB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: (Object e, StackTrace s) {
        if (bMayFail) {
          lastB = fallbackB;
          hasB = true;
          emit();
        } else {
          controller.addError(e, s);
        }
      });
    },
    // Must return void; see InMemoryValue.watch.
    onCancel: () {
      subA?.cancel();
      subB?.cancel();
    },
  );
  return controller.stream;
}
