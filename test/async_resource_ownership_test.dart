import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello/services/async_resource_ownership.dart';

void main() {
  test(
    'logout invalidates pending registration before the bearer is cleared',
    () async {
      var generation = 1;
      final ownership = SessionWorkOwnership(generation: () => generation);
      final old = ownership.activate('a');
      expect(ownership.activate('a'), old);
      final timezoneLookup = Completer<void>();
      var uploads = 0;
      final pending = () async {
        await timezoneLookup.future;
        if (ownership.owns(old)) uploads++;
      }();
      ownership.invalidate();
      timezoneLookup.complete();
      await pending;
      expect(uploads, 0);
      final newScope = ownership.activate('b');
      expect(ownership.owns(old), isFalse);
      expect(ownership.owns(newScope), isTrue);
      generation++;
      expect(ownership.owns(newScope), isFalse);
      expect(ownership.activate('b'), isNot(newScope));
    },
  );

  test(
    'same registration scope shares work; changed scope waits for old work',
    () async {
      final flight = SerialSingleFlight<String, int>();
      final first = Completer<int>();
      final calls = <String>[];
      final old = flight.run('account-a', () {
        calls.add('a');
        return first.future;
      });
      final duplicate = flight.run('account-a', () async {
        calls.add('duplicate');
        return 0;
      });
      final next = flight.run('account-b', () async {
        calls.add('b');
        return 2;
      });
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['a']);
      expect(identical(old, duplicate), isTrue);
      first.complete(1);
      expect(await old, 1);
      expect(await next, 2);
      expect(calls, ['a', 'b']);
    },
  );

  test('a failed registration releases the queue for retry', () async {
    final flight = SerialSingleFlight<String, int>();
    await expectLater(
      flight.run('a', () async => throw StateError('offline')),
      throwsStateError,
    );
    expect(await flight.run('a', () async => 7), 7);
  });

  test('timed out loads dispose a resource delivered later', () async {
    late void Function(Object) loaded;
    final disposed = <Object>[];
    final future = loadOwnedResource<Object>(
      load: (onLoaded, onError) => loaded = onLoaded,
      dispose: disposed.add,
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(future, throwsA(isA<TimeoutException>()));
    final resource = Object();
    loaded(resource);
    expect(disposed, [resource]);
  });

  test('successful loads transfer disposal ownership to the caller', () async {
    final resource = Object();
    final disposed = <Object>[];
    expect(
      await loadOwnedResource<Object>(
        load: (onLoaded, onError) => onLoaded(resource),
        dispose: disposed.add,
        timeout: const Duration(seconds: 1),
      ),
      same(resource),
    );
    expect(disposed, isEmpty);
  });

  test(
    'asynchronous native load failures surface without waiting for timeout',
    () async {
      await expectLater(
        loadOwnedResource<Object>(
          load: (onLoaded, onError) async => throw StateError('native failure'),
          dispose: (_) {},
          timeout: const Duration(seconds: 10),
        ),
        throwsStateError,
      );
    },
  );
}
