import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'settings_screen.dart';

/// Layar Profil Akun & Hak Akses Pengguna Rasantara (Table Service Restoran - UKK Paket 1)
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
  // ── 1. Dialog Ubah Kata Sandi ──
  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Ubah Kata Sandi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kata Sandi Saat Ini',
                hintText: 'Masukkan kata sandi saat ini',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kata Sandi Baru',
                hintText: 'Masukkan kata sandi baru',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Kata Sandi Baru',
                hintText: 'Ulangi kata sandi baru',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () {
              final newP = newPassController.text;
              final confP = confirmPassController.text;
              if (newP.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kata sandi minimal 4 karakter')),
                );
                return;
              }
              if (newP != confP) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Konfirmasi kata sandi tidak cocok')),
                );
                return;
              }

              final u = widget.db.currentUser;
              if (u != null) {
                widget.db.updateUser(u.idUser, u.namaUser, newP, u.role);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF16A34A),
                    content: Text('Kata sandi berhasil diperbarui!'),
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── 2. Dialog Autentikasi 2 Langkah (2FA) ──
  void _openTwoFactorSetupDialog() {
    final user = widget.db.currentUser;
    if (user == null) return;

    final otpController = TextEditingController();
    const mockSecretKey = 'KASIRNIH-2026-SEC89';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Aktivasi 2-Factor Auth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tingkatkan keamanan akun restoran Anda dengan verifikasi 2 langkah untuk setiap sesi login.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 130,
                  height: 130,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 76, color: Color(0xFF1E293B)),
                      Text(
                        mockSecretKey,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Masukkan 6-Digit Kode Verifikasi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 6),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () {
              final code = otpController.text.trim();
              if (code.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Masukkan 6 digit kode OTP verifikasi')),
                );
                return;
              }

              widget.db.updateTwoFactor(user.idUser, isEnabled: true, type: 'Google Authenticator');
              Navigator.of(ctx).pop();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF16A34A),
                  content: Text('Autentikasi 2 Langkah (2FA) Berhasil Diaktifkan!'),
                ),
              );
            },
            child: const Text('Verifikasi & Aktifkan'),
          ),
        ],
      ),
    );
  }

  void _showDisableTwoFactorDialog() {
    final user = widget.db.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan 2FA?'),
        content: const Text('Proteksi verifikasi dua langkah akan dimatikan untuk akun ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              widget.db.updateTwoFactor(user.idUser, isEnabled: false);
              Navigator.of(ctx).pop();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Autentikasi 2 Langkah dinonaktifkan.')),
              );
            },
            child: const Text('Nonaktifkan'),
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
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Konfirmasi Keluar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi akun Rasantara Restoran?',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
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
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.db.currentUser;
    final role = user?.role ?? UserRole.pelanggan;
    final is2Fa = user?.isTwoFactorEnabled == true;

    // Foto profil aman tanpa error
    final photoUrl = user?.displayPhoto ?? '';
    final initial = (user != null && user.namaUser.isNotEmpty)
        ? user.namaUser[0].toUpperCase()
        : 'K';

    final usernameText = user != null && user.username.isNotEmpty
        ? '@${user.username}'
        : '@pengguna';

    final phoneText = (user != null && user.phoneNumber.isNotEmpty)
        ? user.phoneNumber
        : 'Belum diatur';

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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.namaUser ?? 'Pengguna Rasantara',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            usernameText,
                            style: TextStyle(fontSize: 13, color: context.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          if (role == UserRole.pelanggan) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined, size: 13, color: context.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  phoneText,
                                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted),
                      tooltip: 'Pengaturan Aplikasi',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              db: widget.db,
                              onProfileUpdated: () => setState(() {}),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── 2. Keamanan Akun & Kredensial (Khusus Pelanggan Langganan) ──
              if (role == UserRole.pelanggan) ...[
                _buildSectionHeader('Keamanan Akun & 2-Factor Auth (2FA)'),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: is2Fa ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.verified_user_rounded,
                                size: 20,
                                color: is2Fa ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Autentikasi Dua Langkah (2FA)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    is2Fa
                                        ? 'Aktif via Authenticator App'
                                        : 'Tambahkan proteksi kode verifikasi untuk keamanan login.',
                                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: is2Fa,
                              activeThumbColor: const Color(0xFFEA580C),
                              onChanged: (val) {
                                if (val) {
                                  _openTwoFactorSetupDialog();
                                } else {
                                  _showDisableTwoFactorDialog();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, indent: 64),
                      InkWell(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
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
                                      'Ubah Kata Sandi',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Perbarui kata sandi lokal untuk login akun restoran',
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
              ],

              // ── 4. Preferensi Sistem Aplikasi ──
              _buildSectionHeader('Preferensi & Tampilan Aplikasi'),
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
                      title: Text('Mode Tampilan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      subtitle: Text(
                        widget.db.appThemeMode == 'dark' ? 'Mode Gelap (Dark)' : 'Mode Terang (Light)',
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                      trailing: Switch(
                        value: widget.db.appThemeMode == 'dark',
                        activeThumbColor: const Color(0xFF2563EB),
                        onChanged: (val) {
                          widget.db.updateAppSettings(themeMode: val ? 'dark' : 'light');
                          setState(() {});
                        },
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
                      title: Text('Bahasa Sistem', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
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
                  label: const Text(
                    'Keluar dari Akun',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
