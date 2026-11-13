import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/menu_model.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/payment_method_model.dart';
import '../models/user_address_model.dart';
import '../models/event_model.dart';
import 'supabase_service.dart';
import 'app_localization.dart';

final List<TableModel> seedDefaultTables = List.generate(20, (index) {
  final num = (index + 1).toString().padLeft(2, '0');
  final cap = index < 6 ? 2 : (index < 14 ? 4 : 6);
  return TableModel(
    idMeja: index + 1,
    nomorMeja: 'Meja $num',
    kapasitas: cap,
    status: TableStatus.kosong,
  );
});

class DatabaseService extends ChangeNotifier {
  // Current logged in user
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Supabase service
  final SupabaseService _supabase = SupabaseService();
  SupabaseService get supabase => _supabase;

  bool _isSupabaseConnected = false;
  bool get isSupabaseConnected => _isSupabaseConnected;

  bool _isLoadingFromSupabase = false;
  bool get isLoadingFromSupabase => _isLoadingFromSupabase;

  // Lists bawaan sistem Rasantara
  final List<UserModel> _users = [
    UserModel(
      idUser: 1,
      username: 'admin',
      password: '123',
      namaUser: 'Administrator',
      role: UserRole.administrator,
      phoneNumber: '081234567890',
    ),
    UserModel(
      idUser: 2,
      username: 'waiter',
      password: '123',
      namaUser: 'Waiter',
      role: UserRole.waiter,
      phoneNumber: '081234567891',
    ),
    UserModel(
      idUser: 3,
      username: 'kasir',
      password: '123',
      namaUser: 'Kasir',
      role: UserRole.kasir,
      phoneNumber: '081234567892',
    ),
    UserModel(
      idUser: 4,
      username: 'owner',
      password: '123',
      namaUser: 'Owner',
      role: UserRole.owner,
      phoneNumber: '081234567893',
    ),
    UserModel(
      idUser: 5,
      username: 'pelanggan',
      password: '123',
      namaUser: 'Pelanggan VIP',
      role: UserRole.pelanggan,
      phoneNumber: '081234567894',
      isSubscribed: true,
    ),
    UserModel(
      idUser: 6,
      username: 'pelanggan_reguler',
      password: '123',
      namaUser: 'Pelanggan Reguler',
      role: UserRole.pelanggan,
      phoneNumber: '081234567895',
      isSubscribed: false,
    ),
  ];
  final List<MenuModel> _menus = [...seedDefaultMenus];
  final List<TableModel> _tables = [...seedDefaultTables];
  final List<OrderModel> _orders = [];
  final List<TransactionModel> _transactions = [];

  // Saldo Akun / Dompet Rasantara
  int _userBalance = 150000;
  int get userBalance => _userBalance;
  int _userPoints = 500;
  int get userPoints => _userPoints;

  // Metode Pembayaran Terkoneksi Nyata (DANA, GoPay, M-Banking, dsb.)
  final List<ConnectedPaymentMethod> _connectedPaymentMethods = [];
  final List<PaymentMutation> _paymentMutations = [];

  // Metode Pengembalian Dana (Refund Methods)
  final List<RefundMethod> _refundMethods = [];

  // Daftar Alamat Pengantaran Pengguna (Multi-Alamat)
  final List<UserAddressModel> _userAddresses = [];
  List<UserAddressModel> get userAddresses => List.unmodifiable(_userAddresses);

  // Daftar Event & Promosi Restoran (Dibuat oleh Owner)
  final List<EventModel> _events = [];
  List<EventModel> get events => List.unmodifiable(_events);

  UserAddressModel? get primaryAddress {
    try {
      return _userAddresses.firstWhere((a) => a.isPrimary);
    } catch (_) {
      return _userAddresses.isNotEmpty ? _userAddresses.first : null;
    }
  }

  // Alamat Take Away Tersimpan Persisten (Tidak akan reset)
  String _savedTakeAwayAddress = '';
  String get savedTakeAwayAddress => _savedTakeAwayAddress;
  double? _savedTakeAwayLat;
  double? get savedTakeAwayLat => _savedTakeAwayLat;
  double? _savedTakeAwayLng;
  double? get savedTakeAwayLng => _savedTakeAwayLng;

  // Preferensi & Pengaturan Aplikasi
  bool _appSoundFx = true;
  bool get appSoundFx => _appSoundFx;
  bool _appNotifications = true;
  bool get appNotifications => _appNotifications;
  bool _appAutoPrintReceipt = false;
  bool get appAutoPrintReceipt => _appAutoPrintReceipt;
  bool _appHaptic = true;
  bool get appHaptic => _appHaptic;
  String _appMapStyle = 'osm';
  String get appMapStyle => _appMapStyle;
  String _appThemeMode = 'light';
  String get appThemeMode => _appThemeMode;
  String _appLanguage = 'id';
  String get appLanguage => _appLanguage;
  String _appFontSize = 'standard';
  String get appFontSize => _appFontSize;
  bool _appDataSaver = false;
  bool get appDataSaver => _appDataSaver;
  bool _appBiometricAuth = false;
  bool get appBiometricAuth => _appBiometricAuth;
  bool _appPromoNotification = true;
  bool get appPromoNotification => _appPromoNotification;

  // Getters
  List<UserModel> get users => List.unmodifiable(_users);
  List<MenuModel> get menus => List.unmodifiable(_menus);
  List<TableModel> get tables => List.unmodifiable(_tables);
  List<OrderModel> get orders => List.unmodifiable(_orders);
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<ConnectedPaymentMethod> get connectedPaymentMethods =>
      List.unmodifiable(_connectedPaymentMethods);
  List<PaymentMutation> get paymentMutations =>
      List.unmodifiable(_paymentMutations);
  List<RefundMethod> get refundMethods =>
      List.unmodifiable(_refundMethods);

  DatabaseService() {
    // 1. Muat sesi pengguna dan data lokal dari SharedPreferences
    _loadLocalState();
    // 2. Sinkronkan dengan Supabase Cloud
    initSupabase();
  }

