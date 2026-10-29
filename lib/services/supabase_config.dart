/// Konfigurasi Supabase Project Kasir Restoran
/// Berisi URL, Publishable Key, Secret Key, JWKS URL, dan Google OAuth Credentials.
class SupabaseConfig {
  static const String url = 'https://qytqleurueliiztckkgi.supabase.co';
  static const String publishableKey =
      'sb_publishable_F934ghhu6sKtZfse1-DJaw_QuxZyuHG';
  static const String secretKey =
      'sb_secret_QdMqkVQTl9Pf91OuWaxwug_5C_fnGyf';
  static const String jwksUrl =
      'https://qytqleurueliiztckkgi.supabase.co/auth/v1/.well-known/jwks.json';

  // Google OAuth Credentials
  static const String googleClientId =
      '124635820971-cn5609qedpjbrlq8f181kk6vcojp8jjk.apps.googleusercontent.com';
  static const String googleClientSecret =
      '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';

  // Redirect deep link scheme untuk OAuth callback
  static const String redirectUrl = 'io.supabase.kasirrestoran://login-callback';
}
