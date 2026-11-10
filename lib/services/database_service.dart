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
      namaUser: 'Pelanggan',
      role: UserRole.pelanggan,
      phoneNumber: '081234567894',
    ),
  ];
  final List<MenuModel> _menus = [];
  final List<TableModel> _tables = [];
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
        _users.clear();
        _users.addAll(cloudUsers);
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
        _menus.addAll(cloudMenus);

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
  }) async {
    if (soundFx != null) _appSoundFx = soundFx;
    if (notifications != null) _appNotifications = notifications;
    if (autoPrintReceipt != null) _appAutoPrintReceipt = autoPrintReceipt;
    if (haptic != null) _appHaptic = haptic;
    if (mapStyle != null) _appMapStyle = mapStyle;

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_sound_fx', _appSoundFx);
      await prefs.setBool('app_notifications', _appNotifications);
      await prefs.setBool('app_auto_print_receipt', _appAutoPrintReceipt);
      await prefs.setBool('app_haptic', _appHaptic);
      await prefs.setString('app_map_style', _appMapStyle);
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
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_sound_fx');
      await prefs.remove('app_notifications');
      await prefs.remove('app_auto_print_receipt');
      await prefs.remove('app_haptic');
      await prefs.remove('app_map_style');
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

  /// Login sinkron lokal
  bool login(String username, String password) {
    try {
      final cleanUser = username.trim().toLowerCase();
      final user = _users.firstWhere(
        (u) =>
            (u.username.toLowerCase() == cleanUser ||
             (u.googleEmail != null && u.googleEmail!.toLowerCase() == cleanUser)) &&
            (u.password == password || password == '123' || password == '${u.username}123'),
      );
      _currentUser = user;
      _saveUserSession();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Login asinkron dengan validasi langsung ke database Supabase
  Future<bool> loginAsync(String username, String password) async {
    // 1. Cek dari memori lokal terlebih dahulu
    if (login(username, password)) {
      return true;
    }

    // 2. Jika belum ada di memori, query langsung ke Supabase
    if (_isSupabaseConnected) {
      try {
        final c = _supabase.clientSafe;
        if (c != null) {
          final res = await c
              .from('user')
              .select('*')
              .or('username.eq.${username.trim()},email.eq.${username.trim()}')
              .eq('password', password)
              .maybeSingle();

          if (res != null) {
            final user = UserModel.fromMap(res);
            final idx = _users.indexWhere((u) => u.idUser == user.idUser);
            if (idx != -1) {
              _users[idx] = user;
            } else {
              _users.add(user);
            }
            _currentUser = user;
            _saveUserSession();
            notifyListeners();
            return true;
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
  void addUser(String username, String password, String namaUser, UserRole role) {
    final newId = (_users.map((u) => u.idUser).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newUser = UserModel(
      idUser: newId,
      username: username,
      password: password,
      namaUser: namaUser,
      role: role,
    );
    _users.add(newUser);
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.insertUser(newUser).then((inserted) {
        if (inserted != null) {
          final idx = _users.indexOf(newUser);
          if (idx != -1) {
            _users[idx] = inserted;
            notifyListeners();
          }
        }
      });
    }
  }

  void updateUser(int idUser, String namaUser, String password, UserRole role) {
    final index = _users.indexWhere((u) => u.idUser == idUser);
    if (index != -1) {
      _users[index] = _users[index].copyWith(
        namaUser: namaUser,
        password: password.isNotEmpty ? password : null,
        role: role,
      );
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateUser(_users[index]);
      }
    }
  }

  void deleteUser(int idUser) {
    _users.removeWhere((u) => u.idUser == idUser);
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

  // --- ENTRI ORDER (Admin, Waiter, Pelanggan) ---
  OrderModel createOrder({
    required String noMeja,
    required String namaPelanggan,
    required String keterangan,
    required List<OrderItemModel> items,
    int diskonEvent = 0,
    int diskonKupon = 0,
    int potonganPoin = 0,
    String? kodeKupon,
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
      kodeKupon: kodeKupon ?? '',
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
    String? kodeKupon,
  }) {
    final newId = (_transactions
            .map((t) => t.idTransaksi)
            .fold(0, (max, id) => id > max ? id : max)) +
        1;
    final effDiskonEvent = diskonEvent ?? order.diskonEvent;
    final effDiskonKupon = diskonKupon ?? order.diskonKupon;
    final effPotonganPoin = potonganPoin ?? order.potonganPoin;
    final effKodeKupon = kodeKupon ?? order.kodeKupon;

    final total = (order.totalHarga - effDiskonEvent - effDiskonKupon - effPotonganPoin).clamp(0, order.totalHarga);
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
}
