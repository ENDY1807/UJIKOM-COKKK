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
  });

  factory TransactionModel.fromMap(
    Map<String, dynamic> map, {
    required OrderModel order,
    String? fallbackKasirName,
  }) {
    final tglStr = map['tanggal']?.toString();
    DateTime dt;
    try {
      dt = tglStr != null ? DateTime.parse(tglStr) : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }

    return TransactionModel(
      idTransaksi: map['id_transaksi'] is int
          ? map['id_transaksi'] as int
          : int.tryParse('${map['id_transaksi']}') ?? 0,
      idUser: map['id_user'] is int
          ? map['id_user'] as int
          : int.tryParse('${map['id_user']}') ?? 0,
      namaKasir: fallbackKasirName ?? 'Kasir',
      order: order,
      tanggal: dt,
      totalBayar: map['total_bayar'] is int
          ? map['total_bayar'] as int
          : int.tryParse('${map['total_bayar']}') ?? 0,
      jumlahBayar: map['jumlah_bayar'] is int
          ? map['jumlah_bayar'] as int
          : int.tryParse('${map['jumlah_bayar']}') ?? 0,
      kembalian: map['kembalian'] is int
          ? map['kembalian'] as int
          : int.tryParse('${map['kembalian']}') ?? 0,
      metodePembayaran: map['metode_pembayaran'] ?? 'Tunai',
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
      'kembalian': kembalian,
      'metode_pembayaran': metodePembayaran,
    };
  }
}
