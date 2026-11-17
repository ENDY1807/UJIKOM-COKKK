enum MenuCategory {
  semua('Semua'),
  paket('Paket Spesial'),
  makanan('Makanan'),
  minuman('Minuman'),
  addon('Camilan & Add-On');

  final String label;
  const MenuCategory(this.label);

  String localizedLabel(bool isEnglish) {
    if (!isEnglish) return label;
    switch (this) {
      case MenuCategory.semua:
        return 'All';
      case MenuCategory.paket:
        return 'Special Combos';
      case MenuCategory.makanan:
        return 'Food';
      case MenuCategory.minuman:
        return 'Drinks';
      case MenuCategory.addon:
        return 'Snacks & Extras';
    }
  }

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

  String localizedLabel(bool isEnglish) {
    if (!isEnglish) return label;
    switch (this) {
      case MenuStatus.tersedia:
        return 'Available';
      case MenuStatus.habis:
        return 'Sold Out';
    }
  }

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

  static String defaultImageForMenu(String name, MenuCategory cat) {
    final n = name.toLowerCase();
    if (n.contains('bebek')) {
      return 'https://images.unsplash.com/photo-1580476262798-bddd9f4b7369?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('alpukat')) {
      return 'https://images.unsplash.com/photo-1601039641847-7857b994d704?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('rendang')) {
      return 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('betutu') || n.contains('taliwang') || n.contains('ayam')) {
      return 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('liwet')) {
      return 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('rawon')) {
      return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('gudeg')) {
      return 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('sate')) {
      return 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('soto')) {
      return 'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('pempek')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('gado')) {
      return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('nasi goreng')) {
      return 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('mie')) {
      return 'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('bakso')) {
      return 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('cendol')) {
      return 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('teler')) {
      return 'https://images.unsplash.com/photo-1505252585461-04db1eb84625?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('jahe') || n.contains('wedang')) {
      return 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('teh') || n.contains('tarik')) {
      return 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('kopi')) {
      return 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('kelapa') || n.contains('kuwut')) {
      return 'https://images.unsplash.com/photo-1556881286-fc6915169721?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('pisang')) {
      return 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('tahu')) {
      return 'https://images.unsplash.com/photo-1585238342024-78d387f4a707?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('tempe')) {
      return 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80';
    }
    if (n.contains('kerupuk')) {
      return 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=600&auto=format&fit=crop&q=80';
    }

    switch (cat) {
      case MenuCategory.minuman:
        return 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80';
      case MenuCategory.paket:
        return 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=600&auto=format&fit=crop&q=80';
      case MenuCategory.addon:
        return 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80';
      case MenuCategory.makanan:
      case MenuCategory.semua:
        return 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80';
    }
  }

  factory MenuModel.fromMap(Map<String, dynamic> map) {
    final cat = MenuCategory.fromString(map['kategori']?.toString() ?? 'Makanan');
    final nama = map['nama_masakan'] ?? '';
    var img = (map['gambar_url']?.toString() ?? '').trim();
    if (img.isEmpty) {
      img = defaultImageForMenu(nama, cat);
    }

    return MenuModel(
      idMasakan: map['id_masakan'] is int
          ? map['id_masakan'] as int
          : int.tryParse('${map['id_masakan']}') ?? 0,
      namaMasakan: nama,
      kategori: cat,
      harga: _parsePrice(map['harga']),
      status: MenuStatus.fromString(map['status_masakan']?.toString() ?? map['status']?.toString() ?? 'Tersedia'),
      deskripsi: map['deskripsi'] ?? '',
      gambarUrl: img,
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
