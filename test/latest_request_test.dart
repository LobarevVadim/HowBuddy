import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/services/latest_request.dart';

void main() {
  test(
    'late read cannot replace a newer read or authoritative mutation',
    () async {
      final guard = LatestRequest();
      var balance = 0;
      final first = Completer<int>();
      final second = Completer<int>();
      Future<void> load(Future<int> value) async {
        final version = guard.begin();
        final result = await value;
        if (guard.owns(version)) balance = result;
      }

      final a = load(first.future);
      final b = load(second.future);
      second.complete(4);
      await b;
      first.complete(5);
      await a;
      expect(balance, 4);
      final delayed = Completer<int>();
      final c = load(delayed.future);
      guard.invalidate();
      balance = 3;
      delayed.complete(4);
      await c;
      expect(balance, 3);
    },
  );
}
