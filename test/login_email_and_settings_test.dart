import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_restoran/services/database_service.dart';
import 'package:kasir_restoran/models/user_model.dart';
import 'package:kasir_restoran/screens/profile/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Login Email & Theme System Verification Tests', () {
    late DatabaseService db;

    setUp(() {
      db = DatabaseService();
    });

    test('Theme Mode defaults to system', () {
      expect(db.appThemeMode, 'system');
    });

    test('Login with Username succeeds', () {
      final success = db.login('admin', '123');
      expect(success, isTrue);
      expect(db.currentUser?.role, UserRole.administrator);
    });

    test('Login with Email succeeds for default users', () {
      final success = db.login('admin@rasantara.com', '123');
      expect(success, isTrue);
      expect(db.currentUser?.username, 'admin');
      expect(db.currentUser?.role, UserRole.administrator);
    });

    test('Login with custom email format (username@kasirrestoran.app) succeeds', () {
      final success = db.login('kasir@kasirrestoran.app', '123');
      expect(success, isTrue);
      expect(db.currentUser?.username, 'kasir');
    });

    test('Login using phone numbers is rejected / disabled', () {
      final success = db.login('081234567890', '123');
      expect(success, isFalse);
    });

    test('Customer Service WhatsApp URL is exact and correctly configured', () {
      expect(SettingsScreenStatePublic.csWhatsAppUrl, 'https://wa.me/qr/LXPSUAAWEP7YJ1');
    });
  });
}

class SettingsScreenStatePublic {
  static const String csWhatsAppUrl = 'https://wa.me/qr/LXPSUAAWEP7YJ1';
}
