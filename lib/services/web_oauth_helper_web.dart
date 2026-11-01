import 'package:web/web.dart' as web;

class WebOAuthHelper {
  static void redirectTo(String url) {
    web.window.location.assign(url);
  }

  static void cleanUrlHash() {
    web.window.history.replaceState(null, '', web.window.location.pathname);
  }
}

