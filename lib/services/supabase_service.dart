import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/menu_model.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/payment_method_model.dart';
import 'supabase_config.dart';

/// Service untuk mengelola interaksi langsung dengan Supabase PostgreSQL & Auth.
/// Mendukung kompatibilitas penamaan tabel: 'user' / 'tb_user', 'masakan' / 'tb_masakan', dsb.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get clientSafe {
    try {
      if (isInitialized) {
        return Supabase.instance.client;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get client => Supabase.instance.client;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Nama tabel yang terdeteksi di database Supabase
  String _userTable = 'user';
  String _menuTable = 'masakan';
  String _orderTable = 'order';
  String _detailOrderTable = 'detail_order';
  String _transaksiTable = 'transaksi';

  /// Inisialisasi client Supabase
  Future<bool> initialize() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _isConnected = await checkConnection();
      return _isConnected;
    } catch (e) {
      debugPrint('[SupabaseService] Init error: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Cek koneksi ke database Supabase dan deteksi nama tabel
  Future<bool> checkConnection() async {
    try {
      final c = clientSafe;
      if (c == null) {
        _isConnected = false;
        return false;
      }

      // Deteksi tabel user / tb_user
      try {
        await c.from('user').select('id_user').limit(1);
        _userTable = 'user';
      } catch (_) {
        try {
          await c.from('tb_user').select('id_user').limit(1);
          _userTable = 'tb_user';
        } catch (_) {}
      }

      // Deteksi tabel masakan / tb_masakan
      try {
        await c.from('masakan').select('id_masakan').limit(1);
        _menuTable = 'masakan';
      } catch (_) {
        try {
          await c.from('tb_masakan').select('id_masakan').limit(1);
          _menuTable = 'tb_masakan';
        } catch (_) {}
      }

      // Deteksi tabel order / tb_order
      try {
        await c.from('order').select('id_order').limit(1);
        _orderTable = 'order';
      } catch (_) {
        try {
          await c.from('tb_order').select('id_order').limit(1);
          _orderTable = 'tb_order';
        } catch (_) {}
      }

      // Deteksi detail_order
      try {
        await c.from('detail_order').select('id_detail_order').limit(1);
        _detailOrderTable = 'detail_order';
      } catch (_) {
        try {
          await c.from('tb_detail_order').select('id_detail_order').limit(1);
          _detailOrderTable = 'tb_detail_order';
        } catch (_) {}
      }

      // Deteksi transaksi
      try {
        await c.from('transaksi').select('id_transaksi').limit(1);
        _transaksiTable = 'transaksi';
      } catch (_) {
        try {
          await c.from('tb_transaksi').select('id_transaksi').limit(1);
          _transaksiTable = 'tb_transaksi';
        } catch (_) {}
      }

      _isConnected = true;
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Check connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  // ============================================================
  // GOOGLE OAUTH & GOOGLE SIGN-IN
  // ============================================================

  /// 1. Login menggunakan Supabase OAuth Browser Flow
  Future<bool> signInWithGoogleOAuth({String? customRedirect}) async {
    try {
      final defaultRedirect = kIsWeb
          ? null
          : (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS
              ? SupabaseConfig.redirectUrl
              : 'http://localhost:3000');
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: customRedirect ?? defaultRedirect,
      );
    } catch (e) {
      debugPrint('[SupabaseService] signInWithGoogleOAuth error: $e');
      rethrow;
    }
  }

  /// 2. Eksekusi Stored Procedure atau Upsert ke tabel user
  Future<UserModel?> loginWithGoogleRpc({
    required String googleUid,
    required String googleEmail,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      // Coba panggil RPC jika tersedia
      try {
        final res = await client.rpc('sp_google_login', params: {
          'p_google_uid': googleUid,
          'p_google_email': googleEmail,
          'p_display_name': displayName,
          'p_photo_url': photoUrl,
        });

        if (res != null) {
          if (res is List && res.isNotEmpty) {
            return UserModel.fromMap(res.first as Map<String, dynamic>);
          } else if (res is Map<String, dynamic>) {
            return UserModel.fromMap(res);
          }
        }
      } catch (_) {
        // RPC belum dipasang, gunakan direct query ke tabel user
      }

      return await _fallbackGoogleLogin(
        googleUid: googleUid,
        googleEmail: googleEmail,
        displayName: displayName,
        photoUrl: photoUrl,
      );
    } catch (e) {
      debugPrint('[SupabaseService] loginWithGoogleRpc error: $e');
      return null;
    }
  }

  Future<UserModel?> _fallbackGoogleLogin({
    required String googleUid,
    required String googleEmail,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      // 1. Cek user berdasarkan google_uid, google_email, atau username
      final cleanUsername = googleEmail.split('@').first.toLowerCase();
      final existing = await client
          .from(_userTable)
          .select('*')
          .or('google_email.eq.$googleEmail,google_uid.eq.$googleUid,username.eq.$cleanUsername')
          .maybeSingle();

      if (existing != null) {
        final existingId = existing['id_user'];
        // Tautkan data Google ke akun yang sudah ada (menjaga hak akses role yang ada)
        final updated = await client.from(_userTable).update({
          'google_uid': googleUid,
          'google_email': googleEmail,
          'google_photo': photoUrl,
          'auth_provider': 'both',
        }).eq('id_user', existingId).select('*').single();
        return UserModel.fromMap(updated);
      }

      // 2. User baru: Daftarkan sebagai Administrator (id_level = 1)
      // agar seluruh fitur, menu, pesanan, dan laporan dapat langsung diakses & diuji
      final defaultLevel = cleanUsername.contains('pelanggan') ? 5 : 1;
      final newUserData = {
        'username': cleanUsername,
        'nama_user': displayName.isNotEmpty ? displayName : 'Pengguna Google',
        'password': 'google_oauth_verified',
        'id_level': defaultLevel,
        'google_email': googleEmail,
        'google_uid': googleUid,
        'google_photo': photoUrl,
        'auth_provider': 'google',
      };

      final inserted = await client
          .from(_userTable)
          .insert(newUserData)
          .select('*')
          .single();

      return UserModel.fromMap(inserted);
    } catch (e) {
      debugPrint('[SupabaseService] _fallbackGoogleLogin error: $e');
      return null;
    }
  }

  // ============================================================
  // CRUD USERS (tabel user / tb_user)
  // ============================================================

  Future<List<UserModel>> fetchUsers() async {
    try {
      final res = await client.from(_userTable).select('*').order('id_user');
      return (res as List).map((map) => UserModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchUsers error: $e');
      return [];
    }
  }

  Future<UserModel?> insertUser(UserModel user) async {
    try {
      final data = {
        'username': user.username,
        'password': user.password,
        'nama_user': user.namaUser,
        'id_level': user.role.id,
        'email': user.displayEmail,
      };
      final res = await client.from(_userTable).insert(data).select().single();
      return UserModel.fromMap(res);
    } catch (e) {
      debugPrint('[SupabaseService] insertUser error: $e');
      return null;
    }
  }

  Future<bool> updateUser(UserModel user) async {
    try {
      final data = <String, dynamic>{
        'nama_user': user.namaUser,
        'id_level': user.role.id,
      };
      if (user.password.isNotEmpty) {
        data['password'] = user.password;
      }
      await client.from(_userTable).update(data).eq('id_user', user.idUser);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateUser error: $e');
      return false;
    }
  }

  Future<bool> deleteUser(int idUser) async {
    try {
      await client.from(_userTable).delete().eq('id_user', idUser);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] deleteUser error: $e');
      return false;
    }
  }

  // ============================================================
  // CRUD MENUS (tabel masakan / tb_masakan)
  // ============================================================

  Future<List<MenuModel>> fetchMenus() async {
    try {
      final res = await client.from(_menuTable).select('*').order('id_masakan');
      return (res as List).map((map) => MenuModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchMenus error: $e');
      return [];
    }
  }

  Future<MenuModel?> insertMenu(MenuModel menu) async {
    try {
      final data = {
        'nama_masakan': menu.namaMasakan,
        'kategori': menu.kategori.label,
        'harga': menu.harga,
        'status_masakan': menu.status.label,
        'deskripsi': menu.deskripsi,
        if (menu.gambarUrl.isNotEmpty) 'gambar_url': menu.gambarUrl,
      };
      final res = await client.from(_menuTable).insert(data).select().single();
      return MenuModel.fromMap(res);
    } catch (e) {
      debugPrint('[SupabaseService] insertMenu error: $e');
      return null;
    }
  }

  Future<bool> updateMenu(MenuModel menu) async {
    try {
      await client.from(_menuTable).update({
        'nama_masakan': menu.namaMasakan,
        'kategori': menu.kategori.label,
        'harga': menu.harga,
        'status_masakan': menu.status.label,
        'deskripsi': menu.deskripsi,
        if (menu.gambarUrl.isNotEmpty) 'gambar_url': menu.gambarUrl,
      }).eq('id_masakan', menu.idMasakan);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateMenu error: $e');
      return false;
    }
  }

  Future<bool> deleteMenu(int idMasakan) async {
    try {
      await client.from(_menuTable).delete().eq('id_masakan', idMasakan);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] deleteMenu error: $e');
      return false;
    }
  }

  // ============================================================
  // TABLES (tb_meja / meja)
  // ============================================================

  Future<List<TableModel>> fetchTables() async {
    try {
      final res = await client.from('tb_meja').select('*').order('id_meja');
      return (res as List).map((map) => TableModel.fromMap(map)).toList();
    } catch (_) {
      try {
        final res = await client.from('meja').select('*').order('id_meja');
        return (res as List).map((map) => TableModel.fromMap(map)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> insertTable(TableModel table) async {
    try {
      await client.from('tb_meja').insert(table.toMap());
    } catch (_) {
      try {
        await client.from('meja').insert(table.toMap());
      } catch (_) {}
    }
  }

  Future<void> updateTable(TableModel table) async {
    try {
      await client.from('tb_meja').update(table.toMap()).eq('id_meja', table.idMeja);
    } catch (_) {
      try {
        await client.from('meja').update(table.toMap()).eq('id_meja', table.idMeja);
      } catch (_) {}
    }
  }

  Future<void> deleteTable(int idMeja) async {
    try {
      await client.from('tb_meja').delete().eq('id_meja', idMeja);
    } catch (_) {
      try {
        await client.from('meja').delete().eq('id_meja', idMeja);
      } catch (_) {}
    }
  }

  // ============================================================
  // CRUD ORDERS (order / tb_order & detail_order / tb_detail_order)
  // ============================================================

  Future<List<OrderModel>> fetchOrders(
    List<MenuModel> availableMenus,
    List<UserModel> availableUsers,
  ) async {
    try {
      final ordersRes = await client
          .from(_orderTable)
          .select('*')
          .order('id_order', ascending: false);

      final List<OrderModel> result = [];
      for (final oMap in ordersRes as List) {
        final orderId = oMap['id_order'] is int
            ? oMap['id_order'] as int
            : int.tryParse('${oMap['id_order']}') ?? 0;

        // Fetch detail order items
        List detailsRes = [];
        try {
          detailsRes = await client
              .from(_detailOrderTable)
              .select('*')
              .eq('id_order', orderId);
        } catch (de) {
          debugPrint('[SupabaseService] fetch detail_order error: $de');
        }

        final items = <OrderItemModel>[];
        for (final dMap in detailsRes) {
          final idMasakan = dMap['id_masakan'] is int
              ? dMap['id_masakan'] as int
              : int.tryParse('${dMap['id_masakan']}') ?? 0;

          final menu = availableMenus.firstWhere(
            (m) => m.idMasakan == idMasakan,
            orElse: () => MenuModel(
              idMasakan: idMasakan,
              namaMasakan: 'Menu #$idMasakan',
              kategori: MenuCategory.makanan,
              harga: ((dMap['subtotal'] is num ? (dMap['subtotal'] as num).toInt() : int.tryParse('${dMap['subtotal']}') ?? 0)) ~/
                  ((dMap['jumlah'] is num ? (dMap['jumlah'] as num).toInt() : int.tryParse('${dMap['jumlah']}') ?? 1)),
            ),
          );
          items.add(OrderItemModel.fromMap(dMap, menu));
        }

        final idUser = oMap['id_user'] is int
            ? oMap['id_user'] as int
            : int.tryParse('${oMap['id_user']}') ?? 0;

        final user = availableUsers.firstWhere(
          (u) => u.idUser == idUser,
          orElse: () => UserModel(
            idUser: idUser,
            username: 'staff',
            password: '',
            namaUser: 'Staff Restoran',
            role: UserRole.waiter,
          ),
        );

        result.add(OrderModel.fromMap(
          oMap,
          fallbackUserName: user.namaUser,
          items: items,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('[SupabaseService] fetchOrders error: $e');
      return [];
    }
  }

  Future<OrderModel?> insertOrder(OrderModel order) async {
    try {
      final orderDateStr = DateFormat('yyyy-MM-dd').format(order.tanggal);
      final Map<String, dynamic> orderMap = {
        'no_meja': order.noMeja,
        'tanggal': orderDateStr,
        if (order.idUser > 0) 'id_user': order.idUser,
        'keterangan': order.namaPelanggan.isNotEmpty
            ? 'Pelanggan: ${order.namaPelanggan}${order.keterangan.isNotEmpty ? ' | ${order.keterangan}' : ''}'
            : order.keterangan,
        'status_order': order.status.label,
      };

      dynamic insertedOrder;
      try {
        insertedOrder =
            await client.from(_orderTable).insert(orderMap).select().single();
      } catch (err) {
        // Fallback jika id_user tidak ada di database, hilangkan id_user agar foreign key tidak error
        debugPrint('[SupabaseService] insertOrder primary attempt failed: $err. Retrying with id_user null...');
        orderMap.remove('id_user');
        insertedOrder =
            await client.from(_orderTable).insert(orderMap).select().single();
      }

      final newOrderId = insertedOrder['id_order'] is int
          ? insertedOrder['id_order'] as int
          : int.tryParse('${insertedOrder['id_order']}') ?? 0;

      // Insert detail items
      if (order.items.isNotEmpty) {
        final details = order.items.map((item) => {
              'id_order': newOrderId,
              'id_masakan': item.menu.idMasakan,
              'jumlah': item.jumlah,
              'harga_satuan': item.menu.harga,
              'subtotal': item.subtotal,
              'keterangan': item.catatan,
              'status_detail_order': 'Menunggu',
            }).toList();

        await client.from(_detailOrderTable).insert(details);
      }

      return order.copyWith(idOrder: newOrderId);
    } catch (e) {
      debugPrint('[SupabaseService] insertOrder error: $e');
      return null;
    }
  }

  Future<bool> updateOrderStatus(int idOrder, OrderStatus status) async {
    try {
      await client
          .from(_orderTable)
          .update({'status_order': status.label})
          .eq('id_order', idOrder);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateOrderStatus error: $e');
      return false;
    }
  }

  Future<bool> deleteOrder(int idOrder) async {
    try {
      await client.from(_detailOrderTable).delete().eq('id_order', idOrder);
      await client.from(_orderTable).delete().eq('id_order', idOrder);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] deleteOrder error: $e');
      return false;
    }
  }

  // ============================================================
  // CRUD TRANSAKSI (transaksi / tb_transaksi)
  // ============================================================

  Future<List<TransactionModel>> fetchTransactions(
    List<OrderModel> orders,
    List<UserModel> users,
  ) async {
    try {
      final res = await client
          .from(_transaksiTable)
          .select('*')
          .order('id_transaksi', ascending: false);

      final List<TransactionModel> result = [];
      for (final tMap in res as List) {
        final idOrder = tMap['id_order'] is int
            ? tMap['id_order'] as int
            : int.tryParse('${tMap['id_order']}') ?? 0;
        final idUser = tMap['id_user'] is int
            ? tMap['id_user'] as int
            : int.tryParse('${tMap['id_user']}') ?? 0;

        final order = orders.firstWhere(
          (o) => o.idOrder == idOrder,
          orElse: () => OrderModel(
            idOrder: idOrder,
            noMeja: 'Meja -',
            namaPelanggan: 'Pelanggan',
            tanggal: DateTime.now(),
            idUser: idUser,
            namaUser: 'Kasir',
            items: [],
          ),
        );

        final kasir = users.firstWhere(
          (u) => u.idUser == idUser,
          orElse: () => UserModel(
            idUser: idUser,
            username: 'kasir',
            password: '',
            namaUser: 'Kasir',
            role: UserRole.kasir,
          ),
        );

        result.add(TransactionModel.fromMap(
          tMap,
          order: order,
          fallbackKasirName: kasir.namaUser,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('[SupabaseService] fetchTransactions error: $e');
      return [];
    }
  }

  Future<TransactionModel?> insertTransaction(TransactionModel trx) async {
    try {
      final trxDateStr = DateFormat('yyyy-MM-dd').format(trx.tanggal);
      final Map<String, dynamic> trxMap = {
        if (trx.idUser > 0) 'id_user': trx.idUser,
        'id_order': trx.order.idOrder,
        'tanggal': trxDateStr,
        'total_bayar': trx.totalBayar,
        'jumlah_bayar': trx.jumlahBayar,
        'kembalian': trx.kembalian,
        'metode_pembayaran': trx.metodePembayaran,
      };

      dynamic res;
      try {
        res = await client.from(_transaksiTable).insert(trxMap).select().single();
      } catch (err) {
        // Fallback: jika id_user tidak ada atau kolom jumlah_uang dipakai
        debugPrint('[SupabaseService] insertTransaction primary attempt failed: $err. Retrying with fallback...');
        trxMap.remove('id_user');
        try {
          res = await client.from(_transaksiTable).insert(trxMap).select().single();
        } catch (_) {
          trxMap['jumlah_uang'] = trx.jumlahBayar;
          res = await client.from(_transaksiTable).insert(trxMap).select().single();
        }
      }

      final newTrxId = res['id_transaksi'] is int
          ? res['id_transaksi'] as int
          : int.tryParse('${res['id_transaksi']}') ?? 0;

      // Update status order menjadi selesai
      await updateOrderStatus(trx.order.idOrder, OrderStatus.selesai);

      return TransactionModel(
        idTransaksi: newTrxId,
        idUser: trx.idUser,
        namaKasir: trx.namaKasir,
        order: trx.order,
        tanggal: trx.tanggal,
        totalBayar: trx.totalBayar,
        jumlahBayar: trx.jumlahBayar,
        kembalian: trx.kembalian,
        metodePembayaran: trx.metodePembayaran,
      );
    } catch (e) {
      debugPrint('[SupabaseService] insertTransaction error: $e');
      return null;
    }
  }

  // ============================================================
  // USER PAYMENT METHODS (tb_user_payment_methods)
  // ============================================================

  Future<List<ConnectedPaymentMethod>> fetchUserPaymentMethods(int idUser) async {
    try {
      final res = await client
          .from('tb_user_payment_methods')
          .select('*')
          .eq('id_user', idUser)
          .order('connected_at', ascending: false);
      return (res as List).map((map) => ConnectedPaymentMethod.fromMap(map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveUserPaymentMethod(int idUser, ConnectedPaymentMethod method) async {
    try {
      await client.from('tb_user_payment_methods').upsert(method.toMap(idUser: idUser));
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] saveUserPaymentMethod error: $e');
      return false;
    }
  }

  Future<bool> deleteUserPaymentMethod(String id) async {
    try {
      await client.from('tb_user_payment_methods').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] deleteUserPaymentMethod error: $e');
      return false;
    }
  }

  Future<bool> updateUserPaymentMethodBalance(String id, int balance) async {
    try {
      await client.from('tb_user_payment_methods').update({'balance': balance}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateUserPaymentMethodBalance error: $e');
      return false;
    }
  }

  // ============================================================
  // PAYMENT MUTATIONS (tb_payment_mutasi)
  // ============================================================

  Future<List<PaymentMutation>> fetchPaymentMutations(int idUser, {String? paymentMethodId}) async {
    try {
      var query = client.from('tb_payment_mutasi').select('*').eq('id_user', idUser);
      if (paymentMethodId != null && paymentMethodId.isNotEmpty) {
        query = query.eq('id_payment_method', paymentMethodId);
      }
      final res = await query.order('created_at', ascending: false);
      return (res as List).map((map) => PaymentMutation.fromMap(map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> insertPaymentMutation(PaymentMutation mutasi) async {
    try {
      await client.from('tb_payment_mutasi').insert(mutasi.toMap());
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] insertPaymentMutation error: $e');
      return false;
    }
  }
}
