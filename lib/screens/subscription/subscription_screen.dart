import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

/// Layar Menu Berlangganan Restoran
/// - Waiter: Khusus sistem input data pelanggan baru (Nama, Email, No Telepon)
/// - Admin & Owner: Sistem input data & melihat daftar seluruh pelanggan berlangganan VIP
class SubscriptionScreen extends StatefulWidget {
  final DatabaseService db;

  const SubscriptionScreen({
    super.key,
    required this.db,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  // Controllers Form Input Pelanggan
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _generateUsername(String email, String name) {
    String base = '';
    if (email.contains('@')) {
      base = email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
    }
    if (base.isEmpty) {
      base = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
    }
    if (base.isEmpty) base = 'pelanggan';

    String candidate = base;
    int counter = 1;
    while (widget.db.users.any((u) => u.username.toLowerCase() == candidate.toLowerCase())) {
      candidate = '${base}_$counter';
      counter++;
    }
    return candidate;
  }

  Future<void> _submitSubscription() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    // Cek apakah nomor telepon atau email sudah terdaftar
    final existingUser = widget.db.users.cast<UserModel?>().firstWhere(
      (u) =>
          u != null &&
          ((u.phoneNumber.isNotEmpty && u.phoneNumber == phone) ||
              (u.googleEmail != null && u.googleEmail!.toLowerCase() == email.toLowerCase())),
      orElse: () => null,
    );

    if (existingUser != null) {
      if (!existingUser.isSubscribed) {
        // Upgrade user ke berlangganan
        widget.db.updateUser(
          existingUser.idUser,
          existingUser.namaUser,
          password.isNotEmpty ? password : existingUser.password,
          existingUser.role,
          email: email.isNotEmpty ? email : existingUser.googleEmail,
          phoneNumber: phone.isNotEmpty ? phone : existingUser.phoneNumber,
          isSubscribed: true,
        );
        _showSuccessDialog(
          customerName: name,
          username: existingUser.username,
          password: password.isNotEmpty ? password : existingUser.password,
          email: email.isNotEmpty ? email : (existingUser.googleEmail ?? existingUser.displayEmail),
          phone: phone.isNotEmpty ? phone : existingUser.phoneNumber,
          message: 'Akun pelanggan yang sudah ada berhasil di-upgrade menjadi Member Berlangganan VIP!',
        );
        _resetForm();
        return;
      } else {
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final username = _generateUsername(email, name);

    final registeredUser = await widget.db.addUser(
      username,
      password,
      name,
      UserRole.pelanggan,
      email: email,
      phoneNumber: phone,
      isSubscribed: true,
    );

    setState(() => _isSubmitting = false);
    _showSuccessDialog(
      customerName: name,
      username: registeredUser.username,
      password: password,
      email: email,
      phone: phone,
      message: 'Pelanggan berhasil didaftarkan sebagai Member Berlangganan VIP dengan Diskon ${widget.db.memberDiscountPercent}%!',
    );
    _resetForm();
  }

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    setState(() {});
  }

  void _showSuccessDialog({
    String? customerName,
    String? username,
    String? password,
    String? email,
    String phone = '',
    String? message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.surfaceCard,
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Akun langganan telah di tambahkan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orangePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceBg,
      appBar: AppBar(
        backgroundColor: context.surfaceCard,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.card_membership_rounded, color: Color(0xFFEA580C), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Berlangganan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                Text(
                  'Kelola & Pendaftaran Pelanggan Langganan VIP',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEA580C),
          labelColor: const Color(0xFFEA580C),
          unselectedLabelColor: context.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Daftar Member'),
            Tab(icon: Icon(Icons.person_add_alt_1_outlined, size: 18), text: 'Input Pelanggan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubscriberListView(),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _buildInputForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── WIDGET FORM INPUT PELANGGAN BERLANGGANAN ──
  Widget _buildInputForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Input Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Input Data Pelanggan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Isi informasi pelanggan yang ingin didaftarkan berlangganan.',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
                const SizedBox(height: 18),

                // Field 1: Nama Pelanggan
                _buildFieldLabel('Nama Lengkap Pelanggan *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Masukan Nama Lengkap',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama pelanggan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Field 2: Email
                _buildFieldLabel('Alamat Email *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Masukan Email',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Alamat email wajib diisi';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Masukkan format email yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Field 3: No Telepon
                _buildFieldLabel('Nomor Telepon / WhatsApp *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Masukan Nomor Telepon',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nomor telepon wajib diisi';
                    }
                    final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 8) {
                      return 'Nomor telepon minimal 10 digit angka';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Field 4: Password Akun Pelanggan (Untuk Login Mandiri)
                _buildFieldLabel('Password Akun Pelanggan *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Masukan Password (min. 6 karakter)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: context.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Password akun pelanggan wajib diisi';
                    }
                    if (val.trim().length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Password ini akan digunakan pelanggan untuk login ke aplikasi dan memesan makanan secara mandiri.',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
                const SizedBox(height: 24),

                // Tombol Submit
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitSubscription,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Mendaftarkan...' : 'Daftarkan Pelanggan Berlangganan',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.bold,
        color: context.textPrimary,
      ),
    );
  }

  // ── DIALOG KONFIRMASI HAPUS LANGGANAN (ADMIN, WAITER, KASIR, OWNER) ──
  void _confirmUnsubscribe(UserModel member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_remove_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hapus Langganan VIP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menghapus status langganan VIP untuk ${member.namaUser} (@${member.username})?',
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pelanggan tidak akan lagi mendapatkan potongan diskon member ${widget.db.memberDiscountPercent}% di setiap pemesanan.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFC2410C)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.db.unsubscribeUser(member.idUser);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Status langganan ${member.namaUser} berhasil dihapus.'),
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Hapus Langganan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── DIALOG PENGATURAN DISKON MEMBER (OWNER & ADMIN) ──
  void _showEditDiscountDialog() {
    int selectedPercent = widget.db.memberDiscountPercent;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.percent_rounded, color: Color(0xFFEA580C), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ubah Diskon Member VIP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Geser bar untuk mengatur persentase potongan harga pelanggan langganan:',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 18),
                // Display Persentase Terpilih
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A1C14) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$selectedPercent%',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEA580C),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedPercent == 0
                            ? 'Tidak ada diskon (0%)'
                            : 'Potongan $selectedPercent% setiap transaksi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Bar Geser (Slider)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFEA580C),
                    inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    thumbColor: const Color(0xFFEA580C),
                    overlayColor: const Color(0xFFEA580C).withValues(alpha: 0.16),
                    valueIndicatorColor: const Color(0xFFEA580C),
                    valueIndicatorTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  child: Slider(
                    value: selectedPercent.toDouble().clamp(0.0, 100.0),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '$selectedPercent%',
                    onChanged: (double val) {
                      setModalState(() {
                        selectedPercent = val.round();
                      });
                    },
                  ),
                ),
                // Indikator Skala Min dan Max
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary)),
                      Text('50%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary)),
                      Text('100%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await widget.db.setMemberDiscountPercent(selectedPercent);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Besaran diskon member VIP berhasil diubah menjadi $selectedPercent%!'),
                      backgroundColor: const Color(0xFF1E293B),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── WIDGET DAFTAR PELANGGAN BERLANGGANAN (ADMIN, WAITER, KASIR, OWNER) ──
  Widget _buildSubscriberListView() {
    final role = widget.db.currentUser?.role ?? UserRole.waiter;
    final canEditDiscount = role == UserRole.administrator || role == UserRole.owner;

    return ListenableBuilder(
      listenable: widget.db,
      builder: (context, _) {
        final subscribers = widget.db.users.where((u) => u.isSubscribed || (u.role == UserRole.pelanggan && u.isSubscribed)).toList();

        final filtered = subscribers.where((u) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return u.namaUser.toLowerCase().contains(q) ||
              u.username.toLowerCase().contains(q) ||
              (u.googleEmail != null && u.googleEmail!.toLowerCase().contains(q)) ||
              u.phoneNumber.contains(q);
        }).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.card_membership_rounded, color: Color(0xFF16A34A), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Member VIP',
                                style: TextStyle(fontSize: 11, color: context.textSecondary),
                              ),
                              Text(
                                '${subscribers.length}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: canEditDiscount ? _showEditDiscountDialog : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: canEditDiscount ? const Color(0xFFEA580C).withValues(alpha: 0.4) : context.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.percent_rounded, color: Color(0xFFEA580C), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Potongan Menu',
                                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                                      ),
                                      if (canEditDiscount) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit_rounded, size: 12, color: Color(0xFFEA580C)),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${widget.db.memberDiscountPercent}% OFF',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Cari nama, email, atau no telepon member...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderSubtle),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // List of Subscribers
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.person_search_outlined, size: 48, color: context.textSecondary),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty
                                ? 'Tidak ada member cocok dengan pencarian'
                                : 'Belum ada pelanggan berlangganan',
                          style: TextStyle(fontSize: 13, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = filtered[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFDCFCE7),
                            child: Text(
                              member.namaUser.isNotEmpty ? member.namaUser[0].toUpperCase() : 'M',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        member.namaUser,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: context.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Text(
                                        'VIP ${widget.db.memberDiscountPercent}%',
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Username: ${member.username}  •  Email: ${member.googleEmail ?? member.displayEmail}  •  HP: ${member.phoneNumber.isNotEmpty ? member.phoneNumber : '-'}',
                                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Tombol Hapus Langganan untuk Admin, Waiter, Kasir, Owner
                          IconButton(
                            icon: const Icon(Icons.person_remove_rounded, color: Color(0xFFDC2626), size: 20),
                            tooltip: 'Hapus Langganan VIP',
                            onPressed: () => _confirmUnsubscribe(member),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
