import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/menu_model.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
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

  // Lists
  final List<UserModel> _users = [];
  final List<MenuModel> _menus = [];
  final List<TableModel> _tables = [];
  final List<OrderModel> _orders = [];
  final List<TransactionModel> _transactions = [];

  // Getters
  List<UserModel> get users => List.unmodifiable(_users);
  List<MenuModel> get menus => List.unmodifiable(_menus);
  List<TableModel> get tables => List.unmodifiable(_tables);
  List<OrderModel> get orders => List.unmodifiable(_orders);
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  DatabaseService() {
    // 1. Seed fallback data agar UI tidak kosong saat offline / initial frame
    _seedData();
    // Default login as admin for instant preview/testing
    login('admin', 'admin123');

    // 2. Inisialisasi sinkronisasi live data dari Supabase
    initSupabase();
  }

  /// Sinkronisasi dengan database cloud Supabase
  Future<void> initSupabase() async {
    _isLoadingFromSupabase = true;
    notifyListeners();

    try {
      final connected = await _supabase.checkConnection();
      _isSupabaseConnected = connected;

      if (connected) {
        // 1. Sinkronisasi User dari tb_user
        final cloudUsers = await _supabase.fetchUsers();
        if (cloudUsers.isNotEmpty) {
          _users.clear();
          _users.addAll(cloudUsers);
          if (_currentUser != null) {
            final match = _users.where((u) => u.idUser == _currentUser!.idUser);
            if (match.isNotEmpty) {
              _currentUser = match.first;
            }
          }
        }

        // 2. Sinkronisasi Menu dari tb_masakan
        final cloudMenus = await _supabase.fetchMenus();
        if (cloudMenus.isNotEmpty) {
          _menus.clear();
          _menus.addAll(cloudMenus);
        }

        // 3. Sinkronisasi Meja dari tb_meja
        final cloudTables = await _supabase.fetchTables();
        if (cloudTables.isNotEmpty) {
          _tables.clear();
          _tables.addAll(cloudTables);
        }

        // 4. Sinkronisasi Orders dari tb_order & tb_detail_order
        final cloudOrders = await _supabase.fetchOrders(_menus, _users);
        if (cloudOrders.isNotEmpty) {
          _orders.clear();
          _orders.addAll(cloudOrders);
        }

        // 5. Sinkronisasi Transaksi dari tb_transaksi
        final cloudTrx = await _supabase.fetchTransactions(_orders, _users);
        if (cloudTrx.isNotEmpty) {
          _transactions.clear();
          _transactions.addAll(cloudTrx);
        }
      }
    } catch (e) {
      debugPrint('[DatabaseService] initSupabase error: $e');
    } finally {
      _isLoadingFromSupabase = false;
      notifyListeners();
    }
  }

  void _seedData() {
    // 1. Seed Users
    _users.addAll([
      UserModel(
        idUser: 1,
        username: 'admin',
        password: 'admin123',
        namaUser: 'Ahmad Administrator',
        role: UserRole.administrator,
      ),
      UserModel(
        idUser: 2,
        username: 'waiter',
        password: 'waiter123',
        namaUser: 'Budi Waiter',
        role: UserRole.waiter,
      ),
      UserModel(
        idUser: 3,
        username: 'kasir',
        password: 'kasir123',
        namaUser: 'Citra Kasir',
        role: UserRole.kasir,
      ),
      UserModel(
        idUser: 4,
        username: 'owner',
        password: 'owner123',
        namaUser: 'Dedi Pemilik',
        role: UserRole.owner,
      ),
      UserModel(
        idUser: 5,
        username: 'pelanggan',
        password: 'pelanggan123',
        namaUser: 'Eka Pelanggan',
        role: UserRole.pelanggan,
      ),
    ]);

    // 2. Seed Tables
    _tables.addAll([
      TableModel(idMeja: 1, nomorMeja: 'Meja 01', kapasitas: 2, status: TableStatus.terisi),
      TableModel(idMeja: 2, nomorMeja: 'Meja 02', kapasitas: 4, status: TableStatus.terisi),
      TableModel(idMeja: 3, nomorMeja: 'Meja 03', kapasitas: 4, status: TableStatus.kosong),
      TableModel(idMeja: 4, nomorMeja: 'Meja 04', kapasitas: 6, status: TableStatus.kosong),
      TableModel(idMeja: 5, nomorMeja: 'Meja 05', kapasitas: 2, status: TableStatus.kosong),
      TableModel(idMeja: 6, nomorMeja: 'Meja 06', kapasitas: 4, status: TableStatus.reservasi),
      TableModel(idMeja: 7, nomorMeja: 'Meja 07', kapasitas: 8, status: TableStatus.kosong),
      TableModel(idMeja: 8, nomorMeja: 'Meja 08', kapasitas: 4, status: TableStatus.kosong),
    ]);

    // 3. Seed Menus
    _menus.addAll([
      MenuModel(
        idMasakan: 1,
        namaMasakan: 'Nasi Goreng Spesial',
        kategori: MenuCategory.makanan,
        harga: 25000,
        status: MenuStatus.tersedia,
        deskripsi: 'Nasi goreng racikan bumbu khas dengan telur mata sapi dan ayam suwir.',
      ),
      MenuModel(
        idMasakan: 2,
        namaMasakan: 'Ayam Bakar Madu',
        kategori: MenuCategory.makanan,
        harga: 32000,
        status: MenuStatus.tersedia,
        deskripsi: 'Ayam bakar legit berlumur madu hutan dengan sambal terasi dan lalapan.',
      ),
      MenuModel(
        idMasakan: 3,
        namaMasakan: 'Mie Goreng Seafood',
        kategori: MenuCategory.makanan,
        harga: 28000,
        status: MenuStatus.tersedia,
        deskripsi: 'Mie telur kenyal dengan udang, cumi segar, dan sayuran renyah.',
      ),
      MenuModel(
        idMasakan: 4,
        namaMasakan: 'Sop Buntut Sapi',
        kategori: MenuCategory.makanan,
        harga: 45000,
        status: MenuStatus.tersedia,
        deskripsi: 'Potongan buntut empuk dengan kuah kaldu rempah gurih hangat.',
      ),
      MenuModel(
        idMasakan: 5,
        namaMasakan: 'Sate Ayam Madura (10 tusuk)',
        kategori: MenuCategory.makanan,
        harga: 30000,
        status: MenuStatus.tersedia,
        deskripsi: 'Sate daging ayam pilihan dibakar harum dengan bumbu kacang gurih.',
      ),
      MenuModel(
        idMasakan: 6,
        namaMasakan: 'Es Teh Manis',
        kategori: MenuCategory.minuman,
        harga: 6000,
        status: MenuStatus.tersedia,
        deskripsi: 'Teh melati wangi dingin segar pelepas dahaga.',
      ),
      MenuModel(
        idMasakan: 7,
        namaMasakan: 'Es Jeruk Peras',
        kategori: MenuCategory.minuman,
        harga: 9000,
        status: MenuStatus.tersedia,
        deskripsi: 'Perasan jeruk segar alami kaya vitamin C.',
      ),
      MenuModel(
        idMasakan: 8,
        namaMasakan: 'Jus Alpukat Kocok',
        kategori: MenuCategory.minuman,
        harga: 16000,
        status: MenuStatus.tersedia,
        deskripsi: 'Alpukat mentega kental dengan krimer cokelat manis.',
      ),
      MenuModel(
        idMasakan: 9,
        namaMasakan: 'Kopi Susu Gula Aren',
        kategori: MenuCategory.minuman,
        harga: 18000,
        status: MenuStatus.tersedia,
        deskripsi: 'Espresso robusta dengan susu segar dan gula aren murni.',
      ),
      MenuModel(
        idMasakan: 10,
        namaMasakan: 'Paket Hemat Pelajar',
        kategori: MenuCategory.paket,
        harga: 27000,
        status: MenuStatus.tersedia,
        deskripsi: 'Nasi putih pulen, ayam goreng krispi, sambal, lalap, dan Es Teh Manis.',
      ),
      MenuModel(
        idMasakan: 11,
        namaMasakan: 'Paket Keluarga 4 Orang',
        kategori: MenuCategory.paket,
        harga: 125000,
        status: MenuStatus.tersedia,
        deskripsi: '1 Bakul Nasi, 1 Ekor Ayam Bakar, 1 Porsi Sop Buntut, 4 Es Teh Manis.',
      ),
    ]);

    // 4. Seed Active Orders (Table Service)
    final order1 = OrderModel(
      idOrder: 101,
      noMeja: 'Meja 01',
      namaPelanggan: 'Pak Rahman',
      tanggal: DateTime.now().subtract(const Duration(minutes: 35)),
      idUser: 2,
      namaUser: 'Budi Waiter',
      keterangan: 'Minta sendok garpu tambahan',
      status: OrderStatus.diproses,
      items: [
        OrderItemModel(idDetailOrder: 1, menu: _menus[0], jumlah: 2, catatan: 'Satu tidak pedas'),
        OrderItemModel(idDetailOrder: 2, menu: _menus[5], jumlah: 2, catatan: 'Manis sedang'),
      ],
    );

    final order2 = OrderModel(
      idOrder: 102,
      noMeja: 'Meja 02',
      namaPelanggan: 'Ibu Sarah',
      tanggal: DateTime.now().subtract(const Duration(minutes: 15)),
      idUser: 2,
      namaUser: 'Budi Waiter',
      keterangan: 'Pesanan untuk 3 orang',
      status: OrderStatus.menunggu,
      items: [
        OrderItemModel(idDetailOrder: 3, menu: _menus[1], jumlah: 2, catatan: 'Pedas sedang'),
        OrderItemModel(idDetailOrder: 4, menu: _menus[3], jumlah: 1, catatan: 'Kuah dipisah'),
        OrderItemModel(idDetailOrder: 5, menu: _menus[6], jumlah: 3, catatan: ''),
      ],
    );

    _orders.addAll([order1, order2]);

    // 5. Seed Past Finished Transactions
    final pastOrder1 = OrderModel(
      idOrder: 98,
      noMeja: 'Meja 03',
      namaPelanggan: 'Keluarga Hendra',
      tanggal: DateTime.now().subtract(const Duration(hours: 3)),
      idUser: 2,
      namaUser: 'Budi Waiter',
      status: OrderStatus.selesai,
      items: [
        OrderItemModel(idDetailOrder: 6, menu: _menus[10], jumlah: 1),
        OrderItemModel(idDetailOrder: 7, menu: _menus[7], jumlah: 2),
      ],
    );

    final pastOrder2 = OrderModel(
      idOrder: 99,
      noMeja: 'Meja 05',
      namaPelanggan: 'Dewi Anggraini',
      tanggal: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
      idUser: 2,
      namaUser: 'Budi Waiter',
      status: OrderStatus.selesai,
      items: [
        OrderItemModel(idDetailOrder: 8, menu: _menus[2], jumlah: 1),
        OrderItemModel(idDetailOrder: 9, menu: _menus[8], jumlah: 1),
      ],
    );

    final pastOrder3 = OrderModel(
      idOrder: 100,
      noMeja: 'Meja 04',
      namaPelanggan: 'Rian Pratama',
      tanggal: DateTime.now().subtract(const Duration(minutes: 50)),
      idUser: 2,
      namaUser: 'Budi Waiter',
      status: OrderStatus.selesai,
      items: [
        OrderItemModel(idDetailOrder: 10, menu: _menus[9], jumlah: 2),
      ],
    );

    _orders.addAll([pastOrder1, pastOrder2, pastOrder3]);

    _transactions.addAll([
      TransactionModel(
        idTransaksi: 1,
        idUser: 3,
        namaKasir: 'Citra Kasir',
        order: pastOrder1,
        tanggal: DateTime.now().subtract(const Duration(hours: 2, minutes: 20)),
        totalBayar: pastOrder1.totalHarga,
        jumlahBayar: 160000,
        kembalian: 160000 - pastOrder1.totalHarga,
        metodePembayaran: 'Tunai',
      ),
      TransactionModel(
        idTransaksi: 2,
        idUser: 3,
        namaKasir: 'Citra Kasir',
        order: pastOrder2,
        tanggal: DateTime.now().subtract(const Duration(hours: 1)),
        totalBayar: pastOrder2.totalHarga,
        jumlahBayar: 50000,
        kembalian: 50000 - pastOrder2.totalHarga,
        metodePembayaran: 'QRIS',
      ),
      TransactionModel(
        idTransaksi: 3,
        idUser: 3,
        namaKasir: 'Citra Kasir',
        order: pastOrder3,
        tanggal: DateTime.now().subtract(const Duration(minutes: 25)),
        totalBayar: pastOrder3.totalHarga,
        jumlahBayar: 60000,
        kembalian: 60000 - pastOrder3.totalHarga,
        metodePembayaran: 'Tunai',
      ),
    ]);
  }

  // --- AUTHENTICATION & SWITCHER ---
  bool login(String username, String password) {
    try {
      final user = _users.firstWhere(
        (u) =>
            u.username.toLowerCase() == username.trim().toLowerCase() &&
            u.password == password,
      );
      _currentUser = user;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Login / Register via Google OAuth dengan integrasi Supabase (sp_google_login)
  Future<UserModel> loginWithGoogleSupabase({
    required String googleUid,
    required String googleEmail,
    required String displayName,
    String? photoUrl,
  }) async {
    // 1. Coba eksekusi melalui Supabase PL/pgSQL RPC
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
              u.username.toLowerCase() == googleEmail.toLowerCase());

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

    // 2. Fallback ke login lokal jika Supabase offline
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
  }) {
    // 1. Cek apakah Google UID sudah terdaftar
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

    // 2. Cek apakah email Google cocok dgn akun lokal yang ada
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

    // 3. Buat akun baru: default Pelanggan
    final newId =
        (_users.map((u) => u.idUser).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newUser = UserModel(
      idUser: newId,
      username: googleEmail,
      password: '',
      namaUser: displayName,
      role: UserRole.pelanggan,
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
    final user = _users.firstWhere(
      (u) => u.role == role,
      orElse: () => _users.first,
    );
    _currentUser = user;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // --- REGISTRASI / USER MANAGEMENT (Admin, Waiter, Kasir) ---
  void addUser(String username, String password, String namaUser, UserRole role) {
    final newId =
        (_users.map((u) => u.idUser).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newUser = UserModel(
      idUser: newId,
      username: username,
      password: password,
      namaUser: namaUser,
      role: role,
    );
    _users.add(newUser);
    notifyListeners();

    // Simpan ke Supabase asynchronously
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
  void addMenu(String nama, MenuCategory kategori, int harga, String deskripsi) {
    final newId =
        (_menus.map((m) => m.idMasakan).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newMenu = MenuModel(
      idMasakan: newId,
      namaMasakan: nama,
      kategori: kategori,
      harga: harga,
      status: MenuStatus.tersedia,
      deskripsi: deskripsi,
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
      MenuStatus status, String deskripsi) {
    final index = _menus.indexWhere((m) => m.idMasakan == idMasakan);
    if (index != -1) {
      _menus[index] = _menus[index].copyWith(
        namaMasakan: nama,
        kategori: kategori,
        harga: harga,
        status: status,
        deskripsi: deskripsi,
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

  // --- ENTRI REFERENSI MEJA (Admin) ---
  void addTable(String nomorMeja, int kapasitas) {
    final newId =
        (_tables.map((t) => t.idMeja).fold(0, (max, id) => id > max ? id : max)) + 1;
    final newTable = TableModel(
      idMeja: newId,
      nomorMeja: nomorMeja,
      kapasitas: kapasitas,
      status: TableStatus.kosong,
    );
    _tables.add(newTable);
    notifyListeners();

    if (_isSupabaseConnected) {
      _supabase.insertTable(newTable).then((inserted) {
        if (inserted != null) {
          final idx = _tables.indexOf(newTable);
          if (idx != -1) {
            _tables[idx] = inserted;
            notifyListeners();
          }
        }
      });
    }
  }

  void updateTableStatus(String nomorMeja, TableStatus status) {
    final index = _tables.indexWhere((t) => t.nomorMeja == nomorMeja);
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(status: status);
      notifyListeners();

      if (_isSupabaseConnected) {
        _supabase.updateTableStatus(nomorMeja, status);
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
    final newId =
        (_orders.map((o) => o.idOrder).fold(100, (max, id) => id > max ? id : max)) + 1;
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

    // Set meja status to Terisi
    updateTableStatus(noMeja, TableStatus.terisi);
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

    final transaction = TransactionModel(
      idTransaksi: newId,
      idUser: _currentUser?.idUser ?? 3,
      namaKasir: _currentUser?.namaUser ?? 'Citra Kasir',
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

    // Free the table back to Kosong
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
}
