import 'dart:async';

typedef SessionWorkScope = ({String accountId, int generation, int epoch});

/// Account + bearer generation + local logout epoch identify async work.
/// The local epoch also invalidates work before the bearer token is cleared.
class SessionWorkOwnership {
  SessionWorkOwnership({required int Function() generation})
    : _generation = generation;
  final int Function() _generation;
  SessionWorkScope? _current;
  SessionWorkScope? get current => _current;
  int _epoch = 0;
  int get epoch => _epoch;

  SessionWorkScope activate(String accountId) {
    final existing = current;
    final generation = _generation();
    if (existing != null &&
        existing.accountId == accountId &&
        existing.generation == generation) {
      return existing;
    }
    return _current = (
      accountId: accountId,
      generation: generation,
      epoch: ++_epoch,
    );
  }

  bool owns(SessionWorkScope scope) =>
      current == scope && scope.generation == _generation();

  int invalidate() {
    _current = null;
    return ++_epoch;
  }
}

/// Coalesces callers for the same session while serializing platform work
/// across sessions. A failed operation never poisons the queue.
class SerialSingleFlight<K, T> {
  Future<void> _tail = Future<void>.value();
  final Map<K, Future<T>> _pending = {};

  Future<T> run(K key, Future<T> Function() operation) {
    final pending = _pending[key];
    if (pending != null) return pending;
    final result = _tail.then((_) => operation());
    _pending[key] = result;
    void clear() {
      if (identical(_pending[key], result)) _pending.remove(key);
    }

    _tail = result.then<void>(
      (_) => clear(),
      onError: (Object error, StackTrace stack) => clear(),
    );
    return result;
  }
}

/// A callback-based native load may finish after its Future timed out. Retain
/// ownership of such late resources and dispose them rather than leaking them.
Future<T> loadOwnedResource<T>({
  required FutureOr<void> Function(void Function(T), void Function(Object))
  load,
  required void Function(T) dispose,
  required Duration timeout,
}) {
  final result = Completer<T>();
  final timer = Timer(timeout, () {
    if (!result.isCompleted) {
      result.completeError(
        TimeoutException('Resource load timed out.', timeout),
      );
    }
  });
  void fail(Object error) {
    timer.cancel();
    if (!result.isCompleted) result.completeError(error);
  }

  unawaited(
    Future<void>.sync(
      () => load((resource) {
        timer.cancel();
        if (result.isCompleted) {
          dispose(resource);
        } else {
          result.complete(resource);
        }
      }, fail),
    ).catchError((Object error) => fail(error)),
  );
  return result.future;
}
