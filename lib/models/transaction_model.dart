import 'order_model.dart';

class TransactionModel {
  final int idTransaksi;
  final int idUser;
  final String namaKasir;
  final OrderModel order;
  final DateTime tanggal;
  final int totalBayar;
  final int jumlahBayar;
  final int kembalian;
  final String metodePembayaran;
  final int diskonMember;

  TransactionModel({
    required this.idTransaksi,
    required this.idUser,
    required this.namaKasir,
    required this.order,
    required this.tanggal,
    required this.totalBayar,
    required this.jumlahBayar,
    required this.kembalian,
    this.metodePembayaran = 'Tunai',
    this.diskonMember = 0,
  });

  static int _parseInt(dynamic val, {int fallback = 0}) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.round();
    return double.tryParse(val.toString())?.round() ?? fallback;
  }

  factory TransactionModel.fromMap(
    Map<String, dynamic> map, {
    required OrderModel order,
    String? fallbackKasirName,
  }) {
    // Utamakan created_at untuk mendapatkan tanggal & jam lengkap (local time)
    final tglStr = map['created_at']?.toString() ?? map['tanggal']?.toString();
    DateTime dt;
    try {
      if (tglStr != null && tglStr.isNotEmpty) {
        dt = DateTime.parse(tglStr).toLocal();
      } else {
        dt = DateTime.now();
      }
    } catch (_) {
      dt = DateTime.now();
    }

    final total = _parseInt(map['total_bayar'] ?? map['total'] ?? map['total_harga']);
    final jBayar = _parseInt(map['jumlah_bayar'] ?? map['jumlah_uang'] ?? map['bayar'], fallback: total);
    final kembali = _parseInt(map['kembalian']);

    return TransactionModel(
      idTransaksi: _parseInt(map['id_transaksi']),
      idUser: _parseInt(map['id_user']),
      namaKasir: fallbackKasirName ?? 'Kasir',
      order: order,
      tanggal: dt,
      totalBayar: total,
      jumlahBayar: jBayar,
      kembalian: kembali,
      metodePembayaran: map['metode_pembayaran'] ?? 'Tunai',
      diskonMember: _parseInt(map['diskon_member'], fallback: order.diskonMember),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idTransaksi > 0) 'id_transaksi': idTransaksi,
      'id_user': idUser,
      'id_order': order.idOrder,
      'tanggal': tanggal.toIso8601String(),
      'total_bayar': totalBayar,
      'jumlah_bayar': jumlahBayar,
      'jumlah_uang': jumlahBayar,
      'kembalian': kembalian,
      'metode_pembayaran': metodePembayaran,
      'diskon_member': diskonMember,
    };
  }
}
