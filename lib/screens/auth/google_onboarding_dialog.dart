import 'package:flutter/material.dart';
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
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _otpCtrl;

  bool _isOtpSent = false;
  bool _isPhoneVerified = false;
  String? _generatedOtp;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.namaUser);
    final fallbackUsername = widget.user.googleEmail?.split('@').first ?? 'pelanggan_${widget.user.idUser}';
    _usernameCtrl = TextEditingController(
      text: widget.user.username.isNotEmpty && widget.user.username != 'pelanggan'
          ? widget.user.username
          : fallbackUsername,
    );
    _phoneCtrl = TextEditingController(text: widget.user.phoneNumber);
    _otpCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.length < 8) {
      setState(() => _errorMessage = 'Masukkan nomor WhatsApp yang valid');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final code = await WhatsAppOtpService.instance.sendOtp(
        rawPhone: rawPhone,
        userName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Pengguna Rasantara',
        purpose: 'Registrasi & Konfigurasi Akun Google Rasantara',
      );

      setState(() {
        _isOtpSent = true;
        _generatedOtp = code;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengirim OTP: $e';
        _isLoading = false;
      });
    }
  }

  void _verifyOtp() {
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

    if (res.isValid) {
      setState(() {
        _isPhoneVerified = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _errorMessage = res.message);
    }
  }

  Future<void> _completeSetup() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Nama lengkap wajib diisi');
      return;
    }
    if (_usernameCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Username wajib diisi');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Nomor WhatsApp wajib diisi');
      return;
    }

    setState(() => _isLoading = true);

    final cleanUsername = _usernameCtrl.text.trim().replaceAll('@', '').toLowerCase();

    await widget.db.updateUserProfile(
      idUser: widget.user.idUser,
      namaUser: _nameCtrl.text.trim(),
      username: cleanUsername,
      phoneNumber: _phoneCtrl.text.trim(),
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
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
                            'Konfigurasi Akun',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Lengkapi username & nomor WhatsApp Anda',
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

                // Input Nama Lengkap
                const Text('Nama Lengkap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Nama lengkap Anda',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Input Username
                const Text('Username Pilihan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    hintText: 'contoh: rendy_rasantara',
                    prefixIcon: const Icon(Icons.alternate_email, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Input WhatsApp & OTP
                const Text('Nomor WhatsApp (Untuk OTP & Notifikasi)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        enabled: !_isPhoneVerified,
                        decoration: InputDecoration(
                          hintText: '081234567890',
                          prefixIcon: const Icon(Icons.phone_android, size: 18),
                          suffixIcon: _isPhoneVerified
                              ? const Icon(Icons.verified, color: Color(0xFF16A34A), size: 20)
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: _isPhoneVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                        foregroundColor: _isPhoneVerified ? const Color(0xFF15803D) : const Color(0xFFEA580C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      onPressed: _isPhoneVerified || _isLoading ? null : _sendOtp,
                      child: Text(
                        _isPhoneVerified ? 'Terverifikasi' : (_isOtpSent ? 'Kirim Ulang' : 'Kirim OTP'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                if (_isOtpSent && !_isPhoneVerified) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sms_outlined, size: 16, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            const Text(
                              'Masukkan 6 digit OTP WhatsApp:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                            ),
                            const Spacer(),
                            if (_generatedOtp != null)
                              InkWell(
                                onTap: () => _otpCtrl.text = _generatedOtp!,
                                child: Text('Demo: $_generatedOtp (Isi)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D), decoration: TextDecoration.underline)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '••••••',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _verifyOtp,
                              child: const Text('Verifikasi', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Button Masuk Aplikasi
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _completeSetup,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Simpan & Lanjutkan ke Aplikasi',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

