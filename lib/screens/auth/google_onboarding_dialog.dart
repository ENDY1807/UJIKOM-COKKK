import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/phone_otp_service.dart';
import '../../theme/app_theme.dart';

class GoogleOnboardingDialog extends StatefulWidget {
  final DatabaseService db;
  final UserModel user;
  final VoidCallback onComplete;

  const GoogleOnboardingDialog({
    super.key,
    required this.db,
    required this.user,
    required this.onComplete,
  });

  static Future<void> show(
    BuildContext context, {
    required DatabaseService db,
    required UserModel user,
    required VoidCallback onComplete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GoogleOnboardingDialog(
        db: db,
        user: user,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<GoogleOnboardingDialog> createState() => _GoogleOnboardingDialogState();
}

class _GoogleOnboardingDialogState extends State<GoogleOnboardingDialog> {
  late TextEditingController _emailCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _otpCtrl;
  final FocusNode _otpFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: Form Profil & Nomor Telepon (tanpa tombol OTP)
  // Step 2: Konfirmasi Kode OTP setelah nomor diverifikasi
  int _step = 1;
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  Uint8List? _customImageBytes;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    final displayEmail = widget.user.googleEmail?.isNotEmpty == true
        ? widget.user.googleEmail!
        : widget.user.displayEmail;
    _emailCtrl = TextEditingController(text: displayEmail);

    _nameCtrl = TextEditingController(text: widget.user.namaUser);
    final fallbackUsername = displayEmail.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    _usernameCtrl = TextEditingController(
      text: widget.user.username.isNotEmpty && widget.user.username != 'pelanggan'
          ? widget.user.username
          : fallbackUsername,
    );
    _passwordCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: widget.user.phoneNumber);
    _otpCtrl = TextEditingController();
    _profilePhotoUrl = widget.user.fotoProfil;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0 && mounted) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
        setState(() {
          _customImageBytes = bytes;
          _profilePhotoUrl = base64String;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Gagal memilih foto: $e');
    }
  }

  /// Memvalidasi input profil lalu OTOMATIS mengirim kode OTP ke WhatsApp/SMS
  Future<void> _submitAndSendOtp() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final rawPhone = _phoneCtrl.text.trim();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Username wajib diisi');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Password wajib diisi');
      return;
    }
    if (rawPhone.length < 8) {
      setState(() => _errorMessage = 'Masukkan nomor telepon yang valid (minimal 8 digit)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await PhoneOtpService.instance.sendOtp(
        rawPhone: rawPhone,
      );

      _startCountdownTimer();

      setState(() {
        _step = 2; // Pindah ke tampilan konfirmasi OTP
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengirim kode verifikasi: $e';
        _isLoading = false;
      });
    }
  }

  /// Kirim ulang kode OTP
  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;
    final rawPhone = _phoneCtrl.text.trim();
    setState(() => _isLoading = true);

    try {
      await PhoneOtpService.instance.sendOtp(
        rawPhone: rawPhone,
      );
      _startCountdownTimer();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengirim ulang kode: $e';
        _isLoading = false;
      });
    }
  }

  /// Verifikasi kode OTP yang dimasukkan pengguna lalu masuk ke aplikasi
  Future<void> _verifyOtpAndLogin() async {
    final rawPhone = _phoneCtrl.text.trim();
    final inputCode = _otpCtrl.text.trim();

    if (inputCode.length != 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit kode verifikasi.');
      return;
    }

    final res = await PhoneOtpService.instance.verifyOtp(
      rawPhone: rawPhone,
      inputCode: inputCode,
    );

    if (!res.isValid) {
      setState(() => _errorMessage = res.message);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final cleanUsername = _usernameCtrl.text.trim().replaceAll('@', '').toLowerCase();

    await widget.db.updateUserProfile(
      idUser: widget.user.idUser,
      namaUser: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : cleanUsername,
      username: cleanUsername,
      password: _passwordCtrl.text.trim(),
      phoneNumber: rawPhone,
      fotoProfil: _profilePhotoUrl,
      isConfigured: true,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: context.surfaceCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: _step == 1 ? _buildProfileForm() : _buildOtpVerification(),
          ),
        ),
      ),
    );
  }

  /// Step 1: Form Profil Lengkap (Tanpa Tombol OTP, Langsung Konfirmasi di Bawah)
  Widget _buildProfileForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.isDarkMode
                      ? const Color(0xFF7C2D12)
                      : const Color(0xFFFFEDD5),
                ),
              ),
              child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFFEA580C), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfigurasi Akun Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  Text(
                    'Lengkapi profil akun untuk melanjutkan',
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: context.borderSubtle),
        const SizedBox(height: 16),

        // Foto Profil (Pilih dari Galeri)
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImageFromGallery,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: _customImageBytes != null
                          ? MemoryImage(_customImageBytes!)
                          : (_profilePhotoUrl != null && _profilePhotoUrl!.startsWith('http')
                              ? NetworkImage(_profilePhotoUrl!) as ImageProvider
                              : null),
                      child: (_customImageBytes == null &&
                              (_profilePhotoUrl == null || !_profilePhotoUrl!.startsWith('http')))
                          ? const Icon(Icons.person, size: 48, color: Color(0xFF94A3B8))
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.photo_library_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.image_search_rounded, size: 16, color: Color(0xFFEA580C)),
                label: const Text(
                  'Pilih Foto dari Galeri',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Input Email (Read Only - Sesuai Akun Google)
        Text(
          'Email Akun Google (Terkunci)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          enabled: false,
          style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: context.fillSubtle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Input Username
        Text(
          'Username Akun',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameCtrl,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'contoh: endy_rasantara',
            hintStyle: TextStyle(color: context.textSecondary),
            prefixIcon: const Icon(Icons.alternate_email, size: 18, color: Color(0xFFEA580C)),
            filled: true,
            fillColor: context.fillSubtle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Input Password
        Text(
          'Password Akun Baru',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'Buat password untuk login langsung',
            hintStyle: TextStyle(color: context.textSecondary),
            prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18, color: Color(0xFFEA580C)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: context.fillSubtle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Input Nomor Telepon
        Text(
          'Nomor Telepon',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: '081234567890',
            hintStyle: TextStyle(color: context.textSecondary),
            prefixIcon: const Icon(Icons.phone_android, size: 18, color: Color(0xFFEA580C)),
            helperText: 'Kode verifikasi akan dikirimkan untuk konfirmasi nomor telepon',
            helperStyle: TextStyle(fontSize: 11, color: context.textSecondary),
            filled: true,
            fillColor: context.fillSubtle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Tombol Konfirmasi Akun & Masuk Aplikasi
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEA580C),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(
            _isLoading ? 'Mengirim Kode...' : 'Konfirmasi & Lanjutkan',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          onPressed: _isLoading ? null : _submitAndSendOtp,
        ),
      ],
    );
  }

  /// Step 2: Tampilan Verifikasi Kode OTP (Sederhana & Bersih)
  Widget _buildOtpVerification() {
    final rawPhone = _phoneCtrl.text.trim();
    final displayPhone = PhoneOtpService.formatDisplayPhone(rawPhone);
    final text = _otpCtrl.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Verifikasi
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF64748B)),
              onPressed: () {
                setState(() {
                  _step = 1;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(width: 4),
            Text(
              'Verifikasi Nomor Telepon',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 6),

        Text(
          'Masukkan 6 digit kode yang dikirim ke $displayPhone',
          style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 6-Digit Boxes
        GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hidden TextField
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: TextField(
                    controller: _otpCtrl,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (val) {
                      setState(() {});
                      if (val.trim().length == 6) {
                        _verifyOtpAndLogin();
                      }
                    },
                  ),
                ),
              ),

              // 6 Box visuals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final isFilled = index < text.length;
                  final isCurrent = index == text.length;
                  final digit = isFilled ? text[index] : '';

                  return Container(
                    width: 42,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFFEA580C).withValues(alpha: 0.05)
                          : context.fillSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFEA580C)
                            : (isFilled ? context.borderSubtle.withValues(alpha: 0.8) : context.borderSubtle),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      digit,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Countdown & Kirim Ulang
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_resendCountdown > 0)
              Text(
                'Kirim ulang dalam $_resendCountdown detik',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _resendOtp,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Kirim ulang kode',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Tombol Verifikasi & Masuk
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEA580C),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _verifyOtpAndLogin,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text(
                  'Verifikasi & Masuk',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 8),

        // Tombol Ubah Nomor
        TextButton(
          onPressed: () {
            setState(() {
              _step = 1;
              _errorMessage = null;
            });
          },
          child: const Text(
            'Ubah Nomor Telepon',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}
