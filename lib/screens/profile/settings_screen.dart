import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';
import '../../services/whatsapp_otp_service.dart';
import '../../widgets/app_loading_animation.dart';

class SettingsScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback? onProfileUpdated;

  const SettingsScreen({
    super.key,
    required this.db,
    this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers Profil
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _phoneCtrl;
  String _selectedAvatar = '';
  bool _is2faActive = false;
  bool _isSavingProfile = false;

  // Settings Aplikasi
  bool _soundFx = true;
  bool _notifications = true;
  bool _promoNotifications = true;
  bool _autoPrint = false;
  bool _haptic = true;
  String _mapStyle = 'osm';
  String _themeMode = 'light';
  String _language = 'id';
  String _fontSize = 'standard';
  bool _dataSaver = false;
  bool _biometric = false;
  Uint8List? _customImageBytes;

  Future<void> _pickProfilePhoto() async {
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
          _selectedAvatar = base64String;
        });
        _showSnackbar('Foto profil berhasil dipilih dari galeri');
      }
    } catch (e) {
      _showSnackbar('Gagal memilih foto: $e', isError: true);
    }
  }

  void _removeProfilePhoto() {
    setState(() {
      _customImageBytes = null;
      _selectedAvatar = '';
    });
    _showSnackbar('Foto profil telah dihapus');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final u = widget.db.currentUser;
    _nameCtrl = TextEditingController(text: u?.namaUser ?? '');
    _usernameCtrl = TextEditingController(text: u?.username ?? '');
    _phoneCtrl = TextEditingController(text: u?.phoneNumber ?? '');
    _selectedAvatar = u?.displayPhoto ?? '';
    _is2faActive = u?.isTwoFactorEnabled ?? false;

    _soundFx = widget.db.appSoundFx;
    _notifications = widget.db.appNotifications;
    _promoNotifications = widget.db.appPromoNotification;
    _autoPrint = widget.db.appAutoPrintReceipt;
    _haptic = widget.db.appHaptic;
    _mapStyle = widget.db.appMapStyle;
    _themeMode = widget.db.appThemeMode;
    _language = widget.db.appLanguage;
    _fontSize = widget.db.appFontSize;
    _dataSaver = widget.db.appDataSaver;
    _biometric = widget.db.appBiometricAuth;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    final user = widget.db.currentUser;
    if (user == null) return;

    if (_nameCtrl.text.trim().isEmpty) {
      _showSnackbar('Nama lengkap tidak boleh kosong', isError: true);
      return;
    }

    if (_usernameCtrl.text.trim().isEmpty) {
      _showSnackbar('Username tidak boleh kosong', isError: true);
      return;
    }

    AppLoadingAnimation.show(context, message: 'Menyimpan perubahan profil...');
    setState(() => _isSavingProfile = true);

    final cleanUsername = _usernameCtrl.text.trim().replaceAll('@', '').toLowerCase();
    final cleanPhone = _phoneCtrl.text.trim();

    final success = await widget.db.updateUserProfile(
      idUser: user.idUser,
      namaUser: _nameCtrl.text.trim(),
      username: cleanUsername,
      phoneNumber: cleanPhone,
      fotoProfil: _selectedAvatar.isNotEmpty ? _selectedAvatar : null,
      isTwoFactorEnabled: _is2faActive,
      isConfigured: true,
    );

    if (mounted) {
      AppLoadingAnimation.hide(context);
    }
    setState(() => _isSavingProfile = false);

    if (success) {
      _showSnackbar('Pengaturan profil berhasil disimpan');
      widget.onProfileUpdated?.call();
    } else {
      _showSnackbar('Gagal memperbarui profil pengguna', isError: true);
    }
  }

  Future<void> _verifyPhoneWithOtp() async {
    final rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.length < 8) {
      _showSnackbar('Masukkan nomor WhatsApp yang valid terlebih dahulu', isError: true);
      return;
    }

    final user = widget.db.currentUser;
    await WhatsAppOtpService.instance.sendOtp(
      rawPhone: rawPhone,
      userName: user?.namaUser ?? 'Pelanggan Rasantara',
      purpose: 'Verifikasi Nomor WhatsApp Rasantara',
    );

    if (!mounted) return;

    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_chat_read_rounded, color: Color(0xFF16A34A), size: 24),
            SizedBox(width: 10),
            Text('Verifikasi OTP WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kode OTP resmi telah dikirim ke nomor WhatsApp:\n$rawPhone',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF22C55E), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SMS / WhatsApp Terkirim: Silakan buka aplikasi chat Anda untuk melihat 6 digit kode.',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••••',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF16A34A), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () {
              final result = WhatsAppOtpService.instance.verifyOtp(
                rawPhone: rawPhone,
                inputCode: otpCtrl.text,
              );
              Navigator.pop(ctx);
              if (result.isValid) {
                _showSnackbar(result.message);
                setState(() {});
              } else {
                _showSnackbar(result.message, isError: true);
              }
            },
            child: const Text('Verifikasi OTP'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengaturan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Text(
              'Kelola Akun & Preferensi Aplikasi',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEA580C),
          indicatorWeight: 3,
          labelColor: const Color(0xFFEA580C),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Profil Akun'),
            Tab(icon: Icon(Icons.tune_rounded, size: 20), text: 'Sistem Aplikasi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildAppSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = widget.db.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Foto Profil & Pilihan Avatar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.photo_camera_front_outlined, size: 18, color: Color(0xFFEA580C)),
                    SizedBox(width: 8),
                    Text(
                      'Foto Profil Pengguna',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFFF1F5F9),
                            backgroundImage: _customImageBytes != null
                                ? MemoryImage(_customImageBytes!)
                                : (_selectedAvatar.isNotEmpty && _selectedAvatar.startsWith('data:image')
                                    ? MemoryImage(base64Decode(_selectedAvatar.split(',').last)) as ImageProvider
                                    : (_selectedAvatar.isNotEmpty && _selectedAvatar.startsWith('http')
                                        ? NetworkImage(_selectedAvatar) as ImageProvider
                                        : null)),
                            child: (_customImageBytes == null && _selectedAvatar.isEmpty)
                                ? const Icon(Icons.person, size: 36, color: Color(0xFF94A3B8))
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.namaUser ?? 'Pengguna',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFFEDD5)),
                            ),
                            child: Text(
                              user?.telepon.isNotEmpty == true ? user!.telepon : 'Member Rasantara',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF1E293B),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.photo_library_outlined, size: 14),
                                label: const Text('Ganti Foto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _pickProfilePhoto,
                              ),
                              if (_selectedAvatar.isNotEmpty || _customImageBytes != null)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: _removeProfilePhoto,
                                  child: const Text('Hapus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Form Detail Akun
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 18, color: Color(0xFFEA580C)),
                    SizedBox(width: 8),
                    Text(
                      'Informasi & Kredensial Akun',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Nama User
                const Text('Nama Lengkap Tampilan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
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

                // Username
                const Text('Username / ID Pengguna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    hintText: 'username',
                    prefixIcon: const Icon(Icons.alternate_email, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // WhatsApp Phone
                const Text('Nomor WhatsApp Terverifikasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '081234567890',
                          prefixIcon: const Icon(Icons.phone_android, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDCFCE7),
                        foregroundColor: const Color(0xFF15803D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      icon: const Icon(Icons.mark_chat_read, size: 16),
                      label: const Text('Kirim OTP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _verifyPhoneWithOtp,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2FA Switch
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Color(0xFF0284C7), size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Autentikasi 2 Langkah (2FA)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              'Minta kode verifikasi WhatsApp OTP saat login',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _is2faActive,
                        activeThumbColor: const Color(0xFFEA580C),
                        onChanged: (val) {
                          if (val && _phoneCtrl.text.trim().isEmpty) {
                            _showSnackbar('Isi nomor WhatsApp terlebih dahulu untuk mengaktifkan 2FA', isError: true);
                            return;
                          }
                          setState(() => _is2faActive = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tombol Simpan Profil
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isSavingProfile
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              _isSavingProfile ? 'Menyimpan...' : 'Simpan Perubahan Profil',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            onPressed: _isSavingProfile ? null : _handleSaveProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. TAMPILAN & TEMA APLIKASI ──
          _buildSettingsCard(
            icon: Icons.palette_outlined,
            title: 'Tampilan & Tema',
            subtitle: 'Sesuaikan kenyamanan visual dan mode aplikasi',
            children: [
              const Text(
                'Mode Tampilan Tema',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildThemeOption(
                    label: 'Terang',
                    icon: Icons.light_mode_outlined,
                    value: 'light',
                    isSelected: _themeMode == 'light',
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    label: 'Gelap',
                    icon: Icons.dark_mode_outlined,
                    value: 'dark',
                    isSelected: _themeMode == 'dark',
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    label: 'Sistem',
                    icon: Icons.brightness_auto_outlined,
                    value: 'system',
                    isSelected: _themeMode == 'system',
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              const Text(
                'Ukuran Teks & Font',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFontSizeOption(
                    label: 'Standar (100%)',
                    value: 'standard',
                    isSelected: _fontSize == 'standard',
                  ),
                  const SizedBox(width: 8),
                  _buildFontSizeOption(
                    label: 'Besar (115%)',
                    value: 'large',
                    isSelected: _fontSize == 'large',
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.data_saver_on_outlined,
                title: 'Mode Hemat Kuota (Data Saver)',
                subtitle: 'Gunakan resolusi gambar lebih hemat saat jaringan lambat',
                value: _dataSaver,
                onChanged: (val) {
                  setState(() => _dataSaver = val);
                  widget.db.updateAppSettings(dataSaver: val);
                  _showSnackbar('Mode hemat kuota ${val ? "diaktifkan" : "dinonaktifkan"}');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. BAHASA & DAERAH ──
          _buildSettingsCard(
            icon: Icons.language_rounded,
            title: 'Bahasa & Daerah (Language)',
            subtitle: 'Pilihan bahasa dan format mata uang lokal',
            children: [
              const Text(
                'Bahasa Antarmuka',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildLanguageOption(
                    label: 'Bahasa Indonesia',
                    flag: 'ID',
                    value: 'id',
                    isSelected: _language == 'id',
                  ),
                  const SizedBox(width: 8),
                  _buildLanguageOption(
                    label: 'English',
                    flag: 'EN',
                    value: 'en',
                    isSelected: _language == 'en',
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.currency_exchange_rounded, size: 18, color: Color(0xFFEA580C)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Format Mata Uang & Zona Waktu',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Rupiah Indonesia (Rp • IDR) • Waktu Indonesia Barat (WIB)',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 3. NOTIFIKASI & SUARA ──
          _buildSettingsCard(
            icon: Icons.notifications_active_outlined,
            title: 'Notifikasi & Suara',
            subtitle: 'Pengingat pesanan, promo, dan respons suara aplikasi',
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Status Pesanan & Driver',
                subtitle: 'Peringatan saat pesanan disiapkan dapur atau driver mengantar',
                value: _notifications,
                onChanged: (val) {
                  setState(() => _notifications = val);
                  widget.db.updateAppSettings(notifications: val);
                },
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.local_offer_outlined,
                title: 'Promo & Diskon Eksklusif',
                subtitle: 'Info penawaran voucher mingguan dan flash sale kuliner',
                value: _promoNotifications,
                onChanged: (val) {
                  setState(() => _promoNotifications = val);
                  widget.db.updateAppSettings(promoNotification: val);
                },
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.volume_up_outlined,
                title: 'Efek Suara Audio',
                subtitle: 'Umpan balik suara saat klik tombol dan menambah menu ke keranjang',
                value: _soundFx,
                onChanged: (val) {
                  setState(() => _soundFx = val);
                  widget.db.updateAppSettings(soundFx: val);
                },
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.vibration_rounded,
                title: 'Umpan Balik Haptik (Getar)',
                subtitle: 'Getaran lembut perangkat saat konfirmasi checkout dan aksi penting',
                value: _haptic,
                onChanged: (val) {
                  setState(() => _haptic = val);
                  widget.db.updateAppSettings(haptic: val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 4. KEAMANAN & PRIVASI ──
          _buildSettingsCard(
            icon: Icons.security_rounded,
            title: 'Keamanan & Privasi',
            subtitle: 'Perlindungan akun, verifikasi masuk, dan biometrik',
            children: [
              _buildSwitchTile(
                icon: Icons.phonelink_lock_rounded,
                title: 'Verifikasi 2 Langkah (2FA WhatsApp)',
                subtitle: 'Minta kode verifikasi OTP WhatsApp setiap kali masuk akun baru',
                value: _is2faActive,
                onChanged: (val) {
                  if (val && _phoneCtrl.text.trim().isEmpty) {
                    _showSnackbar('Isi nomor telepon terlebih dahulu pada tab profil', isError: true);
                    return;
                  }
                  setState(() => _is2faActive = val);
                  _handleSaveProfile();
                },
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.fingerprint_rounded,
                title: 'Kunci Biometrik / PIN Transaksi',
                subtitle: 'Wajibkan sidik jari atau PIN sebelum memproses pembayaran pesanan',
                value: _biometric,
                onChanged: (val) {
                  setState(() => _biometric = val);
                  widget.db.updateAppSettings(biometricAuth: val);
                  _showSnackbar('Kunci biometrik transaksi ${val ? "diaktifkan" : "dinonaktifkan"}');
                },
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              InkWell(
                onTap: _showPrivacyPolicyDialog,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, size: 20, color: Color(0xFF64748B)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kebijakan Privasi & Perlindungan Data',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              'Pelajari bagaimana data nomor dan pesanan Anda dilindungi',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 5. PREFERENSI PEMESANAN & PETA ──
          _buildSettingsCard(
            icon: Icons.receipt_long_outlined,
            title: 'Preferensi Pemesanan & Peta',
            subtitle: 'Pengaturan pencetakan struk dan tampilan navigasi',
            children: [
              _buildSwitchTile(
                icon: Icons.print_outlined,
                title: 'Cetak Struk Otomatis (Auto-Print)',
                subtitle: 'Kirim perintah cetak struk termal segera setelah transaksi lunas',
                value: _autoPrint,
                onChanged: (val) {
                  setState(() => _autoPrint = val);
                  widget.db.updateAppSettings(autoPrintReceipt: val);
                },
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              const Text(
                'Tipe Tampilan Peta Driver',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMapOption(
                    label: 'OpenStreetMap',
                    desc: 'Standar jalan & bangunan',
                    value: 'osm',
                    isSelected: _mapStyle == 'osm',
                  ),
                  const SizedBox(width: 8),
                  _buildMapOption(
                    label: 'Carto Positron',
                    desc: 'Minimalis & hemat data',
                    value: 'carto_light',
                    isSelected: _mapStyle == 'carto_light',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 6. PENYIMPANAN & PEMELIHARAAN ──
          _buildSettingsCard(
            icon: Icons.cleaning_services_outlined,
            title: 'Penyimpanan & Data Cache',
            subtitle: 'Kelola file sementara dan reset aplikasi',
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Data Cache Sementara', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    Text('14.8 MB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Bersihkan Cache Gambar & Data Sementara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  _showSnackbar('Cache aplikasi 14.8 MB berhasil dibersihkan');
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Kembalikan Semua Pengaturan ke Default', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Reset Pengaturan?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      content: const Text(
                        'Semua tema, bahasa, suara, dan preferensi aplikasi akan dikembalikan ke pengaturan awal.',
                        style: TextStyle(fontSize: 13),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await widget.db.clearAppCacheAndPreferences();
                            setState(() {
                              _soundFx = true;
                              _notifications = true;
                              _promoNotifications = true;
                              _autoPrint = false;
                              _haptic = true;
                              _mapStyle = 'osm';
                              _themeMode = 'light';
                              _language = 'id';
                              _fontSize = 'standard';
                              _dataSaver = false;
                              _biometric = false;
                            });
                            _showSnackbar('Pengaturan aplikasi berhasil direset ke default');
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 7. TENTANG APLIKASI & BANTUAN ──
          _buildSettingsCard(
            icon: Icons.info_outline_rounded,
            title: 'Tentang Aplikasi & Bantuan',
            subtitle: 'Informasi versi dan kontak layanan pelanggan',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C), size: 20),
                ),
                title: const Text('Rasantara Resto & Cafe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Versi 2.4.0 (Official Production)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Terbaru', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ),
              ),
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              InkWell(
                onTap: _showHelpSupportDialog,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.headset_mic_outlined, size: 20, color: Color(0xFF15803D)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pusat Bantuan & Layanan CS',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              'Hubungi layanan pelanggan WhatsApp Rasantara 24 Jam',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Helper Card Pembungkus Pengaturan
  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFFEA580C)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // Opsi Pilihan Tema
  Widget _buildThemeOption({
    required String label,
    required IconData icon,
    required String value,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _themeMode = value);
          widget.db.updateAppSettings(themeMode: value);
          _showSnackbar('Tema tampilan diubah ke $label');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Opsi Pilihan Ukuran Font
  Widget _buildFontSizeOption({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _fontSize = value);
          widget.db.updateAppSettings(fontSize: value);
          _showSnackbar('Ukuran teks diubah ke $label');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // Opsi Pilihan Bahasa
  Widget _buildLanguageOption({
    required String label,
    required String flag,
    required String value,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _language = value);
          widget.db.updateAppSettings(language: value);
          _showSnackbar('Bahasa diubah ke $label');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Opsi Pilihan Gaya Peta
  Widget _buildMapOption({
    required String label,
    required String desc,
    required String value,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _mapStyle = value);
          widget.db.updateAppSettings(mapStyle: value);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 16,
                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog Kebijakan Privasi
  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Color(0xFFEA580C), size: 22),
            SizedBox(width: 8),
            Text('Kebijakan Privasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Rasantara Restoran menjaga kerahasiaan data pengguna. Nomor telepon dan alamat hanya digunakan untuk kepentingan pengiriman pesanan, notifikasi transaksi via WhatsApp, serta keamanan akun 2FA. Kami tidak pernah membagikan data kepada pihak ketiga.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF475569)),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Saya Mengerti'),
          ),
        ],
      ),
    );
  }

  // Dialog Bantuan & Customer Service
  void _showHelpSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.headset_mic_rounded, color: Color(0xFF16A34A), size: 22),
            SizedBox(width: 8),
            Text('Pusat Bantuan CS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Butuh bantuan seputar pesanan atau pembayaran Anda?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            SizedBox(height: 8),
            Text(
              'Layanan Pelanggan Rasantara siap membantu melalui kontak resmi:\n\n• WhatsApp: +62 812-3456-7890\n• Jam Operasional: 08:00 - 22:00 WIB\n• Email: bantuan@rasantara.id',
              style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF475569)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () {
              Navigator.pop(ctx);
              _showSnackbar('Membuka chat WhatsApp Layanan Pelanggan...');
            },
            child: const Text('Chat WhatsApp CS'),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: const Color(0xFFEA580C),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
