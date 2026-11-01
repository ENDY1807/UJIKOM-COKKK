import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

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
  static HttpServer? _server;

  /// 1. Loopback untuk browser Supabase Auth resmi
  static Future<AuthSessionUrlResponse?> listenForOAuthCallback({
    int port = 3000,
  }) async {
    try {
      await stop();
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      debugPrint(
        '[DesktopOAuthServer] Listening on http://localhost:$port for OAuth callback...',
      );
    } catch (e) {
      debugPrint('[DesktopOAuthServer] Bind port $port failed: $e');
      return null;
    }

    try {
      await for (final HttpRequest request in _server!) {
        final uri = request.uri;
        final error = uri.queryParameters['error'];
        final errorDesc = uri.queryParameters['error_description'];

        if (error != null) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.html
            ..write('''
              <!DOCTYPE html>
              <html>
              <body style="font-family:sans-serif;text-align:center;padding:50px;">
                <h2 style="color:#DC2626;">Gagal Autentikasi</h2>
                <p>${errorDesc ?? error}</p>
              </body>
              </html>
            ''');
          await request.response.close();
          throw AuthException(errorDesc ?? error);
        }

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(_successHtml());
        await request.response.close();

        final authRes = await Supabase.instance.client.auth.getSessionFromUrl(
          uri,
        );
        return authRes;
      }
    } finally {
      await stop();
    }
    return null;
  }

  /// 2. Direct Google OAuth 2.0 loopback server (Bypass jika provider Supabase belum di-enable di Dashboard)
  static Future<GoogleOAuthProfile?> listenForGoogleOAuthDirect({
    int port = 3000,
  }) async {
    try {
      await stop();
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      debugPrint(
        '[DesktopOAuthServer] Direct Google OAuth listening on http://localhost:$port...',
      );
    } catch (e) {
      debugPrint('[DesktopOAuthServer] Bind port $port failed: $e');
      return null;
    }

    try {
      // Buat URL Google OAuth resmi
      final redirectUri = 'http://localhost:$port';
      final googleAuthUrl =
          Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
            'client_id': SupabaseConfig.googleClientId,
            'redirect_uri': redirectUri,
            'response_type': 'code',
            'scope': 'openid profile email',
            'access_type': 'offline',
            'prompt': 'select_account',
          });

      // Buka browser pengguna
      await openUrlInBrowser(googleAuthUrl.toString());

      // Tunggu callback dari Google
      await for (final HttpRequest request in _server!) {
        final uri = request.uri;
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        if (error != null || code == null) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.html
            ..write('''
              <!DOCTYPE html>
              <html>
              <body style="font-family:sans-serif;text-align:center;padding:50px;background:#FFF8F4;">
                <h2 style="color:#DC2626;">Login Google Dibatalkan</h2>
                <p>${error ?? 'Tidak ada authorization code dari Google'}</p>
              </body>
              </html>
            ''');
          await request.response.close();
          return null;
        }

        // Tampilkan halaman sukses di browser
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(_successHtml());
        await request.response.close();

        // Tukar code dengan token di https://oauth2.googleapis.com/token
        final tokenResponse = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'code': code,
            'client_id': SupabaseConfig.googleClientId,
            'client_secret': SupabaseConfig.googleClientSecret,
            'redirect_uri': redirectUri,
            'grant_type': 'authorization_code',
          },
        );

        if (tokenResponse.statusCode != 200) {
          debugPrint(
            '[GoogleOAuth] Token exchange failed: ${tokenResponse.body}',
          );
          return null;
        }

        final tokenJson = jsonDecode(tokenResponse.body);
        final accessToken = tokenJson['access_token'] as String?;
        final idToken = tokenJson['id_token'] as String?;

        if (accessToken == null) return null;

        // Ambil data profil Google user
        final userinfoResponse = await http.get(
          Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (userinfoResponse.statusCode != 200) {
          debugPrint('[GoogleOAuth] Userinfo failed: ${userinfoResponse.body}');
          return null;
        }

        final userJson = jsonDecode(userinfoResponse.body);
        final uid =
            userJson['sub'] as String? ??
            'google_${DateTime.now().millisecondsSinceEpoch}';
        final email = userJson['email'] as String? ?? '';
        final name =
            userJson['name'] as String? ??
            (email.isNotEmpty ? email.split('@').first : 'Pengguna Google');
        final picture = userJson['picture'] as String?;

        return GoogleOAuthProfile(
          uid: uid,
          email: email,
          name: name,
          photoUrl: picture,
          idToken: idToken,
        );
      }
    } catch (e) {
      debugPrint('[DesktopOAuthServer] Direct Google OAuth error: $e');
    } finally {
      await stop();
    }
    return null;
  }

  static Future<void> openUrlInBrowser(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '""', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (e) {
      debugPrint('[DesktopOAuthServer] openUrlInBrowser error: $e');
    }
  }

  static String _successHtml() {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Login Berhasil · Rasantara</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #FFF8F4; color: #1A1A2E; }
          .card { background: white; padding: 40px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.08); text-align: center; max-width: 420px; border-top: 6px solid #EA580C; }
          h2 { color: #EA580C; margin-top: 10px; font-size: 22px; }
          p { color: #64748B; font-size: 14px; line-height: 1.6; }
        </style>
      </head>
      <body>
        <div class="card">
          <div style="font-size: 48px;">✅</div>
          <h2>Login Google Berhasil!</h2>
          <p>Autentikasi akun Google Anda telah terverifikasi. Anda dapat menutup tab ini dan kembali ke aplikasi <b>Rasantara</b>.</p>
        </div>
        <script>setTimeout(() => window.close(), 2500);</script>
      </body>
      </html>
    ''';
  }

  static Future<void> stop() async {
    try {
      await _server?.close(force: true);
      _server = null;
    } catch (_) {}
  }
}
