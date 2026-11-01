enum MenuCategory {
  semua('Semua'),
  paket('Paket Spesial'),
  makanan('Makanan'),
  minuman('Minuman'),
  addon('Camilan & Add-On');

  final String label;
  const MenuCategory(this.label);

  static MenuCategory fromString(String val) {
    final v = val.trim().toLowerCase();
    if (v.contains('paket')) return MenuCategory.paket;
    if (v.contains('minum') || v.contains('drink') || v.contains('beverage')) return MenuCategory.minuman;
    if (v.contains('addon') || v.contains('add-on') || v.contains('snack') || v.contains('camilan') || v.contains('ekstra')) return MenuCategory.addon;
    return MenuCategory.values.firstWhere(
      (c) => c.label.toLowerCase() == v || c.name.toLowerCase() == v,
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
  final String gambarUrl;

  MenuModel({
    required this.idMasakan,
    required this.namaMasakan,
    required this.kategori,
    required this.harga,
    this.status = MenuStatus.tersedia,
    this.deskripsi = '',
    this.gambarUrl = '',
  });

  bool get isTersedia => status == MenuStatus.tersedia;

  MenuModel copyWith({
    int? idMasakan,
    String? namaMasakan,
    MenuCategory? kategori,
    int? harga,
    MenuStatus? status,
    String? deskripsi,
    String? gambarUrl,
  }) {
    return MenuModel(
      idMasakan: idMasakan ?? this.idMasakan,
      namaMasakan: namaMasakan ?? this.namaMasakan,
      kategori: kategori ?? this.kategori,
      harga: harga ?? this.harga,
      status: status ?? this.status,
      deskripsi: deskripsi ?? this.deskripsi,
      gambarUrl: gambarUrl ?? this.gambarUrl,
    );
  }

  static int _parsePrice(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.round();
    return double.tryParse(val.toString())?.round() ?? 0;
  }

  factory MenuModel.fromMap(Map<String, dynamic> map) {
    return MenuModel(
      idMasakan: map['id_masakan'] is int
          ? map['id_masakan'] as int
          : int.tryParse('${map['id_masakan']}') ?? 0,
      namaMasakan: map['nama_masakan'] ?? '',
      kategori: MenuCategory.fromString(map['kategori']?.toString() ?? 'Makanan'),
      harga: _parsePrice(map['harga']),
      status: MenuStatus.fromString(map['status_masakan']?.toString() ?? map['status']?.toString() ?? 'Tersedia'),
      deskripsi: map['deskripsi'] ?? '',
      gambarUrl: map['gambar_url'] ?? '',
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
      if (gambarUrl.isNotEmpty) 'gambar_url': gambarUrl,
    };
  }
}
