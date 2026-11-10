class UserAddressModel {
  final int idAlamat;
  final int idUser;
  final String label; // Rumah, Kantor, Apartemen, Kost, Teman, Keluarga
  final String recipientName;
  final String recipientPhone;
  final String province;
  final String city;
  final String district;
  final String postalCode;
  final String fullAddress;
  final String notes;
  final double? latitude;
  final double? longitude;
  final String? gmapsLink;
  final bool isPrimary;
  final DateTime createdAt;

  UserAddressModel({
    required this.idAlamat,
    required this.idUser,
    this.label = 'Rumah',
    required this.recipientName,
    required this.recipientPhone,
    this.province = '',
    this.city = '',
    this.district = '',
    this.postalCode = '',
    required this.fullAddress,
    this.notes = '',
    this.latitude,
    this.longitude,
    this.gmapsLink,
    this.isPrimary = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedFullAddress {
    final parts = <String>[];
    if (fullAddress.isNotEmpty) parts.add(fullAddress);
    if (district.isNotEmpty) parts.add('Kec. $district');
    if (city.isNotEmpty) parts.add(city);
    if (province.isNotEmpty) parts.add(province);
    if (postalCode.isNotEmpty) parts.add(postalCode);
    return parts.join(', ');
  }

  UserAddressModel copyWith({
    int? idAlamat,
    int? idUser,
    String? label,
    String? recipientName,
    String? recipientPhone,
    String? province,
    String? city,
    String? district,
    String? postalCode,
    String? fullAddress,
    String? notes,
    double? latitude,
    double? longitude,
    String? gmapsLink,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return UserAddressModel(
      idAlamat: idAlamat ?? this.idAlamat,
      idUser: idUser ?? this.idUser,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      postalCode: postalCode ?? this.postalCode,
      fullAddress: fullAddress ?? this.fullAddress,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gmapsLink: gmapsLink ?? this.gmapsLink,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int _parseInt(dynamic val, {int fallback = 0}) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.round();
    return double.tryParse(val.toString())?.round() ?? fallback;
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  factory UserAddressModel.fromMap(Map<String, dynamic> map) {
    DateTime dt;
    try {
      final str = map['created_at']?.toString();
      dt = str != null ? DateTime.parse(str) : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }

    return UserAddressModel(
      idAlamat: _parseInt(map['id_alamat']),
      idUser: _parseInt(map['id_user']),
      label: map['label']?.toString() ?? 'Rumah',
      recipientName: map['recipient_name']?.toString() ?? '',
      recipientPhone: map['recipient_phone']?.toString() ?? '',
      province: map['province']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      postalCode: map['postal_code']?.toString() ?? '',
      fullAddress: map['full_address']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      gmapsLink: map['gmaps_link']?.toString(),
      isPrimary: map['is_primary'] == true || map['is_primary'] == 1,
      createdAt: dt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idAlamat > 0) 'id_alamat': idAlamat,
      'id_user': idUser,
      'label': label,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'province': province,
      'city': city,
      'district': district,
      'postal_code': postalCode,
      'full_address': fullAddress,
      'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (gmapsLink != null && gmapsLink!.isNotEmpty) 'gmaps_link': gmapsLink,
      'is_primary': isPrimary,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

