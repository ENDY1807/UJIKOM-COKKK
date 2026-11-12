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
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final role = widget.db.currentUser?.role ?? UserRole.waiter;
    if (role != UserRole.waiter) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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

  void _submitSubscription() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

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
          existingUser.role,
          email: email.isNotEmpty ? email : existingUser.googleEmail,
          phoneNumber: phone.isNotEmpty ? phone : existingUser.phoneNumber,
          isSubscribed: true,
        );
        _showSuccessDialog(name, 'Akun pelanggan yang sudah ada berhasil di-upgrade menjadi Member Berlangganan VIP!');
        _resetForm();
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pelanggan dengan kontak tersebut sudah terdaftar sebagai Member Berlangganan.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final username = _generateUsername(email, name);
    // Default password sederhana dari 6 digit terakhir nomor HP atau 123456
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final password = cleanDigits.length >= 6 ? cleanDigits.substring(cleanDigits.length - 6) : '123456';

    widget.db.addUser(
      username,
      password,
      name,
      UserRole.pelanggan,
      email: email,
      phoneNumber: phone,
      isSubscribed: true,
    );

    setState(() => _isSubmitting = false);
    _showSuccessDialog(name, 'Pelanggan berhasil didaftarkan sebagai Member Berlangganan VIP dengan Diskon 10%!');
    _resetForm();
  }

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    setState(() {});
  }

  void _showSuccessDialog(String customerName, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.surfaceCard,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Pendaftaran Berhasil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFFEA580C), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                        ),
                        const Text(
                          'Benefit: Diskon 10% di setiap pesanan',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orangePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.db.currentUser?.role ?? UserRole.waiter;
    final isWaiter = role == UserRole.waiter;

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
                  isWaiter ? 'Pendaftaran Pelanggan Langganan' : 'Kelola Pelanggan Langganan VIP',
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
              ],
            ),
          ],
        ),
        bottom: !isWaiter && _tabController != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFEA580C),
                labelColor: const Color(0xFFEA580C),
                unselectedLabelColor: context.textSecondary,
                tabs: const [
                  Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Daftar Member'),
                  Tab(icon: Icon(Icons.person_add_alt_1_outlined, size: 18), text: 'Input Pelanggan'),
                ],
              )
            : null,
      ),
      body: isWaiter
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: _buildInputForm(),
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSubscriberListView(),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
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
          // Banner Info VIP
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Member Berlangganan (VIP)',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pelanggan langsung mendapatkan potongan 10% di setiap transaksi pemesanan meja.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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
                    hintText: 'Contoh: Budi Santoso',
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
                    hintText: 'Contoh: budi@gmail.com',
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
                    hintText: 'Contoh: 081234567890',
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
                      return 'Nomor telepon minimal 8 digit angka';
                    }
                    return null;
                  },
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

  // ── WIDGET DAFTAR PELANGGAN BERLANGGANAN (ADMIN & OWNER) ──
  Widget _buildSubscriberListView() {
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
          padding: const EdgeInsets.all(16),
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
                              color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.percent_rounded, color: Color(0xFFEA580C), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Potongan Menu',
                                style: TextStyle(fontSize: 11, color: context.textSecondary),
                              ),
                              Text(
                                '10% OFF',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                              ),
                            ],
                          ),
                        ],
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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                                      child: const Text(
                                        'VIP 10%',
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Email: ${member.googleEmail ?? member.displayEmail}  •  HP: ${member.phoneNumber.isNotEmpty ? member.phoneNumber : '-'}',
                                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
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
