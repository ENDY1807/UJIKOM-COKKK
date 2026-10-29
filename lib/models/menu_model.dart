enum MenuCategory {
  semua('Semua'),
  makanan('Makanan'),
  minuman('Minuman'),
  paket('Paket');

  final String label;
  const MenuCategory(this.label);

  static MenuCategory fromString(String val) {
    return MenuCategory.values.firstWhere(
      (c) => c.label.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => MenuCategory.makanan,
    );
  }
}

enum MenuStatus {
  tersedia('Tersedia'),
  habis('Habis');

  final String label;
  const MenuStatus(this.label);

  static MenuStatus fromString(String val) {
    return MenuStatus.values.firstWhere(
      (s) => s.label.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => MenuStatus.tersedia,
    );
  }
}

class MenuModel {
  final int idMasakan;
  final String namaMasakan;
  final MenuCategory kategori;
  final int harga;
  final MenuStatus status;
  final String deskripsi;

  MenuModel({
    required this.idMasakan,
    required this.namaMasakan,
    required this.kategori,
    required this.harga,
    this.status = MenuStatus.tersedia,
    this.deskripsi = '',
  });

  bool get isTersedia => status == MenuStatus.tersedia;

  MenuModel copyWith({
    int? idMasakan,
    String? namaMasakan,
    MenuCategory? kategori,
    int? harga,
    MenuStatus? status,
    String? deskripsi,
  }) {
    return MenuModel(
      idMasakan: idMasakan ?? this.idMasakan,
      namaMasakan: namaMasakan ?? this.namaMasakan,
      kategori: kategori ?? this.kategori,
      harga: harga ?? this.harga,
      status: status ?? this.status,
      deskripsi: deskripsi ?? this.deskripsi,
    );
  }

  factory MenuModel.fromMap(Map<String, dynamic> map) {
    return MenuModel(
      idMasakan: map['id_masakan'] is int
          ? map['id_masakan'] as int
          : int.tryParse('${map['id_masakan']}') ?? 0,
      namaMasakan: map['nama_masakan'] ?? '',
      kategori: MenuCategory.fromString(map['kategori']?.toString() ?? 'Makanan'),
      harga: map['harga'] is int
          ? map['harga'] as int
          : int.tryParse('${map['harga']}') ?? 0,
      status: MenuStatus.fromString(map['status_masakan']?.toString() ?? 'Tersedia'),
      deskripsi: map['deskripsi'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idMasakan > 0) 'id_masakan': idMasakan,
      'nama_masakan': namaMasakan,
      'kategori': kategori.label,
      'harga': harga,
      'status_masakan': status.label,
      'deskripsi': deskripsi,
    };
  }
}
