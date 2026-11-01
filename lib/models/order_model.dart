import 'menu_model.dart';

enum OrderStatus {
  menunggu('Menunggu'),
  diproses('Diproses'),
  selesai('Selesai'),
  dibatalkan('Dibatalkan');

  final String label;
  const OrderStatus(this.label);

  static OrderStatus fromString(String val) {
    final clean = val.trim().toLowerCase();
    if (clean.contains('selesai')) return OrderStatus.selesai;
    if (clean.contains('proses') || clean.contains('dimasak')) return OrderStatus.diproses;
    if (clean.contains('batal')) return OrderStatus.dibatalkan;
    return OrderStatus.menunggu;
  }
}

class OrderItemModel {
  final int idDetailOrder;
  final MenuModel menu;
  int jumlah;
  String catatan;

  OrderItemModel({
    required this.idDetailOrder,
    required this.menu,
    this.jumlah = 1,
    this.catatan = '',
  });

  int get subtotal => menu.harga * jumlah;

  OrderItemModel copyWith({
    int? idDetailOrder,
    MenuModel? menu,
    int? jumlah,
    String? catatan,
  }) {
    return OrderItemModel(
      idDetailOrder: idDetailOrder ?? this.idDetailOrder,
      menu: menu ?? this.menu,
      jumlah: jumlah ?? this.jumlah,
      catatan: catatan ?? this.catatan,
    );
  }

  static int _parseInt(dynamic val, {int fallback = 0}) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.round();
    return double.tryParse(val.toString())?.round() ?? fallback;
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map, MenuModel menu) {
    return OrderItemModel(
      idDetailOrder: _parseInt(map['id_detail_order']),
      menu: menu,
      jumlah: _parseInt(map['jumlah'], fallback: 1),
      catatan: map['keterangan'] ?? '',
    );
  }

  Map<String, dynamic> toMap(int orderId) {
    return {
      if (idDetailOrder > 0) 'id_detail_order': idDetailOrder,
      'id_order': orderId,
      'id_masakan': menu.idMasakan,
      'jumlah': jumlah,
      'harga_satuan': menu.harga,
      'subtotal': subtotal,
      'keterangan': catatan,
      'status_detail_order': 'Menunggu',
    };
  }
}

class OrderModel {
  final int idOrder;
  final String noMeja;
  final String namaPelanggan;
  final DateTime tanggal;
  final int idUser;
  final String namaUser;
  final String keterangan;
  OrderStatus status;
  final List<OrderItemModel> items;

  OrderModel({
    required this.idOrder,
    required this.noMeja,
    required this.namaPelanggan,
    required this.tanggal,
    required this.idUser,
    required this.namaUser,
    this.keterangan = '',
    this.status = OrderStatus.menunggu,
    required this.items,
  });

  int get totalHarga => items.fold(0, (sum, item) => sum + item.subtotal);
  int get totalItem => items.fold(0, (sum, item) => sum + item.jumlah);

  OrderModel copyWith({
    int? idOrder,
    String? noMeja,
    String? namaPelanggan,
    DateTime? tanggal,
    int? idUser,
    String? namaUser,
    String? keterangan,
    OrderStatus? status,
    List<OrderItemModel>? items,
  }) {
    return OrderModel(
      idOrder: idOrder ?? this.idOrder,
      noMeja: noMeja ?? this.noMeja,
      namaPelanggan: namaPelanggan ?? this.namaPelanggan,
      tanggal: tanggal ?? this.tanggal,
      idUser: idUser ?? this.idUser,
      namaUser: namaUser ?? this.namaUser,
      keterangan: keterangan ?? this.keterangan,
      status: status ?? this.status,
      items: items ?? this.items,
    );
  }

  static int _parseInt(dynamic val, {int fallback = 0}) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.round();
    return double.tryParse(val.toString())?.round() ?? fallback;
  }

  factory OrderModel.fromMap(
    Map<String, dynamic> map, {
    String? fallbackUserName,
    List<OrderItemModel>? items,
  }) {
    final tglStr = map['tanggal']?.toString();
    DateTime dt;
    try {
      dt = tglStr != null ? DateTime.parse(tglStr) : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }

    String ket = map['keterangan'] ?? '';
    String pel = map['nama_pelanggan'] ?? '';
    // Jika nama_pelanggan tidak ada di kolom terpisah, coba parse dari keterangan
    if (pel.isEmpty && ket.contains('Pelanggan:')) {
      final parts = ket.split('Pelanggan:');
      if (parts.length > 1) {
        final sub = parts[1].split('|');
        pel = sub.first.trim();
        ket = sub.length > 1 ? sub.sublist(1).join('|').trim() : '';
      }
    }

    return OrderModel(
      idOrder: _parseInt(map['id_order']),
      noMeja: map['no_meja'] ?? 'Meja -',
      namaPelanggan: pel.isNotEmpty ? pel : 'Pelanggan',
      tanggal: dt,
      idUser: _parseInt(map['id_user']),
      namaUser: fallbackUserName ?? 'Staff',
      keterangan: ket,
      status: OrderStatus.fromString(map['status_order']?.toString() ?? map['status']?.toString() ?? 'Menunggu'),
      items: items ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idOrder > 0) 'id_order': idOrder,
      'no_meja': noMeja,
      'tanggal': tanggal.toIso8601String(),
      'id_user': idUser,
      'keterangan': namaPelanggan.isNotEmpty
          ? 'Pelanggan: $namaPelanggan${keterangan.isNotEmpty ? ' | $keterangan' : ''}'
          : keterangan,
      'status_order': status.label,
    };
  }
}
