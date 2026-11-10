import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/whatsapp_otp_service.dart';

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

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: Form Profil & Nomor Telepon (tanpa tombol OTP)
  // Step 2: Konfirmasi Kode OTP setelah nomor diverifikasi
  int _step = 1;
  String? _sentOtpCode;
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
      final code = await WhatsAppOtpService.instance.sendOtp(
        rawPhone: rawPhone,
        userName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : username,
        purpose: 'Konfirmasi Akun & Nomor Telepon Rasantara',
      );

      _startCountdownTimer();

      setState(() {
        _sentOtpCode = code;
        _step = 2; // Pindah ke tampilan konfirmasi OTP
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengirim OTP ke nomor tersebut: $e';
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
      final code = await WhatsAppOtpService.instance.sendOtp(
        rawPhone: rawPhone,
        userName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Pengguna',
        purpose: 'Kirim Ulang Kode OTP Rasantara',
      );
      _startCountdownTimer();
      setState(() {
        _sentOtpCode = code;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengirim ulang OTP: $e';
        _isLoading = false;
      });
    }
  }

  /// Verifikasi kode OTP yang dimasukkan pengguna lalu masuk ke aplikasi
  Future<void> _verifyOtpAndLogin() async {
    final rawPhone = _phoneCtrl.text.trim();
    final inputCode = _otpCtrl.text.trim();

    if (inputCode.length != 6) {
      setState(() => _errorMessage = 'Kode OTP harus 6 digit');
      return;
    }

    final res = WhatsAppOtpService.instance.verifyOtp(
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
      backgroundColor: Colors.white,
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
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFFEA580C), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfigurasi Akun Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    'Lengkapi profil akun untuk melanjutkan',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
        const Text(
          'Email Akun Google (Terkunci)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          enabled: false,
          style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Input Username
        const Text(
          'Username Akun',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameCtrl,
          decoration: InputDecoration(
            hintText: 'contoh: endy_rasantara',
            prefixIcon: const Icon(Icons.alternate_email, size: 18, color: Color(0xFFEA580C)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),

        // Input Password
        const Text(
          'Password Akun Baru',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Buat password untuk login langsung',
            prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18, color: Color(0xFFEA580C)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),

        // Input Nomor Telepon / WhatsApp (Bersih, TANPA TOMBOL OTP)
        const Text(
          'Nomor Telepon / WhatsApp',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '081234567890',
            prefixIcon: const Icon(Icons.phone_android, size: 18, color: Color(0xFFEA580C)),
            helperText: 'Kode OTP akan otomatis dikirimkan ke nomor ini saat konfirmasi',
            helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            _isLoading ? 'Mengirim Kode OTP...' : 'Konfirmasi Akun & Masuk Aplikasi',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          onPressed: _isLoading ? null : _submitAndSendOtp,
        ),
      ],
    );
  }

  /// Step 2: Tampilan Verifikasi Kode OTP (dengan banner notifikasi SMS/WA masuk)
  Widget _buildOtpVerification() {
    final rawPhone = _phoneCtrl.text.trim();
    final normalized = WhatsAppOtpService.normalizePhoneNumber(rawPhone);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Simulated Push Notification Banner SMS / WhatsApp
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1F000000),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mark_chat_unread_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'WhatsApp / SMS • Rasantara Security',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Baru saja',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 9),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kode OTP verifikasi Anda: ${_sentOtpCode ?? "------"}. Masukkan kode ini untuk mengonfirmasi akun.',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

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
            const Text(
              'Verifikasi Kode OTP',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Text(
          'Kode 6 digit keamanan telah dikirimkan ke nomor WhatsApp/SMS +$normalized.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),

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

        // Input 6 Digit OTP
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEA580C), width: 2),
            ),
          ),
          onChanged: (val) {
            if (val.trim().length == 6) {
              _verifyOtpAndLogin();
            }
          },
        ),
        const SizedBox(height: 12),

        // Countdown & Kirim Ulang
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _resendCountdown > 0
                  ? 'Kirim ulang kode dalam $_resendCountdown detik'
                  : 'Tidak menerima kode?',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (_resendCountdown == 0) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: _isLoading ? null : _resendOtp,
                child: const Text(
                  'Kirim Ulang',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Tombol Verifikasi & Masuk
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _verifyOtpAndLogin,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text(
                  'Verifikasi & Masuk ke Aplikasi',
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
