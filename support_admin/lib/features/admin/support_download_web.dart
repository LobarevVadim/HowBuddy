import 'package:web/web.dart' as web;

void openSupportAttachment(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
