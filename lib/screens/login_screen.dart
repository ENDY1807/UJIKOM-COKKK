import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/database_service.dart';
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
  bool _isRegisterMode = false;

  // Controllers Login
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;

  // Controllers Register Pelanggan
  final _regNameController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _regObscure = true;
  final bool _regIsSubscribed = true; // Default mendaftar sebagai Member Berlangganan VIP

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

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
  }

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _fadeController.dispose();
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
      setState(() => _errorMessage = context.t('Kolom wajib diisi', 'Please fill in all fields'));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await widget.db.loginAsync(_loginUsernameController.text.trim(), password);
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
          _errorMessage = widget.db.lastLoginError ??
              context.t('Username / Email atau password salah', 'Incorrect Username / Email or password');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final name = _regNameController.text.trim();
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final phone = _regPhoneController.text.trim();
    final password = _regPasswordController.text;

    if (name.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Nama, Username, dan Password wajib diisi.');
      return;
    }

    if (password.length < 3) {
      setState(() => _errorMessage = 'Password minimal 3 karakter.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final newUser = await widget.db.registerUser(
        username: username,
        password: password,
        namaUser: name,
        email: email.isNotEmpty ? email : null,
        isSubscribed: _regIsSubscribed,
      );

      // Update nomor telepon jika diisi
      if (phone.isNotEmpty) {
        widget.db.updateUser(
          newUser.idUser,
          newUser.namaUser,
          newUser.password,
          newUser.role,
          email: newUser.googleEmail,
          phoneNumber: phone,
          isSubscribed: newUser.isSubscribed,
        );
      }

      if (!mounted) return;
      widget.onLoginSuccess();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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

    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBg,
              Color(0xFF040506),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFAFAF9),
              Color(0xFFF5F5F4),
            ],
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Prevent accidental app close silently without bottom banner
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + bottomInset),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1020, minHeight: 620),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Brand Presentation Panel (Orange & Putih)
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF7A00),
                          AppTheme.orangePrimary,
                          Color(0xFFEA580C),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo Aplikasi Rasantara
                        SizedBox(
                          width: 104,
                          height: 104,
                          child: Image.asset(
                            'assets/images/Rasantara Cloche App Icon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.restaurant_rounded,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Nama Restoran / Brand
                        const Text(
                          'Rasantara',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Slogan
                        Text(
                          'Autentik Cita Rasa Nusantara',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),

                        // Garis aksen pemisah putih halus
                        Container(
                          width: 48,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 22),

                      ],
                    ),
                  ),
                ),

                // Right Form Panel
                Expanded(
                  flex: 5,
                  child: Container(
                    color: context.surfaceCard,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _buildLoginForm(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── MOBILE LAYOUT ─────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 24, 22, 24 + bottomInset),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 410),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clean App Brand Icon
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    'assets/images/Rasantara Cloche App Icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.restaurant_rounded,
                      color: AppTheme.orangePrimary,
                      size: 44,
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
                const SizedBox(height: 4),
                Text(
                  'Autentik Cita Rasa Nusantara',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 24),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
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

  // ─── LOGIN / REGISTER FORM ────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab Switcher Masuk vs Daftar Pelanggan
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.fillSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isRegisterMode = false;
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: !_isRegisterMode ? context.surfaceCard : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: !_isRegisterMode
                          ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        context.t('Masuk', 'Sign In'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: !_isRegisterMode ? AppTheme.orangePrimary : context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isRegisterMode = true;
                      _errorMessage = null;
                      _successMessage = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _isRegisterMode ? context.surfaceCard : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _isRegisterMode
                          ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Daftar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isRegisterMode ? AppTheme.orangePrimary : context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          _isRegisterMode ? 'Registrasi Pelanggan' : context.t('Masuk', 'Sign In'),
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        if (_successMessage != null) _feedbackBanner(_successMessage!, true),
        if (_errorMessage != null) _feedbackBanner(_errorMessage!, false),

        if (!_isRegisterMode) ...[
          _inputField(
            controller: _loginUsernameController,
            label: context.t('Username atau Email', 'Username or Email'),
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: _loginPasswordController,
            label: context.t('Password', 'Password'),
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscure: _loginObscure,
            onToggle: () => setState(() => _loginObscure = !_loginObscure),
            onSubmit: (_) => _handleLogin(),
          ),
          const SizedBox(height: 20),
          _primaryButton(context.t('Masuk', 'Sign In'), Icons.arrow_forward_rounded, _handleLogin),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegisterMode = true),
              child: const Text(
                'Belum punya akun? Daftar sebagai Pelanggan di sini',
                style: TextStyle(fontSize: 12, color: AppTheme.orangePrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ] else ...[
          _inputField(
            controller: _regNameController,
            label: 'Nama Lengkap',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _regUsernameController,
            label: 'Username',
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _regEmailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _regPhoneController,
            label: 'No Telepon',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _inputField(
            controller: _regPasswordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscure: _regObscure,
            onToggle: () => setState(() => _regObscure = !_regObscure),
            onSubmit: (_) => _handleRegister(),
          ),
          const SizedBox(height: 14),

          _primaryButton('Daftar', Icons.check_circle_outline, _handleRegister),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegisterMode = false),
              child: const Text(
                'Sudah memiliki akun? Masuk di sini',
                style: TextStyle(fontSize: 12, color: AppTheme.orangePrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(
          fontSize: 13.5,
          color: context.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 13,
          color: AppTheme.orangePrimary,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.orangePrimary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: context.textSecondary,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: context.fillSubtle,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            color: AppTheme.orangePrimary,
            borderRadius: BorderRadius.circular(10),
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

}
