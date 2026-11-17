import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../widgets/app_loading_animation.dart';
import '../../theme/app_theme.dart';
import '../../services/audio_notification_service.dart';

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
  late TextEditingController _emailCtrl;
  String _selectedAvatar = '';
  bool _isSavingProfile = false;

  // Settings Aplikasi
  bool _notifications = true;
  String _themeMode = 'system';
  String _language = 'id';
  Uint8List? _customImageBytes;

  static const String csWhatsAppUrl = 'https://wa.me/qr/LXPSUAAWEP7YJ1';

  Future<void> _launchWhatsAppCS() async {
    final uri = Uri.parse(csWhatsAppUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[SettingsScreen] launch WhatsApp error: $e');
    }
  }

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
      }
    } catch (e) {
      debugPrint('Gagal memilih foto: $e');
    }
  }

  void _removeProfilePhoto() {
    setState(() {
      _customImageBytes = null;
      _selectedAvatar = '';
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final u = widget.db.currentUser;
    _nameCtrl = TextEditingController(text: u?.namaUser ?? '');
    _usernameCtrl = TextEditingController(text: u?.username ?? '');
    _emailCtrl = TextEditingController(text: u?.googleEmail ?? u?.displayEmail ?? '');
    _selectedAvatar = u?.displayPhoto ?? '';

    _notifications = widget.db.appNotifications;
    _themeMode = (widget.db.appThemeMode == 'dark' || widget.db.appThemeMode == 'light')
        ? widget.db.appThemeMode
        : 'system';
    _language = (widget.db.appLanguage == 'en') ? 'en' : 'id';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    final user = widget.db.currentUser;
    if (user == null) return;

    if (_nameCtrl.text.trim().isEmpty) {
      return;
    }

    if (_usernameCtrl.text.trim().isEmpty) {
      return;
    }

    AppLoadingAnimation.show(context, message: context.t('Menyimpan perubahan profil...', 'Saving profile changes...'));
    setState(() => _isSavingProfile = true);

    final cleanUsername = _usernameCtrl.text.trim().replaceAll('@', '').toLowerCase();
    final cleanEmail = _emailCtrl.text.trim();

    final success = await widget.db.updateUserProfile(
      idUser: user.idUser,
      namaUser: _nameCtrl.text.trim(),
      username: cleanUsername,
      email: cleanEmail.isNotEmpty ? cleanEmail : null,
      fotoProfil: _selectedAvatar.isNotEmpty ? _selectedAvatar : null,
      isConfigured: true,
    );

    if (mounted) {
      AppLoadingAnimation.hide(context);
    }
    setState(() => _isSavingProfile = false);

    if (success) {
      widget.onProfileUpdated?.call();
    }
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
                context.t('Profil Pengguna & Preferensi', 'User Profile & Preferences'),
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
            Tab(
              icon: const Icon(Icons.person_outline_rounded, size: 20),
              text: context.t('Profil Pengguna', 'User Profile'),
            ),
            Tab(
              icon: const Icon(Icons.tune_rounded, size: 20),
              text: context.t('Sistem Aplikasi', 'System Settings'),
            ),
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
          // Card Foto Profil
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
                      context.t('Foto Profil Pengguna', 'User Profile Photo'),
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
                            user?.namaUser ?? context.t('Pengguna', 'User'),
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
                              user?.displayEmail ?? 'user@rasantara.com',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                                label: Text(context.t('Ganti Foto', 'Change Photo'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                                  child: Text(context.t('Hapus', 'Remove'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                      context.t('Informasi Profil & Kredensial', 'Profile Info & Credentials'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Nama User
                Text(
                  context.t('Nama Lengkap Tampilan', 'Display Name'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: context.t('Nama lengkap Anda', 'Your full name'),
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // Username
                Text(
                  context.t('Username / ID Pengguna', 'Username / User ID'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
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

                // Email
                Text(
                  context.t('Email Pengguna', 'User Email'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'nama@domain.com',
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              _isSavingProfile ? context.t('Menyimpan...', 'Saving...') : context.t('Simpan Perubahan Profil', 'Save Profile Changes'),
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
            subtitle: context.t('Mode tampilan sistem cerah atau gelap', 'System display mode light or dark'),
            children: [
              Text(
                context.t('Mode Tampilan Tema', 'Theme Mode'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildThemeOption(
                    label: context.t('Sistem (Otomatis)', 'System (Auto)'),
                    icon: Icons.brightness_auto_outlined,
                    value: 'system',
                    isSelected: _themeMode == 'system',
                  ),
                  const SizedBox(width: 8),
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

          // ── 3. NOTIFIKASI (Hanya 1 Switch Sederhana) ──
          _buildSettingsCard(
            icon: Icons.notifications_active_outlined,
            title: context.t('Notifikasi', 'Notifications'),
            subtitle: context.t('Pengingat status pesanan dan konfirmasi restoran', 'Order alerts and restaurant status updates'),
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: context.t('Aktifkan Notifikasi', 'Enable Notifications'),
                subtitle: context.t('Notifikasi status pesanan, meja, dan transaksi lunas', 'Alerts for orders, table status, and completed payments'),
                value: _notifications,
                onChanged: (val) async {
                  setState(() => _notifications = val);
                  widget.db.updateAppSettings(notifications: val);
                  if (val) {
                    await AudioNotificationService.requestSystemNotificationPermission();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 4. KEBIJAKAN PRIVASI & PERLINDUNGAN DATA ──
          _buildSettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: context.t('Kebijakan Privasi & PDP', 'Privacy Policy & Data Protection'),
            subtitle: context.t('Perlindungan data pribadi sesuai ketentuan resmi UU No. 27/2022', 'Personal data protection under official regulations'),
            children: [
              InkWell(
                onTap: _showPrivacyPolicyDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.fillSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shield_outlined, size: 20, color: Color(0xFFEA580C)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('Kebijakan Privasi & Perlindungan Data', 'Privacy Policy & Data Protection'),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t('Pelajari bagaimana data akun dan keamanan pesanan Anda dilindungi', 'Learn how your account data and order security are safeguarded'),
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

          // ── 5. TENTANG APLIKASI & KONTAK CS ──
          _buildSettingsCard(
            icon: Icons.info_outline_rounded,
            title: context.t('Tentang Aplikasi & Bantuan', 'About App & Customer Support'),
            subtitle: context.t('Informasi versi dan kontak langsung layanan pelanggan', 'Version info and direct customer support contact'),
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
                onTap: _launchWhatsAppCS,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.t('Hubungi Kontak CS via WhatsApp', 'Contact Support via WhatsApp'),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF16A34A)),
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

  // Dialog Kebijakan Privasi & PDP (Form Bersih & Elegan)
  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  Text(
                    context.t('Kebijakan Privasi & PDP', 'Privacy Policy & PDP'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  Text(
                    context.t('Pelindungan Data Pribadi (UU No. 27/2022)', 'Personal Data Protection (Act No. 27/2022)'),
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
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
                    context.t(
                      'PT Rasantara Kuliner Indonesia ("Rasantara") berkomitmen penuh melindungi privasi, integritas data, dan kenyamanan seluruh pengguna aplikasi Rasantara Resto & Cafe sesuai ketentuan UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.',
                      'PT Rasantara Kuliner Indonesia ("Rasantara") is fully committed to safeguarding user privacy and data security in compliance with Personal Data Protection regulations.',
                    ),
                    style: TextStyle(fontSize: 11.5, color: context.textPrimary, height: 1.45),
                  ),
                ),
                const SizedBox(height: 14),
                _buildPolicySection(
                  number: '1',
                  title: context.t('Informasi & Data yang Dikumpulkan', 'Information Collected'),
                  body: context.t(
                    'Kami mengumpulkan nama lengkap, username, alamat email untuk autentikasi masuk, serta riwayat transaksi pemesanan menu kuliner Anda di meja restoran.',
                    'We collect your full name, username, email address for authentication, and your restaurant dining order history.',
                  ),
                ),
                _buildPolicySection(
                  number: '2',
                  title: context.t('Tujuan Penggunaan Data', 'Purpose of Data Use'),
                  body: context.t(
                    'Data digunakan secara sah untuk verifikasi identitas akun, memproses antrean pesanan di dapur restoran, serta pencatatan struk pembayaran.',
                    'Data is strictly used to authenticate your user account, prepare kitchen order tickets, and issue dining receipts.',
                  ),
                ),
                _buildPolicySection(
                  number: '3',
                  title: context.t('Keamanan & Enkripsi', 'Security & Encryption'),
                  body: context.t(
                    'Lalu lintas data dilindungi enkripsi SSL/TLS modern. Data kredensial tersimpan dengan aman pada database cloud Supabase PostgreSQL berstandar industri.',
                    'All data traffic is protected with SSL/TLS protocols and stored securely on cloud enterprise databases.',
                  ),
                ),
                _buildPolicySection(
                  number: '4',
                  title: context.t('Layanan Bantuan & Kontak CS', 'Customer Care & Contact'),
                  body: context.t(
                    'Jika memiliki pertanyaan mengenai privasi akun, hubungi Layanan Pelanggan resmi Rasantara via WhatsApp.',
                    'For inquiries regarding your data privacy, reach out to our Customer Service via WhatsApp.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('Saya Mengerti', 'I Understand')),
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
