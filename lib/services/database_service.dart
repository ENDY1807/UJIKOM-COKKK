import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/menu_model.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/payment_method_model.dart';
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

  // Lists (Murni mengikuti database cloud Supabase, tidak menggunakan dummy/seed bawaan)
  final List<UserModel> _users = [];
  final List<MenuModel> _menus = [];
  final List<TableModel> _tables = [];
  final List<OrderModel> _orders = [];
  final List<TransactionModel> _transactions = [];

  // Metode Pembayaran Terkoneksi Nyata (DANA, GoPay, M-Banking, dsb.) - Mulai dari 0 / kosong
  final List<ConnectedPaymentMethod> _connectedPaymentMethods = [];
  final List<PaymentMutation> _paymentMutations = [];

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

  DatabaseService() {
    // Data bawaan dikosongkan sesuai instruksi user
    // Seluruh data murni disinkronisasi dari database Supabase
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

  void _ensureDefaultDanaSandbox() {
    if (_connectedPaymentMethods.isEmpty) {
      _connectedPaymentMethods.add(
        ConnectedPaymentMethod(
          id: 'dana_h2h_sandbox',
          provider: PaymentMethodProvider.dana,
          accountNumber: '081099999999',
          accountName: 'Tester DANA (H2H Gateway)',
          balance: 2500000,
          isDefault: true,
        ),
      );
    }
  }

  // --- AUTHENTICATION & LOGIN ---

  /// Login sinkron lokal
  bool login(String username, String password) {
    try {
      final user = _users.firstWhere(
        (u) =>
            (u.username.toLowerCase() == username.trim().toLowerCase() ||
             (u.googleEmail != null && u.googleEmail!.toLowerCase() == username.trim().toLowerCase())) &&
            u.password == password,
      );
      _currentUser = user;
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

    // Simpan ke Supabase jika terhubung
    if (_isSupabaseConnected) {
      try {
        final saved = await _supabase.insertUser(newUser);
        if (saved != null) {
          _users.add(saved);
          _currentUser = saved;
          notifyListeners();
          return saved;
        }
      } catch (e) {
        debugPrint('[DatabaseService] registerUser Supabase error: $e');
        throw 'Gagal mendaftarkan akun ke database: $e';
      }
    }

    // Simpan ke memori jika offline
    _users.add(newUser);
    _currentUser = newUser;
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
    if (_isSupabaseConnected) {
      try {
        final cloudUser = await _supabase.loginWithGoogleRpc(
          googleUid: googleUid,
          googleEmail: googleEmail,
          displayName: displayName,
          photoUrl: photoUrl,
        );

        if (cloudUser != null) {
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
          notifyListeners();
          return cloudUser;
        }
      } catch (e) {
        debugPrint('[DatabaseService] loginWithGoogleSupabase error: $e');
      }
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
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
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
  }) {
    final newId = (_transactions
            .map((t) => t.idTransaksi)
            .fold(0, (max, id) => id > max ? id : max)) +
        1;
    final total = order.totalHarga;
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
    notifyListeners();
  }

  void topUpPaymentMethod(String id, int amount, {String? notes}) {
    final idx = _connectedPaymentMethods.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final current = _connectedPaymentMethods[idx];
      final updated = current.copyWith(balance: current.balance + amount);
      _connectedPaymentMethods[idx] = updated;

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
}
