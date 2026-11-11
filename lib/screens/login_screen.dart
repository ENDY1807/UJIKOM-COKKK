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
      duration: const Duration(milliseconds: 350),
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
              _successMessage = 'Berhasil masuk sebagai ${name ?? email} (${user.role.label})';
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
    final success = await widget.db.loginAsync(usernameOrEmail, password);
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
        (!user.isConfigured || user.phoneNumber.isEmpty || user.username == 'pelanggan')) {
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
    final rawPhone = user.phoneNumber.isNotEmpty ? user.phoneNumber : '081234567890';

    await PhoneOtpService.instance.sendOtp(
      rawPhone: rawPhone,
    );

    if (!mounted) return;

    PhoneOtpDialog.show(
      context,
      phoneNumber: rawPhone,
      title: 'Verifikasi Dua Langkah',
      subtitle: 'Masukkan 6 digit kode yang dikirim ke ${PhoneOtpService.formatDisplayPhone(rawPhone)}',
      onVerified: () {
        widget.onLoginSuccess();
      },
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
            content: Text('Aplikasi KasirNih tetap aktif.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: context.surfaceBg,
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
    const w = 900.0;
    const h = 540.0;
    const half = w / 2;

    return Center(
      child: Container(
        width: w,
        height: h,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: context.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Left branding panel
            Container(
              width: half,
              height: h,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF7300),
                    Color(0xFFEA580C),
                    Color(0xFFCC4A0B),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(44),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/kasirnih_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.storefront,
                          color: Color(0xFFEA580C),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'KasirNih',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sistem Kasir & Pemesanan Restoran',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Right form panel
            Expanded(
              child: Container(
                color: context.surfaceCard,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MOBILE ───────────────────────────────────────────────────────────────
  Widget _buildMobile() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/kasirnih_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Container(
                        color: const Color(0xFFEA580C),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'KasirNih',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: context.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
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
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 20),

        if (_successMessage != null) _feedbackBanner(_successMessage!, true),
        if (_errorMessage != null) _feedbackBanner(_errorMessage!, false),

        _inputField(
          controller: _loginUsernameController,
          label: 'Username/Email',
          hintText: 'Masukkan username atau email',
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
        const SizedBox(height: 20),

        _primaryButton('Masuk', Icons.login, _handleLogin),
        const SizedBox(height: 16),

        _orDivider(),
        const SizedBox(height: 16),

        _googleSignInButton(),
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
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onSubmitted: onSubmit,
      style: TextStyle(
        fontSize: 14,
        color: context.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText ?? 'Masukkan $label',
        labelStyle: TextStyle(color: context.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.orangePrimary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: context.textSecondary,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: context.fillSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: AppTheme.orangePrimary, width: 1.8),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
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
          padding: const EdgeInsets.symmetric(vertical: 15),
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
        Expanded(child: Divider(color: context.borderSubtle, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'atau',
            style: TextStyle(
              fontSize: 12,
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
          padding: const EdgeInsets.symmetric(vertical: 13),
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
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(painter: _GoogleLogoPainter()),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Masuk dengan Google',
                  style: TextStyle(
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
