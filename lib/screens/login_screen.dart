import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/desktop_oauth_service.dart';
import '../services/supabase_config.dart';
import '../services/web_oauth_helper.dart';
import '../services/phone_otp_service.dart';
import '../widgets/phone_otp_dialog.dart';
import '../widgets/menu_price_list_dialog.dart';
import '../theme/app_theme.dart';
import 'auth/google_onboarding_dialog.dart';

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
    with SingleTickerProviderStateMixin {
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;

  bool _isGoogleLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _gsiSub;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
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
              _successMessage =
                  'Berhasil masuk sebagai ${name ?? email} (${user.role.label})';
            });
            _completeUserLogin(user);
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
                  _completeUserLogin(user);
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
    _fadeController.dispose();
    DesktopOAuthServer.stop();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final usernameOrEmail = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;

    if (usernameOrEmail.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username/Email dan password wajib diisi');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await widget.db.loginAsync(usernameOrEmail, password);
      if (!mounted) return;

      if (success) {
        final user = widget.db.currentUser;
        if (user != null) {
          _completeUserLogin(user);
        } else {
          widget.onLoginSuccess();
        }
      } else {
        setState(() {
          _errorMessage = 'Username/Email atau password salah';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  static bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: SupabaseConfig.googleClientId,
        clientId: kIsWeb ? SupabaseConfig.googleClientId : null,
      );
      _googleSignInInitialized = true;
    } catch (e) {
      if (!e.toString().contains('already been called')) {
        debugPrint('[GoogleSignIn] initialize error: $e');
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;

    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isGoogleLoading = true;
    });

    try {
      GoogleSignInAccount? account;

      try {
        await _ensureGoogleSignInInitialized();
        if (GoogleSignIn.instance.supportsAuthenticate()) {
          account = await GoogleSignIn.instance.authenticate();
        }
      } catch (signInErr) {
        debugPrint('[GoogleOAuth] GoogleSignIn authenticate error: $signInErr');
        account = null;
      }

      if (account != null) {
        final email = account.email;
        final name = account.displayName ?? email.split('@').first;
        final photo = account.photoUrl;

        final user = await widget.db.loginWithGoogleSupabase(
          googleUid: account.id,
          googleEmail: email,
          displayName: name,
          photoUrl: photo,
        );

        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
            _successMessage =
                'Berhasil masuk sebagai $name (${user.role.label})';
          });
          _completeUserLogin(user);
        }
        return;
      }

      if (kIsWeb) {
        final origin = Uri.base.origin;
        final nonce = DateTime.now().millisecondsSinceEpoch.toString();
        final googleUrl =
            Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
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

      if (!kIsWeb &&
          defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) {
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
            _completeUserLogin(appUser);
          }
          return;
        }

        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
            _errorMessage = 'Masuk dengan Google dibatalkan.';
          });
          return;
        }
      }

      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    } catch (e) {
      debugPrint('[GoogleSignIn] unexpected error: $e');
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage =
              'Gagal masuk dengan Google. Silakan login menggunakan Username/Email.';
        });
      }
    }
  }

  void _completeUserLogin(UserModel user) {
    if (user.authProvider == AuthProvider.google &&
        (!user.isConfigured ||
            user.phoneNumber.isEmpty ||
            user.username == 'pelanggan')) {
      GoogleOnboardingDialog.show(
        context,
        db: widget.db,
        user: user,
        onComplete: () {
          widget.onLoginSuccess();
        },
      );
      return;
    }

    if (user.isTwoFactorEnabled) {
      _showTwoFactorDialog(user);
      return;
    }

    widget.onLoginSuccess();
  }

  void _showTwoFactorDialog(UserModel user) async {
    final rawPhone =
        user.phoneNumber.isNotEmpty ? user.phoneNumber : '081234567890';

    await PhoneOtpService.instance.sendOtp(
      rawPhone: rawPhone,
    );

    if (!mounted) return;

    PhoneOtpDialog.show(
      context,
      phoneNumber: rawPhone,
      title: 'Verifikasi Dua Langkah',
      subtitle:
          'Masukkan 6 digit kode yang dikirim ke ${PhoneOtpService.formatDisplayPhone(rawPhone)}',
      onVerified: () {
        widget.onLoginSuccess();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgGradient = isDark
        ? const RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.3,
            colors: [
              Color(0xFF1B2234),
              Color(0xFF0F172A),
              Color(0xFF080D1A),
            ],
            stops: [0.0, 0.6, 1.0],
          )
        : const RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.3,
            colors: [
              Color(0xFFFFF7ED),
              Color(0xFFF8FAFC),
              Color(0xFFF1F5F9),
            ],
            stops: [0.0, 0.55, 1.0],
          );

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
        body: Container(
          decoration: BoxDecoration(gradient: bgGradient),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── DESKTOP (ELEGANT SPLIT-SCREEN) ────────────────────────────────────────
  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 580),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark
                ? const Color(0xFF334155).withValues(alpha: 0.7)
                : const Color(0xFFE2E8F0),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.09),
              blurRadius: 48,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: AppTheme.orangePrimary.withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Left Feature & Visual Showcase
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1E1712),
                            const Color(0xFF0F172A),
                            const Color(0xFF0D1322),
                          ]
                        : [
                            const Color(0xFF1E293B),
                            const Color(0xFF0F172A),
                            const Color(0xFF111827),
                          ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Identity Row
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.orangePrimary
                                    .withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/Rasantara Cloche App Icon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.restaurant_rounded,
                              color: AppTheme.orangePrimary,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rasantara',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Point of Sale & Kitchen Suite',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Big Compelling Headline
                    const Text(
                      'Pengalaman Kasir &\nManajemen Meja yang\nCepat dan Presisi.',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Akses terpadu untuk kasir, pelayan, koki dapur, hingga pemilik restoran secara real-time.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Metric Showcase Cards
                    Row(
                      children: [
                        _metricBadge(
                            '⚡ 0.2s', 'Respons Kasir', const Color(0xFFF97316)),
                        const SizedBox(width: 10),
                        _metricBadge('📊 Real-Time', 'Laporan Penjualan',
                            const Color(0xFF10B981)),
                      ],
                    ),

                    const Spacer(),

                    // Security & Certification Footer
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sistem Keamanan Terenkripsi & Cloud Sync',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Right Form Panel
            Expanded(
              flex: 6,
              child: Container(
                color: context.surfaceCard,
                padding:
                    const EdgeInsets.symmetric(horizontal: 46, vertical: 36),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: _buildLoginForm(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBadge(String value, String label, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MOBILE LAYOUT ─────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 410),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Logo Card
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.orangePrimary.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.08,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/Rasantara Cloche App Icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.restaurant_rounded,
                      color: AppTheme.orangePrimary,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Rasantara',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  'Sistem Kasir & Operasional Restoran',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Floating Elevated Login Card
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155).withValues(alpha: 0.6)
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.4 : 0.07),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: _buildLoginForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── LOGIN FORM ────────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Masuk',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gunakan kredensial akun untuk melanjutkan',
          style: TextStyle(
            fontSize: 12.5,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        if (_successMessage != null) _feedbackBanner(_successMessage!, true),
        if (_errorMessage != null) _feedbackBanner(_errorMessage!, false),

        _inputField(
          controller: _loginUsernameController,
          label: 'Username/Email',
          hintText: 'contoh: nama@email.com atau username',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _loginPasswordController,
          label: 'Password',
          hintText: '••••••••',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _loginObscure,
          onToggle: () => setState(() => _loginObscure = !_loginObscure),
          onSubmit: (_) => _handleLogin(),
        ),

        const SizedBox(height: 22),

        // Primary Login Button (Warm Gradient & Raised Depth)
        _primaryButton('Masuk', Icons.arrow_forward_rounded, _handleLogin),

        const SizedBox(height: 16),

        _orDivider(),

        const SizedBox(height: 16),

        // Google Sign-In Button
        _googleSignInButton(),

        const SizedBox(height: 18),

        // Menu & Price List for Customers / Visitors
        _menuPriceListButton(),
      ],
    );
  }

  Widget _feedbackBanner(String message, bool isSuccess) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
            isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: 18,
            color: isSuccess ? AppTheme.statusGreen : AppTheme.statusRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
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
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          onSubmitted: onSubmit,
          style: TextStyle(
            fontSize: 13.5,
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 12.5,
              color: context.textSecondary.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(icon, size: 19, color: AppTheme.orangePrimary),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                      color: context.textSecondary,
                    ),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: context.fillSubtle,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.orangePrimary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSubmitting ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF97316), Color(0xFFEA580C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.orangePrimary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSubmitting) ...[
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
              ] else ...[
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
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
        Expanded(child: Divider(color: context.borderSubtle, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'atau',
            style: TextStyle(
              fontSize: 11.5,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.borderSubtle, thickness: 1)),
      ],
    );
  }

  Widget _googleSignInButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isGoogleLoading ? null : _handleGoogleLogin,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderSubtle, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGoogleLoading) ...[
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.orangePrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Menghubungkan ke Google...',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: 19,
                  height: 19,
                  child: CustomPaint(painter: _GoogleLogoPainter()),
                ),
                const SizedBox(width: 10),
                Text(
                  'Masuk dengan Google',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuPriceListButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => MenuPriceListDialog.show(context, db: widget.db),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.orangePrimary.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.orangePrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 17,
                  color: AppTheme.orangePrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Buku Menu & Price List Pelanggan',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Lihat harga & unduh katalog PDF',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppTheme.orangePrimary,
              ),
            ],
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

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, whitePaint);

    canvas.drawRect(
      Rect.fromLTWH(w * 0.48, h * 0.38, w * 0.52, h * 0.24),
      bluePaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(w * 0.48, h * 0.0, w * 0.52, h * 0.38),
      whitePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
