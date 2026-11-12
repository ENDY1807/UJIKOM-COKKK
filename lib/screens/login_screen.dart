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
          _errorMessage = 'Username/Email atau password tidak sesuai';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _fillDemoCredentials(String username, String password) {
    setState(() {
      _loginUsernameController.text = username;
      _loginPasswordController.text = password;
      _errorMessage = null;
    });
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
            _successMessage = 'Berhasil masuk sebagai $name (${user.role.label})';
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
        backgroundColor:
            isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 880;
              return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
            },
          ),
        ),
      ),
    );
  }

  // ─── DESKTOP LAYOUT (SPLIT SCREEN) ──────────────────────────────────────────
  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 960,
        height: 600,
        margin: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Left Hero & Branding Section
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF1E293B),
                ),
                padding: const EdgeInsets.all(44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Badge
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.orangePrimary
                                    .withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.restaurant_rounded,
                                color: AppTheme.orangePrimary,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rasantara',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'POS & Restaurant Suite',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Tagline & Value Highlights
                    const Text(
                      'Kelola Pesanan &\nOperasional Restoran\nLebih Cepat.',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dirancang khusus untuk efisiensi meja kasir, dapur, pelayan, dan laporan terintegrasi.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Feature Pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _featurePill('⚡ Transaksi Kilat'),
                        _featurePill('📊 Laporan Otomatis'),
                        _featurePill('📱 Integrasi Meja'),
                      ],
                    ),

                    const Spacer(),

                    // Version Tag
                    Text(
                      'v3.0 Production Ready • UJIKOM certified',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 32),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _buildLoginForm(isDesktop: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featurePill(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  // ─── MOBILE LAYOUT ─────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Brand Icon
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.orangePrimary.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.restaurant_rounded,
                        color: AppTheme.orangePrimary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'Rasantara',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  'Sistem Kasir & Pemesanan Restoran',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _buildLoginForm(isDesktop: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── LOGIN FORM ────────────────────────────────────────────────────────────
  Widget _buildLoginForm({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Masuk',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Akses akun kasir, staf, atau pelanggan',
          style: TextStyle(
            fontSize: 12,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 18),

        if (_successMessage != null) _feedbackBanner(_successMessage!, true),
        if (_errorMessage != null) _feedbackBanner(_errorMessage!, false),

        _inputField(
          controller: _loginUsernameController,
          label: 'Username/Email',
          hintText: 'Contoh: admin atau nama@email.com',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        _inputField(
          controller: _loginPasswordController,
          label: 'Password',
          hintText: 'Masukkan kata sandi',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          obscure: _loginObscure,
          onToggle: () => setState(() => _loginObscure = !_loginObscure),
          onSubmit: (_) => _handleLogin(),
        ),

        const SizedBox(height: 18),

        // Primary Login Button
        _primaryButton('Masuk', Icons.arrow_forward_rounded, _handleLogin),

        const SizedBox(height: 14),

        _orDivider(),

        const SizedBox(height: 14),

        // Google Sign-In Button
        _googleSignInButton(),

        const SizedBox(height: 20),

        // Quick Role Shortcuts (Demo Fillers)
        _buildDemoRoleChips(),
      ],
    );
  }

  Widget _feedbackBanner(String message, bool isSuccess) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isSuccess ? AppTheme.statusGreenBg : AppTheme.statusRedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSuccess
              ? AppTheme.statusGreen.withValues(alpha: 0.25)
              : AppTheme.statusRed.withValues(alpha: 0.25),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
            prefixIcon: Icon(icon, size: 18, color: AppTheme.orangePrimary),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: context.textSecondary,
                    ),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: context.fillSubtle,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppTheme.orangePrimary, width: 1.6),
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
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF97316), Color(0xFFEA580C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.orangePrimary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSubmitting) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.2,
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'atau',
            style: TextStyle(
              fontSize: 11,
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
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderSubtle, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGoogleLoading) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.orangePrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Menghubungkan ke Google...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CustomPaint(painter: _GoogleLogoPainter()),
                ),
                const SizedBox(width: 10),
                Text(
                  'Masuk dengan Google',
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildDemoRoleChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.touch_app_outlined,
                size: 13, color: context.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Akses Cepat Pengujian (1-Klik):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _demoRoleChip('Admin', 'admin', 'admin123', const Color(0xFFEF4444)),
            _demoRoleChip('Kasir', 'kasir', 'kasir123', const Color(0xFF10B981)),
            _demoRoleChip('Waiter', 'waiter', 'waiter123', const Color(0xFF3B82F6)),
            _demoRoleChip('Owner', 'owner', 'owner123', const Color(0xFF8B5CF6)),
            _demoRoleChip(
                'Pelanggan', 'pelanggan', 'pelanggan123', const Color(0xFFF59E0B)),
          ],
        ),
      ],
    );
  }

  Widget _demoRoleChip(
      String label, String username, String password, Color accentColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _fillDemoCredentials(username, password),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
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