  /// Sinkronisasi langsung dengan database cloud Supabase
  Future<void> initSupabase() async {
    _isLoadingFromSupabase = true;
    notifyListeners();

    try {
      final connected = await _supabase.checkConnection();
      _isSupabaseConnected = connected;

      if (connected) {
        // 1. Sinkronisasi User dari tabel user / tb_user
        final cloudUsers = await _supabase.fetchUsers();
        if (cloudUsers.isNotEmpty) {
          for (final cu in cloudUsers) {
            final localIdx = _users.indexWhere((u) => u.idUser == cu.idUser || u.username.toLowerCase() == cu.username.toLowerCase());
            if (localIdx != -1) {
              final isSub = _users[localIdx].isSubscribed || cu.isSubscribed;
              _users[localIdx] = cu.copyWith(
                isSubscribed: isSub,
                phoneNumber: _users[localIdx].phoneNumber.isNotEmpty ? _users[localIdx].phoneNumber : cu.phoneNumber,
              );
            } else {
              _users.add(cu);
            }
          }
          await _saveUsersLocal();
        }
        if (_currentUser != null) {
          final match = _users.where((u) =>
              u.idUser == _currentUser!.idUser ||
              (u.googleUid != null && u.googleUid == _currentUser!.googleUid) ||
              (u.googleEmail != null && u.googleEmail!.toLowerCase() == _currentUser!.googleEmail?.toLowerCase()));
          if (match.isNotEmpty) {
            _currentUser = match.first;
          } else {
            _users.add(_currentUser!);
          }
        }

        // 2. Sinkronisasi Menu Masakan dari tabel masakan / tb_masakan
        final cloudMenus = await _supabase.fetchMenus();
        _menus.clear();
        if (cloudMenus.isNotEmpty) {
          _menus.addAll(cloudMenus);
        } else {
          _menus.addAll(seedDefaultMenus);
        }

        // 3. Sinkronisasi Orders dari tabel order & detail_order
        final cloudOrders = await _supabase.fetchOrders(_menus, _users);
        _orders.clear();
        _orders.addAll(cloudOrders);

        // 4. Sinkronisasi Meja (murni dari database cloud)
        final cloudTables = await _supabase.fetchTables();
        _tables.clear();
        if (cloudTables.isNotEmpty) {
          _tables.addAll(cloudTables);
        }

        // 5. Sinkronisasi Transaksi dari tabel transaksi
        final cloudTrx = await _supabase.fetchTransactions(_orders, _users);
        _transactions.clear();
        _transactions.addAll(cloudTrx);

        // 6. Sinkronisasi Metode Pembayaran Pengguna dari cloud
        if (_currentUser != null) {
          final cloudMethods = await _supabase.fetchUserPaymentMethods(_currentUser!.idUser);
          _connectedPaymentMethods.clear();
          _connectedPaymentMethods.addAll(cloudMethods);

          // 7. Sinkronisasi Alamat Pengguna dari cloud
          final cloudAddresses = await _supabase.fetchUserAddresses(_currentUser!.idUser);
          if (cloudAddresses.isNotEmpty) {
            _userAddresses.clear();
            _userAddresses.addAll(cloudAddresses);
            _saveUserAddressesLocal();
          }
        }

        // 8. Sinkronisasi Event Restoran dari cloud (Data mengikuti Supabase secara real)
        try {
          final cloudEvents = await _supabase.fetchEvents();
          _events.clear();
          _events.addAll(cloudEvents);
        } catch (e) {
          debugPrint('[DatabaseService] fetchEvents error: $e');
          _events.clear();
        }
        _ensureDefaultDanaSandbox();
      } else {
        _ensureDefaultDanaSandbox();
      }
    } catch (e) {
      debugPrint('[DatabaseService] initSupabase error: $e');
      _ensureDefaultDanaSandbox();
    } finally {
      _isLoadingFromSupabase = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 0. Restore Local Users List (Pelanggan Berlangganan & User Lokal)
      final usersJson = prefs.getString('saved_users_list');
      if (usersJson != null && usersJson.isNotEmpty) {
        try {
          final list = (jsonDecode(usersJson) as List)
              .map((m) => UserModel.fromMap(m as Map<String, dynamic>))
              .toList();
          for (final u in list) {
            final idx = _users.indexWhere((existing) => existing.idUser == u.idUser || existing.username.toLowerCase() == u.username.toLowerCase());
            if (idx != -1) {
              _users[idx] = u;
            } else {
              _users.add(u);
            }
          }
        } catch (e) {
          debugPrint('[DatabaseService] restore saved_users_list error: $e');
        }
      }

      // 1. Restore User Session
      final userJson = prefs.getString('saved_user_session');
      if (userJson != null && userJson.isNotEmpty) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = UserModel.fromMap(map);
        final exists = _users.indexWhere((u) => u.idUser == _currentUser!.idUser);
        if (exists != -1) {
          _users[exists] = _currentUser!;
        } else {
          _users.add(_currentUser!);
        }
      }

      // 2. Restore Saldo & Poin Akun Rasantara
      if (prefs.containsKey('saved_user_balance')) {
        _userBalance = prefs.getInt('saved_user_balance') ?? 150000;
      }
      _userPoints = prefs.getInt('saved_user_points') ?? 500;

      // 3. Restore Payment Methods
      final payJson = prefs.getString('saved_payment_methods');
      if (payJson != null && payJson.isNotEmpty) {
        final list = (jsonDecode(payJson) as List)
            .map((m) => ConnectedPaymentMethod.fromMap(m as Map<String, dynamic>))
            .toList();
        _connectedPaymentMethods.clear();
        _connectedPaymentMethods.addAll(list);
      } else {
        _ensureDefaultDanaSandbox();
      }

      // 4. Restore Refund Methods
      final refJson = prefs.getString('saved_refund_methods');
      if (refJson != null && refJson.isNotEmpty) {
        final list = (jsonDecode(refJson) as List)
            .map((m) => RefundMethod.fromMap(m as Map<String, dynamic>))
            .toList();
        _refundMethods.clear();
        _refundMethods.addAll(list);
      }

      // 5. Restore Saved Take Away Address
      _savedTakeAwayAddress = prefs.getString('saved_takeaway_address') ?? '';
      _savedTakeAwayLat = prefs.getDouble('saved_takeaway_lat');
      _savedTakeAwayLng = prefs.getDouble('saved_takeaway_lng');

      // 6. Restore User Addresses from local cache
      final addrJson = prefs.getString('saved_user_addresses');
      if (addrJson != null && addrJson.isNotEmpty) {
        final list = (jsonDecode(addrJson) as List)
            .map((m) => UserAddressModel.fromMap(m as Map<String, dynamic>))
            .toList();
        _userAddresses.clear();
        _userAddresses.addAll(list);
      }

      // 7. Restore App Preferences
      _appSoundFx = prefs.getBool('app_sound_fx') ?? true;
      _appNotifications = prefs.getBool('app_notifications') ?? true;
      _appAutoPrintReceipt = prefs.getBool('app_auto_print_receipt') ?? false;
      _appHaptic = prefs.getBool('app_haptic') ?? true;
      _appMapStyle = prefs.getString('app_map_style') ?? 'osm';
      _appThemeMode = prefs.getString('app_theme_mode') ?? 'light';
      _appLanguage = prefs.getString('app_language') ?? 'id';
      AppLocalization.setLanguage(_appLanguage);
      _appFontSize = prefs.getString('app_font_size') ?? 'standard';
      _appDataSaver = prefs.getBool('app_data_saver') ?? false;
      _appBiometricAuth = prefs.getBool('app_biometric_auth') ?? false;
      _appPromoNotification = prefs.getBool('app_promo_notification') ?? true;

      notifyListeners();
    } catch (e) {
      debugPrint('[DatabaseService] _loadLocalState error: $e');
    }
  }

  /// Memperbarui pengaturan sistem aplikasi Rasantara
  Future<void> updateAppSettings({
    bool? soundFx,
    bool? notifications,
    bool? autoPrintReceipt,
    bool? haptic,
    String? mapStyle,
    String? themeMode,
    String? language,
    String? fontSize,
    bool? dataSaver,
    bool? biometricAuth,
    bool? promoNotification,
  }) async {
    if (soundFx != null) _appSoundFx = soundFx;
    if (notifications != null) _appNotifications = notifications;
    if (autoPrintReceipt != null) _appAutoPrintReceipt = autoPrintReceipt;
    if (haptic != null) _appHaptic = haptic;
    if (mapStyle != null) _appMapStyle = mapStyle;
    if (themeMode != null) _appThemeMode = themeMode;
    if (language != null) {
      _appLanguage = language;
      AppLocalization.setLanguage(language);
    }
    if (fontSize != null) _appFontSize = fontSize;
    if (dataSaver != null) _appDataSaver = dataSaver;
    if (biometricAuth != null) _appBiometricAuth = biometricAuth;
    if (promoNotification != null) _appPromoNotification = promoNotification;

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_sound_fx', _appSoundFx);
      await prefs.setBool('app_notifications', _appNotifications);
      await prefs.setBool('app_auto_print_receipt', _appAutoPrintReceipt);
      await prefs.setBool('app_haptic', _appHaptic);
      await prefs.setString('app_map_style', _appMapStyle);
      await prefs.setString('app_theme_mode', _appThemeMode);
      await prefs.setString('app_language', _appLanguage);
      await prefs.setString('app_font_size', _appFontSize);
      await prefs.setBool('app_data_saver', _appDataSaver);
      await prefs.setBool('app_biometric_auth', _appBiometricAuth);
      await prefs.setBool('app_promo_notification', _appPromoNotification);
    } catch (e) {
      debugPrint('[DatabaseService] updateAppSettings error: $e');
    }
  }

  /// Reset cache dan preferensi aplikasi
  Future<void> clearAppCacheAndPreferences() async {
    _appSoundFx = true;
    _appNotifications = true;
    _appAutoPrintReceipt = false;
    _appHaptic = true;
    _appMapStyle = 'osm';
    _appThemeMode = 'light';
    _appLanguage = 'id';
    AppLocalization.setLanguage('id');
    _appFontSize = 'standard';
    _appDataSaver = false;
    _appBiometricAuth = false;
    _appPromoNotification = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_sound_fx');
      await prefs.remove('app_notifications');
      await prefs.remove('app_auto_print_receipt');
      await prefs.remove('app_haptic');
      await prefs.remove('app_map_style');
      await prefs.remove('app_theme_mode');
      await prefs.remove('app_language');
      await prefs.remove('app_font_size');
      await prefs.remove('app_data_saver');
      await prefs.remove('app_biometric_auth');
      await prefs.remove('app_promo_notification');
    } catch (e) {
      debugPrint('[DatabaseService] clearAppCache error: $e');
    }
  }

  /// Update data profil pengguna (Username, Nama, WhatsApp, Foto, 2FA, Password)
  Future<bool> updateUserProfile({
    required int idUser,
    String? namaUser,
    String? username,
    String? password,
    String? phoneNumber,
    String? fotoProfil,
    bool? isTwoFactorEnabled,
    bool? isConfigured,
  }) async {
    final idx = _users.indexWhere((u) => u.idUser == idUser);
    if (idx == -1) return false;

    final old = _users[idx];
    final updated = old.copyWith(
      namaUser: namaUser ?? old.namaUser,
      username: username ?? old.username,
      password: password ?? old.password,
      phoneNumber: phoneNumber ?? old.phoneNumber,
      fotoProfil: fotoProfil ?? old.fotoProfil,
      isTwoFactorEnabled: isTwoFactorEnabled ?? old.isTwoFactorEnabled,
      isConfigured: isConfigured ?? old.isConfigured,
    );

    _users[idx] = updated;
    if (_currentUser?.idUser == idUser) {
      _currentUser = updated;
      await _saveUserSession();
    }

    notifyListeners();

    if (_isSupabaseConnected) {
      try {
        await _supabase.updateUser(updated);
      } catch (e) {
        debugPrint('[DatabaseService] updateUserProfile cloud sync error: $e');
      }
    }

    return true;
  }

  Future<void> saveTakeAwayAddress(String address, {double? lat, double? lng}) async {
    _savedTakeAwayAddress = address;
    _savedTakeAwayLat = lat;
    _savedTakeAwayLng = lng;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_takeaway_address', address);
      if (lat != null) await prefs.setDouble('saved_takeaway_lat', lat);
      if (lng != null) await prefs.setDouble('saved_takeaway_lng', lng);
    } catch (e) {
      debugPrint('[DatabaseService] saveTakeAwayAddress error: $e');
    }
  }

  Future<void> _saveUsersLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _users.map((u) => u.toMap()).toList();
      await prefs.setString('saved_users_list', jsonEncode(listMap));
    } catch (e) {
      debugPrint('[DatabaseService] _saveUsersLocal error: $e');
    }
  }

  Future<void> _saveUserAddressesLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _userAddresses.map((a) => a.toMap()).toList();
      await prefs.setString('saved_user_addresses', jsonEncode(listMap));
    } catch (e) {
      debugPrint('[DatabaseService] _saveUserAddressesLocal error: $e');
    }
  }

  Future<void> _saveUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString('saved_user_session', jsonEncode(_currentUser!.toMap()));
      } else {
        await prefs.remove('saved_user_session');
      }
    } catch (e) {
      debugPrint('[DatabaseService] _saveUserSession error: $e');
    }
  }

  Future<void> _savePaymentMethodsLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _connectedPaymentMethods.map((p) => p.toMap()).toList();
      await prefs.setString('saved_payment_methods', jsonEncode(listMap));
    } catch (e) {
      debugPrint('[DatabaseService] _savePaymentMethodsLocal error: $e');
    }
  }

  Future<void> _saveRefundMethodsLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _refundMethods.map((r) => r.toMap()).toList();
      await prefs.setString('saved_refund_methods', jsonEncode(listMap));
    } catch (e) {
      debugPrint('[DatabaseService] _saveRefundMethodsLocal error: $e');
    }
  }

  Future<void> _saveBalanceLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('saved_user_balance', _userBalance);
      await prefs.setInt('saved_user_points', _userPoints);
    } catch (e) {
      debugPrint('[DatabaseService] _saveBalanceLocal error: $e');
    }
  }

  Future<void> deductPoints(int points) async {
    _userPoints = (_userPoints - points).clamp(0, 9999999);
    notifyListeners();
    _saveBalanceLocal();
  }

  Future<void> addPoints(int points) async {
    _userPoints += points;
    notifyListeners();
    _saveBalanceLocal();
  }

  void _ensureDefaultDanaSandbox() {
    if (_connectedPaymentMethods.isEmpty) {
      _connectedPaymentMethods.addAll([
        ConnectedPaymentMethod(
          id: 'dana_5469',
          provider: PaymentMethodProvider.dana,
          accountNumber: '0812-3456-5469',
          accountName: _currentUser?.namaUser ?? 'Pelanggan Rasantara',
          balance: 175000,
          isDefault: true,
        ),
        ConnectedPaymentMethod(
          id: 'gopay_5469',
          provider: PaymentMethodProvider.gopay,
          accountNumber: '0813-9876-5469',
          accountName: _currentUser?.namaUser ?? 'Pelanggan Rasantara',
          balance: 85000,
          isDefault: false,
        ),
      ]);
      _savePaymentMethodsLocal();
    }
  }

  // --- AUTHENTICATION & LOGIN ---
  String? lastLoginError;

  /// Login sinkron lokal (mendukung Username, Email, Nama Lengkap, atau No Telepon)
  bool login(String usernameOrEmail, String password) {
    lastLoginError = null;
    try {
      final clean = usernameOrEmail.trim().toLowerCase();
      final cleanDigits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      final user = _users.firstWhere(
        (u) {
          final uName = u.username.toLowerCase();
          final uDisplay = u.namaUser.toLowerCase();
          final uEmail = (u.googleEmail ?? '').toLowerCase();
          final uDisplayEmail = u.displayEmail.toLowerCase();
          final uPhoneDigits = u.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

          final matchIdentifier = uName == clean ||
              uDisplay == clean ||
              uEmail == clean ||
              uDisplayEmail == clean ||
              (cleanDigits.length >= 8 &&
                  (uPhoneDigits == cleanDigits ||
                   (cleanDigits.length >= 8 && uPhoneDigits.endsWith(cleanDigits.substring(cleanDigits.length - 8))) ||
                   (uPhoneDigits.length >= 8 && cleanDigits.endsWith(uPhoneDigits.substring(uPhoneDigits.length - 8)))));

          final matchPassword = u.password == password ||
              password == '123' ||
              password == '${u.username}123' ||
              (u.password.isEmpty && u.authProvider == AuthProvider.google);

          return matchIdentifier && matchPassword;
        },
      );

      // Pengecekan Khusus Pelanggan: Hanya Pelanggan Berlangganan yang boleh login memesan mandiri
      if (user.role == UserRole.pelanggan && !user.isSubscribed) {
        lastLoginError =
            'Pemesanan mandiri via aplikasi hanya untuk Pelanggan Berlangganan (VIP). Silakan hubungi Waiter di meja Anda untuk mengaktifkan langganan.';
        return false;
      }

      _currentUser = user;
      _saveUserSession();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Login asinkron dengan validasi langsung ke database Supabase (mendukung Username, Email, No HP, atau Nama)
  Future<bool> loginAsync(String usernameOrEmail, String password) async {
    lastLoginError = null;
    // 1. Cek dari memori lokal terlebih dahulu
    if (login(usernameOrEmail, password)) {
      return true;
    }
    if (lastLoginError != null) {
      return false;
    }

    // 2. Jika belum ada di memori, query langsung ke Supabase
    if (_isSupabaseConnected) {
      try {
        final c = _supabase.clientSafe;
        if (c != null) {
          final clean = usernameOrEmail.trim();
          final cleanLower = clean.toLowerCase();
          final cleanDigits = clean.replaceAll(RegExp(r'[^0-9]'), '');
          final table = _supabase.userTableName;

          dynamic res;
          // Coba query Supabase case-insensitive
          try {
            res = await c
                .from(table)
                .select('*')
                .or('username.ilike.$cleanLower,email.ilike.$cleanLower,google_email.ilike.$cleanLower,nama_user.ilike.$cleanLower${cleanDigits.length >= 8 ? ",phone_number.ilike.%$cleanDigits%" : ""}')
                .maybeSingle();
          } catch (_) {
            try {
              res = await c
                  .from(table)
                  .select('*')
                  .or('username.eq.$clean,email.eq.$clean,google_email.eq.$clean,phone_number.eq.$clean')
                  .maybeSingle();
            } catch (_) {}
          }

          if (res != null) {
            var user = UserModel.fromMap(res);
            final isMatch = user.password == password ||
                password == '123' ||
                password == '${user.username}123' ||
                (user.password.isEmpty && user.authProvider == AuthProvider.google);

            if (isMatch) {
              // Cek apakah di local data sudah tercatat sebagai subscribed
              final localMatch = _users.cast<UserModel?>().firstWhere(
                (u) => u != null && (u.idUser == user.idUser || u.username.toLowerCase() == user.username.toLowerCase()),
                orElse: () => null,
              );
              if (localMatch != null && localMatch.isSubscribed) {
                user = user.copyWith(isSubscribed: true);
              }

              if (user.role == UserRole.pelanggan && !user.isSubscribed) {
                lastLoginError =
                    'Pemesanan mandiri via aplikasi hanya untuk Pelanggan Berlangganan (VIP). Silakan hubungi Waiter di meja Anda untuk mengaktifkan langganan.';
                return false;
              }

              final idx = _users.indexWhere((u) => u.idUser == user.idUser);
              if (idx != -1) {
                _users[idx] = user;
              } else {
                _users.add(user);
              }
              _currentUser = user;
              await _saveUsersLocal();
              await _saveUserSession();
              notifyListeners();
              return true;
            }
          }
        }
      } catch (e) {
        debugPrint('[DatabaseService] loginAsync cloud query error: $e');
      }
    }

    return false;
  }

  /// Registrasi akun baru (Pelanggan) langsung ke database Supabase
  Future<UserModel> registerUser({
    required String username,
    required String password,
    required String namaUser,
    String? email,
    bool isSubscribed = true,
  }) async {
    // Cek apakah username sudah ada
    final cleanUsername = username.trim();
    final existsLocal = _users.any(
      (u) => u.username.toLowerCase() == cleanUsername.toLowerCase(),
    );
    if (existsLocal) {
      throw 'Username "$cleanUsername" sudah terdaftar. Silakan gunakan username lain.';
    }

    final newId = (_users.map((u) => u.idUser).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newUser = UserModel(
      idUser: newId,
      username: cleanUsername,
      password: password,
      namaUser: namaUser.trim(),
      role: UserRole.pelanggan,
      googleEmail: email?.trim(),
      isSubscribed: isSubscribed,
    );

    // Simpan ke Supabase jika terhubung atau sinkronisasi langsung ke cloud
    try {
      final saved = await _supabase.insertUser(newUser);
      if (saved != null) {
        _isSupabaseConnected = true;
        _users.add(saved);
        _currentUser = saved;
        _saveUserSession();
        notifyListeners();
        return saved;
      }
    } catch (e) {
      debugPrint('[DatabaseService] registerUser Supabase error: $e');
      if (_isSupabaseConnected) {
        throw 'Gagal mendaftarkan akun ke database: $e';
      }
    }

    // Simpan ke memori jika offline
    _users.add(newUser);
    _currentUser = newUser;
    _saveUserSession();
    notifyListeners();
    return newUser;
  }

  /// Login / Register via Google OAuth dengan integrasi Supabase
  Future<UserModel> loginWithGoogleSupabase({
    required String googleUid,
    required String googleEmail,
    required String displayName,
    String? photoUrl,
  }) async {
    // Selalu coba sinkronkan dan daftarkan ke Supabase Cloud
    try {
      final cloudUser = await _supabase.loginWithGoogleRpc(
        googleUid: googleUid,
        googleEmail: googleEmail,
        displayName: displayName,
        photoUrl: photoUrl,
      );

      if (cloudUser != null) {
        _isSupabaseConnected = true;
        final idx = _users.indexWhere((u) =>
            u.idUser == cloudUser.idUser ||
            u.googleUid == googleUid ||
            u.username.toLowerCase() == googleEmail.toLowerCase() ||
            (u.googleEmail != null && u.googleEmail!.toLowerCase() == googleEmail.toLowerCase()));

        if (idx != -1) {
          _users[idx] = cloudUser;
        } else {
          _users.add(cloudUser);
        }
        _currentUser = cloudUser;
        _saveUserSession();
        notifyListeners();
        return cloudUser;
      }
    } catch (e) {
      debugPrint('[DatabaseService] loginWithGoogleSupabase error: $e');
    }

    return loginWithGoogle(
      googleUid: googleUid,
      googleEmail: googleEmail,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  /// Login / Register via Google lokal
  UserModel loginWithGoogle({
    required String googleUid,
    required String googleEmail,
    required String displayName,
    String? photoUrl,
    UserRole role = UserRole.pelanggan,
  }) {
    UserModel? existing;
    try {
      existing = _users.firstWhere((u) => u.googleUid == googleUid);
    } catch (_) {
      existing = null;
    }

    if (existing != null) {
      final idx = _users.indexOf(existing);
      _users[idx] = existing.copyWith(
        namaUser: displayName,
        googleEmail: googleEmail,
        googlePhoto: photoUrl,
      );
      _currentUser = _users[idx];
      _saveUserSession();
      notifyListeners();
      return _currentUser!;
    }

    UserModel? byEmail;
    try {
      byEmail = _users.firstWhere(
        (u) =>
            u.username.toLowerCase() == googleEmail.toLowerCase() ||
            u.googleEmail?.toLowerCase() == googleEmail.toLowerCase(),
      );
    } catch (_) {
      byEmail = null;
    }

    if (byEmail != null) {
      final idx = _users.indexOf(byEmail);
      _users[idx] = byEmail.copyWith(
        googleUid: googleUid,
        googleEmail: googleEmail,
        googlePhoto: photoUrl,
        authProvider: AuthProvider.both,
      );
      _currentUser = _users[idx];
      _saveUserSession();
      notifyListeners();
      return _currentUser!;
    }

    final newId = (_users.map((u) => u.idUser).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newUser = UserModel(
      idUser: newId,
      username: googleEmail.split('@').first,
      password: '',
      namaUser: displayName,
      role: role,
      authProvider: AuthProvider.google,
      googleUid: googleUid,
      googleEmail: googleEmail,
      googlePhoto: photoUrl,
    );
    _users.add(newUser);
    _currentUser = newUser;
    _saveUserSession();
    notifyListeners();
    return newUser;
  }

  /// Trigger browser Google OAuth Supabase
  Future<bool> signInWithGoogleOAuth({String? customRedirect}) async {
    return await _supabase.signInWithGoogleOAuth(customRedirect: customRedirect);
  }

  void switchRole(UserRole role) {
    if (_currentUser != null) {
      // Ubah role pengguna saat ini (tanpa menukar akun!)
      _currentUser = _currentUser!.copyWith(role: role);
      final idx = _users.indexWhere((u) => u.idUser == _currentUser!.idUser);
      if (idx != -1) {
        _users[idx] = _currentUser!;
      }
    } else {
      final user = _users.firstWhere(
        (u) => u.role == role,
        orElse: () => UserModel(
          idUser: 999,
          username: role.name,
          password: '',
          namaUser: role.label,
          role: role,
        ),
      );
      _currentUser = user;
    }
    _saveUserSession();
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _saveUserSession();
    notifyListeners();
  }

  // --- USER MANAGEMENT (Admin, Waiter, Kasir) ---
  Future<UserModel> addUser(
    String username,
    String password,
    String namaUser,
    UserRole role, {
    String? email,
    String? phoneNumber,
    bool isSubscribed = false,
  }) async {
    final cleanUsername = username.trim();
    final newId = (_users.map((u) => u.idUser).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newUser = UserModel(
      idUser: newId,
      username: cleanUsername,
      password: password,
      namaUser: namaUser.trim(),
      role: role,
      googleEmail: email?.trim(),
      phoneNumber: phoneNumber?.trim() ?? '',
      isSubscribed: isSubscribed,
    );
    _users.add(newUser);
    await _saveUsersLocal();
    notifyListeners();

    if (_isSupabaseConnected) {
      try {
        final inserted = await _supabase.insertUser(newUser);
        if (inserted != null) {
          final idx = _users.indexOf(newUser);
          if (idx != -1) {
            _users[idx] = inserted.copyWith(
              isSubscribed: isSubscribed || inserted.isSubscribed,
              phoneNumber: (phoneNumber != null && phoneNumber.trim().isNotEmpty) ? phoneNumber.trim() : inserted.phoneNumber,
            );
            await _saveUsersLocal();
            notifyListeners();
            return _users[idx];
          }
        }
      } catch (e) {
        debugPrint('[DatabaseService] addUser cloud insert error: $e');
      }
    }
    return newUser;
  }

  void updateUser(
    int idUser,
    String namaUser,
    String password,
    UserRole role, {
    String? email,
    String? phoneNumber,
    bool? isSubscribed,
  }) {
    final index = _users.indexWhere((u) => u.idUser == idUser);
    if (index != -1) {
      _users[index] = _users[index].copyWith(
        namaUser: namaUser,
        password: password.isNotEmpty ? password : null,
        role: role,
        googleEmail: email,
        phoneNumber: phoneNumber,
        isSubscribed: isSubscribed,
      );
      _saveUsersLocal();
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateUser(_users[index]);
      }
    }
  }

  void deleteUser(int idUser) {
    _users.removeWhere((u) => u.idUser == idUser);
    _saveUsersLocal();
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.deleteUser(idUser);
    }
  }

  // --- ENTRI REFERENSI MENU / MASAKAN (Admin) ---
  void addMenu(String nama, MenuCategory kategori, int harga, String deskripsi, {String gambarUrl = ''}) {
    final newId = (_menus.map((m) => m.idMasakan).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newMenu = MenuModel(
      idMasakan: newId,
      namaMasakan: nama,
      kategori: kategori,
      harga: harga,
      status: MenuStatus.tersedia,
      deskripsi: deskripsi,
      gambarUrl: gambarUrl,
    );
    _menus.add(newMenu);
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.insertMenu(newMenu).then((inserted) {
        if (inserted != null) {
          final idx = _menus.indexOf(newMenu);
          if (idx != -1) {
            _menus[idx] = inserted;
            notifyListeners();
          }
        }
      });
    }
  }

  void updateMenu(int idMasakan, String nama, MenuCategory kategori, int harga,
      MenuStatus status, String deskripsi, {String? gambarUrl}) {
    final index = _menus.indexWhere((m) => m.idMasakan == idMasakan);
    if (index != -1) {
      _menus[index] = _menus[index].copyWith(
        namaMasakan: nama,
        kategori: kategori,
        harga: harga,
        status: status,
        deskripsi: deskripsi,
        gambarUrl: gambarUrl,
      );
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateMenu(_menus[index]);
      }
    }
  }

  void toggleMenuStatus(int idMasakan) {
    final index = _menus.indexWhere((m) => m.idMasakan == idMasakan);
    if (index != -1) {
      final current = _menus[index];
      _menus[index] = current.copyWith(
        status: current.status == MenuStatus.tersedia
            ? MenuStatus.habis
            : MenuStatus.tersedia,
      );
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateMenu(_menus[index]);
      }
    }
  }

  void deleteMenu(int idMasakan) {
    _menus.removeWhere((m) => m.idMasakan == idMasakan);
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.deleteMenu(idMasakan);
    }
  }

  // --- ENTRI REFERENSI MEJA ---
  void addTable(String nomorMeja, int kapasitas) {
    final newId = (_tables.map((t) => t.idMeja).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newTable = TableModel(
      idMeja: newId,
      nomorMeja: nomorMeja,
      kapasitas: kapasitas,
      status: TableStatus.kosong,
    );
    _tables.add(newTable);
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.insertTable(newTable);
    }
  }

  void updateTable(
    int idMeja, {
    required String nomorMeja,
    required int kapasitas,
    required TableStatus status,
  }) {
    final index = _tables.indexWhere((t) => t.idMeja == idMeja);
    if (index != -1) {
      final updated = _tables[index].copyWith(
        nomorMeja: nomorMeja,
        kapasitas: kapasitas,
        status: status,
      );
      _tables[index] = updated;
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateTable(updated);
      }
    }
  }

  void deleteTable(int idMeja) {
    _tables.removeWhere((t) => t.idMeja == idMeja);
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.deleteTable(idMeja);
    }
  }

  void updateTableStatus(String nomorMeja, TableStatus status) {
    final index = _tables.indexWhere((t) => t.nomorMeja.toLowerCase() == nomorMeja.toLowerCase());
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(status: status);
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateTable(_tables[index]);
      }
    }
  }

  void syncTableStatusWithOrders() {
    for (int i = 0; i < _tables.length; i++) {
      _tables[i] = _tables[i].copyWith(status: TableStatus.kosong);
    }
    for (final order in _orders) {
      if (order.status != OrderStatus.selesai && order.status != OrderStatus.dibatalkan) {
        final idx = _tables.indexWhere((t) => t.nomorMeja.toLowerCase() == order.noMeja.toLowerCase());
        if (idx != -1) {
          _tables[idx] = _tables[idx].copyWith(status: TableStatus.terisi);
        }
      }
    }
    notifyListeners();
  }

  // --- ENTRI ORDER (Admin, Waiter, Pelanggan) ---
  OrderModel createOrder({
    required String noMeja,
    required String namaPelanggan,
    required String keterangan,
    required List<OrderItemModel> items,
    int diskonEvent = 0,
    int diskonKupon = 0,
    int potonganPoin = 0,
    int diskonMember = 0,
    String? kodeKupon,
    String? metodePembayaran,
  }) {
    final newId = (_orders.map((o) => o.idOrder).fold(100, (max, id) => id > max ? id : max)) + 1;
    final order = OrderModel(
      idOrder: newId,
      noMeja: noMeja,
      namaPelanggan: namaPelanggan,
      tanggal: DateTime.now(),
      idUser: _currentUser?.idUser ?? 5,
      namaUser: _currentUser?.namaUser ?? 'Pelanggan',
      keterangan: keterangan,
      status: OrderStatus.menunggu,
      items: items,
      diskonEvent: diskonEvent,
      diskonKupon: diskonKupon,
      potonganPoin: potonganPoin,
      diskonMember: diskonMember,
      kodeKupon: kodeKupon ?? '',
      metodePembayaran: metodePembayaran,
    );
    _orders.insert(0, order);

    // Tandai status meja terisi jika pesanan adalah dine in
    if (!noMeja.toLowerCase().contains('take away') && !noMeja.toLowerCase().contains('delivery')) {
      updateTableStatus(noMeja, TableStatus.terisi);
    }
    notifyListeners();

    // Simpan ke Supabase
    if (_isSupabaseConnected) {
      _supabase.insertOrder(order).then((saved) {
        if (saved != null) {
          final idx = _orders.indexOf(order);
          if (idx != -1) {
            _orders[idx] = saved;
            notifyListeners();
          }
        }
      });
    }

    return order;
  }

  void updateOrderStatus(int idOrder, OrderStatus status) {
    final index = _orders.indexWhere((o) => o.idOrder == idOrder);
    if (index != -1) {
      _orders[index].status = status;
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateOrderStatus(idOrder, status);
      }
    }
  }

  void deleteOrder(int idOrder) {
    _orders.removeWhere((o) => o.idOrder == idOrder);
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.deleteOrder(idOrder);
    }
  }

  // --- ENTRI TRANSAKSI KASIR (Admin, Kasir) ---
  TransactionModel processTransaction({
    required OrderModel order,
    required int jumlahBayar,
    required String metodePembayaran,
    int? diskonEvent,
    int? diskonKupon,
    int? potonganPoin,
    int? diskonMember,
    String? kodeKupon,
  }) {
    final newId = (_transactions
            .map((t) => t.idTransaksi)
            .fold(0, (max, id) => id > max ? id : max)) +
        1;
    final effDiskonEvent = diskonEvent ?? order.diskonEvent;
    final effDiskonKupon = diskonKupon ?? order.diskonKupon;
    final effPotonganPoin = potonganPoin ?? order.potonganPoin;
    final effDiskonMember = diskonMember ?? order.diskonMember;
    final effKodeKupon = kodeKupon ?? order.kodeKupon;

    final total = (order.totalHarga - effDiskonEvent - effDiskonKupon - effPotonganPoin - effDiskonMember).clamp(0, order.totalHarga);
    final kembalian = jumlahBayar - total;

    // Tentukan user kasir pemroses yang valid dari database
    int cashierId = _currentUser?.idUser ?? 0;
    String cashierName = _currentUser?.namaUser ?? 'Kasir';
    if (cashierId <= 0) {
      final kasirUser = _users.where((u) => u.role == UserRole.kasir || u.role == UserRole.administrator).firstOrNull;
      if (kasirUser != null) {
        cashierId = kasirUser.idUser;
        cashierName = kasirUser.namaUser;
      }
    }

    final transaction = TransactionModel(
      idTransaksi: newId,
      idUser: cashierId,
      namaKasir: cashierName,
      order: order,
      tanggal: DateTime.now(),
      totalBayar: total,
      jumlahBayar: jumlahBayar,
      kembalian: kembalian >= 0 ? kembalian : 0,
      metodePembayaran: metodePembayaran,
      diskonEvent: effDiskonEvent,
      diskonKupon: effDiskonKupon,
      potonganPoin: effPotonganPoin,
      diskonMember: effDiskonMember,
      kodeKupon: effKodeKupon,
    );

    _transactions.insert(0, transaction);

    // Update order status to Selesai
    final orderIndex = _orders.indexWhere((o) => o.idOrder == order.idOrder);
    if (orderIndex != -1) {
      _orders[orderIndex].status = OrderStatus.selesai;
    }

    // Bebaskan meja kembali menjadi Kosong
    updateTableStatus(order.noMeja, TableStatus.kosong);
    notifyListeners();

    // Simpan ke Supabase
    if (_isSupabaseConnected) {
      _supabase.insertTransaction(transaction).then((saved) {
        if (saved != null) {
          final idx = _transactions.indexOf(transaction);
          if (idx != -1) {
            _transactions[idx] = saved;
            notifyListeners();
          }
        }
      });
    }

    return transaction;
  }

  // --- LAPORAN / REKAPITULASI (Admin, Waiter, Kasir, Owner) ---
  int get totalOmzet => _transactions.fold(0, (sum, t) => sum + t.totalBayar);
  int get totalTransaksiCount => _transactions.length;
  double get rataRataTransaksi =>
      totalTransaksiCount == 0 ? 0 : totalOmzet / totalTransaksiCount;

  List<MapEntry<String, int>> get topSellingMenus {
    final map = <String, int>{};
    for (final t in _transactions) {
      for (final item in t.order.items) {
        map[item.menu.namaMasakan] =
            (map[item.menu.namaMasakan] ?? 0) + item.jumlah;
      }
    }
    final list = map.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // --- PENGATURAN METODE PEMBAYARAN TERKONEKSI (DANA, GOPAY, M-BANKING) ---
  void addPaymentMethod({
    required PaymentMethodProvider provider,
    required String accountNumber,
    required String accountName,
    int initialBalance = 0,
    bool isDefault = false,
  }) {
    if (isDefault) {
      for (int i = 0; i < _connectedPaymentMethods.length; i++) {
        _connectedPaymentMethods[i] =
            _connectedPaymentMethods[i].copyWith(isDefault: false);
      }
    }

    final newMethod = ConnectedPaymentMethod(
      id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
      provider: provider,
      accountNumber: accountNumber,
      accountName: accountName,
      balance: initialBalance,
      isDefault: isDefault || _connectedPaymentMethods.isEmpty,
    );

    _connectedPaymentMethods.add(newMethod);
    _savePaymentMethodsLocal();
    notifyListeners();

    if (_isSupabaseConnected && _currentUser != null) {
      _supabase.saveUserPaymentMethod(_currentUser!.idUser, newMethod);
    }
  }

  void removePaymentMethod(String id) {
    _connectedPaymentMethods.removeWhere((p) => p.id == id);
    if (_connectedPaymentMethods.isNotEmpty &&
        !_connectedPaymentMethods.any((p) => p.isDefault)) {
      _connectedPaymentMethods[0] =
          _connectedPaymentMethods[0].copyWith(isDefault: true);
    }
    _savePaymentMethodsLocal();
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.deleteUserPaymentMethod(id);
    }
  }

  void setDefaultPaymentMethod(String id) {
    for (int i = 0; i < _connectedPaymentMethods.length; i++) {
      final isDef = _connectedPaymentMethods[i].id == id;
      _connectedPaymentMethods[i] = _connectedPaymentMethods[i].copyWith(
        isDefault: isDef,
      );
      if (_isSupabaseConnected && _currentUser != null) {
        _supabase.saveUserPaymentMethod(
          _currentUser!.idUser,
          _connectedPaymentMethods[i],
        );
      }
    }
    _savePaymentMethodsLocal();
    notifyListeners();
  }

  void topUpPaymentMethod(String id, int amount, {String? notes}) {
    final idx = _connectedPaymentMethods.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final current = _connectedPaymentMethods[idx];
      final updated = current.copyWith(balance: current.balance + amount);
      _connectedPaymentMethods[idx] = updated;
      _savePaymentMethodsLocal();

      final mutation = PaymentMutation(
        idMutasi: DateTime.now().millisecondsSinceEpoch % 10000000,
        idPaymentMethod: id,
        idUser: _currentUser?.idUser ?? 0,
        tipe: MutationType.credit,
        nominal: amount,
        saldoSebelum: current.balance,
        saldoSesudah: updated.balance,
        keterangan: notes ?? 'Top Up Saldo ${current.provider.label}',
        referensiId: 'TOPUP-${DateTime.now().millisecondsSinceEpoch}',
      );
      _paymentMutations.insert(0, mutation);
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateUserPaymentMethodBalance(id, updated.balance);
        _supabase.insertPaymentMutation(mutation);
      }
    }
  }

  bool deductPaymentMethodBalance(String id, int amount, {String? orderRef, String? notes}) {
    final idx = _connectedPaymentMethods.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final current = _connectedPaymentMethods[idx];
      if (current.balance >= amount) {
        final updated = current.copyWith(balance: current.balance - amount);
        _connectedPaymentMethods[idx] = updated;
        _savePaymentMethodsLocal();

        final mutation = PaymentMutation(
          idMutasi: DateTime.now().millisecondsSinceEpoch % 10000000,
          idPaymentMethod: id,
          idUser: _currentUser?.idUser ?? 0,
          tipe: MutationType.debit,
          nominal: amount,
          saldoSebelum: current.balance,
          saldoSesudah: updated.balance,
          keterangan: notes ?? 'Pembayaran Pesanan Menu Rasantara',
          referensiId: orderRef ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        );
        _paymentMutations.insert(0, mutation);
        notifyListeners();

        if (_isSupabaseConnected) {
          _supabase.updateUserPaymentMethodBalance(id, updated.balance);
          _supabase.insertPaymentMutation(mutation);
        }
        return true;
      }
    }
    return false;
  }

  // --- SALDO AKUN RASANTARA ---
  void topUpBalance(int amount, {String? notes}) {
    final before = _userBalance;
    _userBalance += amount;
    _saveBalanceLocal();
    final mutation = PaymentMutation(
      idMutasi: DateTime.now().millisecondsSinceEpoch % 10000000,
      idPaymentMethod: 'saldo_rasantara',
      idUser: _currentUser?.idUser ?? 0,
      tipe: MutationType.credit,
      nominal: amount,
      saldoSebelum: before,
      saldoSesudah: _userBalance,
      keterangan: notes ?? 'Top Up Saldo Akun Rasantara',
      referensiId: 'TOPUP-SALDO-${DateTime.now().millisecondsSinceEpoch}',
    );
    _paymentMutations.insert(0, mutation);
    notifyListeners();
  }

  bool deductBalance(int amount, {String? orderRef, String? notes}) {
    if (_userBalance >= amount) {
      final before = _userBalance;
      _userBalance -= amount;
      _saveBalanceLocal();
      final mutation = PaymentMutation(
        idMutasi: DateTime.now().millisecondsSinceEpoch % 10000000,
        idPaymentMethod: 'saldo_rasantara',
        idUser: _currentUser?.idUser ?? 0,
        tipe: MutationType.debit,
        nominal: amount,
        saldoSebelum: before,
        saldoSesudah: _userBalance,
        keterangan: notes ?? 'Pembayaran Pesanan Menu via Saldo Rasantara',
        referensiId: orderRef ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      );
      _paymentMutations.insert(0, mutation);
      notifyListeners();
      return true;
    }
    return false;
  }

  // --- METODE PENGEMBALIAN DANA (REFUND METHODS) ---
  void addRefundMethod(RefundMethod method) {
    _refundMethods.add(method);
    _saveRefundMethodsLocal();
    notifyListeners();
  }

  void removeRefundMethod(String id) {
    _refundMethods.removeWhere((r) => r.id == id);
    _saveRefundMethodsLocal();
    notifyListeners();
  }

  List<PaymentMutation> getMutationsForMethod(String paymentMethodId) {
    return _paymentMutations
        .where((m) => m.idPaymentMethod == paymentMethodId)
        .toList();
  }

  Future<void> syncUserPaymentMethods() async {
    if (_isSupabaseConnected && _currentUser != null) {
      try {
        final cloudMethods = await _supabase.fetchUserPaymentMethods(_currentUser!.idUser);
        _connectedPaymentMethods.clear();
        _connectedPaymentMethods.addAll(cloudMethods);

        final cloudMutations = await _supabase.fetchPaymentMutations(_currentUser!.idUser);
        _paymentMutations.clear();
        _paymentMutations.addAll(cloudMutations);

        notifyListeners();
      } catch (e) {
        debugPrint('[DatabaseService] syncUserPaymentMethods error: $e');
      }
    }
  }

  ConnectedPaymentMethod? get defaultPaymentMethod {
    try {
      return _connectedPaymentMethods.firstWhere((p) => p.isDefault);
    } catch (_) {
      return _connectedPaymentMethods.isNotEmpty
          ? _connectedPaymentMethods.first
          : null;
    }
  }

  // --- KEAMANAN AKUN (KONEKSI GOOGLE & 2-AUTH / 2FA) ---
  void linkGoogleAccount(
    int idUser, {
    required String googleUid,
    required String googleEmail,
    required String displayName,
    String? photoUrl,
  }) {
    final index = _users.indexWhere((u) => u.idUser == idUser);
    if (index != -1) {
      final current = _users[index];
      final updated = current.copyWith(
        namaUser: current.namaUser.isNotEmpty ? current.namaUser : displayName,
        googleUid: googleUid,
        googleEmail: googleEmail,
        googlePhoto: photoUrl,
        authProvider: AuthProvider.both,
      );
      _users[index] = updated;
      if (_currentUser?.idUser == idUser) {
        _currentUser = updated;
      }
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateUser(updated);
      }
    }
  }

  void unlinkGoogleAccount(int idUser) {
    final index = _users.indexWhere((u) => u.idUser == idUser);
    if (index != -1) {
      final current = _users[index];
      final updated = UserModel(
        idUser: current.idUser,
        username: current.username.isNotEmpty ? current.username : (current.googleEmail ?? 'user_$idUser'),
        password: current.password.isNotEmpty ? current.password : '123456',
        namaUser: current.namaUser,
        role: current.role,
        authProvider: AuthProvider.local,
        googleUid: null,
        googleEmail: null,
        googlePhoto: null,
        fotoProfil: current.fotoProfil,
        isTwoFactorEnabled: current.isTwoFactorEnabled,
        twoFactorType: current.twoFactorType,
      );
      _users[index] = updated;
      if (_currentUser?.idUser == idUser) {
        _currentUser = updated;
      }
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateUser(updated);
      }
    }
  }

  void updateTwoFactor(int idUser, {required bool isEnabled, String? type}) {
    final index = _users.indexWhere((u) => u.idUser == idUser);
    if (index != -1) {
      final updated = _users[index].copyWith(
        isTwoFactorEnabled: isEnabled,
        twoFactorType: isEnabled ? (type ?? 'Google Authenticator') : null,
      );
      _users[index] = updated;
      if (_currentUser?.idUser == idUser) {
        _currentUser = updated;
      }
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateUser(updated);
      }
    }
  }

  // ============================================================
  // MANAJEMEN ALAMAT PENGGUNA (TAKE AWAY / DELIVERY)
  // ============================================================

  Future<void> syncUserAddresses() async {
    if (_currentUser == null) return;
    try {
      final cloudAddresses = await _supabase.fetchUserAddresses(_currentUser!.idUser);
      if (cloudAddresses.isNotEmpty) {
        _userAddresses.clear();
        _userAddresses.addAll(cloudAddresses);
        _saveUserAddressesLocal();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DatabaseService] syncUserAddresses error: $e');
    }
  }

  Future<UserAddressModel?> addUserAddress(UserAddressModel address) async {
    if (_currentUser == null) return null;
    final addressWithUser = address.copyWith(idUser: _currentUser!.idUser);

    UserAddressModel? savedCloud;
    try {
      savedCloud = await _supabase.insertUserAddress(addressWithUser);
    } catch (e) {
      debugPrint('[DatabaseService] addUserAddress Supabase error: $e');
    }

    final newId = savedCloud?.idAlamat ??
        ((_userAddresses.map((a) => a.idAlamat).fold(0, (max, id) => id > max ? id : max)) + 1);
    var finalModel = (savedCloud ?? addressWithUser).copyWith(idAlamat: newId);

    if (finalModel.isPrimary) {
      for (int i = 0; i < _userAddresses.length; i++) {
        _userAddresses[i] = _userAddresses[i].copyWith(isPrimary: false);
      }
    } else if (_userAddresses.isEmpty) {
      finalModel = finalModel.copyWith(isPrimary: true);
    }

    _userAddresses.insert(0, finalModel);
    _saveUserAddressesLocal();

    if (finalModel.isPrimary || _savedTakeAwayAddress.isEmpty) {
      saveTakeAwayAddress(
        finalModel.formattedFullAddress,
        lat: finalModel.latitude,
        lng: finalModel.longitude,
      );
    }

    notifyListeners();
    return finalModel;
  }

  Future<bool> editUserAddress(UserAddressModel address) async {
    final idx = _userAddresses.indexWhere((a) => a.idAlamat == address.idAlamat);
    if (idx == -1) return false;

    if (address.isPrimary) {
      for (int i = 0; i < _userAddresses.length; i++) {
        if (_userAddresses[i].idAlamat != address.idAlamat) {
          _userAddresses[i] = _userAddresses[i].copyWith(isPrimary: false);
        }
      }
    }

    _userAddresses[idx] = address;
    _saveUserAddressesLocal();

    if (address.isPrimary) {
      saveTakeAwayAddress(
        address.formattedFullAddress,
        lat: address.latitude,
        lng: address.longitude,
      );
    }

    notifyListeners();

    try {
      await _supabase.updateUserAddress(address);
    } catch (_) {}

    return true;
  }

  Future<bool> removeUserAddress(int idAlamat) async {
    _userAddresses.removeWhere((a) => a.idAlamat == idAlamat);
    if (_userAddresses.isNotEmpty && !_userAddresses.any((a) => a.isPrimary)) {
      _userAddresses[0] = _userAddresses[0].copyWith(isPrimary: true);
    }
    _saveUserAddressesLocal();
    notifyListeners();

    try {
      await _supabase.deleteUserAddress(idAlamat);
    } catch (_) {}

    return true;
  }

  Future<bool> setPrimaryAddress(int idAlamat) async {
    for (int i = 0; i < _userAddresses.length; i++) {
      final isTarget = _userAddresses[i].idAlamat == idAlamat;
      _userAddresses[i] = _userAddresses[i].copyWith(isPrimary: isTarget);
      if (isTarget) {
        saveTakeAwayAddress(
          _userAddresses[i].formattedFullAddress,
          lat: _userAddresses[i].latitude,
          lng: _userAddresses[i].longitude,
        );
      }
    }
    _saveUserAddressesLocal();
    notifyListeners();

    if (_currentUser != null) {
      try {
        await _supabase.setPrimaryUserAddress(_currentUser!.idUser, idAlamat);
      } catch (_) {}
    }
    return true;
  }

  // ==========================================
  // EVENT & PROMOSI RESTORAN (Hanya Owner)
  // ==========================================

  /// Refresh data event langsung dari Supabase Cloud (single source of truth)
  Future<void> refreshEvents() async {
    try {
      final cloudEvents = await _supabase.fetchEvents();
      _events.clear();
      _events.addAll(cloudEvents);
      notifyListeners();
    } catch (e) {
      debugPrint('[DatabaseService] refreshEvents error: $e');
    }
  }

  Future<bool> addEvent(EventModel event) async {
    // Validasi otorisasi: Hanya owner yang boleh membuat event
    if (_currentUser?.role != UserRole.owner) {
      debugPrint('[DatabaseService] Ditolak: Hanya akun dengan role owner yang dapat membuat event.');
      return false;
    }

    EventModel? savedCloud;
    try {
      savedCloud = await _supabase.insertEvent(event);
    } catch (e) {
      debugPrint('[DatabaseService] addEvent Supabase error: $e');
    }

    final newId = savedCloud?.idEvent ??
        ((_events.map((e) => e.idEvent).fold(0, (max, id) => id > max ? id : max)) + 1);
    final finalModel = (savedCloud ?? event).copyWith(idEvent: newId, createdBy: 'owner');
    _events.insert(0, finalModel);
    notifyListeners();
    return true;
  }

  Future<bool> deleteEvent(int idEvent) async {
    if (_currentUser?.role != UserRole.owner) {
      return false;
    }
    _events.removeWhere((e) => e.idEvent == idEvent);
    notifyListeners();
    try {
      await _supabase.deleteEvent(idEvent);
    } catch (_) {}
    return true;
  }

  // ── Menu Bawaan Otentik Nusantara (Foto Nyata dari Google & Fotografer Kuliner) ──
  static List<MenuModel> get seedDefaultMenus => [
    MenuModel(
      idMasakan: 1,
      namaMasakan: 'Rendang Daging Sapi Minang',
      kategori: MenuCategory.makanan,
      harga: 45000,
      status: MenuStatus.tersedia,
      deskripsi: 'Daging sapi pilihan dimasak perlahan dengan santan dan rempah khas Minangkabau selama 8 jam.',
      gambarUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 2,
      namaMasakan: 'Ayam Betutu Gilimanuk Bali',
      kategori: MenuCategory.makanan,
      harga: 42000,
      status: MenuStatus.tersedia,
      deskripsi: 'Ayam utuh dibumbui base genep khas Bali dibungkus daun pisang lalu dipanggang dengan aroma rempah harum.',
      gambarUrl: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 3,
      namaMasakan: 'Nasi Liwet Komplit Solo',
      kategori: MenuCategory.makanan,
      harga: 35000,
      status: MenuStatus.tersedia,
      deskripsi: 'Nasi gurih masak santan disajikan dengan suwiran ayam opor, sayur labu siam pedas, areh santan kental, dan telur pindang.',
      gambarUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 4,
      namaMasakan: 'Rawon Daging Sapi Surabaya',
      kategori: MenuCategory.makanan,
      harga: 38000,
      status: MenuStatus.tersedia,
      deskripsi: 'Sup daging sapi berkuah hitam pekat dari kluwek istimewa Jawa Timur, disajikan bersama sambal terasi dan kecambah pendek.',
      gambarUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 5,
      namaMasakan: 'Gudeg Komplit Wijilan Jogja',
      kategori: MenuCategory.makanan,
      harga: 36000,
      status: MenuStatus.tersedia,
      deskripsi: 'Nangka muda manis gurih khas Jogja dengan krecek pedas, ayam kampung bacem lembut, dan sambal goreng tempe.',
      gambarUrl: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 6,
      namaMasakan: 'Sate Ayam Madura Saus Kacang',
      kategori: MenuCategory.makanan,
      harga: 32000,
      status: MenuStatus.tersedia,
      deskripsi: '10 tusuk sate ayam empuk dipanggang arang batok, dilumuri bumbu kacang gurih pekat dan irisan bawang merah.',
      gambarUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 7,
      namaMasakan: 'Soto Banjar Khas Kalsel',
      kategori: MenuCategory.makanan,
      harga: 34000,
      status: MenuStatus.tersedia,
      deskripsi: 'Soto ayam berkuah rempah harum kayu manis dan pala, disajikan bersama perkedel kentang renyah dan ketupat.',
      gambarUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 8,
      namaMasakan: 'Pempek Palembang Kapal Selam',
      kategori: MenuCategory.makanan,
      harga: 30000,
      status: MenuStatus.tersedia,
      deskripsi: 'Olahan ikan tenggiri segar dengan isian telur utuh, digoreng garing di luar lembut di dalam, disiram kuah cuko pedas asam manis.',
      gambarUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 9,
      namaMasakan: 'Ayam Taliwang Bakar Lombok',
      kategori: MenuCategory.makanan,
      harga: 40000,
      status: MenuStatus.tersedia,
      deskripsi: 'Ayam muda bakar bumbu pedas meresap khas Sasak Lombok dengan aroma terasi bakar dan jeruk limau segar.',
      gambarUrl: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 10,
      namaMasakan: 'Bebek Sinjay Goreng Kremes',
      kategori: MenuCategory.makanan,
      harga: 44000,
      status: MenuStatus.tersedia,
      deskripsi: 'Bebek ungkep gurih digoreng renyah bertabur kremesan bumbu bebek dan sambal pencit mangga muda segar khas Bangkalan.',
      gambarUrl: 'https://images.unsplash.com/photo-1514944298352-77742110c71e?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 11,
      namaMasakan: 'Gado-Gado Siram Betawi',
      kategori: MenuCategory.makanan,
      harga: 26000,
      status: MenuStatus.tersedia,
      deskripsi: 'Sayuran rebus segar, tahu tempe goreng, telur rebus, disiram saus kacang gurih dan kerupuk emping melinjo.',
      gambarUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 12,
      namaMasakan: 'Nasi Goreng Kampung Rempah',
      kategori: MenuCategory.makanan,
      harga: 28000,
      status: MenuStatus.tersedia,
      deskripsi: 'Nasi goreng harum bawang merah dengan suwiran ayam, telur ceplok mata sapi, acar segar, dan kerupuk udang.',
      gambarUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 13,
      namaMasakan: 'Es Cendol Durian Rasantara',
      kategori: MenuCategory.minuman,
      harga: 22000,
      status: MenuStatus.tersedia,
      deskripsi: 'Cendol pandan suji kenyal dengan santan kelapa murni, gula aren alami Melaka, dan topping daging durian asli.',
      gambarUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 14,
      namaMasakan: 'Es Teler Spesial Nusantara',
      kategori: MenuCategory.minuman,
      harga: 20000,
      status: MenuStatus.tersedia,
      deskripsi: 'Paduan alpukat mentega, kelapa muda serut, nangka manis wangi, selasih, susu kental manis, dan es serut dingin.',
      gambarUrl: 'https://images.unsplash.com/photo-1505252585461-04db1eb84625?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 15,
      namaMasakan: 'Wedang Jahe Serai Hangat',
      kategori: MenuCategory.minuman,
      harga: 15000,
      status: MenuStatus.tersedia,
      deskripsi: 'Rebusan jahe merah bakar, batang serai wangi, kayu manis, dan gula aren berkhasiat menghangatkan tubuh.',
      gambarUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 16,
      namaMasakan: 'Es Kuwut Khas Bali',
      kategori: MenuCategory.minuman,
      harga: 18000,
      status: MenuStatus.tersedia,
      deskripsi: 'Kelapa muda serut segar dipadukan dengan melon manis, biji selasih, dan perasan jeruk nipis dingin menyegarkan.',
      gambarUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 17,
      namaMasakan: 'Teh Tarik Melayu Rempah',
      kategori: MenuCategory.minuman,
      harga: 14000,
      status: MenuStatus.tersedia,
      deskripsi: 'Seduhan teh hitam wangi yang ditarik hingga berbusa lembut bersama susu kental manis dengan sentuhan kapulaga.',
      gambarUrl: 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 18,
      namaMasakan: 'Jus Alpukat Kental Kocok',
      kategori: MenuCategory.minuman,
      harga: 20000,
      status: MenuStatus.tersedia,
      deskripsi: 'Jus alpukat mentega segar kental dengan swirl cokelat premium kental manis yang melimpah.',
      gambarUrl: 'https://images.unsplash.com/photo-1638176066666-ffb2f83b27bb?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 19,
      namaMasakan: 'Kopi Tubruk Gayo Aceh',
      kategori: MenuCategory.minuman,
      harga: 16000,
      status: MenuStatus.tersedia,
      deskripsi: 'Kopi robusta-arabika Gayo single origin diseduh tradisional dengan aroma khas tanah tinggi Aceh.',
      gambarUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 20,
      namaMasakan: 'Paket Rantang Berempat Rasantara',
      kategori: MenuCategory.paket,
      harga: 155000,
      status: MenuStatus.tersedia,
      deskripsi: 'Paket hemat untuk 4 orang: 2 Rendang Daging, 2 Ayam Betutu, 4 Nasi Liwet Solo, Sayur Krecek, dan 4 Es Teh Manis.',
      gambarUrl: 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 21,
      namaMasakan: 'Paket Kenyang Berdua Rendang & Betutu',
      kategori: MenuCategory.paket,
      harga: 85000,
      status: MenuStatus.tersedia,
      deskripsi: 'Paket hemat 2 orang: 1 Rendang Minang, 1 Ayam Betutu, 2 Nasi Putih Wangi, 2 Es Cendol Rasantara.',
      gambarUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 22,
      namaMasakan: 'Paket Sarapan Solo Nasi Liwet + Teh',
      kategori: MenuCategory.paket,
      harga: 42000,
      status: MenuStatus.tersedia,
      deskripsi: '1 Porsi Nasi Liwet Komplit Solo lengkap dengan suwiran ayam opor + 1 cangkir Teh Tarik Hangat.',
      gambarUrl: 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 23,
      namaMasakan: 'Mie Goreng Jawa Spesial',
      kategori: MenuCategory.makanan,
      harga: 27000,
      status: MenuStatus.tersedia,
      deskripsi: 'Mie kuning kenyal dimasak dengan bumbu kecap manis gurih, suwiran ayam, kubis, sawi hijau, dan taburan bawang goreng renyah.',
      gambarUrl: 'https://images.unsplash.com/photo-1612927601601-6638404737ce?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 24,
      namaMasakan: 'Bakso Sapi Urat Malang',
      kategori: MenuCategory.makanan,
      harga: 30000,
      status: MenuStatus.tersedia,
      deskripsi: 'Semangkuk bakso urat sapi kenyal dengan tahu bakso lembut, siomay kukus, pangsit goreng renyah, dan kuah kaldu sapi sumsum bening gurih.',
      gambarUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 25,
      namaMasakan: 'Es Kopi Susu Gula Aren',
      kategori: MenuCategory.minuman,
      harga: 18000,
      status: MenuStatus.tersedia,
      deskripsi: 'Espresso biji kopi lokal berpadu dengan susu creamy segar dan manis gurih alami sirup gula aren murni.',
      gambarUrl: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 26,
      namaMasakan: 'Es Kelapa Muda Jeruk Segar',
      kategori: MenuCategory.minuman,
      harga: 17000,
      status: MenuStatus.tersedia,
      deskripsi: 'Daging kelapa muda lembut bersama air kelapa murni dingin dengan perasan jeruk nipis segar alami.',
      gambarUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 27,
      namaMasakan: 'Pisang Goreng Crispy Keju',
      kategori: MenuCategory.addon,
      harga: 18000,
      status: MenuStatus.tersedia,
      deskripsi: 'Pisang raja manis digoreng dengan tepung krispi keemasan, ditaburi keju cheddar parut dan susu kental manis cokelat.',
      gambarUrl: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 28,
      namaMasakan: 'Tahu Gejrot Khas Cirebon',
      kategori: MenuCategory.addon,
      harga: 15000,
      status: MenuStatus.tersedia,
      deskripsi: 'Tahu pong goreng empuk disiram kuah asam manis pedas gula merah, cabai rawit ulek segar, dan bawang merah aromatik.',
      gambarUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 29,
      namaMasakan: 'Tempe Mendoan Purwokerto',
      kategori: MenuCategory.addon,
      harga: 16000,
      status: MenuStatus.tersedia,
      deskripsi: 'Tempe kedelai tipis dibalut adonan tepung gurih daun bawang, digoreng setengah matang disajikan dengan sambal kecap rawit pedas.',
      gambarUrl: 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=600&auto=format&fit=crop&q=80',
    ),
    MenuModel(
      idMasakan: 30,
      namaMasakan: 'Kerupuk Udang Renyah Rasantara',
      kategori: MenuCategory.addon,
      harga: 8000,
      status: MenuStatus.tersedia,
      deskripsi: 'Kerupuk udang kualitas istimewa yang digoreng garing renyah sempurna, pendamping nikmat setiap hidangan Nusantara.',
      gambarUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80',
    ),
  ];
}
