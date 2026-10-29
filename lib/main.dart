import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/database_service.dart';
import 'services/supabase_config.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase SDK
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    debugPrint('[Main] Supabase initialize warning: $e');
  }

  runApp(const KasirRestoranApp());
}

class KasirRestoranApp extends StatefulWidget {
  const KasirRestoranApp({super.key});

  @override
  State<KasirRestoranApp> createState() => _KasirRestoranAppState();
}

class _KasirRestoranAppState extends State<KasirRestoranApp> {
  late final DatabaseService _db;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _db.addListener(_onDbChange);

    // Dengarkan perubahan sesi autentikasi Supabase (misal return dari Google OAuth Browser)
    _listenSupabaseAuth();
  }

  void _listenSupabaseAuth() {
    try {
      if (!SupabaseService().isInitialized) return;
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null && session.user.id.isNotEmpty) {
          final user = session.user;
          final email = user.email ?? '';
          final meta = user.userMetadata ?? {};
          final name = (meta['full_name'] ?? meta['name'] ?? email.split('@').first).toString();
          final photo = (meta['avatar_url'] ?? meta['picture'])?.toString();

          _db.loginWithGoogleSupabase(
            googleUid: user.id,
            googleEmail: email,
            displayName: name,
            photoUrl: photo,
          );
        }
      });
    } catch (e) {
      debugPrint('[KasirRestoranApp] Auth listener error: $e');
    }
  }

  void _onDbChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _db.removeListener(_onDbChange);
    _db.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Kasir Restoran (Table Service)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _db.currentUser == null
          ? LoginScreen(
              db: _db,
              onLoginSuccess: () => setState(() {}),
            )
          : MainNavigationScreen(
              db: _db,
              onLogout: () => setState(() {}),
            ),
    );
  }
}
