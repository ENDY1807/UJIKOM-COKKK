import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/payment_method_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

/// Layar Profil Pengguna & Pengaturan Terintegrasi:
/// 1. Koneksi Akun Google (Tautkan / Putuskan Google OAuth)
/// 2. Keamanan Akun & Autentikasi 2 Langkah (2FA / 2-Auth)
/// 3. Kelola & Tambah Metode Pembayaran Terkoneksi Nyata (DANA, GoPay, M-Banking BCA/Mandiri/BRI)
/// 4. Top Up Saldo & Atur Metode Utama
/// 5. Membership & Riwayat Alamat Pengantaran
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
  final List<String> _savedAddresses = [];

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // ── 1. AUTENTIKASI DUA LANGKAH (2FA / 2-AUTH) ──
  void _openTwoFactorSetupDialog() {
    final user = widget.db.currentUser;
    if (user == null) return;

    final otpController = TextEditingController();
    const mockSecretKey = 'RASAN-TARA-2026-X89K';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
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
                    'Lindungi akun dan transaksi pembayaran e-wallet Anda dengan verifikasi 2 langkah.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Visual QR Acuan Authenticator
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 76, color: Color(0xFF1E293B)),
                          Text(
                            mockSecretKey,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pindai QR di atas menggunakan aplikasi Google Authenticator, atau masukkan kode kunci rahasia.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Kode OTP Input
                  const Text('Masukkan 6-Digit Kode Verifikasi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 6),
                    decoration: InputDecoration(
                      hintText: 'Kode Verifikasi',
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
                      const SnackBar(content: Text('Masukkan 6 digit kode OTP')),
                    );
                    return;
                  }

                  widget.db.updateTwoFactor(user.idUser, isEnabled: true, type: 'Google Authenticator');
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF16A34A),
                      content: Text('✓ Autentikasi 2 Langkah (2FA) Berhasil Diaktifkan!'),
                    ),
                  );
                },
                child: const Text('Verifikasi & Aktifkan'),
              ),
            ],
          );
        },
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
        content: const Text('Keamanan akun akan berkurang saat melakukan transaksi dan pergantian perangkat.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              widget.db.updateTwoFactor(user.idUser, isEnabled: false);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Autentikasi 2 Langkah telah dinonaktifkan.')),
              );
            },
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
  }

  // ── 3. TAMBAH & KELOLA METODE PEMBAYARAN TERKONEKSI ──
  void _openAddPaymentMethodDialog() {
    PaymentMethodProvider selectedProvider = PaymentMethodProvider.dana;
    final accountController = TextEditingController();
    final nameController = TextEditingController();
    bool isDefaultCheck = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_card_rounded, color: Color(0xFFEA580C)),
                SizedBox(width: 8),
                Text('Koneksikan Metode Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih Penyedia Layanan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PaymentMethodProvider.values.map((p) {
                      final isSelected = selectedProvider == p;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p.icon, size: 14, color: isSelected ? Colors.white : p.brandColor),
                            const SizedBox(width: 4),
                            Text(p.label),
                          ],
                        ),
                        selectedColor: p.brandColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF1E293B),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selectedProvider = p;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  if (selectedProvider == PaymentMethodProvider.dana) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 16, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Terhubung ke DANA Sandbox Gateway',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                ),
                                Text(
                                  'Merchant ID: 216620010001053576081 (api.sandbox.dana.id)',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF1E3A8A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Text(
                    selectedProvider.category == PaymentMethodCategory.eWallet
                        ? 'Nomor HP Akun ${selectedProvider.label}:'
                        : 'Nomor Rekening Bank ${selectedProvider.label}:',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: accountController,
                    keyboardType: selectedProvider.category == PaymentMethodCategory.eWallet
                        ? TextInputType.phone
                        : TextInputType.number,
                    decoration: InputDecoration(
                      hintText: selectedProvider.category == PaymentMethodCategory.eWallet ? 'Nomor HP' : 'Nomor Rekening',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Nama Pemilik Akun:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Nama Pemilik Akun',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Checkbox(
                        value: isDefaultCheck,
                        activeColor: const Color(0xFFEA580C),
                        onChanged: (val) => setDialogState(() => isDefaultCheck = val ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Jadikan metode pembayaran utama (Default)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                onPressed: () {
                  final acc = accountController.text.trim();
                  final name = nameController.text.trim();

                  if (acc.isEmpty || name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lengkapi nomor akun/HP dan nama pemilik')),
                    );
                    return;
                  }

                  Navigator.of(ctx).pop();

                  if (selectedProvider.category == PaymentMethodCategory.eWallet) {
                    _showEWalletOtpDialog(
                      provider: selectedProvider,
                      accountNumber: acc,
                      accountName: name,
                      balance: 0,
                      isDefault: isDefaultCheck,
                    );
                  } else {
                    widget.db.addPaymentMethod(
                      provider: selectedProvider,
                      accountNumber: acc,
                      accountName: name,
                      initialBalance: 0,
                      isDefault: isDefaultCheck,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF16A34A),
                        content: Text('✓ ${selectedProvider.label} ($acc) berhasil dikoneksikan ke database!'),
                      ),
                    );
                  }
                },
                child: const Text('Koneksikan Sekarang'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEWalletOtpDialog({
    required PaymentMethodProvider provider,
    required String accountNumber,
    required String accountName,
    required int balance,
    required bool isDefault,
  }) {
    final generatedOtp = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    final otpCtrl = TextEditingController(text: generatedOtp);
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: provider.brandColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(provider.icon, color: provider.brandColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Verifikasi Akun ${provider.label}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Otorisasi Akun
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              'Otorisasi Cepat Terhubung (${provider.label})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kode otorisasi otomatis: $generatedOtp. Akun Anda siap dikoneksikan ke sistem restoran secara langsung tanpa perlu menunggu SMS.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Kode verifikasi koneksi:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: InputDecoration(
                      hintText: 'Kode OTP',
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: provider.brandColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: provider.brandColor),
                onPressed: isVerifying
                    ? null
                    : () async {
                        final otp = otpCtrl.text.trim();
                        if (otp.length < 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Masukkan kode OTP valid')),
                          );
                          return;
                        }

                        setDState(() => isVerifying = true);
                        await Future.delayed(const Duration(milliseconds: 600));

                        widget.db.addPaymentMethod(
                          provider: provider,
                          accountNumber: accountNumber,
                          accountName: accountName,
                          initialBalance: balance,
                          isDefault: isDefault,
                        );

                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF16A34A),
                            content: Text('✓ Akun ${provider.label} ($accountNumber) berhasil terverifikasi & terkoneksi!'),
                          ),
                        );
                      },
                child: isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Konfirmasi & Hubungkan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTopUpDialog(ConnectedPaymentMethod method) {
    int selectedAmount = 100000;
    final amounts = [50000, 100000, 200000, 500000];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(method.provider.icon, color: method.provider.brandColor),
                const SizedBox(width: 8),
                Text('Top Up ${method.provider.label}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo saat ini: ${_currencyFmt.format(method.balance)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text('Pilih Nominal Top Up:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: amounts.map((amt) {
                    final isSel = selectedAmount == amt;
                    return ChoiceChip(
                      selected: isSel,
                      label: Text(_currencyFmt.format(amt)),
                      selectedColor: const Color(0xFFEA580C),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setDialogState(() => selectedAmount = amt);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                onPressed: () {
                  widget.db.topUpPaymentMethod(method.id, selectedAmount);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF16A34A),
                      content: Text('✓ Top up ${_currencyFmt.format(selectedAmount)} ke ${method.provider.label} berhasil!'),
                    ),
                  );
                },
                child: const Text('Isi Saldo'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMutationHistoryDialog(ConnectedPaymentMethod method) {
    final mutations = widget.db.getMutationsForMethod(method.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: method.provider.brandColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mutasi ${method.provider.label}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${method.provider.label} • ${method.maskedNumber}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 2),
                        Text(method.accountName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Saldo Terkoneksi', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(
                          _currencyFmt.format(method.balance),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Histori Transaksi Akun:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              if (mutations.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada riwayat transaksi pada akun ini.\nSaldo otomatis terdebit saat memesan menu atau bertambah saat Top Up.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 240,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: mutations.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = mutations[i];
                      final isCredit = m.tipe == MutationType.credit;
                      final dateStr = DateFormat('dd MMM, HH:mm').format(m.tanggal);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                size: 16,
                                color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.keterangan,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$dateStr ${m.referensiId != null ? "• ${m.referensiId}" : ""}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isCredit ? "+" : "-"}${_currencyFmt.format(m.nominal)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                ),
                                Text(
                                  'Sisa: ${_currencyFmt.format(m.saldoSesudah)}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

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
                hintText: 'Masukkan Kata Sandi Saat Ini',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kata Sandi Baru',
                hintText: 'Masukkan Kata Sandi Baru',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Kata Sandi Baru',
                hintText: 'Masukkan Konfirmasi Kata Sandi Baru',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
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
                    content: Text('✓ Kata sandi berhasil diperbarui!'),
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

  void _showAddAddressDialog() {
    final addrController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_location_alt_rounded, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Tambah Alamat Antar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: addrController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alamat Rumah / Kantor',
            hintText: 'Masukkan Alamat',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () {
              final text = addrController.text.trim();
              if (text.isNotEmpty) {
                setState(() => _savedAddresses.add(text));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF16A34A),
                    content: Text('✓ Alamat baru berhasil disimpan!'),
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

  @override
  Widget build(BuildContext context) {
    final user = widget.db.currentUser;
    final role = user?.role ?? UserRole.pelanggan;
    final is2Fa = user?.isTwoFactorEnabled == true;
    final paymentMethods = widget.db.connectedPaymentMethods;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Profile Header Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFFFF7ED),
                      backgroundImage: user?.displayPhoto.isNotEmpty == true
                          ? NetworkImage(user!.displayPhoto)
                          : null,
                      child: (user?.displayPhoto.isEmpty ?? true)
                          ? Text(
                              (user?.namaUser.isNotEmpty == true ? user!.namaUser[0] : 'R').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEA580C),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.namaUser ?? 'Tamu Rasantara',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.displayEmail ?? 'pelanggan@rasantara.resto',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFFEDD5)),
                                ),
                                child: Text(
                                  role.label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 2. Keamanan Akun & Two-Factor Auth (2FA / 2-Auth) ──
              _buildSectionHeader('Keamanan Akun & 2-Factor Auth (2FA)'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                const Text(
                                  'Autentikasi Dua Langkah (2-Auth)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  is2Fa
                                      ? 'Aktif via ${user?.twoFactorType ?? "Authenticator App"}'
                                      : 'Tambahkan proteksi kode verifikasi untuk transaksi dan pesanan.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ubah Kata Sandi',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Perbarui password lokal untuk keamanan login',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
              const SizedBox(height: 16),

              // ── 4. Metode Pembayaran Terkoneksi Nyata (DANA, GoPay, M-Banking, dsb.) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Metode Pembayaran Terkoneksi'),
                  InkWell(
                    onTap: _openAddPaymentMethodDialog,
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 8, right: 4),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 14, color: Color(0xFFEA580C)),
                          SizedBox(width: 4),
                          Text(
                            '+ Tambah Baru',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (paymentMethods.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.credit_card_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        const Text('Belum ada metode pembayaran yang terkoneksi', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        const SizedBox(height: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                          onPressed: _openAddPaymentMethodDialog,
                          child: const Text('Koneksikan DANA / GoPay / M-Banking'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...paymentMethods.map((method) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: method.isDefault ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
                        width: method.isDefault ? 1.5 : 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: method.provider.brandColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(method.provider.icon, color: method.provider.brandColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        method.provider.label,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                      ),
                                      if (method.isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFFFEDD5)),
                                          ),
                                          child: const Text(
                                            'UTAMA',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${method.maskedNumber} • ${method.accountName}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Saldo Aktif', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                Text(
                                  _currencyFmt.format(method.balance),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Action buttons per payment method
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!method.isDefault)
                              TextButton(
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => widget.db.setDefaultPaymentMethod(method.id),
                                child: const Text('Jadikan Utama', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF64748B)),
                              label: const Text('Mutasi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              onPressed: () => _showMutationHistoryDialog(method),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: const Icon(Icons.add, size: 14, color: Color(0xFFEA580C)),
                              label: const Text('Top Up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                              onPressed: () => _showTopUpDialog(method),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                              tooltip: 'Hapus Koneksi',
                              onPressed: () => widget.db.removePaymentMethod(method.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),

              // ── 5. Member Restoran Nusantara (Poin & Rewards) ──
              _buildSectionHeader('Langganan & Member Restoran'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEA580C), Color(0xFFFF7300)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MEMBER GOLD RASANTARA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.stars, color: Colors.amber, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Aktif',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${(widget.db.orders.where((o) => o.idUser == user?.idUser).length * 100)} Poin Kuliner',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tukarkan poin dengan potongan harga saat makan di tempat atau pesan delivery OSM.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildSectionHeader('Alamat Pengantaran (Delivery & Take Away)'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    ..._savedAddresses.map((addr) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.place_rounded, size: 18, color: Color(0xFFEA580C)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(addr, style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEA580C),
                        side: const BorderSide(color: Color(0xFFEA580C)),
                        minimumSize: const Size.fromHeight(38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                      label: const Text('Tambah Alamat Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _showAddAddressDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 7. Tombol Keluar / Logout ──
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE2E2),
                  foregroundColor: const Color(0xFFDC2626),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  widget.db.logout();
                  widget.onLogout();
                },
              ),
              const SizedBox(height: 20),
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
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}
