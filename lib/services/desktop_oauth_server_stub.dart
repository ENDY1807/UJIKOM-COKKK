import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleOAuthProfile {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final String? idToken;

  const GoogleOAuthProfile({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    this.idToken,
  });
}

class DesktopOAuthServer {
  static Future<AuthSessionUrlResponse?> listenForOAuthCallback({int port = 3000}) async {
    return null;
  }

  static Future<GoogleOAuthProfile?> listenForGoogleOAuthDirect({int port = 3000}) async {
    return null;
  }

  static Future<void> openUrlInBrowser(String url) async {}

  static Future<void> stop() async {}
}
