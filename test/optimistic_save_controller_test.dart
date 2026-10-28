import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello/features/profile/optimistic_save_controller.dart';

void main() {
  test(
    'language preview and failed save restore the same parent preference snapshot',
    () async {
      final pending = Completer<({String language, int age})>();
      final published = <({String language, int age})>[];
      final controller = OptimisticSaveController(
        initialValue: (language: 'en', age: 18),
        persist: (_) => pending.future,
      );
      addTearDown(controller.dispose);
      final saving = controller.save(
        (language: 'fr', age: 18),
        onPreview: published.add,
        onRollback: published.add,
      );
      expect(controller.value.language, 'fr');
      expect(controller.isSaving, isTrue);
      expect(published, [(language: 'fr', age: 18)]);
      pending.completeError(StateError('offline'));
      await expectLater(saving, throwsStateError);
      expect(controller.value, (language: 'en', age: 18));
      expect(controller.isSaving, isFalse);
      expect(published, [(language: 'fr', age: 18), (language: 'en', age: 18)]);
    },
  );

  test(
    'avatar preview stays local; parent receives only the normalized saved value',
    () async {
      final saved = Completer<int>();
      final commits = <int>[];
      final controller = OptimisticSaveController(
        initialValue: 0,
        persist: (_) => saved.future,
      );
      addTearDown(controller.dispose);
      final operation = controller.save(3, onCommit: commits.add);
      expect(controller.value, 3);
      expect(commits, isEmpty);
      saved.complete(2);
      expect(await operation, isTrue);
      expect(controller.value, 2);
      expect(commits, [2]);
    },
  );

  test(
    'overlapping or unchanged saves do not issue duplicate writes',
    () async {
      var writes = 0;
      final pending = Completer<int>();
      final controller = OptimisticSaveController(
        initialValue: 1,
        persist: (_) {
          writes++;
          return pending.future;
        },
      );
      addTearDown(controller.dispose);
      expect(await controller.save(1), isFalse);
      final first = controller.save(2);
      expect(await controller.save(3), isFalse);
      expect(writes, 1);
      pending.complete(2);
      await first;
      expect(controller.value, 2);
    },
  );

  test(
    'disposing during save prevents stale callbacks and notifications',
    () async {
      final pending = Completer<int>();
      final commits = <int>[];
      final controller = OptimisticSaveController(
        initialValue: 1,
        persist: (_) => pending.future,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      final operation = controller.save(2, onCommit: commits.add);
      expect(notifications, 1);
      controller.dispose();
      pending.complete(2);
      expect(await operation, isFalse);
      expect(commits, isEmpty);
      expect(notifications, 1);
    },
  );
}
