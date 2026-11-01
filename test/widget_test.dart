import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_restoran/main.dart';
import 'package:kasir_restoran/models/user_model.dart';
import 'package:kasir_restoran/screens/login_screen.dart';
import 'package:kasir_restoran/screens/main_navigation_screen.dart';
import 'package:kasir_restoran/services/database_service.dart';
import 'package:kasir_restoran/services/order_simulation_service.dart';

void main() {
  tearDown(() {
    OrderSimulationService().stop();
  });
  testWidgets('App starts on LoginScreen with Google OAuth and Register toggle',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KasirRestoranApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Login Screen is displayed
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);

    // Verify Toggle Register
    expect(find.text('Belum punya akun? Daftar'), findsOneWidget);
  });

  testWidgets('MainNavigationScreen renders DANA-style bottom navbar on mobile',
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

    // Verify DANA floating PINDAI button
    expect(find.text('PINDAI'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
  });

  testWidgets('Test MainNavigationScreen Desktop full render',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = DatabaseService();
    // Simulate user exactly as shown in screenshot
    db.loginWithGoogle(
      googleUid: 'google_user_123',
      googleEmail: 'pengguna.google@gmail.com',
      displayName: 'Akun Pengguna Google',
    );

    // Also simulate Supabase dishes & orders if any
    await tester.pumpWidget(MaterialApp(
      home: MainNavigationScreen(
        db: db,
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Beranda
    expect(tester.takeException(), isNull);

    // Switch to Pesan Menu
    await tester.tap(find.text('Pesan Menu'));
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

    // Test Admin (has all screens)
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

    // Kasir & Tagihan
    await tester.tap(find.text('Kasir & Tagihan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Referensi Menu
    await tester.tap(find.text('Referensi Menu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Laporan
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Kelola User
    await tester.tap(find.text('Kelola User'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // QR Meja
    await tester.tap(find.text('QR Meja'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Profil
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
