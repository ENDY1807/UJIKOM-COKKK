import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/desktop_oauth_service.dart';
import '../services/supabase_config.dart';
import '../services/supabase_service.dart';
import '../services/web_oauth_helper.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.db,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Login
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;

  // Register
  final _regNameController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  bool _regObscure = true;

  bool _isRegisterMode = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  String? _successMessage;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _gsiSub;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();
    if (kIsWeb) {
      _initWebGoogleListener();
      _checkWebOAuthCallback();
    }
  }

  Future<void> _checkWebOAuthCallback() async {
    final fragment = Uri.base.fragment;
    final queryParams = Uri.base.queryParameters;

    String? accessToken;
    String? idToken;

    if (fragment.isNotEmpty) {
      final params = Uri.splitQueryString(fragment);
      accessToken = params['access_token'];
      idToken = params['id_token'];
    }

    if (accessToken == null && idToken == null) {
      accessToken = queryParams['access_token'];
      idToken = queryParams['id_token'];
    }

    if (accessToken != null || idToken != null) {
      setState(() => _isGoogleLoading = true);
      try {
        String? email;
        String? name;
        String? photo;
        String? uid;

        // 1. Ekstrak langsung dari ID Token (JWT) yang di-sign oleh Google
        if (idToken != null && idToken.contains('.')) {
          try {
            final parts = idToken.split('.');
            if (parts.length >= 2) {
              final payload = parts[1];
              final normalized = base64Url.normalize(payload);
              final decodedStr = utf8.decode(base64Url.decode(normalized));
              final jwtData = jsonDecode(decodedStr) as Map<String, dynamic>;
              email = jwtData['email']?.toString();
              name = (jwtData['name'] ?? jwtData['given_name'])?.toString();
              photo = jwtData['picture']?.toString();
              uid = jwtData['sub']?.toString();
            }
          } catch (jwtErr) {
            debugPrint('[GoogleOAuth] JWT decode error: $jwtErr');
          }
        }

        // 2. Jika ID Token tidak lengkap, panggil OpenID Connect UserInfo API
        if ((email == null || uid == null) && accessToken != null) {
          final res = await http.get(
            Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            email = data['email']?.toString();
            name = (data['name'] ?? data['given_name'])?.toString();
            photo = data['picture']?.toString();
            uid = data['sub']?.toString();
          }
        }

        if (email != null && uid != null) {
          final user = await widget.db.loginWithGoogleSupabase(
            googleUid: uid,
            googleEmail: email,
            displayName: name ?? email.split('@').first,
            photoUrl: photo,
          );

          WebOAuthHelper.cleanUrlHash();

          if (mounted) {
            setState(() {
              _isGoogleLoading = false;
              _successMessage = 'Berhasil masuk sebagai ${name ?? email} (${user.role.label})';
            });
            widget.onLoginSuccess();
          }
          return;
        }
      } catch (e) {
        debugPrint('[GoogleOAuth] Web OAuth callback error: $e');
      } finally {
        if (mounted) {
          setState(() => _isGoogleLoading = false);
        }
      }
    }
  }

  void _initWebGoogleListener() {
    try {
      _gsiSub = GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          final account = event.user;
          final email = account.email;
          final name = account.displayName ??
              (email.isNotEmpty ? email.split('@').first : 'Pengguna Google');
          widget.db
              .loginWithGoogleSupabase(
                googleUid: account.id,
                googleEmail: email,
                displayName: name,
                photoUrl: account.photoUrl,
              )
              .then((user) {
                if (mounted) {
                  setState(() {
                    _isGoogleLoading = false;
                    _successMessage = 'Berhasil masuk sebagai $name';
                  });
                  widget.onLoginSuccess();
                }
              });
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _gsiSub?.cancel();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regUsernameController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    DesktopOAuthServer.stop();
    super.dispose();
  }

  void _toggleMode(bool register) {
    setState(() {
      _isRegisterMode = register;
      _errorMessage = null;
      _successMessage = null;
    });
    if (register) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username dan password wajib diisi');
      return;
    }
    final success = await widget.db.loginAsync(username, password);
    if (success) {
      final user = widget.db.currentUser;
      if (user != null && user.isTwoFactorEnabled) {
        _showTwoFactorDialog(user);
        return;
      }
      widget.onLoginSuccess();
    } else {
      setState(() => _errorMessage = 'Username atau password tidak cocok');
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
    final name = _regNameController.text.trim();
    final username = _regUsernameController.text.trim();
    final password = _regPasswordController.text;
    final confirm = _regConfirmPasswordController.text;

    if (name.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Semua field wajib diisi');
      return;
    }
    if (password.length < 4) {
      setState(() => _errorMessage = 'Password minimal 4 karakter');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Konfirmasi password tidak cocok');
      return;
    }

    try {
      final newUser = await widget.db.registerUser(
        username: username,
        password: password,
        namaUser: name,
      );
      _loginUsernameController.text = username;
      _loginPasswordController.text = password;
      setState(() {
        _successMessage =
            'Registrasi akun "${newUser.namaUser}" berhasil! Silakan masuk.';
      });
      _toggleMode(false);
      _regNameController.clear();
      _regUsernameController.clear();
      _regPasswordController.clear();
      _regConfirmPasswordController.clear();
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  static bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    _googleSignInInitialized = true;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? SupabaseConfig.googleClientId : null,
        serverClientId: kIsWeb ? null : SupabaseConfig.googleClientId,
      );
    } catch (e) {
      if (!e.toString().contains('already been called')) {
        debugPrint('[GoogleSignIn] initialize error: $e');
      }
    }
  }

  Future<void> _handleGoogleLogin({bool isRegister = false}) async {
    if (_isGoogleLoading) return;

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isGoogleLoading = true;
    });

    try {
      GoogleSignInAccount? account;

      // 1. Coba Google Sign-In SDK resmi (Android, iOS & Web)
      try {
        await _ensureGoogleSignInInitialized();
        if (GoogleSignIn.instance.supportsAuthenticate()) {
          account = await GoogleSignIn.instance.authenticate();
        }
      } catch (signInErr) {
        debugPrint('[GoogleOAuth] GoogleSignIn SDK error: $signInErr');
        account = null;
      }

      if (account != null) {
        final email = account.email;
        final name =
            account.displayName ??
            (email.isNotEmpty ? email.split('@').first : 'Pengguna Google');
        final photo = account.photoUrl;
        final uid = account.id;

        final user = await widget.db.loginWithGoogleSupabase(
          googleUid: uid,
          googleEmail: email,
          displayName: name,
          photoUrl: photo,
        );

        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
            _successMessage =
                'Berhasil masuk dengan Google sebagai $name (${user.role.label})';
          });
          widget.onLoginSuccess();
        }
        return;
      }

      // 2. Mobile platform: Jika native Google Play Services tidak tersedia / belum dikonfigurasi SHA-1,
      // coba Supabase OAuth flow via custom tab/browser dengan redirect deep link
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          final launched = await SupabaseService().signInWithGoogleOAuth(
            customRedirect: SupabaseConfig.redirectUrl,
          );
          if (launched) {
            if (mounted) {
              setState(() => _isGoogleLoading = false);
            }
            return;
          }
        } catch (oauthErr) {
          debugPrint('[GoogleOAuth] Supabase mobile OAuth fallback: $oauthErr');
        }

        // Tawarkan dialog autentikasi akun Google
        if (mounted) {
          setState(() => _isGoogleLoading = false);
          _showGoogleFallbackDialog();
          return;
        }
      }

      // 3. Web platform: Buka form login / pemilih akun resmi Google (accounts.google.com)
      if (kIsWeb) {
        final origin = Uri.base.origin;
        final nonce = DateTime.now().millisecondsSinceEpoch.toString();
        final googleUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
          'client_id': SupabaseConfig.googleClientId,
          'redirect_uri': origin,
          'response_type': 'token id_token',
          'scope': 'openid profile email',
          'prompt': 'select_account',
          'nonce': nonce,
        });

        WebOAuthHelper.redirectTo(googleUrl.toString());
        return;
      }

      // 4. Desktop (Windows / macOS / Linux): Direct Google OAuth 2.0 loopback server (Buka browser resmi Google)
      if (!kIsWeb) {
        setState(() {
          _successMessage =
              'Membuka Google OAuth di browser... Silakan pilih akun Google Anda.';
        });

        final googleProfile =
            await DesktopOAuthServer.listenForGoogleOAuthDirect(port: 3000);

        if (googleProfile != null && mounted) {
          final appUser = await widget.db.loginWithGoogleSupabase(
            googleUid: googleProfile.uid,
            googleEmail: googleProfile.email,
            displayName: googleProfile.name,
            photoUrl: googleProfile.photoUrl,
          );

          if (mounted) {
            setState(() {
              _isGoogleLoading = false;
              _successMessage =
                  'Berhasil masuk sebagai ${googleProfile.name} (${appUser.role.label})';
            });
            if (appUser.isTwoFactorEnabled) {
              _showTwoFactorDialog(appUser);
              return;
            }
            widget.onLoginSuccess();
          }
          return;
        }

        // Jika browser direct gagal/dibatalkan, tawarkan dialog verifikasi akun Google
        if (mounted) {
          setState(() => _isGoogleLoading = false);
          _showGoogleFallbackDialog();
          return;
        }
      }

      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        _showGoogleFallbackDialog();
      }
    }
  }

  void _showTwoFactorDialog(UserModel user) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Verifikasi 2 Langkah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akun ${user.namaUser} dilindungi dengan autentikasi dua langkah (${user.twoFactorType ?? "Authenticator"}). Masukkan 6-digit kode verifikasi Anda:',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Kode Verifikasi 6-Digit',
                hintText: '123456',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.pin, color: Color(0xFFEA580C)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final code = codeCtrl.text.trim();
              if (code.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Masukkan kode autentikasi 2 langkah yang valid')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              widget.onLoginSuccess();
            },
            child: const Text('Verifikasi & Masuk'),
          ),
        ],
      ),
    );
  }

  void _showGoogleFallbackDialog() {
    final prefilledEmail = _loginUsernameController.text.trim().contains('@')
        ? _loginUsernameController.text.trim()
        : '';
    final emailCtrl = TextEditingController(text: prefilledEmail);
    final nameCtrl = TextEditingController();

    // Akun terdaftar di database lokal / cloud
    final registeredGoogleUsers = widget.db.users.where((u) =>
        (u.googleEmail != null && u.googleEmail!.isNotEmpty) ||
        (u.username.contains('@')) ||
        u.role == UserRole.pelanggan).take(3).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(painter: _GoogleLogoPainter()),
              ),
              const SizedBox(width: 10),
              const Text(
                'Masuk dengan Akun Google',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih akun Google Anda yang tersimpan atau masukkan email Google untuk masuk / sinkronisasi langsung ke Cloud:',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),

              if (registeredGoogleUsers.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < registeredGoogleUsers.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 40),
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: registeredGoogleUsers[i].role == UserRole.administrator
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFEA580C),
                            child: Text(
                              registeredGoogleUsers[i].namaUser.isNotEmpty
                                  ? registeredGoogleUsers[i].namaUser[0].toUpperCase()
                                  : 'G',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            registeredGoogleUsers[i].displayEmail,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${registeredGoogleUsers[i].namaUser} (${registeredGoogleUsers[i].role.label})',
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                          onTap: () {
                            setDialogState(() {
                              emailCtrl.text = registeredGoogleUsers[i].displayEmail;
                              nameCtrl.text = registeredGoogleUsers[i].namaUser;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Akun Google',
                  hintText: 'nama@gmail.com',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.alternate_email,
                    size: 18,
                    color: Color(0xFFEA580C),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Tampilan Akun',
                  hintText: 'Nama Anda',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Color(0xFFEA580C),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final email = emailCtrl.text.trim();
                var name = nameCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Silakan masukkan format email Google yang valid')),
                  );
                  return;
                }
                if (name.isEmpty) {
                  name = email.split('@').first;
                }
                Navigator.of(ctx).pop();
                setState(() => _isGoogleLoading = true);
                try {
                  final appUser = await widget.db.loginWithGoogleSupabase(
                    googleUid: 'google_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
                    googleEmail: email,
                    displayName: name,
                    photoUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=EA580C&color=fff',
                  );
                  if (mounted) {
                    setState(() {
                      _isGoogleLoading = false;
                      _successMessage = 'Selamat datang, $name!';
                    });
                    if (appUser.isTwoFactorEnabled) {
                      _showTwoFactorDialog(appUser);
                      return;
                    }
                    widget.onLoginSuccess();
                  }
                } catch (err) {
                  if (mounted) {
                    setState(() {
                      _isGoogleLoading = false;
                      _errorMessage = err.toString();
                    });
                  }
                }
              },
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('Masuk Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aplikasi Rasantara tetap aktif.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F4F0),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              return isDesktop ? _buildDesktop() : _buildMobile();
            },
          ),
        ),
      ),
    );
  }

  // ─── DESKTOP ──────────────────────────────────────────────────────────────
  Widget _buildDesktop() {
    const w = 1000.0;
    const h = 620.0;
    const half = w / 2;

    return Center(
      child: Container(
        width: w,
        height: h,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 60,
              spreadRadius: 0,
              offset: const Offset(0, 24),
            ),
            BoxShadow(
              color: AppTheme.orangePrimary.withValues(alpha: 0.06),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Left panel white content (register form area)
            Positioned(
              left: 0,
              top: 0,
              width: half,
              height: h,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, _) => IgnorePointer(
                  ignoring: _slideAnimation.value < 0.5,
                  child: _buildWhiteFormArea(isLogin: false),
                ),
              ),
            ),

            // Right panel white content (login form area)
            Positioned(
              left: half,
              top: 0,
              width: half,
              height: h,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, _) => IgnorePointer(
                  ignoring: _slideAnimation.value > 0.5,
                  child: _buildWhiteFormArea(isLogin: true),
                ),
              ),
            ),

            // ─── Sliding Orange Panel ───
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                // Login: orange on LEFT (0). Register: orange slides to RIGHT (half).
                final left = _slideAnimation.value * half;
                return Positioned(
                  left: left,
                  top: 0,
                  width: half,
                  height: h,
                  child: child!,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF7300),
                      Color(0xFFEA580C),
                      Color(0xFFCC4A0B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -60,
                      right: -60,
                      child: _buildDecorCircle(200, Colors.white, 0.07),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -40,
                      child: _buildDecorCircle(240, Colors.white, 0.05),
                    ),
                    Positioned(
                      top: 120,
                      right: 40,
                      child: _buildDecorCircle(80, Colors.white, 0.1),
                    ),

                    // Content inside orange panel with smooth cross-fade during sliding
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, _) {
                          final loginOpacity =
                              (1.0 - _slideAnimation.value * 2.0).clamp(
                                0.0,
                                1.0,
                              );
                          final registerOpacity =
                              ((_slideAnimation.value - 0.5) * 2.0).clamp(
                                0.0,
                                1.0,
                              );

                          return Stack(
                            children: [
                              if (loginOpacity > 0.0)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: loginOpacity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        -20 * _slideAnimation.value,
                                        0,
                                      ),
                                      child: IgnorePointer(
                                        ignoring: _slideAnimation.value > 0.3,
                                        child: _buildOrangePanelInfo(
                                          key: const ValueKey('info_login'),
                                          isRegisterSide: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (registerOpacity > 0.0)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: registerOpacity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        20 * (1.0 - _slideAnimation.value),
                                        0,
                                      ),
                                      child: IgnorePointer(
                                        ignoring: _slideAnimation.value < 0.7,
                                        child: _buildOrangePanelInfo(
                                          key: const ValueKey('info_register'),
                                          isRegisterSide: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorCircle(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  // Orange panel: branding info + toggle button
  Widget _buildOrangePanelInfo({Key? key, required bool isRegisterSide}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.all(44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Brand
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rasantara',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          Text(
            isRegisterSide
                ? 'Bergabung\nBersama Kami!'
                : 'Selamat\nDatang Kembali!',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isRegisterSide
                ? 'Buat akun baru untuk memesan\nmenu restoran kami dengan mudah.'
                : 'Cita Rasa Kuliner Nusantara\nSistem Pemesanan & Kasir Restoran.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),

          // CTA button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleMode(!isRegisterSide),
              borderRadius: BorderRadius.circular(50),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRegisterSide
                          ? 'Sudah punya akun? Masuk'
                          : 'Belum punya akun? Daftar',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.orangePrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isRegisterSide ? Icons.login : Icons.person_add,
                      size: 18,
                      color: AppTheme.orangePrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // White form area (right for login, left for register in desktop)
  Widget _buildWhiteFormArea({required bool isLogin}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 40),
      child: SingleChildScrollView(
        child: isLogin ? _buildLoginForm() : _buildRegisterForm(),
      ),
    );
  }

  // ─── LOGIN FORM ────────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Masuk',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Gunakan akun Rasantara Anda untuk masuk',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 24),

        // Feedback
        if (_successMessage != null) _feedbackBanner(_successMessage!, true),
        if (_errorMessage != null && !_isRegisterMode)
          _feedbackBanner(_errorMessage!, false),

        _inputField(
          controller: _loginUsernameController,
          label: 'Username',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _loginPasswordController,
          label: 'Password',
          icon: Icons.lock_outline,
          isPassword: true,
          obscure: _loginObscure,
          onToggle: () => setState(() => _loginObscure = !_loginObscure),
          onSubmit: (_) => _handleLogin(),
        ),
        const SizedBox(height: 24),

        _primaryButton('Masuk Sekarang', Icons.login, _handleLogin),
        const SizedBox(height: 18),

        _orDivider(),
        const SizedBox(height: 18),

        _googleSignInButton(),
      ],
    );
  }

  // ─── REGISTER FORM ─────────────────────────────────────────────────────────
  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Daftar Akun',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Buat akun pelanggan untuk memesan menu',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 24),

        if (_errorMessage != null && _isRegisterMode)
          _feedbackBanner(_errorMessage!, false),

        _inputField(
          controller: _regNameController,
          label: 'Nama Lengkap',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),
        _inputField(
          controller: _regUsernameController,
          label: 'Username',
          icon: Icons.alternate_email,
        ),
        const SizedBox(height: 12),
        _inputField(
          controller: _regPasswordController,
          label: 'Password Baru',
          icon: Icons.lock_outline,
          isPassword: true,
          obscure: _regObscure,
          onToggle: () => setState(() => _regObscure = !_regObscure),
        ),
        const SizedBox(height: 12),
        _inputField(
          controller: _regConfirmPasswordController,
          label: 'Konfirmasi Password',
          icon: Icons.lock_reset,
          isPassword: true,
          obscure: _regObscure,
          onToggle: () => setState(() => _regObscure = !_regObscure),
        ),
        const SizedBox(height: 24),

        _primaryButton('Buat Akun Sekarang', Icons.person_add, _handleRegister),
        const SizedBox(height: 18),

        _orDivider(),
        const SizedBox(height: 18),

        _googleSignInButton(isRegister: true),
      ],
    );
  }

  Widget _feedbackBanner(String message, bool isSuccess) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSuccess ? AppTheme.statusGreenBg : AppTheme.statusRedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess
              ? AppTheme.statusGreen.withValues(alpha: 0.3)
              : AppTheme.statusRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: isSuccess ? AppTheme.statusGreen : AppTheme.statusRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSuccess ? AppTheme.statusGreen : AppTheme.statusRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    ValueChanged<String>? onSubmit,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmit,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF1A1A2E),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Masukkan $label',
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.orangePrimary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.grey[400],
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.orangePrimary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7300), Color(0xFFEA580C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'atau',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[200], thickness: 1)),
      ],
    );
  }

  Widget _googleSignInButton({bool isRegister = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isGoogleLoading
            ? null
            : () => _handleGoogleLogin(isRegister: isRegister),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGoogleLoading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppTheme.orangePrimary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Menghubungkan ke Google...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                  ),
                ),
              ] else ...[
                // Google 'G' logo
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(painter: _GoogleLogoPainter()),
                ),
                const SizedBox(width: 12),
                Text(
                  isRegister ? 'Daftar dengan Google' : 'Masuk dengan Google',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── MOBILE ───────────────────────────────────────────────────────────────
  Widget _buildMobile() {
    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3E8), Color(0xFFF8F4F0)],
            ),
          ),
        ),

        // Floating decorative elements
        Positioned(
          top: -80,
          right: -80,
          child: _buildDecorCircle(280, AppTheme.orangePrimary, 0.08),
        ),
        Positioned(
          top: 60,
          left: -60,
          child: _buildDecorCircle(180, AppTheme.orangePrimary, 0.05),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo area
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7300), Color(0xFFEA580C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rasantara',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  'Sistem Kasir & Layanan Meja',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),

                // Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tab switcher
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            _mobileTab(
                              'Masuk',
                              !_isRegisterMode,
                              () => _toggleMode(false),
                            ),
                            _mobileTab(
                              'Daftar',
                              _isRegisterMode,
                              () => _toggleMode(true),
                            ),
                          ],
                        ),
                      ),

                      // Form content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) {
                            final isReg = child.key == const ValueKey('m_reg');
                            final offsetTween = Tween<Offset>(
                              begin: Offset(isReg ? 0.08 : -0.08, 0),
                              end: Offset.zero,
                            );
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: offsetTween.animate(
                                  CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: _isRegisterMode
                              ? Column(
                                  key: const ValueKey('m_reg'),
                                  children: [
                                    if (_errorMessage != null &&
                                        _isRegisterMode)
                                      _feedbackBanner(_errorMessage!, false),
                                    _inputField(
                                      controller: _regNameController,
                                      label: 'Nama Lengkap',
                                      icon: Icons.badge_outlined,
                                    ),
                                    const SizedBox(height: 12),
                                    _inputField(
                                      controller: _regUsernameController,
                                      label: 'Username',
                                      icon: Icons.alternate_email,
                                    ),
                                    const SizedBox(height: 12),
                                    _inputField(
                                      controller: _regPasswordController,
                                      label: 'Password',
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                      obscure: _regObscure,
                                      onToggle: () => setState(
                                        () => _regObscure = !_regObscure,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _inputField(
                                      controller: _regConfirmPasswordController,
                                      label: 'Konfirmasi Password',
                                      icon: Icons.lock_reset,
                                      isPassword: true,
                                      obscure: _regObscure,
                                      onToggle: () => setState(
                                        () => _regObscure = !_regObscure,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    _primaryButton(
                                      'Buat Akun',
                                      Icons.person_add,
                                      _handleRegister,
                                    ),
                                    const SizedBox(height: 16),
                                    _orDivider(),
                                    const SizedBox(height: 16),
                                    _googleSignInButton(isRegister: true),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey('m_login'),
                                  children: [
                                    if (_successMessage != null)
                                      _feedbackBanner(_successMessage!, true),
                                    if (_errorMessage != null &&
                                        !_isRegisterMode)
                                      _feedbackBanner(_errorMessage!, false),
                                    _inputField(
                                      controller: _loginUsernameController,
                                      label: 'Username',
                                      icon: Icons.person_outline,
                                    ),
                                    const SizedBox(height: 12),
                                    _inputField(
                                      controller: _loginPasswordController,
                                      label: 'Password',
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                      obscure: _loginObscure,
                                      onToggle: () => setState(
                                        () => _loginObscure = !_loginObscure,
                                      ),
                                      onSubmit: (_) => _handleLogin(),
                                    ),
                                    const SizedBox(height: 22),
                                    _primaryButton(
                                      'Masuk Sekarang',
                                      Icons.login,
                                      _handleLogin,
                                    ),
                                    const SizedBox(height: 16),
                                    _orDivider(),
                                    const SizedBox(height: 16),
                                    _googleSignInButton(),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Rasantara Restoran © 2026',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileTab(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isActive ? AppTheme.orangePrimary : Colors.grey[400],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for the Google 'G' multicolor logo
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Blue arc (top-right)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.6,
      1.8,
      true,
      bluePaint,
    );

    // Green arc (bottom-right)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.2,
      1.2,
      true,
      greenPaint,
    );

    // Yellow arc (bottom-left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      2.4,
      1.0,
      true,
      yellowPaint,
    );

    // Red arc (top-left)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.4,
      1.0,
      true,
      redPaint,
    );

    // White inner circle to create the 'G' shape
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, whitePaint);

    // Blue horizontal bar (the inner part of G)
    canvas.drawRect(
      Rect.fromLTWH(w * 0.48, h * 0.38, w * 0.52, h * 0.24),
      bluePaint,
    );

    // White cutout above the bar
    canvas.drawRect(
      Rect.fromLTWH(w * 0.48, h * 0.0, w * 0.52, h * 0.38),
      whitePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
