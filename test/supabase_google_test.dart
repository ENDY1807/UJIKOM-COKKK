import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_restoran/models/payment_method_model.dart';
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
      expect(SupabaseConfig.url, 'https://kzhqoowfvdyllcaewsao.supabase.co');
      expect(SupabaseConfig.publishableKey, 'sb_publishable_79_UbfbUBCxW_Q2k_oksYQ_Rh0JjjAU');
      expect(SupabaseConfig.jwksUrl, 'https://kzhqoowfvdyllcaewsao.supabase.co/auth/v1/.well-known/jwks.json');
      expect(SupabaseConfig.googleClientId, '124635820971-cn5609qedpjbrlq8f181kk6vcojp8jjk.apps.googleusercontent.com');
      expect(SupabaseConfig.googleClientSecret.isNotEmpty, isTrue);
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
        'deskripsi': 'Enak dan lezat',
      };

      final menu = MenuModel.fromMap(map);
      expect(menu.idMasakan, 1);
      expect(menu.namaMasakan, 'Nasi Goreng Spesial');
      expect(menu.kategori, MenuCategory.makanan);
      expect(menu.harga, 25000);
      expect(menu.isTersedia, isTrue);

      final toMap = menu.toMap();
      expect(toMap['id_masakan'], 1);
      expect(toMap['kategori'], 'Makanan');
    });

    test('TableModel fromMap and toMap', () {
      final map = {
        'id_meja': 1,
        'nomor_meja': 'Meja 01',
        'kapasitas': 4,
        'status_meja': 'Kosong',
      };

      final table = TableModel.fromMap(map);
      expect(table.idMeja, 1);
      expect(table.nomorMeja, 'Meja 01');
      expect(table.status, TableStatus.kosong);

      final toMap = table.toMap();
      expect(toMap['nomor_meja'], 'Meja 01');
      expect(toMap['status_meja'], 'Kosong');
    });

    test('OrderModel and OrderItemModel mapping', () {
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
      // Tambah user lokal terlebih dahulu
      db.addUser('admin', 'admin123', 'Ahmad Admin', UserRole.administrator);

      final user = db.loginWithGoogle(
        googleUid: 'google_admin_uid',
        googleEmail: 'admin',
        displayName: 'Ahmad Admin Google',
      );

      expect(user.role, UserRole.administrator);
      expect(user.authProvider, AuthProvider.both);
      expect(user.googleUid, 'google_admin_uid');
      expect(db.currentUser?.role, UserRole.administrator);
    });
  });

  group('Connected Payment Methods & Profile Security', () {
    test('Connected Payment Methods CRUD and balance deduction', () {
      final db = DatabaseService();
      expect(db.connectedPaymentMethods.isEmpty, isTrue);

      final initialCount = db.connectedPaymentMethods.length;
      db.addPaymentMethod(
        provider: PaymentMethodProvider.dana,
        accountNumber: '0812-9999-8888',
        accountName: 'Budi DANA',
        initialBalance: 300000,
        isDefault: true,
      );

      expect(db.connectedPaymentMethods.length, initialCount + 1);
      final added = db.connectedPaymentMethods.last;
      expect(added.provider, PaymentMethodProvider.dana);
      expect(added.balance, 300000);
      expect(added.isDefault, isTrue);

      // Top up
      db.topUpPaymentMethod(added.id, 50000);
      final afterTopUp = db.connectedPaymentMethods.firstWhere((p) => p.id == added.id);
      expect(afterTopUp.balance, 350000);

      // Deduct balance
      final success = db.deductPaymentMethodBalance(added.id, 100000);
      expect(success, isTrue);
      final afterDeduct = db.connectedPaymentMethods.firstWhere((p) => p.id == added.id);
      expect(afterDeduct.balance, 250000);

      // Insufficient balance
      final fail = db.deductPaymentMethodBalance(added.id, 500000);
      expect(fail, isFalse);
    });

    test('Link and unlink Google account and 2FA in profile', () {
      final db = DatabaseService();
      db.addUser('siti', 'siti123', 'Siti Pelanggan', UserRole.pelanggan);
      final user = db.users.firstWhere((u) => u.username == 'siti');

      // Link Google
      db.linkGoogleAccount(
        user.idUser,
        googleUid: 'google_siti_777',
        googleEmail: 'siti@gmail.com',
        displayName: 'Siti Google',
      );
      final linkedUser = db.users.firstWhere((u) => u.idUser == user.idUser);
      expect(linkedUser.isGoogleLinked, isTrue);
      expect(linkedUser.googleEmail, 'siti@gmail.com');

      // 2FA toggle
      db.updateTwoFactor(user.idUser, isEnabled: true, type: 'Google Authenticator');
      final user2Fa = db.users.firstWhere((u) => u.idUser == user.idUser);
      expect(user2Fa.isTwoFactorEnabled, isTrue);
      expect(user2Fa.twoFactorType, 'Google Authenticator');

      // Unlink Google
      db.unlinkGoogleAccount(user.idUser);
      final unlinkedUser = db.users.firstWhere((u) => u.idUser == user.idUser);
      expect(unlinkedUser.isGoogleLinked, isFalse);
    });
  });
}
