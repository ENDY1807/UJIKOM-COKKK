import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_restoran/main.dart';
import 'package:kasir_restoran/models/user_model.dart';
import 'package:kasir_restoran/screens/login_screen.dart';
import 'package:kasir_restoran/screens/main_navigation_screen.dart';
import 'package:kasir_restoran/services/database_service.dart';
import 'package:kasir_restoran/services/order_simulation_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    OrderSimulationService().stop();
  });

  testWidgets('App starts on LoginScreen with Username/Email, Password, and Google OAuth',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KasirRestoranApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Verify Login Screen is displayed
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);
    expect(find.text('Username/Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
  });

  testWidgets('MainNavigationScreen renders bottom navbar on mobile',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = DatabaseService();
    // Simulate user login
    db.loginWithGoogle(
      googleUid: 'test_uid',
      googleEmail: 'pelanggan@test.com',
      displayName: 'Tamu Restoran',
    );

    await tester.pumpWidget(MaterialApp(
      home: MainNavigationScreen(
        db: db,
        onLogout: () {},
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Mobile Navigation Tabs for Pelanggan
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Entri Order'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('Test MainNavigationScreen Desktop full render',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = DatabaseService();
    // Simulate user
    db.loginWithGoogle(
      googleUid: 'google_user_123',
      googleEmail: 'pengguna.google@gmail.com',
      displayName: 'Akun Pengguna Google',
    );

    await tester.pumpWidget(MaterialApp(
      home: MainNavigationScreen(
        db: db,
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Beranda
    expect(tester.takeException(), isNull);

    // Switch to Entri Order
    await tester.tap(find.text('Entri Order'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Switch to Profil
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Test All Screens Across All Roles without exceptions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = DatabaseService();

    // Test Admin (has all screens according to UKK 2134)
    db.switchRole(UserRole.administrator);
    await tester.pumpWidget(MaterialApp(
      home: MainNavigationScreen(db: db, onLogout: () {}),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Entri Order
    await tester.tap(find.text('Entri Order'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Entri Transaksi
    await tester.tap(find.text('Entri Transaksi'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Entri Referensi
    await tester.tap(find.text('Entri Referensi'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Laporan
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Registrasi User
    await tester.tap(find.text('Registrasi User'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Profil
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
