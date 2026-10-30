import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DesktopOAuthServer {
  static HttpServer? _server;

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
          ..write('''
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <title>Login Berhasil</title>
              <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #FFF8F4; color: #1A1A2E; }
                .card { background: white; padding: 40px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.08); text-align: center; max-width: 420px; }
                h2 { color: #EA580C; margin-top: 10px; }
                p { color: #64748B; font-size: 14px; line-height: 1.5; }
              </style>
            </head>
            <body>
              <div class="card">
                <div style="font-size: 48px;">✅</div>
                <h2>Login Berhasil!</h2>
                <p>Autentikasi akun Google Anda telah selesai. Anda dapat menutup tab ini dan kembali ke aplikasi <b>Kasir Restoran Nusantara</b>.</p>
              </div>
              <script>setTimeout(() => window.close(), 2500);</script>
            </body>
            </html>
          ''');
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

  static Future<void> stop() async {
    try {
      await _server?.close(force: true);
      _server = null;
    } catch (_) {}
  }
}
