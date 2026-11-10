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
  late bool _soundFx;
  late bool _notifications;
  late bool _autoPrint;
  late bool _haptic;
  late String _mapStyle;
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
    _autoPrint = widget.db.appAutoPrintReceipt;
    _haptic = widget.db.appHaptic;
    _mapStyle = widget.db.appMapStyle;
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
    final code = await WhatsAppOtpService.instance.sendOtp(
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
              child: Row(
                children: [
                  const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF22C55E), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SMS / WhatsApp Masuk: Kode OTP verifikasi adalah $code',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                                color: const Color(0xFF00AA13),
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
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Text(
                              'Role: ${user?.role.label ?? "Pelanggan"}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF1E293B),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.photo_library_outlined, size: 14),
                                label: const Text('Ganti Foto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _pickProfilePhoto,
                              ),
                              if (_selectedAvatar.isNotEmpty || _customImageBytes != null) ...[
                                const SizedBox(width: 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  onPressed: _removeProfilePhoto,
                                  child: const Text('Hapus', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
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
                        activeColor: const Color(0xFFEA580C),
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
                    Icon(Icons.tune_rounded, size: 18, color: Color(0xFFEA580C)),
                    SizedBox(width: 8),
                    Text(
                      'Preferensi Fungsional & Suara',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Suara Tombol
                _buildSwitchTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Efek Suara Audio',
                  subtitle: 'Suara feedback saat menekan tombol dan menambah pesanan',
                  value: _soundFx,
                  onChanged: (val) {
                    setState(() => _soundFx = val);
                    widget.db.updateAppSettings(soundFx: val);
                  },
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // Notifikasi Pesanan
                _buildSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifikasi Pesanan Masuk',
                  subtitle: 'Tampilkan peringatan saat status pesanan diperbarui dapur',
                  value: _notifications,
                  onChanged: (val) {
                    setState(() => _notifications = val);
                    widget.db.updateAppSettings(notifications: val);
                  },
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // Cetak Struk Otomatis
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

                // Getar Haptik
                _buildSwitchTile(
                  icon: Icons.vibration_rounded,
                  title: 'Umpan Balik Haptik (Getaran)',
                  subtitle: 'Getar lembut saat aksi penting atau konfirmasi pesanan',
                  value: _haptic,
                  onChanged: (val) {
                    setState(() => _haptic = val);
                    widget.db.updateAppSettings(haptic: val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pilihan Gaya Peta Driver
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
                    Icon(Icons.map_outlined, size: 18, color: Color(0xFFEA580C)),
                    SizedBox(width: 8),
                    Text(
                      'Tipe Tampilan Peta Pelacakan Driver',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  value: 'osm',
                  groupValue: _mapStyle,
                  activeColor: const Color(0xFFEA580C),
                  title: const Text('OpenStreetMap Standar (Jalan & Bangunan)', style: TextStyle(fontSize: 13)),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _mapStyle = val);
                      widget.db.updateAppSettings(mapStyle: val);
                    }
                  },
                ),
                RadioListTile<String>(
                  value: 'carto_light',
                  groupValue: _mapStyle,
                  activeColor: const Color(0xFFEA580C),
                  title: const Text('Carto Positron (Minimalis & Ringan)', style: TextStyle(fontSize: 13)),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _mapStyle = val);
                      widget.db.updateAppSettings(mapStyle: val);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reset Preferensi & Bersihkan Cache
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
                const Text(
                  'Pemeliharaan & Data Cache',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hapus temporary cache gambar dan reset preferensi aplikasi ke pengaturan default pabrik.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Bersihkan Cache & Reset Pengaturan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Reset Pengaturan?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        content: const Text(
                          'Tindakan ini akan mengembalikan suara, notifikasi, dan preferensi aplikasi ke kondisi awal.',
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
                                _autoPrint = false;
                                _haptic = true;
                                _mapStyle = 'osm';
                              });
                              _showSnackbar('Cache berhasil dibersihkan');
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
          activeColor: const Color(0xFFEA580C),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
