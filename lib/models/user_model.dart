enum UserRole {
  administrator(1, 'Administrator'),
  waiter(2, 'Waiter'),
  kasir(3, 'Kasir'),
  owner(4, 'Owner'),
  pelanggan(5, 'Pelanggan');

  final int id;
  final String label;
  const UserRole(this.id, this.label);

  static UserRole fromId(int id) {
    return UserRole.values.firstWhere(
      (r) => r.id == id,
      orElse: () => UserRole.pelanggan,
    );
  }

  // Privilege checks based on UKK matrix
  bool get canRegisterUsers =>
      this == UserRole.administrator ||
      this == UserRole.waiter ||
      this == UserRole.kasir;
  bool get canManageReferences => this == UserRole.administrator;
  bool get canCreateOrder =>
      this == UserRole.administrator ||
      this == UserRole.waiter ||
      this == UserRole.pelanggan;
  bool get canProcessTransactions =>
      this == UserRole.administrator || this == UserRole.kasir;
  bool get canViewReports => this != UserRole.pelanggan;
}

enum AuthProvider { local, google, both }

class UserModel {
  final int idUser;
  final String username;
  final String password;
  final String namaUser;
  final UserRole role;
  final AuthProvider authProvider;
  final String? googleUid;
  final String? googleEmail;
  final String? googlePhoto;
  final String? fotoProfil;

  UserModel({
    required this.idUser,
    required this.username,
    required this.password,
    required this.namaUser,
    required this.role,
    this.authProvider = AuthProvider.local,
    this.googleUid,
    this.googleEmail,
    this.googlePhoto,
    this.fotoProfil,
  });

  bool get isGoogleLinked =>
      authProvider == AuthProvider.google || authProvider == AuthProvider.both;

  bool get isLocalAccount =>
      authProvider == AuthProvider.local || authProvider == AuthProvider.both;

  String get displayPhoto => googlePhoto ?? fotoProfil ?? '';

  String get displayEmail => googleEmail ?? '$username@kasirrestoran.app';

  UserModel copyWith({
    int? idUser,
    String? username,
    String? password,
    String? namaUser,
    UserRole? role,
    AuthProvider? authProvider,
    String? googleUid,
    String? googleEmail,
    String? googlePhoto,
    String? fotoProfil,
  }) {
    return UserModel(
      idUser: idUser ?? this.idUser,
      username: username ?? this.username,
      password: password ?? this.password,
      namaUser: namaUser ?? this.namaUser,
      role: role ?? this.role,
      authProvider: authProvider ?? this.authProvider,
      googleUid: googleUid ?? this.googleUid,
      googleEmail: googleEmail ?? this.googleEmail,
      googlePhoto: googlePhoto ?? this.googlePhoto,
      fotoProfil: fotoProfil ?? this.fotoProfil,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    AuthProvider provider = AuthProvider.local;
    final pStr = (map['auth_provider'] ?? 'local').toString().toLowerCase();
    if (pStr == 'google') {
      provider = AuthProvider.google;
    } else if (pStr == 'both') {
      provider = AuthProvider.both;
    }

    final idLevel = map['id_level'] is int
        ? map['id_level'] as int
        : int.tryParse('${map['id_level']}') ?? 5;

    return UserModel(
      idUser: map['id_user'] is int
          ? map['id_user'] as int
          : int.tryParse('${map['id_user']}') ?? 0,
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      namaUser: map['nama_user'] ?? '',
      role: UserRole.fromId(idLevel),
      authProvider: provider,
      googleUid: map['google_uid'],
      googleEmail: map['google_email'],
      googlePhoto: map['google_photo'],
      fotoProfil: map['foto_profil'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idUser > 0) 'id_user': idUser,
      'username': username,
      'password': password,
      'nama_user': namaUser,
      'id_level': role.id,
      'auth_provider': authProvider.name,
      'google_uid': googleUid,
      'google_email': googleEmail,
      'google_photo': googlePhoto,
      'foto_profil': fotoProfil,
    };
  }
}
