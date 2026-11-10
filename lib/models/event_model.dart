class EventModel {
  final int idEvent;
  final String judulEvent;
  final String deskripsi;
  final String gambarUrl;
  final String kodePromo;
  final int diskonPersen;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final bool isActive;
  final String createdBy; // Hanya 'owner' yang berhak membuat
  final DateTime createdAt;

  EventModel({
    required this.idEvent,
    required this.judulEvent,
    required this.deskripsi,
    this.gambarUrl = '',
    this.kodePromo = '',
    this.diskonPersen = 10,
    DateTime? tanggalMulai,
    DateTime? tanggalSelesai,
    this.isActive = true,
    this.createdBy = 'owner',
    DateTime? createdAt,
  })  : tanggalMulai = tanggalMulai ?? DateTime.now(),
        tanggalSelesai = tanggalSelesai ?? DateTime.now().add(const Duration(days: 14)),
        createdAt = createdAt ?? DateTime.now();

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      idEvent: (map['id_event'] as num?)?.toInt() ?? 0,
      judulEvent: map['judul_event']?.toString() ?? '',
      deskripsi: map['deskripsi']?.toString() ?? '',
      gambarUrl: map['gambar_url']?.toString() ?? '',
      kodePromo: map['kode_promo']?.toString() ?? '',
      diskonPersen: (map['diskon_persen'] as num?)?.toInt() ?? 10,
      tanggalMulai: map['tanggal_mulai'] != null
          ? DateTime.tryParse(map['tanggal_mulai'].toString()) ?? DateTime.now()
          : DateTime.now(),
      tanggalSelesai: map['tanggal_selesai'] != null
          ? DateTime.tryParse(map['tanggal_selesai'].toString()) ?? DateTime.now().add(const Duration(days: 14))
          : DateTime.now().add(const Duration(days: 14)),
      isActive: map['is_active'] == true || map['is_active'] == 1 || map['is_active'] == 'true',
      createdBy: map['created_by']?.toString() ?? 'owner',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idEvent > 0) 'id_event': idEvent,
      'judul_event': judulEvent,
      'deskripsi': deskripsi,
      'gambar_url': gambarUrl,
      'kode_promo': kodePromo,
      'diskon_persen': diskonPersen,
      'tanggal_mulai': tanggalMulai.toIso8601String().split('T').first,
      'tanggal_selesai': tanggalSelesai.toIso8601String().split('T').first,
      'is_active': isActive,
      'created_by': createdBy,
    };
  }

  EventModel copyWith({
    int? idEvent,
    String? judulEvent,
    String? deskripsi,
    String? gambarUrl,
    String? kodePromo,
    int? diskonPersen,
    DateTime? tanggalMulai,
    DateTime? tanggalSelesai,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return EventModel(
      idEvent: idEvent ?? this.idEvent,
      judulEvent: judulEvent ?? this.judulEvent,
      deskripsi: deskripsi ?? this.deskripsi,
      gambarUrl: gambarUrl ?? this.gambarUrl,
      kodePromo: kodePromo ?? this.kodePromo,
      diskonPersen: diskonPersen ?? this.diskonPersen,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      tanggalSelesai: tanggalSelesai ?? this.tanggalSelesai,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

