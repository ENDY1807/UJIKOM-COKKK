import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_restoran/main.dart';
import 'package:kasir_restoran/screens/login_screen.dart';

void main() {
  testWidgets('App renders Dashboard with live metrics & Table Floor Map',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KasirRestoranApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Brand Title & Dashboard elements
    expect(find.text('Restoran Nusantara'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Meja Terisi'), findsOneWidget);
    expect(find.text('Pesanan Aktif'), findsOneWidget);
    expect(find.text('Denah Meja Restoran (Table Floor Map)'), findsOneWidget);
  });

  testWidgets('Logout flow navigates to responsive Login Screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KasirRestoranApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Find and tap logout button
    final logoutBtn = find.byTooltip('Keluar');
    expect(logoutBtn, findsOneWidget);
    await tester.tap(logoutBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Login Screen is displayed
    expect(find.byType(LoginScreen), findsOneWidget);

    // Verify Supabase Cloud status badge is removed from login screen
    expect(find.textContaining('Supabase Cloud Aktif'), findsNothing);
    expect(find.textContaining('Supabase Offline'), findsNothing);

    // Verify Google OAuth button is present
    expect(find.text('Masuk dengan Google'), findsOneWidget);

    // Verify Toggle Mode button works smoothly
    final toggleBtn = find.text('Belum punya akun? Daftar');
    expect(toggleBtn, findsOneWidget);
    await tester.tap(toggleBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));

    // After animation, register form elements should be active
    expect(find.text('Daftar Akun'), findsOneWidget);
    expect(find.text('Sudah punya akun? Masuk'), findsOneWidget);
  });
}
