import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'settings_screen.dart';

/// Layar Profil Akun & Hak Akses Pengguna Rasantara
class ProfileScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.db,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String csWhatsAppUrl = 'https://wa.me/qr/LXPSUAAWEP7YJ1';

  Future<void> _launchWhatsAppCS() async {
    final uri = Uri.parse(csWhatsAppUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[ProfileScreen] launch WhatsApp error: $e');
    }
  }

  // ── 1. Dialog Ubah Kata Sandi ──
  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset_rounded, color: Color(0xFFEA580C)),
            const SizedBox(width: 8),
            Text(context.t('Ubah Kata Sandi', 'Change Password'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.t('Kata Sandi Saat Ini', 'Current Password'),
                hintText: context.t('Masukkan kata sandi saat ini', 'Enter current password'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.t('Kata Sandi Baru', 'New Password'),
                hintText: context.t('Masukkan kata sandi baru', 'Enter new password'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.t('Konfirmasi Kata Sandi Baru', 'Confirm New Password'),
                hintText: context.t('Ulangi kata sandi baru', 'Re-enter new password'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.t('Batal', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () {
              final newP = newPassController.text;
              final confP = confirmPassController.text;
              if (newP.length < 3 || newP != confP) {
                return;
              }

              final u = widget.db.currentUser;
              if (u != null) {
                widget.db.updateUser(u.idUser, u.namaUser, newP, u.role);
                Navigator.of(ctx).pop();
                setState(() {});
              }
            },
            child: Text(context.t('Simpan', 'Save')),
          ),
        ],
      ),
    );
  }

  // ── 2. Dialog Kebijakan Privasi & PDP ──
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
          height: 380,
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
                      'PT Rasantara Kuliner Indonesia berkomitmen melindungi privasi, data kredensial, dan kenyamanan pengguna sesuai ketentuan UU Pelindungan Data Pribadi.',
                      'PT Rasantara Kuliner Indonesia is committed to safeguarding user privacy, credentials, and security under Data Protection laws.',
                    ),
                    style: TextStyle(fontSize: 11.5, color: context.textPrimary, height: 1.45),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPolicyItem('1', context.t('Data yang Dikumpulkan', 'Data Collected'),
                    context.t('Nama lengkap, username, alamat email autentikasi, serta riwayat pemesanan meja restoran.', 'Full name, username, authentication email, and dining order history.')),
                _buildPolicyItem('2', context.t('Tujuan Penggunaan', 'Purpose of Use'),
                    context.t('Data digunakan untuk verifikasi login, antrean pesanan dapur, dan pencetakan struk pembayaran.', 'Used for authentication, kitchen ticket preparation, and receipt generation.')),
                _buildPolicyItem('3', context.t('Keamanan Data', 'Data Security'),
                    context.t('Semua komunikasi dilindungi enkripsi SSL/TLS dan database cloud Supabase berstandar enterprise.', 'Communications are encrypted via SSL/TLS and stored securely on cloud database.')),
                _buildPolicyItem('4', context.t('Layanan Kontak CS', 'Customer Care Support'),
                    context.t('Hubungi Layanan CS resmi WhatsApp:\nhttps://wa.me/qr/LXPSUAAWEP7YJ1', 'Official WhatsApp customer care:\nhttps://wa.me/qr/LXPSUAAWEP7YJ1')),
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

  Widget _buildPolicyItem(String num, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.3) : const Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: Text(num, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(fontSize: 11, color: context.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Dialog Konfirmasi Logout ──
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 8),
            Text(context.t('Konfirmasi Keluar', 'Confirm Logout'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          context.t(
            'Apakah Anda yakin ingin keluar dari sesi akun Rasantara Restoran?',
            'Are you sure you want to sign out from Rasantara Restaurant?',
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('Batal', 'Cancel'), style: const TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.db.logout();
              widget.onLogout();
            },
            child: Text(context.t('Ya, Keluar', 'Yes, Sign Out')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.db.currentUser;
    final role = user?.role ?? UserRole.pelanggan;

    final photoUrl = user?.displayPhoto ?? '';
    final initial = (user != null && user.namaUser.isNotEmpty)
        ? user.namaUser[0].toUpperCase()
        : 'R';

    final usernameText = user != null && user.username.isNotEmpty
        ? '@${user.username}'
        : '@pengguna';

    final emailText = (user != null && user.displayEmail.isNotEmpty)
        ? user.displayEmail
        : 'user@rasantara.com';

    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Profile Header Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderSubtle),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFFFF7ED),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEA580C),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.namaUser ?? context.t('Pengguna Rasantara', 'Rasantara User'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            usernameText,
                            style: TextStyle(fontSize: 13, color: context.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 13, color: context.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  emailText,
                                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role.label,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted),
                      tooltip: context.t('Pengaturan Aplikasi', 'App Settings'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              db: widget.db,
                              onProfileUpdated: () => setState(() {}),
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 2. Informasi Akun & Keamanan ──
              _buildSectionHeader(context.t('Keamanan Akun', 'Account Security')),
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderSubtle),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _showChangePasswordDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF7ED),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_reset_rounded, size: 20, color: Color(0xFFEA580C)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.t('Ubah Kata Sandi', 'Change Password'),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.t('Perbarui kata sandi akun untuk keamanan', 'Update account password for security'),
                                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 3. Layanan Pelanggan & Bantuan ──
              _buildSectionHeader(context.t('Bantuan & Layanan', 'Support & Help')),
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderSubtle),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: _launchWhatsAppCS,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.t('Kontak CS WhatsApp', 'WhatsApp Customer Service'),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'https://wa.me/qr/LXPSUAAWEP7YJ1',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF16A34A)),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 64),
                    InkWell(
                      onTap: _showPrivacyPolicyDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFFEA580C), size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.t('Kebijakan Privasi & PDP', 'Privacy Policy & PDP'),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.t('Perlindungan data pribadi UU No. 27/2022', 'Data protection regulations'),
                                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 4. Preferensi Sistem Aplikasi ──
              _buildSectionHeader(context.t('Preferensi & Tampilan Aplikasi', 'Preferences & App Theme')),
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderSubtle),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.palette_outlined, color: Color(0xFF2563EB), size: 20),
                      ),
                      title: Text(context.t('Mode Tampilan', 'Theme Mode'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      subtitle: Text(
                        widget.db.appThemeMode == 'system'
                            ? context.t('Mode Sistem (Otomatis)', 'System Mode (Auto)')
                            : (widget.db.appThemeMode == 'dark'
                                ? context.t('Mode Gelap (Dark)', 'Dark Mode')
                                : context.t('Mode Terang (Light)', 'Light Mode')),
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                      trailing: PopupMenuButton<String>(
                        initialValue: widget.db.appThemeMode,
                        tooltip: context.t('Pilih Mode Tema', 'Select Theme Mode'),
                        onSelected: (mode) {
                          widget.db.updateAppSettings(themeMode: mode);
                          setState(() {});
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'system',
                            child: Row(
                              children: [
                                const Icon(Icons.brightness_auto_outlined, size: 18, color: Color(0xFFEA580C)),
                                const SizedBox(width: 8),
                                Text(context.t('Sistem (Otomatis)', 'System (Auto)')),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'light',
                            child: Row(
                              children: [
                                const Icon(Icons.light_mode_outlined, size: 18, color: Color(0xFFEA580C)),
                                const SizedBox(width: 8),
                                Text(context.t('Terang (Light)', 'Light')),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'dark',
                            child: Row(
                              children: [
                                const Icon(Icons.dark_mode_outlined, size: 18, color: Color(0xFFEA580C)),
                                const SizedBox(width: 8),
                                Text(context.t('Gelap (Dark)', 'Dark')),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.fillSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.db.appThemeMode == 'system'
                                    ? context.t('Sistem', 'System')
                                    : (widget.db.appThemeMode == 'dark' ? 'Dark' : 'Light'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFFEA580C)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 64),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.translate_rounded, color: Color(0xFF16A34A), size: 20),
                      ),
                      title: Text(context.t('Bahasa Sistem', 'System Language'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      subtitle: Text(
                        widget.db.appLanguage == 'en' ? 'English (EN)' : 'Bahasa Indonesia (ID)',
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          final newLang = widget.db.appLanguage == 'id' ? 'en' : 'id';
                          widget.db.updateAppSettings(language: newLang);
                          setState(() {});
                        },
                        child: Text(
                          widget.db.appLanguage == 'id' ? 'Ganti ke EN' : 'Ganti ke ID',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 5. Tombol Keluar dari Akun ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(
                    context.t('Keluar dari Akun', 'Sign Out from Account'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _confirmLogout,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: context.textPrimary,
        ),
      ),
    );
  }
}
