import 'dart:js_interop';

@JS('howBuddyShowNotification')
external void _showNotification(
  JSString title,
  JSString body,
  JSString topicId,
);

void showBrowserNotification(String title, String body, String topicId) {
  _showNotification(title.toJS, body.toJS, topicId.toJS);
}
