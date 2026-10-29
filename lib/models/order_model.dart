import 'menu_model.dart';

enum OrderStatus {
  menunggu('Menunggu'),
  diproses('Diproses'),
  selesai('Selesai'),
  dibatalkan('Dibatalkan');

  final String label;
  const OrderStatus(this.label);

  static OrderStatus fromString(String val) {
    return OrderStatus.values.firstWhere(
      (s) => s.label.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => OrderStatus.menunggu,
    );
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

  factory OrderItemModel.fromMap(Map<String, dynamic> map, MenuModel menu) {
    return OrderItemModel(
      idDetailOrder: map['id_detail_order'] is int
          ? map['id_detail_order'] as int
          : int.tryParse('${map['id_detail_order']}') ?? 0,
      menu: menu,
      jumlah: map['jumlah'] is int
          ? map['jumlah'] as int
          : int.tryParse('${map['jumlah']}') ?? 1,
      catatan: map['keterangan'] ?? '',
    );
  }

  Map<String, dynamic> toMap(int orderId) {
    return {
      if (idDetailOrder > 0) 'id_detail_order': idDetailOrder,
      'id_order': orderId,
      'id_masakan': menu.idMasakan,
      'jumlah': jumlah,
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

    return OrderModel(
      idOrder: map['id_order'] is int
          ? map['id_order'] as int
          : int.tryParse('${map['id_order']}') ?? 0,
      noMeja: map['no_meja'] ?? '',
      namaPelanggan: map['nama_pelanggan'] ?? '',
      tanggal: dt,
      idUser: map['id_user'] is int
          ? map['id_user'] as int
          : int.tryParse('${map['id_user']}') ?? 0,
      namaUser: fallbackUserName ?? 'Staff',
      keterangan: map['keterangan'] ?? '',
      status: OrderStatus.fromString(map['status_order']?.toString() ?? 'Menunggu'),
      items: items ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idOrder > 0) 'id_order': idOrder,
      'no_meja': noMeja,
      'nama_pelanggan': namaPelanggan,
      'tanggal': tanggal.toIso8601String(),
      'id_user': idUser,
      'keterangan': keterangan,
      'status_order': status.label,
    };
  }
}
