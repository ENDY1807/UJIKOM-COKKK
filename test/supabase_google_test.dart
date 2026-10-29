import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_restoran/models/user_model.dart';
import 'package:kasir_restoran/models/menu_model.dart';
import 'package:kasir_restoran/models/table_model.dart';
import 'package:kasir_restoran/models/order_model.dart';
import 'package:kasir_restoran/models/transaction_model.dart';
import 'package:kasir_restoran/services/database_service.dart';
import 'package:kasir_restoran/services/supabase_config.dart';

void main() {
  group('Supabase Configuration & Credentials', () {
    test('Config contains correct project URL and keys', () {
      expect(SupabaseConfig.url, 'https://qytqleurueliiztckkgi.supabase.co');
      expect(SupabaseConfig.publishableKey, 'sb_publishable_F934ghhu6sKtZfse1-DJaw_QuxZyuHG');
      expect(SupabaseConfig.secretKey, 'sb_secret_QdMqkVQTl9Pf91OuWaxwug_5C_fnGyf');
      expect(SupabaseConfig.jwksUrl, 'https://qytqleurueliiztckkgi.supabase.co/auth/v1/.well-known/jwks.json');
      expect(SupabaseConfig.googleClientId, '124635820971-cn5609qedpjbrlq8f181kk6vcojp8jjk.apps.googleusercontent.com');
      expect(SupabaseConfig.googleClientSecret, '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');
    });
  });

  group('UserModel Google OAuth Mapping', () {
    test('Converts from and to Supabase PostgREST map with Google fields', () {
      final map = {
        'id_user': 10,
        'username': 'test.google@gmail.com',
        'password': '',
        'nama_user': 'Tester Google',
        'id_level': 5,
        'auth_provider': 'google',
        'google_uid': 'google_test_uid_999',
        'google_email': 'test.google@gmail.com',
        'google_photo': 'https://lh3.googleusercontent.com/a/test',
        'foto_profil': null,
      };

      final user = UserModel.fromMap(map);
      expect(user.idUser, 10);
      expect(user.username, 'test.google@gmail.com');
      expect(user.role, UserRole.pelanggan);
      expect(user.authProvider, AuthProvider.google);
      expect(user.isGoogleLinked, isTrue);
      expect(user.googleUid, 'google_test_uid_999');
      expect(user.googleEmail, 'test.google@gmail.com');
      expect(user.displayPhoto, 'https://lh3.googleusercontent.com/a/test');

      final toMap = user.toMap();
      expect(toMap['id_user'], 10);
      expect(toMap['auth_provider'], 'google');
      expect(toMap['google_uid'], 'google_test_uid_999');
    });
  });

  group('Menu, Table, Order & Transaction Models', () {
    test('MenuModel fromMap and toMap', () {
      final map = {
        'id_masakan': 1,
        'nama_masakan': 'Nasi Goreng Spesial',
        'kategori': 'Makanan',
        'harga': 25000,
        'status_masakan': 'Tersedia',
        'deskripsi': 'Nasi goreng racikan',
      };
      final menu = MenuModel.fromMap(map);
      expect(menu.idMasakan, 1);
      expect(menu.namaMasakan, 'Nasi Goreng Spesial');
      expect(menu.kategori, MenuCategory.makanan);
      expect(menu.isTersedia, isTrue);

      final toMap = menu.toMap();
      expect(toMap['nama_masakan'], 'Nasi Goreng Spesial');
      expect(toMap['harga'], 25000);
    });

    test('TableModel fromMap and toMap', () {
      final map = {
        'id_meja': 2,
        'nomor_meja': 'Meja 02',
        'kapasitas': 4,
        'status_meja': 'Terisi',
      };
      final table = TableModel.fromMap(map);
      expect(table.idMeja, 2);
      expect(table.nomorMeja, 'Meja 02');
      expect(table.status, TableStatus.terisi);
    });

    test('OrderModel and OrderItemModel mapping', () {
      final menu = MenuModel(idMasakan: 1, namaMasakan: 'Nasi Goreng', kategori: MenuCategory.makanan, harga: 20000);
      final item = OrderItemModel(idDetailOrder: 1, menu: menu, jumlah: 2);
      expect(item.subtotal, 40000);

      final order = OrderModel(
        idOrder: 101,
        noMeja: 'Meja 01',
        namaPelanggan: 'Budi',
        tanggal: DateTime.now(),
        idUser: 2,
        namaUser: 'Waiter',
        items: [item],
      );
      expect(order.totalHarga, 40000);
      expect(order.totalItem, 2);

      final orderMap = order.toMap();
      expect(orderMap['no_meja'], 'Meja 01');
      expect(orderMap['status_order'], 'Menunggu');
    });

    test('TransactionModel mapping', () {
      final menu = MenuModel(idMasakan: 1, namaMasakan: 'Nasi Goreng', kategori: MenuCategory.makanan, harga: 20000);
      final item = OrderItemModel(idDetailOrder: 1, menu: menu, jumlah: 2);
      final order = OrderModel(
        idOrder: 101,
        noMeja: 'Meja 01',
        namaPelanggan: 'Budi',
        tanggal: DateTime.now(),
        idUser: 2,
        namaUser: 'Waiter',
        items: [item],
      );

      final trx = TransactionModel(
        idTransaksi: 1,
        idUser: 3,
        namaKasir: 'Citra',
        order: order,
        tanggal: DateTime.now(),
        totalBayar: 40000,
        jumlahBayar: 50000,
        kembalian: 10000,
        metodePembayaran: 'Tunai',
      );
      expect(trx.kembalian, 10000);
      expect(trx.metodePembayaran, 'Tunai');
    });
  });

  group('DatabaseService Google Integration Logic', () {
    test('Login with Google creates Pelanggan user and signs in', () {
      final db = DatabaseService();
      final user = db.loginWithGoogle(
        googleUid: 'google_uid_test_123',
        googleEmail: 'pelanggan.baru@gmail.com',
        displayName: 'Pelanggan Baru',
        photoUrl: 'https://example.com/avatar.jpg',
      );

      expect(user.role, UserRole.pelanggan);
      expect(user.googleEmail, 'pelanggan.baru@gmail.com');
      expect(user.namaUser, 'Pelanggan Baru');
      expect(user.isGoogleLinked, isTrue);
      expect(db.currentUser?.googleUid, 'google_uid_test_123');
    });

    test('Login with Google links existing local user by email', () {
      final db = DatabaseService();
      // admin user is Ahmad Administrator with username 'admin'
      final user = db.loginWithGoogle(
        googleUid: 'google_admin_uid',
        googleEmail: 'admin',
        displayName: 'Ahmad Admin Google',
      );

      expect(user.idUser, 1);
      expect(user.role, UserRole.administrator);
      expect(user.authProvider, AuthProvider.both);
      expect(user.googleUid, 'google_admin_uid');
      expect(db.currentUser?.role, UserRole.administrator);
    });
  });
}

