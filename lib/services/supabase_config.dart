/// Konfigurasi Supabase Project Kasir Restoran
/// Berisi URL, Publishable Key, Secret Key, JWKS URL, dan Google OAuth Credentials.
class SupabaseConfig {
  static const String url = 'https://kzhqoowfvdyllcaewsao.supabase.co';
  static const String publishableKey =
      'sb_publishable_79_UbfbUBCxW_Q2k_oksYQ_Rh0JjjAU';
  static const String secretKey = String.fromEnvironment(
    'SUPABASE_SECRET_KEY',
    defaultValue: 'YOUR_SUPABASE_SECRET_KEY',
  );
  static const String jwksUrl =
      'https://kzhqoowfvdyllcaewsao.supabase.co/auth/v1/.well-known/jwks.json';

  // Google OAuth Credentials
  static const String googleClientId =
      '124635820971-cn5609qedpjbrlq8f181kk6vcojp8jjk.apps.googleusercontent.com';
  static const String googleClientSecret = String.fromEnvironment(
    'GOOGLE_CLIENT_SECRET',
    defaultValue: 'YOUR_GOOGLE_CLIENT_SECRET',
  );

  // Redirect deep link scheme untuk OAuth callback
  static const String redirectUrl = 'io.supabase.kasirrestoran://login-callback';
}
