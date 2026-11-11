import 'package:flutter/widgets.dart';

/// Service lokalisasi dua bahasa (Bahasa Indonesia dan English) untuk Rasantara Restoran
class AppLocalization {
  static String _currentLanguage = 'id';
  static String get currentLanguage => _currentLanguage;
  static bool get isEnglish => _currentLanguage == 'en';

  static void setLanguage(String code) {
    _currentLanguage = (code == 'en') ? 'en' : 'id';
  }

  static String tr(String key) {
    final langMap = _localizedValues[_currentLanguage] ?? _localizedValues['id']!;
    return langMap[key] ?? _localizedValues['id']![key] ?? key;
  }

  static String t(String idText, String enText) {
    return isEnglish ? enText : idText;
  }

  final String languageCode;
  AppLocalization([String? code]) : languageCode = code ?? _currentLanguage;

  static const Map<String, Map<String, String>> _localizedValues = {
    'id': {
      // Navigasi Utama
      'nav_beranda': 'Beranda',
      'nav_pesan': 'Pesan',
      'nav_riwayat': 'Riwayat',
      'nav_kasir': 'Kasir',
      'nav_referensi': 'Referensi',
      'nav_laporan': 'Laporan',
      'nav_pengguna': 'Pengguna',
      'nav_akun': 'Akun',
      'nav_pengaturan': 'Pengaturan',
      'nav_keluar': 'Keluar Akun',

      // Beranda / Dashboard
      'hero_tagline': 'Cita Rasa Otentik Masakan Nusantara',
      'resto_name': 'KasirNih Resto & Cafe',
      'resto_desc': 'Nikmati hidangan warisan Nusantara dengan bumbu rempah pilihan',
      'search_hint': 'Cari menu favorit Anda...',
      'best_seller_title': 'Menu Best Seller & Rekomendasi',
      'best_seller_sub': 'Paling banyak dipesan pelanggan KasirNih',
      'kategori_title': 'Kategori Menu Pilihan',
      'kategori_sub': 'Jelajahi beragam cita rasa kuliner Nusantara',
      'voucher_title': 'Voucher & Kupon Hemat',
      'voucher_sub': 'Klaim voucher spesial pesanan Anda',
      'lihat_menu': 'Lihat Menu',
      'pakai': 'Pakai',
      'detail_pesan': 'Detail & Pesan',

      // Entri Order / Pemesanan Table Service
      'order_title': 'Entri Order (Table Service)',
      'delivery_label': 'Take Away (Pengantaran)',
      'pickup_label': 'Self Pick-Up (Ambil Sendiri)',
      'dinein_label': 'Makan di Tempat (Dine In)',
      'flash_sale_title': 'Flash Sale KasirNih',
      'flash_sale_desc': 'Diskonnya s.d. 40%, serbu hidangan lezat sekarang!',
      'cat_semua': 'Semua',
      'cat_makanan': 'Makanan',
      'cat_minuman': 'Minuman',
      'cat_paket': 'Paket',
      'cat_addon': 'Pelengkap',
      'total_pesanan': 'Total Pesanan',
      'lihat_keranjang': 'Lihat Keranjang',
      'pesan_sekarang': 'Pesan Sekarang',
      'pesan_dan_antar': 'Pesan dan antar sekarang',
      'keranjang_kosong': 'Keranjang masih kosong',
      'rincian_pesanan': 'Rincian Pesanan KasirNih',
      'pilih_alamat': 'Pilih Alamat Pengantaran',
      'alamat_saya': 'Alamat Saya',
      'peta_osm': 'Peta OSM',

      // Pelacakan Pesanan (Pantau Pesanan)
      'pantau_pesanan': 'Pantau Pesanan',
      'status_diterima': 'Pesanan Diterima Resto',
      'status_dimasak': 'Sedang Dimasak di Dapur',
      'status_diantar': 'Sedang Diantar Kurir',
      'status_selesai': 'Selesai Diterima Pelanggan',
      'lacak_driver': 'Lacak Lokasi Driver',
      'lihat_struk': 'Lihat Struk',
      'percepat': 'Percepat Simulasi',

      // Pengaturan Aplikasi
      'settings_title': 'Pengaturan',
      'tab_profil': 'Profil Akun',
      'tab_sistem': 'Sistem Aplikasi',
      'tema_title': 'Tampilan & Tema',
      'tema_terang': 'Terang',
      'tema_gelap': 'Gelap',
      'tema_sistem': 'Sistem',
      'bahasa_title': 'Bahasa Antarmuka',
      'notif_title': 'Notifikasi & Suara',
      'notif_order': 'Status Pesanan & Driver',
      'notif_promo': 'Promo & Diskon Eksklusif',
      'audio_fx': 'Efek Suara Audio',
      'haptic_fx': 'Umpan Balik Haptik (Getar)',
      'keamanan_title': 'Keamanan & Privasi',
      'biometrik_title': 'Kunci Biometrik / PIN Transaksi',
      'kebijakan_privasi': 'Kebijakan Privasi & Perlindungan Data',
      'peta_title': 'Preferensi Pemesanan & Peta',
      'peta_osm_label': 'OpenStreetMap',
      'peta_carto_label': 'Carto Positron',
      'cache_title': 'Penyimpanan & Data Cache',
      'bersihkan_cache': 'Bersihkan Cache Gambar & Data Sementara',
      'reset_default': 'Kembalikan Semua Pengaturan ke Default',
      'bantuan_title': 'Pusat Bantuan & Layanan CS',
    },
    'en': {
      // Main Navigation
      'nav_beranda': 'Home',
      'nav_pesan': 'Order',
      'nav_riwayat': 'History',
      'nav_kasir': 'Cashier',
      'nav_referensi': 'Menu Master',
      'nav_laporan': 'Reports',
      'nav_pengguna': 'Users',
      'nav_akun': 'Account',
      'nav_pengaturan': 'Settings',
      'nav_keluar': 'Sign Out',

      // Home / Dashboard
      'hero_tagline': 'Authentic Taste of Indonesian Heritage',
      'resto_name': 'KasirNih Resto & Cafe',
      'resto_desc': 'Indulge in time-honored Indonesian cuisine infused with aromatic herbs and spices',
      'search_hint': 'Search your favorite dishes...',
      'best_seller_title': 'Best Sellers & Recommendations',
      'best_seller_sub': 'Most popular dishes loved by KasirNih guests',
      'kategori_title': 'Featured Categories',
      'kategori_sub': 'Explore a diverse culinary tapestry of Indonesia',
      'voucher_title': 'Vouchers & Savings Coupons',
      'voucher_sub': 'Claim exclusive discounts for your order',
      'lihat_menu': 'View Menu',
      'pakai': 'Apply',
      'detail_pesan': 'Details & Order',

      // Order Entry
      'order_title': 'Table Service Order Entry',
      'delivery_label': 'Take Away (Delivery)',
      'pickup_label': 'Self Pick-Up',
      'dinein_label': 'Dine In (Table)',
      'flash_sale_title': 'KasirNih Flash Sale',
      'flash_sale_desc': 'Up to 40% OFF, feast on signature recipes today!',
      'cat_semua': 'All',
      'cat_makanan': 'Food',
      'cat_minuman': 'Drinks',
      'cat_paket': 'Combos',
      'cat_addon': 'Add-ons',
      'total_pesanan': 'Total Order',
      'lihat_keranjang': 'View Cart',
      'pesan_sekarang': 'Order Now',
      'pesan_dan_antar': 'Place order & deliver now',
      'keranjang_kosong': 'Your cart is still empty',
      'rincian_pesanan': 'KasirNih Order Summary',
      'pilih_alamat': 'Select Delivery Address',
      'alamat_saya': 'My Addresses',
      'peta_osm': 'OSM Map',

      // Order Tracking
      'pantau_pesanan': 'Track Order',
      'status_diterima': 'Order Received by Restaurant',
      'status_dimasak': 'Cooking in Kitchen',
      'status_diantar': 'Courier Out for Delivery',
      'status_selesai': 'Delivered to Customer',
      'lacak_driver': 'Live Driver Tracking',
      'lihat_struk': 'View Receipt',
      'percepat': 'Fast Forward Simulation',

      // Application Settings
      'settings_title': 'Settings',
      'tab_profil': 'Profile Account',
      'tab_sistem': 'System Settings',
      'tema_title': 'Theme & Appearance',
      'tema_terang': 'Light',
      'tema_gelap': 'Dark',
      'tema_sistem': 'System',
      'bahasa_title': 'Interface Language',
      'notif_title': 'Notifications & Sound',
      'notif_order': 'Order Status & Courier Alerts',
      'notif_promo': 'Exclusive Promos & Deals',
      'audio_fx': 'Audio Sound Effects',
      'haptic_fx': 'Haptic Vibrations',
      'keamanan_title': 'Security & Privacy',
      'biometrik_title': 'Biometric Lock / Transaction PIN',
      'kebijakan_privasi': 'Privacy Policy & Data Protection',
      'peta_title': 'Ordering & Map Preferences',
      'peta_osm_label': 'OpenStreetMap',
      'peta_carto_label': 'Carto Positron',
      'cache_title': 'Storage & Cache Data',
      'bersihkan_cache': 'Clear Image & Temporary Cache',
      'reset_default': 'Reset All Settings to Default',
      'bantuan_title': 'Help Center & Customer Care',
    },
  };

  String translate(String key) {
    final langMap = _localizedValues[languageCode] ?? _localizedValues['id']!;
    return langMap[key] ?? _localizedValues['id']![key] ?? key;
  }
}

extension LocalizationExtension on BuildContext {
  String tr(String key) => AppLocalization.tr(key);
  String t(String idText, String enText) => AppLocalization.t(idText, enText);
  bool get isEnglish => AppLocalization.isEnglish;
}
