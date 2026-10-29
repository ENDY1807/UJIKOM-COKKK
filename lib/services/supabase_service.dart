import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/menu_model.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import 'supabase_config.dart';

/// Service untuk mengelola interaksi langsung dengan Supabase PostgreSQL & Auth.
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

  /// Cek koneksi ke database Supabase
  Future<bool> checkConnection() async {
    try {
      final c = clientSafe;
      if (c == null) {
        _isConnected = false;
        return false;
      }
      final res = await c.from('tb_user').select('id_user').limit(1);
      _isConnected = res.isNotEmpty || res.isEmpty;
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
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: customRedirect ?? (kIsWeb ? null : 'http://localhost:3000'),
      );
    } catch (e) {
      debugPrint('[SupabaseService] signInWithGoogleOAuth error: $e');
      rethrow;
    }
  }

  /// 2. Eksekusi Stored Procedure `sp_google_login` di Supabase
  /// Sesuai fungsi PL/pgSQL yang ada pada skema database kasir
  Future<UserModel?> loginWithGoogleRpc({
    required String googleUid,
    required String googleEmail,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final res = await client.rpc(
        'sp_google_login',
        params: {
          'p_google_uid': googleUid,
          'p_google_email': googleEmail,
          'p_nama': displayName,
          'p_google_photo': photoUrl ?? 'https://lh3.googleusercontent.com/a/default-user',
        },
      );

      if (res is List && res.isNotEmpty) {
        final row = Map<String, dynamic>.from(res.first as Map);
        return UserModel(
          idUser: row['id_user'] is int
              ? row['id_user'] as int
              : int.tryParse('${row['id_user']}') ?? 0,
          username: row['username']?.toString() ?? googleEmail,
          password: '',
          namaUser: row['nama_user']?.toString() ?? displayName,
          role: UserRole.fromId(row['id_level'] is int
              ? row['id_level'] as int
              : int.tryParse('${row['id_level']}') ?? 5),
          authProvider: AuthProvider.google,
          googleUid: googleUid,
          googleEmail: googleEmail,
          googlePhoto: row['google_photo']?.toString() ?? photoUrl,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[SupabaseService] loginWithGoogleRpc error: $e');
      // Jika RPC gagal, fallback insert/upsert langsung ke tb_user
      return await _fallbackGoogleLogin(
        googleUid: googleUid,
        googleEmail: googleEmail,
        displayName: displayName,
        photoUrl: photoUrl,
      );
    }
  }

  /// Fallback langsung ke tb_user jika RPC terkendala
  Future<UserModel?> _fallbackGoogleLogin({
    required String googleUid,
    required String googleEmail,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      // 1. Cek google_uid
      final existingUid = await client
          .from('tb_user')
          .select('*')
          .eq('google_uid', googleUid)
          .maybeSingle();

      if (existingUid != null) {
        final updated = await client
            .from('tb_user')
            .update({
              'nama_user': displayName,
              'google_email': googleEmail,
              'google_photo': photoUrl,
            })
            .eq('id_user', existingUid['id_user'])
            .select('*')
            .single();
        return UserModel.fromMap(updated);
      }

      // 2. Cek email
      final existingEmail = await client
          .from('tb_user')
          .select('*')
          .or('username.eq.$googleEmail,google_email.eq.$googleEmail')
          .maybeSingle();

      if (existingEmail != null) {
        final updated = await client
            .from('tb_user')
            .update({
              'google_uid': googleUid,
              'google_email': googleEmail,
              'google_photo': photoUrl,
              'auth_provider': 'both',
            })
            .eq('id_user', existingEmail['id_user'])
            .select('*')
            .single();
        return UserModel.fromMap(updated);
      }

      // 3. User baru
      final inserted = await client
          .from('tb_user')
          .insert({
            'username': googleEmail,
            'nama_user': displayName,
            'id_level': 5,
            'auth_provider': 'google',
            'google_uid': googleUid,
            'google_email': googleEmail,
            'google_photo': photoUrl,
          })
          .select('*')
          .single();

      return UserModel.fromMap(inserted);
    } catch (e) {
      debugPrint('[SupabaseService] _fallbackGoogleLogin error: $e');
      return null;
    }
  }

  // ============================================================
  // CRUD USERS (tb_user)
  // ============================================================

  Future<List<UserModel>> fetchUsers() async {
    try {
      final res = await client.from('tb_user').select('*').order('id_user');
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
        'auth_provider': user.authProvider.name,
        'google_uid': user.googleUid,
        'google_email': user.googleEmail,
        'google_photo': user.googlePhoto,
        'foto_profil': user.fotoProfil,
      };
      final res = await client.from('tb_user').insert(data).select().single();
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
      await client.from('tb_user').update(data).eq('id_user', user.idUser);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateUser error: $e');
      return false;
    }
  }

  Future<bool> deleteUser(int idUser) async {
    try {
      await client.from('tb_user').delete().eq('id_user', idUser);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] deleteUser error: $e');
      return false;
    }
  }

  // ============================================================
  // CRUD MENUS (tb_masakan)
  // ============================================================

  Future<List<MenuModel>> fetchMenus() async {
    try {
      final res = await client.from('tb_masakan').select('*').order('id_masakan');
      return (res as List).map((map) => MenuModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchMenus error: $e');
      return [];
    }
  }

  Future<MenuModel?> insertMenu(MenuModel menu) async {
    try {
      final res = await client
          .from('tb_masakan')
          .insert({
            'nama_masakan': menu.namaMasakan,
            'kategori': menu.kategori.label,
            'harga': menu.harga,
            'status_masakan': menu.status.label,
            'deskripsi': menu.deskripsi,
          })
          .select()
          .single();
      return MenuModel.fromMap(res);
    } catch (e) {
      debugPrint('[SupabaseService] insertMenu error: $e');
      return null;
    }
  }

  Future<bool> updateMenu(MenuModel menu) async {
    try {
      await client.from('tb_masakan').update({
        'nama_masakan': menu.namaMasakan,
        'kategori': menu.kategori.label,
        'harga': menu.harga,
        'status_masakan': menu.status.label,
        'deskripsi': menu.deskripsi,
      }).eq('id_masakan', menu.idMasakan);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateMenu error: $e');
      return false;
    }
  }

  Future<bool> deleteMenu(int idMasakan) async {
    try {
      await client.from('tb_masakan').delete().eq('id_masakan', idMasakan);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] deleteMenu error: $e');
      return false;
    }
  }

  // ============================================================
  // CRUD TABLES (tb_meja)
  // ============================================================

  Future<List<TableModel>> fetchTables() async {
    try {
      final res = await client.from('tb_meja').select('*').order('id_meja');
      return (res as List).map((map) => TableModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchTables error: $e');
      return [];
    }
  }

  Future<TableModel?> insertTable(TableModel table) async {
    try {
      final res = await client
          .from('tb_meja')
          .insert({
            'nomor_meja': table.nomorMeja,
            'kapasitas': table.kapasitas,
            'status_meja': table.status.label,
          })
          .select()
          .single();
      return TableModel.fromMap(res);
    } catch (e) {
      debugPrint('[SupabaseService] insertTable error: $e');
      return null;
    }
  }

  Future<bool> updateTableStatus(String nomorMeja, TableStatus status) async {
    try {
      await client
          .from('tb_meja')
          .update({'status_meja': status.label})
          .eq('nomor_meja', nomorMeja);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateTableStatus error: $e');
      return false;
    }
  }

  // ============================================================
  // CRUD ORDERS (tb_order & tb_detail_order)
  // ============================================================

  Future<List<OrderModel>> fetchOrders(
    List<MenuModel> availableMenus,
    List<UserModel> availableUsers,
  ) async {
    try {
      final ordersRes = await client
          .from('tb_order')
          .select('*')
          .order('id_order', ascending: false);

      final List<OrderModel> result = [];
      for (final oMap in ordersRes as List) {
        final orderId = oMap['id_order'] as int;

        // Fetch detail order items
        final detailsRes = await client
            .from('tb_detail_order')
            .select('*')
            .eq('id_order', orderId);

        final items = <OrderItemModel>[];
        for (final dMap in detailsRes as List) {
          final idMasakan = dMap['id_masakan'] as int;
          final menu = availableMenus.firstWhere(
            (m) => m.idMasakan == idMasakan,
            orElse: () => MenuModel(
              idMasakan: idMasakan,
              namaMasakan: 'Menu #$idMasakan',
              kategori: MenuCategory.makanan,
              harga: (dMap['subtotal'] as int? ?? 0) ~/ (dMap['jumlah'] as int? ?? 1),
            ),
          );
          items.add(OrderItemModel.fromMap(dMap, menu));
        }

        final idUser = oMap['id_user'] as int? ?? 0;
        final user = availableUsers.firstWhere(
          (u) => u.idUser == idUser,
          orElse: () => UserModel(
            idUser: idUser,
            username: 'staff',
            password: '',
            namaUser: 'Staff',
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
      final orderMap = {
        'no_meja': order.noMeja,
        'nama_pelanggan': order.namaPelanggan,
        'tanggal': order.tanggal.toIso8601String(),
        'id_user': order.idUser,
        'keterangan': order.keterangan,
        'status_order': order.status.label,
      };

      final insertedOrder =
          await client.from('tb_order').insert(orderMap).select().single();
      final newOrderId = insertedOrder['id_order'] as int;

      // Insert detail items
      if (order.items.isNotEmpty) {
        final details = order.items.map((item) => {
              'id_order': newOrderId,
              'id_masakan': item.menu.idMasakan,
              'jumlah': item.jumlah,
              'subtotal': item.subtotal,
              'keterangan': item.catatan,
              'status_detail_order': 'Menunggu',
            }).toList();

        await client.from('tb_detail_order').insert(details);
      }

      // Log aktivitas
      await logActivity(
        idUser: order.idUser,
        aksi: 'TAMBAH_ORDER',
        detail: 'Order #$newOrderId meja ${order.noMeja} untuk ${order.namaPelanggan}',
      );

      return order.copyWith(idOrder: newOrderId);
    } catch (e) {
      debugPrint('[SupabaseService] insertOrder error: $e');
      return null;
    }
  }

  Future<bool> updateOrderStatus(int idOrder, OrderStatus status) async {
    try {
      await client
          .from('tb_order')
          .update({'status_order': status.label})
          .eq('id_order', idOrder);
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] updateOrderStatus error: $e');
      return false;
    }
  }

  // ============================================================
  // CRUD TRANSAKSI (tb_transaksi)
  // ============================================================

  Future<List<TransactionModel>> fetchTransactions(
    List<OrderModel> orders,
    List<UserModel> users,
  ) async {
    try {
      final res = await client
          .from('tb_transaksi')
          .select('*')
          .order('id_transaksi', ascending: false);

      final List<TransactionModel> result = [];
      for (final tMap in res as List) {
        final idOrder = tMap['id_order'] as int;
        final idUser = tMap['id_user'] as int;

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
      final res = await client
          .from('tb_transaksi')
          .insert({
            'id_user': trx.idUser,
            'id_order': trx.order.idOrder,
            'tanggal': trx.tanggal.toIso8601String(),
            'total_bayar': trx.totalBayar,
            'jumlah_bayar': trx.jumlahBayar,
            'kembalian': trx.kembalian,
            'metode_pembayaran': trx.metodePembayaran,
          })
          .select()
          .single();

      final newTrxId = res['id_transaksi'] as int;

      // Update order status di Supabase
      await updateOrderStatus(trx.order.idOrder, OrderStatus.selesai);

      // Bebaskan meja di Supabase
      await updateTableStatus(trx.order.noMeja, TableStatus.kosong);

      // Catat log
      await logActivity(
        idUser: trx.idUser,
        aksi: 'TRANSAKSI',
        detail: 'Transaksi #$newTrxId - Order #${trx.order.idOrder} Rp ${trx.totalBayar} (${trx.metodePembayaran})',
      );

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
  // AUDIT LOG (tb_log_aktivitas)
  // ============================================================

  Future<void> logActivity({
    int? idUser,
    required String aksi,
    String? detail,
  }) async {
    try {
      await client.from('tb_log_aktivitas').insert({
        'id_user': idUser,
        'aksi': aksi,
        'detail': detail,
      });
    } catch (e) {
      debugPrint('[SupabaseService] logActivity error: $e');
    }
  }
}
