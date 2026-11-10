import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/payment_method_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class ManagePaymentsScreen extends StatefulWidget {
  final DatabaseService db;

  const ManagePaymentsScreen({super.key, required this.db});

  static Future<void> navigate(BuildContext context, DatabaseService db) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManagePaymentsScreen(db: db),
      ),
    );
  }

  @override
  State<ManagePaymentsScreen> createState() => _ManagePaymentsScreenState();
}

class _ManagePaymentsScreenState extends State<ManagePaymentsScreen> {
  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.db,
      builder: (context, _) {
        final paymentMethods = widget.db.connectedPaymentMethods;
        final refundMethods = widget.db.refundMethods;
        final balance = widget.db.userBalance;

        return Scaffold(
          backgroundColor: context.surfaceBg,
          appBar: AppBar(
            backgroundColor: context.surfaceCard,
            elevation: 0,
            scrolledUnderElevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Manage payments',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF1E293B)),
                onPressed: _showSettingsDialog,
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SECTION 1: BALANCE ──
                  const Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBalanceCard(balance),
                  const SizedBox(height: 24),

                  // ── SECTION 2: PAYMENT METHODS ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment methods',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showAddPaymentMethodSheet(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (paymentMethods.isEmpty)
                    _buildEmptyPaymentMethodsCard()
                  else
                    ...paymentMethods.map((method) => _buildPaymentMethodItem(method)),
                  const SizedBox(height: 24),

                  // ── SECTION 3: REFUND METHODS ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Refund methods',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showAddRefundMethodSheet(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (refundMethods.isEmpty)
                    _buildEmptyRefundMethodsCard()
                  else
                    ...refundMethods.map((method) => _buildRefundMethodItem(method)),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── BALANCE CARD ──
  Widget _buildBalanceCard(int balance) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _showTopUpBalanceDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFmt.format(balance),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── EMPTY PAYMENT METHODS ──
  Widget _buildEmptyPaymentMethodsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.payment_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            const Text(
              'Belum ada metode pembayaran yang terhubung.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showAddPaymentMethodSheet(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Metode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // ── PAYMENT METHOD ITEM ──
  Widget _buildPaymentMethodItem(ConnectedPaymentMethod method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: method.isDefault ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
          width: method.isDefault ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showManagePaymentMethodDialog(method),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildProviderIcon(method.provider),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              method.displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (method.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Saldo: ${_currencyFmt.format(method.balance)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── REFUND METHODS SECTION ──
  Widget _buildEmptyRefundMethodsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Friendly vector illustration for refund empty state
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 40,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "You haven't added any refund\nmethods.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Metode refund digunakan untuk pengembalian dana cepat jika pesanan dibatalkan.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundMethodItem(RefundMethod method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            method.type == 'bank' ? Icons.account_balance_rounded : Icons.account_balance_wallet_rounded,
            color: const Color(0xFF0F172A),
            size: 20,
          ),
        ),
        title: Text(
          method.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
        ),
        subtitle: Text(
          'A.n. ${method.accountHolderName}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
          onPressed: () => _confirmDeleteRefundMethod(method),
        ),
      ),
    );
  }

  // ── PROVIDER ICON BUILDER ──
  Widget _buildProviderIcon(PaymentMethodProvider provider) {
    switch (provider) {
      case PaymentMethodProvider.dana:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF118EEA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.wallet, color: Colors.white, size: 20),
          ),
        );
      case PaymentMethodProvider.gopay:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF00AED6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
          ),
        );
      case PaymentMethodProvider.ovo:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF4C2A86),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('ovo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        );
      case PaymentMethodProvider.card:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.credit_card_rounded, color: Colors.white, size: 20),
          ),
        );
      default:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: provider.brandColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(provider.icon, color: Colors.white, size: 20),
          ),
        );
    }
  }

  // ── MODAL BOTTOM SHEET: "Add payment methods" (Persis Referensi Foto) ──
  void _showAddPaymentMethodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title and close icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 36), // spacer
                      const Text(
                        'Add payment methods',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Option 1: Add OVO
                _buildSheetOptionTile(
                  iconWidget: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C2A86),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text('ovo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                  title: 'Add OVO',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openInputPaymentMethodDialog(PaymentMethodProvider.ovo);
                  },
                ),

                // Option 2: Add credit/debit card
                _buildSheetOptionTile(
                  iconWidget: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(Icons.credit_card_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  title: 'Add credit/debit card',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openInputPaymentMethodDialog(PaymentMethodProvider.card);
                  },
                ),

                // Option 3: Add DANA
                _buildSheetOptionTile(
                  iconWidget: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF118EEA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(Icons.wallet, color: Colors.white, size: 18),
                    ),
                  ),
                  title: 'Add DANA',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openInputPaymentMethodDialog(PaymentMethodProvider.dana);
                  },
                ),

                // Option 4: Add GoPay
                _buildSheetOptionTile(
                  iconWidget: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00AED6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  title: 'Add GoPay',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openInputPaymentMethodDialog(PaymentMethodProvider.gopay);
                  },
                ),

                // Option 5: Add BCA / Bank Direct Debit
                _buildSheetOptionTile(
                  iconWidget: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF005DAA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(Icons.account_balance_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  title: 'Add Bank Account (BCA / Mandiri / BRI)',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openInputPaymentMethodDialog(PaymentMethodProvider.bca);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetOptionTile({
    required Widget iconWidget,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: iconWidget,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 15,
        color: Color(0xFF94A3B8),
      ),
      onTap: onTap,
    );
  }

  // ── INPUT DIALOG TAMBAH METODE PEMBAYARAN ──
  void _openInputPaymentMethodDialog(PaymentMethodProvider provider) {
    final accountController = TextEditingController();
    final nameController = TextEditingController(text: widget.db.currentUser?.namaUser ?? '');
    final balanceController = TextEditingController(text: '150000');
    bool isDefault = widget.db.connectedPaymentMethods.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Hubungkan ${provider.label}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.category == PaymentMethodCategory.eWallet
                      ? 'Nomor Handphone Terdaftar:'
                      : 'Nomor Kartu / Rekening:',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: accountController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: provider.defaultFormat,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nama Pemilik Akun:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Nama lengkap sesuai akun',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Simulasi Saldo Awal (Rp):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '150000',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isDefault,
                  onChanged: (val) => setDialogState(() => isDefault = val ?? false),
                  title: const Text(
                    'Jadikan metode utama (Default)',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final acc = accountController.text.trim();
                final name = nameController.text.trim();
                final bal = int.tryParse(balanceController.text.trim()) ?? 100000;

                if (acc.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nomor akun dan nama tidak boleh kosong!')),
                  );
                  return;
                }

                widget.db.addPaymentMethod(
                  provider: provider,
                  accountNumber: acc,
                  accountName: name,
                  initialBalance: bal,
                  isDefault: isDefault,
                );

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF16A34A),
                    content: Text('Berhasil menghubungkan ${provider.label}!'),
                  ),
                );
              },
              child: const Text('Simpan & Hubungkan'),
            ),
          ],
        ),
      ),
    );
  }

  // ── MODAL BOTTOM SHEET: "Add refund methods" ──
  void _showAddRefundMethodSheet(BuildContext context) {
    String type = 'bank';
    String providerName = 'Bank BCA';
    final accountController = TextEditingController();
    final nameController = TextEditingController(text: widget.db.currentUser?.namaUser ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Tambah Metode Refund',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jenis Metode:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: providerName,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Bank BCA', child: Text('Bank BCA')),
                    DropdownMenuItem(value: 'Bank Mandiri', child: Text('Bank Mandiri')),
                    DropdownMenuItem(value: 'Bank BRI', child: Text('Bank BRI')),
                    DropdownMenuItem(value: 'Bank BNI', child: Text('Bank BNI')),
                    DropdownMenuItem(value: 'DANA', child: Text('DANA')),
                    DropdownMenuItem(value: 'GoPay', child: Text('GoPay')),
                    DropdownMenuItem(value: 'OVO', child: Text('OVO')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        providerName = val;
                        type = (val == 'DANA' || val == 'GoPay' || val == 'OVO') ? 'ewallet' : 'bank';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  type == 'bank' ? 'Nomor Rekening:' : 'Nomor HP Terdaftar:',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: accountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: type == 'bank' ? '8830129488' : '081234567890',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nama Pemilik Rekening / Akun:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Nama lengkap pemilik',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final acc = accountController.text.trim();
                final name = nameController.text.trim();
                if (acc.isEmpty || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nomor dan nama rekening wajib diisi!')),
                  );
                  return;
                }

                widget.db.addRefundMethod(
                  RefundMethod(
                    id: 'ref_${DateTime.now().millisecondsSinceEpoch}',
                    type: type,
                    providerName: providerName,
                    accountNumber: acc,
                    accountHolderName: name,
                  ),
                );

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF16A34A),
                    content: Text('Metode refund berhasil ditambahkan!'),
                  ),
                );
              },
              child: const Text('Simpan Refund Method'),
            ),
          ],
        ),
      ),
    );
  }

  // ── MANAGE / TOP UP / DELETE PAYMENT METHOD ──
  void _showManagePaymentMethodDialog(ConnectedPaymentMethod method) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _buildProviderIcon(method.provider),
                title: Text(method.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Saldo: ${_currencyFmt.format(method.balance)} · ${method.accountName}'),
              ),
              const Divider(),
              if (!method.isDefault)
                ListTile(
                  leading: const Icon(Icons.star_rounded, color: Color(0xFF0284C7)),
                  title: const Text('Jadikan Metode Utama (Default)'),
                  onTap: () {
                    widget.db.setDefaultPaymentMethod(method.id);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${method.displayName} dijadikan metode utama.')),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A)),
                title: const Text('Isi Saldo (Top Up)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showTopUpDialogForMethod(method);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                title: const Text('Hapus / Putuskan Metode', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  widget.db.removePaymentMethod(method.id);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${method.displayName} berhasil dihapus.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTopUpDialogForMethod(ConnectedPaymentMethod method) {
    int amount = 50000;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Isi Saldo ${method.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [20000, 50000, 100000, 200000].map((nom) {
                  final isSelected = amount == nom;
                  return ChoiceChip(
                    label: Text(_currencyFmt.format(nom)),
                    selected: isSelected,
                    onSelected: (val) => setDialogState(() => amount = nom),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                widget.db.topUpPaymentMethod(method.id, amount);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF16A34A),
                    content: Text('Saldo ${method.displayName} bertambah ${_currencyFmt.format(amount)}!'),
                  ),
                );
              },
              child: const Text('Top Up Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopUpBalanceDialog() {
    int amount = 50000;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Isi Saldo Akun Rasantara'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saldo Saat Ini: ${_currencyFmt.format(widget.db.userBalance)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
              const SizedBox(height: 12),
              const Text('Pilih nominal top up:'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [20000, 50000, 100000, 250000].map((nom) {
                  final isSelected = amount == nom;
                  return ChoiceChip(
                    label: Text(_currencyFmt.format(nom)),
                    selected: isSelected,
                    onSelected: (val) => setDialogState(() => amount = nom),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                widget.db.topUpBalance(amount);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF059669),
                    content: Text('Saldo Rasantara bertambah ${_currencyFmt.format(amount)}!'),
                  ),
                );
              },
              child: const Text('Top Up Saldo'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRefundMethod(RefundMethod method) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Metode Refund?'),
        content: Text('Apakah Anda yakin ingin menghapus ${method.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              widget.db.removeRefundMethod(method.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pengaturan Pembayaran'),
        content: const Text(
          'Metode pembayaran terhubung tersimpan secara aman dan tersinkronisasi otomatis dengan akun Anda. Anda dapat mengatur metode utama atau metode refund kapan saja.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')),
        ],
      ),
    );
  }
}
