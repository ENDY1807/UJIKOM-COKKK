import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/phone_otp_service.dart';
import '../../widgets/app_loading_animation.dart';
import '../../widgets/biometric_auth_dialog.dart';
import '../../widgets/phone_otp_dialog.dart';
import '../../theme/app_theme.dart';
import '../../services/audio_notification_service.dart';
import '../../services/export_report_service.dart';

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
  bool _biometric = false;
  String _cacheSize = '14.8 MB';
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
    _mapStyle = (widget.db.appMapStyle == 'carto_light') ? 'carto_light' : 'osm';
    _themeMode = (widget.db.appThemeMode == 'dark' || widget.db.appThemeMode == 'system') ? widget.db.appThemeMode : 'light';
    _language = (widget.db.appLanguage == 'en') ? 'en' : 'id';
    _biometric = widget.db.appBiometricAuth;
    _cacheSize = '14.8 MB';
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
      _showSnackbar('Masukkan nomor telepon yang valid terlebih dahulu', isError: true);
      return;
    }

    _showSnackbar('Mengirim kode verifikasi...');
    await PhoneOtpService.instance.sendOtp(
      rawPhone: rawPhone,
    );

    if (!mounted) return;

    PhoneOtpDialog.show(
      context,
      phoneNumber: rawPhone,
      title: 'Verifikasi Nomor Telepon',
      subtitle: 'Masukkan 6 digit kode yang dikirim ke ${PhoneOtpService.formatDisplayPhone(rawPhone)}',
      onVerified: () {
        _showSnackbar('Nomor telepon berhasil diverifikasi.');
        setState(() {});
      },
    );
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : (context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFF0F172A)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError
                ? const Color(0xFFB91C1C)
                : (context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFEA580C)),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.db.currentUser;
    final isPelanggan = user?.role == UserRole.pelanggan;

    if (!isPelanggan) {
      return Scaffold(
        backgroundColor: context.surfaceBg,
        appBar: AppBar(
          backgroundColor: context.surfaceCard,
          elevation: 0.5,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('Pengaturan', 'Settings'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              Text(
                context.t('Preferensi Sistem Aplikasi', 'System Preferences'),
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
            ],
          ),
        ),
        body: _buildAppSettingsTab(),
      );
    }

    return Scaffold(
      backgroundColor: context.surfaceBg,
      appBar: AppBar(
        backgroundColor: context.surfaceCard,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('Pengaturan Akun', 'Account Settings'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            Text(
              context.t('Keamanan Akun & Preferensi', 'Account Security & Preferences'),
              style: TextStyle(fontSize: 11, color: context.textSecondary),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEA580C),
          indicatorWeight: 3,
          labelColor: const Color(0xFFEA580C),
          unselectedLabelColor: context.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: [
            Tab(icon: const Icon(Icons.shield_outlined, size: 20), text: context.t('Keamanan & Profil', 'Security & Profile')),
            Tab(icon: const Icon(Icons.tune_rounded, size: 20), text: context.t('Sistem Aplikasi', 'System Settings')),
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
              color: context.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_camera_front_outlined, size: 18, color: Color(0xFFEA580C)),
                    const SizedBox(width: 8),
                    Text(
                      'Foto Profil Pengguna',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary),
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
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
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
              color: context.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 18, color: Color(0xFFEA580C)),
                    const SizedBox(width: 8),
                    Text(
                      'Informasi & Kredensial Akun',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary),
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
                    color: context.fillSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Color(0xFF0284C7), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('Autentikasi 2 Langkah (2FA)', 'Two-Factor Authentication (2FA)'),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                            ),
                            Text(
                              context.t('Minta kode verifikasi SMS / Telepon saat login', 'Require SMS / Phone verification code upon login'),
                              style: TextStyle(fontSize: 11, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _is2faActive,
                        activeThumbColor: const Color(0xFFEA580C),
                        onChanged: (val) {
                          if (val && _phoneCtrl.text.trim().isEmpty) {
                            _showSnackbar(context.t('Isi nomor telepon terlebih dahulu untuk mengaktifkan 2FA', 'Please enter your phone number first to enable 2FA'), isError: true);
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
            title: context.t('Tampilan & Tema', 'Theme & Appearance'),
            subtitle: context.t('Sesuaikan kenyamanan visual dan mode aplikasi', 'Customize visual comfort and theme mode'),
            children: [
              Text(
                context.t('Mode Tampilan Tema', 'Theme Mode'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildThemeOption(
                    label: context.t('Terang', 'Light'),
                    icon: Icons.light_mode_outlined,
                    value: 'light',
                    isSelected: _themeMode == 'light',
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    label: context.t('Gelap', 'Dark'),
                    icon: Icons.dark_mode_outlined,
                    value: 'dark',
                    isSelected: _themeMode == 'dark',
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    label: context.t('Sistem', 'System'),
                    icon: Icons.brightness_auto_outlined,
                    value: 'system',
                    isSelected: _themeMode == 'system',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. BAHASA ──
          _buildSettingsCard(
            icon: Icons.language_rounded,
            title: context.t('Bahasa', 'Language'),
            subtitle: context.t('Pilihan bahasa antarmuka aplikasi', 'Choose app interface language'),
            children: [
              Text(
                context.t('Bahasa Antarmuka', 'Interface Language'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.textPrimary),
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
            ],
          ),
          const SizedBox(height: 16),

          // ── 3. NOTIFIKASI & SUARA ──
          _buildSettingsCard(
            icon: Icons.notifications_active_outlined,
            title: context.t('Notifikasi & Suara', 'Notifications & Sound'),
            subtitle: context.t('Pengingat pesanan, promo, dan respons suara aplikasi', 'Order alerts, promos, and audio responses'),
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: context.t('Notifikasi Langsung ke HP / Windows', 'Push Notifications to Device / Windows'),
                subtitle: context.t('Muncul di bilah status notifikasi HP & Windows Action Center (Toast OS)', 'Appear in phone status bar & Windows Action Center'),
                value: _notifications,
                onChanged: (val) async {
                  setState(() => _notifications = val);
                  widget.db.updateAppSettings(notifications: val);
                  if (val) {
                    await AudioNotificationService.requestSystemNotificationPermission();
                  }
                },
              ),
              Divider(height: 20, color: context.borderSubtle),
              _buildSwitchTile(
                icon: Icons.local_offer_outlined,
                title: context.t('Promo & Diskon Eksklusif', 'Promos & Exclusive Deals'),
                subtitle: context.t('Info penawaran voucher mingguan dan flash sale kuliner', 'Weekly voucher discounts and flash sale specials'),
                value: _promoNotifications,
                onChanged: (val) {
                  setState(() => _promoNotifications = val);
                  widget.db.updateAppSettings(promoNotification: val);
                },
              ),
              Divider(height: 20, color: context.borderSubtle),
              _buildSwitchTile(
                icon: Icons.volume_up_outlined,
                title: context.t('Efek Suara Audio', 'Sound Effects'),
                subtitle: context.t('Umpan balik suara saat klik tombol dan menambah menu ke keranjang', 'Audio feedback on button click and adding items to cart'),
                value: _soundFx,
                onChanged: (val) {
                  setState(() => _soundFx = val);
                  widget.db.updateAppSettings(soundFx: val);
                },
              ),
              Divider(height: 20, color: context.borderSubtle),
              _buildSwitchTile(
                icon: Icons.vibration_rounded,
                title: context.t('Umpan Balik Haptik (Getar)', 'Haptic Feedback (Vibration)'),
                subtitle: context.t('Getaran lembut perangkat saat konfirmasi checkout dan aksi penting', 'Gentle device vibration on checkout and key actions'),
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
            title: context.t('Keamanan & Privasi', 'Security & Privacy'),
            subtitle: context.t('Perlindungan akun, verifikasi masuk, dan biometrik', 'Account protection, 2FA sign-in, and biometrics'),
            children: [
              _buildSwitchTile(
                icon: Icons.phonelink_lock_rounded,
                title: context.t('Verifikasi 2 Langkah (2FA Telepon)', '2-Step Verification (Phone 2FA)'),
                subtitle: context.t('Minta kode verifikasi OTP SMS/Telepon setiap kali masuk akun baru', 'Require phone OTP verification code on new sign-ins'),
                value: _is2faActive,
                onChanged: (val) {
                  if (val && _phoneCtrl.text.trim().isEmpty) {
                    _showSnackbar(context.t('Isi nomor telepon terlebih dahulu pada tab profil', 'Please enter your phone number in the profile tab first'), isError: true);
                    return;
                  }
                  setState(() => _is2faActive = val);
                  _handleSaveProfile();
                },
              ),
              Divider(height: 20, color: context.borderSubtle),
              _buildSwitchTile(
                icon: Icons.fingerprint_rounded,
                title: context.t('Kunci Biometrik / PIN Transaksi', 'Biometric Lock / Transaction PIN'),
                subtitle: context.t('Wajibkan sidik jari atau PIN sebelum memproses pembayaran pesanan', 'Require fingerprint or PIN before completing order payments'),
                value: _biometric,
                onChanged: (val) async {
                  final isVerified = await BiometricAuthDialog.authenticate(
                    context: context,
                    title: val
                        ? context.t('Aktivasi Kunci Biometrik', 'Enable Biometric Lock')
                        : context.t('Nonaktifkan Kunci Biometrik', 'Disable Biometric Lock'),
                    reason: val
                        ? context.t('Verifikasi sidik jari atau PIN keamanan untuk mengaktifkan proteksi transaksi pesanan.', 'Verify fingerprint or PIN to activate order payment protection.')
                        : context.t('Verifikasi sidik jari atau PIN keamanan Anda untuk menonaktifkan proteksi transaksi.', 'Verify fingerprint or PIN to disable payment protection.'),
                  );
                  if (isVerified) {
                    setState(() => _biometric = val);
                    widget.db.updateAppSettings(biometricAuth: val);
                  }
                },
              ),
              Divider(height: 20, color: context.borderSubtle),
              InkWell(
                onTap: _showPrivacyPolicyDialog,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, size: 20, color: Color(0xFF64748B)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('Kebijakan Privasi & Perlindungan Data', 'Privacy Policy & Data Protection'),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                            ),
                            Text(
                              context.t('Pelajari bagaimana data nomor dan pesanan Anda dilindungi', 'Learn how your data, orders, and privacy are protected'),
                              style: TextStyle(fontSize: 11, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: context.textSecondary),
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
            title: context.t('Preferensi Pemesanan & Peta', 'Ordering & Map Preferences'),
            subtitle: context.t('Pengaturan pencetakan struk dan tampilan navigasi', 'Receipt printing options and map navigation styles'),
            children: [
              _buildSwitchTile(
                icon: Icons.print_outlined,
                title: context.t('Cetak Struk Otomatis (Auto-Print)', 'Auto-Print Thermal Receipt'),
                subtitle: context.t('Kirim perintah cetak struk termal segera setelah transaksi lunas', 'Send print command to thermal printer upon payment completion'),
                value: _autoPrint,
                onChanged: (val) {
                  setState(() => _autoPrint = val);
                  widget.db.updateAppSettings(autoPrintReceipt: val);
                },
              ),
              Divider(height: 20, color: context.borderSubtle),
              Text(
                context.t('Tipe Tampilan Peta Driver', 'Driver Map View Style'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMapOption(
                    label: 'OpenStreetMap',
                    desc: context.t('Standar jalan & bangunan', 'Standard roads & buildings'),
                    value: 'osm',
                    isSelected: _mapStyle == 'osm',
                  ),
                  const SizedBox(width: 8),
                  _buildMapOption(
                    label: 'Carto Positron',
                    desc: context.t('Minimalis & hemat data', 'Clean & data saving'),
                    value: 'carto_light',
                    isSelected: _mapStyle == 'carto_light',
                  ),
                ],
              ),
              Divider(height: 20, color: context.borderSubtle),
              InkWell(
                onTap: () {
                  final ctrl = TextEditingController(text: ExportReportService.customerFeedbackGFormUrl);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: [
                          const Icon(Icons.feedback_outlined, color: Color(0xFFEA580C)),
                          const SizedBox(width: 8),
                          const Text('URL Google Form Ulasan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Masukkan tautan Google Form (dari https://docs.google.com/forms/) untuk ulasan pelanggan yang akan dijadikan QR code pada struk transaksi.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: ctrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'https://docs.google.com/forms/d/e/.../viewform',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.all(10),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                          onPressed: () {
                            if (ctrl.text.trim().isNotEmpty) {
                              setState(() {
                                ExportReportService.customerFeedbackGFormUrl = ctrl.text.trim();
                              });
                            }
                            Navigator.pop(dCtx);
                            _showSnackbar('Tautan Google Form ulasan berhasil diperbarui');
                          },
                          child: const Text('Simpan URL'),
                        ),
                      ],
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFFEA580C)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('URL Google Form Ulasan Struk', 'Receipt Feedback Google Form URL'),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                            ),
                            Text(
                              ExportReportService.customerFeedbackGFormUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_outlined, size: 18, color: context.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 6. PENYIMPANAN & PEMELIHARAAN ──
          _buildSettingsCard(
            icon: Icons.cleaning_services_outlined,
            title: context.t('Penyimpanan & Data Cache', 'Storage & Cache Data'),
            subtitle: context.t('Kelola file sementara dan reset aplikasi', 'Manage temporary files and reset app'),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.fillSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.t('Data Cache Sementara', 'Temporary Cache Data'), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    Text(_cacheSize, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textPrimary,
                  side: BorderSide(color: context.borderSubtle),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(context.t('Bersihkan Cache Gambar & Data Sementara', 'Clear Images & Temporary Cache'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();
                  setState(() => _cacheSize = '0.0 MB');
                  _showSnackbar(context.t('Cache gambar & data sementara berhasil dibersihkan (0.0 MB)', 'Temporary cache successfully cleared (0.0 MB)'));
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
                label: Text(context.t('Kembalikan Semua Pengaturan ke Default', 'Reset All Settings to Factory Default'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text(context.t('Reset Pengaturan?', 'Reset Settings?'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      content: Text(
                        context.t(
                          'Semua tema, bahasa, suara, dan preferensi aplikasi akan dikembalikan ke pengaturan awal pabrik.',
                          'All theme, language, sound, and app preferences will be reset to factory defaults.',
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('Batal', 'Cancel'))),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            PaintingBinding.instance.imageCache.clear();
                            PaintingBinding.instance.imageCache.clearLiveImages();
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
                              _biometric = false;
                              _cacheSize = '0.0 MB';
                            });
                          },
                          child: Text(context.t('Reset', 'Reset')),
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
            title: context.t('Tentang Aplikasi & Bantuan', 'About App & Customer Support'),
            subtitle: context.t('Informasi versi dan kontak layanan pelanggan', 'Version information and customer care contacts'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C), size: 20),
                ),
                title: Text('Rasantara Resto & Cafe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
                subtitle: Text('Versi 2.4.0 (Official Production)', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15803D).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(context.t('Terbaru', 'Latest'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ),
              ),
              Divider(height: 16, color: context.borderSubtle),
              InkWell(
                onTap: _showHelpSupportDialog,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.headset_mic_outlined, size: 20, color: Color(0xFF15803D)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('Pusat Bantuan & Layanan CS', 'Help Center & CS Support'),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                            ),
                            Text(
                              context.t('No Telepon: +62 8978655469 • Email: endymahavira@gmail.com', 'Phone: +62 8978655469 • Email: endymahavira@gmail.com'),
                              style: TextStyle(fontSize: 11, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: context.textSecondary),
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
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderSubtle),
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
                  color: context.isDarkMode
                      ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFFEA580C)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFF7ED))
                : context.fillSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEA580C) : context.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? const Color(0xFFEA580C) : context.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFFEA580C) : context.textSecondary,
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
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFF7ED))
                : context.fillSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEA580C) : context.borderSubtle,
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
                    color: isSelected ? const Color(0xFFEA580C) : context.textSecondary,
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? (context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFF7ED))
                : context.fillSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEA580C) : context.borderSubtle,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFFEA580C) : context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  desc,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isSelected ? const Color(0xFFEA580C) : context.textSecondary,
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

  // Dialog Kebijakan Privasi
  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFFEA580C), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kebijakan Privasi & PDP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary)),
                  Text('UU No. 27/2022 Pelindungan Data Pribadi', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.fillSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderSubtle),
                  ),
                  child: Text(
                    'PT Rasantara Kuliner Indonesia ("Rasantara") berkomitmen penuh melindungi privasi, integritas data, dan kenyamanan seluruh pengguna aplikasi Rasantara Resto & Cafe sesuai ketentuan UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.',
                    style: TextStyle(fontSize: 11.5, color: context.textPrimary, height: 1.45),
                  ),
                ),
                const SizedBox(height: 14),
                _buildPolicySection(
                  number: '1',
                  title: 'Informasi & Data yang Dikumpulkan',
                  body: 'Kami mengumpulkan data profil pengguna (nama lengkap, username, foto profil), data kontak resmi (nomor WhatsApp untuk pengiriman OTP), data alamat pengantaran makanan dan koordinat peta OpenStreetMap, serta riwayat pemesanan menu kuliner Anda.',
                ),
                _buildPolicySection(
                  number: '2',
                  title: 'Tujuan Pemrosesan & Penggunaan Data',
                  body: 'Data digunakan secara sah untuk verifikasi identitas masuk akun (2FA WhatsApp OTP), memproses pesanan makanan di dapur restoran, navigasi pengantaran pesanan oleh kurir/driver, perhitungan promo dan kupon diskon, serta integrasi resmi payment gateway Midtrans Snap BI.',
                ),
                _buildPolicySection(
                  number: '3',
                  title: 'Keamanan, Enkripsi & Penyimpanan',
                  body: 'Semua lalu lintas komunikasi dilindungi enkripsi protokol TLS 1.3. Data akun dan alamat tersimpan terenkripsi pada infrastruktur cloud Supabase Enterprise PostgreSQL. Kami tidak pernah merekam ataupun menyimpan PIN transaksi atau data kartu perbankan Anda di server lokal.',
                ),
                _buildPolicySection(
                  number: '4',
                  title: 'Pembagian Data kepada Pihak Ketiga',
                  body: 'Informasi hanya diteruskan ke mitra pengemudi (nama depan dan alamat antar) saat pesanan aktif, serta lembaga gerbang pembayaran berizin Bank Indonesia untuk kliring transaksi pembayaran. Rasantara menjamin data Anda tidak pernah dijual atau disewakan kepada pihak manapun.',
                ),
                _buildPolicySection(
                  number: '5',
                  title: 'Hak Pemilik Data & Layanan Pengaduan',
                  body: 'Sesuai UU PDP, Anda berhak melihat, memperbarui profil, mengubah izin notifikasi, dan mengajukan penghapusan akun beserta riwayat pesanan dengan menghubungi Petugas Perlindungan Data (DPO) resmi kami:\n• Email: endymahavira@gmail.com\n• WhatsApp Resmi: +62 8978655469',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Saya Mengerti & Setuju'),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection({required String number, required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
                      : const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(body, style: TextStyle(fontSize: 11.5, color: context.textSecondary, height: 1.45)),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Butuh bantuan seputar pesanan atau pembayaran Anda?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.fillSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF15803D).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.phone_rounded, color: Color(0xFF15803D), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No Telepon / WhatsApp', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                          Text('+62 8978655469', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                  Divider(height: 16, color: context.borderSubtle),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.email_outlined, color: Color(0xFF2563EB), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email Resmi CS', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                          Text('endymahavira@gmail.com', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            onPressed: () {
              Navigator.pop(ctx);
              _showSnackbar('Menghubungi Customer Service WhatsApp (+62 8978655469)...');
            },
            label: const Text('Chat WhatsApp CS'),
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
        Icon(icon, size: 20, color: context.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: context.textSecondary)),
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
