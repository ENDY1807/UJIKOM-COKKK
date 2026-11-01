import 'package:flutter/material.dart';

enum PaymentMethodCategory {
  eWallet('E-Wallet & Dompet Digital'),
  mBanking('Mobile Banking & Direct Debit'),
  qris('QRIS Nasional'),
  tunai('Tunai');

  final String label;
  const PaymentMethodCategory(this.label);
}

enum PaymentMethodProvider {
  dana(
    'DANA',
    PaymentMethodCategory.eWallet,
    Icons.account_balance_wallet_rounded,
    Color(0xFF118EEA),
    '0812-3456-7890',
    'Dompet digital DANA Indonesia. Pembayaran 1-klik terintegrasi.',
  ),
  gopay(
    'GoPay',
    PaymentMethodCategory.eWallet,
    Icons.payments_rounded,
    Color(0xFF00AED6),
    '0813-9876-5432',
    'GoPay terintegrasi langsung dengan pesanan dan pengantaran GoFood.',
  ),
  ovo(
    'OVO',
    PaymentMethodCategory.eWallet,
    Icons.wallet_rounded,
    Color(0xFF4C2A86),
    '0812-5555-1234',
    'Dompet digital OVO terhubung dengan verifikasi OTP cepat.',
  ),
  shopeepay(
    'ShopeePay',
    PaymentMethodCategory.eWallet,
    Icons.shopping_bag_rounded,
    Color(0xFFEE4D2D),
    '0819-1122-3344',
    'ShopeePay terhubung dengan cashback dan promo pesanan.',
  ),
  bca(
    'BCA Mobile / OneKlik',
    PaymentMethodCategory.mBanking,
    Icons.account_balance_rounded,
    Color(0xFF005DAA),
    'Rek. 8830-1294-88',
    'Debit langsung Bank Central Asia (BCA) tanpa perlu konfirmasi manual.',
  ),
  mandiri(
    'Mandiri Livin',
    PaymentMethodCategory.mBanking,
    Icons.account_balance_rounded,
    Color(0xFF003876),
    'Rek. 1370-0192-34',
    'Direct debit terhubung dengan rekening Mandiri Livin nasabah.',
  ),
  bri(
    'BRImo',
    PaymentMethodCategory.mBanking,
    Icons.account_balance_rounded,
    Color(0xFF00529C),
    'Rek. 0206-0100-55',
    'Koneksi rekening Bank Rakyat Indonesia via integrasi debit aman.',
  ),
  bni(
    'BNI Mobile',
    PaymentMethodCategory.mBanking,
    Icons.account_balance_rounded,
    Color(0xFFE55300),
    'Rek. 0455-8821-90',
    'Direct debit rekening Bank Negara Indonesia dengan PIN otorisasi.',
  );

  final String label;
  final PaymentMethodCategory category;
  final IconData icon;
  final Color brandColor;
  final String defaultFormat;
  final String description;

  const PaymentMethodProvider(
    this.label,
    this.category,
    this.icon,
    this.brandColor,
    this.defaultFormat,
    this.description,
  );
}

class ConnectedPaymentMethod {
  final String id;
  final PaymentMethodProvider provider;
  final String accountNumber;
  final String accountName;
  int balance;
  bool isDefault;
  final DateTime connectedAt;

