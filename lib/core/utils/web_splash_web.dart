import 'package:web/web.dart' as web;

void notifyWebAppReady() {
  web.window.dispatchEvent(web.Event('hudoori-app-ready'));
}
