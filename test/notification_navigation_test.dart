import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hello/services/notification_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationNavigation.resetForTest();
  });

  test(
    'notification destination survives app restart until consumed after login',
    () async {
      await NotificationNavigation.remember('immune');

      // Model a fresh app process by clearing memory while keeping preferences.
      NotificationNavigation.resetForTest();
      await NotificationNavigation.restore();
      expect(NotificationNavigation.take(), 'immune');
      expect(NotificationNavigation.take(), isNull);
    },
  );

  test('a notification link remains queued through reauthentication', () async {
    await NotificationNavigation.restoreLinkedTopic('sleep');
    NotificationNavigation.resetForTest();
    await NotificationNavigation.restore();
    expect(NotificationNavigation.take(), 'sleep');
  });
}