  ConnectedPaymentMethod({
    required this.id,
    required this.provider,
    required this.accountNumber,
    required this.accountName,
    this.balance = 0,
    this.isDefault = false,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  String get maskedNumber {
    if (accountNumber.length <= 4) return accountNumber;
    final clean = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 8) {
      final prefix = clean.substring(0, 4);
      final suffix = clean.substring(clean.length - 4);
      return '$prefix-****-$suffix';
    }
    return accountNumber;
  }

  ConnectedPaymentMethod copyWith({
    String? id,
    PaymentMethodProvider? provider,
    String? accountNumber,
    String? accountName,
    int? balance,
    bool? isDefault,
    DateTime? connectedAt,
  }) {
    return ConnectedPaymentMethod(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      balance: balance ?? this.balance,
      isDefault: isDefault ?? this.isDefault,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }

  factory ConnectedPaymentMethod.fromMap(Map<String, dynamic> map) {
    PaymentMethodProvider prov = PaymentMethodProvider.dana;
    final provStr = map['provider']?.toString().toLowerCase() ?? 'dana';
    for (final p in PaymentMethodProvider.values) {
      if (p.name.toLowerCase() == provStr || p.label.toLowerCase() == provStr) {
        prov = p;
        break;
      }
    }

    final int bal = map['balance'] is int
        ? map['balance'] as int
        : int.tryParse('${map['balance']}') ?? 0;

    DateTime conn = DateTime.now();
    if (map['connected_at'] != null) {
      try {
        conn = DateTime.parse(map['connected_at'].toString());
      } catch (_) {}
    }

    return ConnectedPaymentMethod(
      id: map['id']?.toString() ?? 'pay_${DateTime.now().millisecondsSinceEpoch}',
      provider: prov,
      accountNumber: map['account_number']?.toString() ?? '',
      accountName: map['account_name']?.toString() ?? '',
      balance: bal,
      isDefault: map['is_default'] == true,
      connectedAt: conn,
    );
  }

  Map<String, dynamic> toMap({int? idUser}) {
    return {
      'id': id,
      '?id_user': idUser,
      'provider': provider.name,
      'account_number': accountNumber,
      'account_name': accountName,
      'balance': balance,
      'is_default': isDefault,
      'connected_at': connectedAt.toIso8601String(),
    };
  }
}

enum MutationType {
  credit('Kredit / Masuk', Icons.arrow_downward_rounded, Color(0xFF16A34A)),
  debit('Debit / Keluar', Icons.arrow_upward_rounded, Color(0xFFDC2626));

  final String label;
  final IconData icon;
  final Color color;
  const MutationType(this.label, this.icon, this.color);
}

class PaymentMutation {
  final int idMutasi;
  final String idPaymentMethod;
  final int idUser;
  final MutationType tipe;
  final int nominal;
  final int saldoSebelum;
  final int saldoSesudah;
  final String keterangan;
  final String? referensiId;
  final DateTime tanggal;

  PaymentMutation({
    required this.idMutasi,
    required this.idPaymentMethod,
    required this.idUser,
    required this.tipe,
    required this.nominal,
    required this.saldoSebelum,
    required this.saldoSesudah,
    required this.keterangan,
    this.referensiId,
    DateTime? tanggal,
  }) : tanggal = tanggal ?? DateTime.now();

  factory PaymentMutation.fromMap(Map<String, dynamic> map) {
    final tStr = (map['tipe'] ?? 'Debit').toString().toLowerCase();
    final type = tStr.contains('kredit') ? MutationType.credit : MutationType.debit;

    DateTime dt = DateTime.now();
    if (map['created_at'] != null || map['tanggal'] != null) {
      try {
        dt = DateTime.parse((map['created_at'] ?? map['tanggal']).toString());
      } catch (_) {}
    }

    return PaymentMutation(
      idMutasi: map['id_mutasi'] is int ? map['id_mutasi'] as int : int.tryParse('${map['id_mutasi']}') ?? 0,
      idPaymentMethod: map['id_payment_method']?.toString() ?? '',
      idUser: map['id_user'] is int ? map['id_user'] as int : int.tryParse('${map['id_user']}') ?? 0,
      tipe: type,
      nominal: map['nominal'] is int ? map['nominal'] as int : int.tryParse('${map['nominal']}') ?? 0,
      saldoSebelum: map['saldo_sebelum'] is int ? map['saldo_sebelum'] as int : int.tryParse('${map['saldo_sebelum']}') ?? 0,
      saldoSesudah: map['saldo_sesudah'] is int ? map['saldo_sesudah'] as int : int.tryParse('${map['saldo_sesudah']}') ?? 0,
      keterangan: map['keterangan']?.toString() ?? '',
      referensiId: map['referensi_id']?.toString(),
      tanggal: dt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idMutasi > 0) 'id_mutasi': idMutasi,
      'id_payment_method': idPaymentMethod,
      'id_user': idUser,
      'tipe': tipe == MutationType.credit ? 'Kredit' : 'Debit',
      'nominal': nominal,
      'saldo_sebelum': saldoSebelum,
      'saldo_sesudah': saldoSesudah,
      'keterangan': keterangan,
      if (referensiId != null) 'referensi_id': referensiId,
      'created_at': tanggal.toIso8601String(),
    };
  }
}

