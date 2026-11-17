import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
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

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

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
    _profilePhotoUrl = widget.user.fotoProfil;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
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

  /// Memvalidasi input profil lalu menyimpan perubahan ke database
  Future<void> _saveProfileAndContinue() async {
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

    final cleanUsername = username.replaceAll('@', '').toLowerCase();

    await widget.db.updateUserProfile(
      idUser: widget.user.idUser,
      namaUser: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : cleanUsername,
      username: cleanUsername,
      password: password,
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
            child: _buildProfileForm(),
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
        TextField(
          controller: _emailCtrl,
          enabled: false,
          style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Email Akun Google (Terkunci)',
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(fontSize: 13, color: context.textSecondary),
            floatingLabelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: context.fillSubtle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Input Username
        TextField(
          controller: _usernameCtrl,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            labelText: 'Username Akun',
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(fontSize: 13, color: context.textSecondary),
            floatingLabelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFEA580C), fontWeight: FontWeight.bold),
            prefixIcon: const Icon(Icons.alternate_email, size: 18, color: Color(0xFFEA580C)),
            filled: true,
            fillColor: context.fillSubtle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Input Password
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            labelText: 'Password Akun Baru',
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(fontSize: 13, color: context.textSecondary),
            floatingLabelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFEA580C), fontWeight: FontWeight.bold),
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
        const SizedBox(height: 16),

        // Input Nomor Telepon
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            labelText: 'Nomor Telepon',
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(fontSize: 13, color: context.textSecondary),
            floatingLabelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFEA580C), fontWeight: FontWeight.bold),
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
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(
            _isLoading ? 'Menyimpan...' : 'Simpan & Masuk Aplikasi',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          onPressed: _isLoading ? null : _saveProfileAndContinue,
        ),
      ],
    );
  }
}
