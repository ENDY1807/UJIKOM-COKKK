# KasirNih Rebranding and Waiter-First Ordering System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the application into **KasirNih**: transparent squircle logo, remove table QR/scan features, enforce waiter-assisted table ordering for regular customers while allowing VIP subscribed customers to self-order, upgrade loading screen, refine login/OTP, and apply anti-slop frontend design principles.

---

### Task 1: Logo Extraction & Transparent Asset Generation
- [ ] Write and run a PowerShell script using `System.Drawing.Bitmap` to process `media_1794403226402_03d62910.jpg`, removing the outer white background around the orange rounded rectangle.
- [ ] Save the transparent PNG to `assets/images/logo.png` and `assets/images/kasirnih_logo.png`.
- [ ] Generate Android launcher icons across `android/app/src/main/res/mipmap-*` (`ic_launcher.png`).
- [ ] Verify generated images exist and have transparency.

### Task 2: Rebranding to KasirNih Across the Project
- [ ] Update `android/app/src/main/AndroidManifest.xml` (`android:label="KasirNih"`).
- [ ] Update `web/index.html` title and meta tags to "KasirNih".
- [ ] Update `lib/main.dart` MaterialApp title to "KasirNih".
- [ ] Update app headers, brand badges, and titles across screens from "Rasantara" to "KasirNih".

### Task 3: Removal of Table QR & Table QR Scanner Features
- [ ] Delete `lib/screens/reference/table_qr_screen.dart`.
- [ ] Delete `lib/screens/order/qr_scanner_dialog.dart`.
- [ ] Remove `TableQrScreen` and `QrScannerDialog` imports and destinations in `lib/screens/main_navigation_screen.dart`.
- [ ] Redesign bottom navigation bar in `lib/screens/main_navigation_screen.dart`: remove the center "PINDAI" button; implement a clean, accessible 4-to-5 tab bar tailored to the active user role.
- [ ] Remove QR scanner quick button from desktop sidebar.

### Task 4: Subscription-Aware Login & Waiter-Assisted Ordering Architecture
- [ ] Update `UserModel` in `lib/models/user_model.dart`:
  - Add `final bool isSubscribed;`
  - Update `toMap()`, `fromMap()`, `copyWith()`.
- [ ] Update `DatabaseService` in `lib/services/database_service.dart`:
  - Add default mock users with subscription statuses: regular customer (`isSubscribed: false`) and VIP customer (`isSubscribed: true`).
  - In `login()` and `loginAsync()`: If `user.role == UserRole.pelanggan && !user.isSubscribed`, reject login with:
    `"Akun Anda adalah Pelanggan Reguler. Pemesanan mandiri hanya untuk Pelanggan Berlangganan (VIP). Silakan pesan melalui Waiter di meja Anda."`
- [ ] In `OrderEntryScreen` (`lib/screens/order/order_entry_screen.dart`):
  - Ensure Waiter role can easily select Table Numbers (Meja 1-20) from an intuitive selector when taking orders at tables.
  - Submitting order routes directly to active orders for Kasir / Kitchen billing.
- [ ] In `LoginScreen` (`lib/screens/login_screen.dart`):
  - Display clear explanation if non-subscribed customer attempts login.
  - Polish Username/Email input and Google Sign-In handling.

### Task 5: Redesign Loading & Splash Screen (Anti-Slop Craft)
- [ ] Redesign `SplashScreen` / initial app loader in `lib/main.dart` (or dedicated splash widget):
  - Clean, focused layout featuring the new KasirNih logo.
  - High-contrast typography, subtle status text, and swift transition without artificial delays.

### Task 6: Cleanup of Unused Files & Code Hygiene
- [ ] Inspect workspace for obsolete scripts, unused mockups, or dangling assets.
- [ ] Remove unused imports across modified files.

### Task 7: Verification and Git Push
- [ ] Run `flutter analyze` to verify zero compile errors or warnings.
- [ ] Verify `git diff` confirms all requirements met.
- [ ] Commit all changes without emojis.
- [ ] Push to `origin main` to trigger GitHub Actions Android build.
