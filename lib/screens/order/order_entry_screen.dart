import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../models/menu_model.dart';
import '../../models/order_model.dart';
import '../../models/payment_method_model.dart';
import '../../services/database_service.dart';
import '../../widgets/osm_map_widget.dart';
import '../../widgets/qris_payment_dialog.dart';
import '../../widgets/va_payment_dialog.dart';
import '../../widgets/snap_payment_dialog.dart';
import '../../widgets/menu_detail_dialog.dart';
import '../profile/manage_addresses_screen.dart';
import 'gofood_tracking_dialog.dart';
import 'qr_scanner_dialog.dart';
import '../../widgets/app_loading_animation.dart';
import '../../widgets/biometric_auth_dialog.dart';
import '../../services/audio_notification_service.dart';
import '../../theme/app_theme.dart';

enum OrderServiceType {
  dineIn('Makan di Tempat', Icons.table_restaurant_rounded),
  takeAway('Take Away', Icons.delivery_dining_rounded),
  selfPickUp('Self Pick-Up', Icons.shopping_bag_outlined);

  final String label;
  final IconData icon;
  const OrderServiceType(this.label, this.icon);

  String localizedLabel(bool isEnglish) {
    switch (this) {
      case OrderServiceType.dineIn:
        return isEnglish ? 'Dine In' : 'Makan di Tempat';
      case OrderServiceType.takeAway:
        return 'Take Away';
      case OrderServiceType.selfPickUp:
        return isEnglish ? 'Self Pick-Up' : 'Self Pick-Up';
    }
  }
}

class OrderEntryScreen extends StatefulWidget {
  final DatabaseService db;
  final String? initialTableNo;
  final MenuCategory? initialCategory;
  final String? initialSearch;
  final String? initialCoupon;
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onOrderSubmitted;

  const OrderEntryScreen({
    super.key,
    required this.db,
    this.initialTableNo,
    this.initialCategory,
    this.initialSearch,
    this.initialCoupon,
    this.onNavigateToTab,
    this.onOrderSubmitted,
  });

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  // ── Mode Layanan Pemesanan ──
  OrderServiceType _serviceType = OrderServiceType.takeAway;

  // Form Fields
  final _customerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _orderNotesController = TextEditingController();
  final _searchController = TextEditingController();

  // Dine-In Specifics
  String? _selectedTableNo;

  // Delivery Specifics (GoFood OpenStreetMap)
  int _deliveryFee = 8000;
  double _deliveryDistanceKm = 2.4;
  String _deliveryEstimatedTime = '20 - 30 Menit';
  Position? _currentPosition;
  bool _isLoadingGps = false;

  // Filter & Search
  MenuCategory _selectedCategory = MenuCategory.semua;
  String _searchQuery = '';

  // Local Cart State: idMasakan -> OrderItemModel
  final Map<int, OrderItemModel> _cart = {};

  // Metode Pembayaran Terpilih
  String _selectedPaymentMethodId = 'dana_default';

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final defPay = widget.db.defaultPaymentMethod;
    if (defPay != null) {
      _selectedPaymentMethodId = defPay.id;
    } else if (widget.db.connectedPaymentMethods.isNotEmpty) {
      _selectedPaymentMethodId = widget.db.connectedPaymentMethods.first.id;
    } else {
      _selectedPaymentMethodId = 'qris';
    }

    final user = widget.db.currentUser;
    if (user != null) {
      _customerNameController.text = user.namaUser;
      if (user.googleEmail != null && user.googleEmail!.isNotEmpty) {
        _phoneController.text = '';
      }
    } else {
      _customerNameController.text = '';
    }

    if (widget.initialTableNo != null && widget.initialTableNo!.isNotEmpty) {
      _selectedTableNo = widget.initialTableNo;
      _serviceType = OrderServiceType.dineIn;
    } else {
      _selectedTableNo = null;
      _serviceType = OrderServiceType.takeAway;
    }

    // Restore alamat take away persisten (tidak akan reset)
    final savedAddr = widget.db.savedTakeAwayAddress;
    if (savedAddr.isNotEmpty) {
      _deliveryAddressController.text = savedAddr;
    } else if (widget.db.primaryAddress != null) {
      _deliveryAddressController.text = widget.db.primaryAddress!.formattedFullAddress;
    }

    // Terapkan filter kategori, search, dan kupon dari navigasi
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchController.text = widget.initialSearch!;
      _searchQuery = widget.initialSearch!;
    }
    if (widget.initialCoupon != null && widget.initialCoupon!.isNotEmpty) {
      _applyCoupon(widget.initialCoupon!);
    }
  }

  @override
  void didUpdateWidget(covariant OrderEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTableNo != null &&
        widget.initialTableNo!.isNotEmpty &&
        widget.initialTableNo != oldWidget.initialTableNo) {
      setState(() {
        _selectedTableNo = widget.initialTableNo;
        _serviceType = OrderServiceType.dineIn;
      });
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _deliveryAddressController.dispose();
    _orderNotesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Multi-Kupon Promo, Event & Poin Loyalitas ──
  int? _selectedEventId;
  final Set<String> _appliedCoupons = {};
  bool _usePointsDiscount = false;
  final TextEditingController _couponInputCtrl = TextEditingController();
  String? _couponStatusMsg;

  int _calcDiscountForCoupon(String code) {
    final clean = code.trim().toUpperCase();
    if (clean == 'RASANTARA30') {
      // Diskon 30% s.d. Rp 30.000
      return (_cartTotalHarga * 0.30).round().clamp(0, 30000);
    } else if (clean == 'HEMAT15K') {
      // Potongan langsung Rp 15.000
      return 15000.clamp(0, _cartTotalHarga);
    } else if (clean == 'BEBASONGKIR') {
      // Bebas ongkir pengantaran (Rp 10.000)
      return _currentDeliveryFee.clamp(0, 10000);
    } else if (clean == 'RASANTARA10') {
      // Kupon Event 10% s.d. Rp 25.000
      return (_cartTotalHarga * 0.10).round().clamp(0, 25000);
    } else if (clean == 'DISKONMEMBER') {
      // Kupon Member Spesial Rp 15.000
      return 15000.clamp(0, _cartTotalHarga);
    } else if (clean == 'HEMAT20') {
      // Pesta Kuliner 20% s.d. Rp 30.000
      return (_cartTotalHarga * 0.20).round().clamp(0, 30000);
    } else if (clean == 'MAKANENAK') {
      // Santap Nikmat Rp 10.000
      return 10000.clamp(0, _cartTotalHarga);
    }
    return 0;
  }

  int get _couponDiscount {
    int total = 0;
    for (final code in _appliedCoupons) {
      total += _calcDiscountForCoupon(code);
    }
    return total.clamp(0, _cartTotalHarga + _currentDeliveryFee);
  }

  String get _couponCode => _appliedCoupons.join(', ');

  int get _diskonEventAmount {
    if (_selectedEventId == null) return 0;
    final match = widget.db.events.where((e) => e.idEvent == _selectedEventId).firstOrNull;
    if (match != null && match.diskonPersen > 0) {
      return (_cartTotalHarga * (match.diskonPersen / 100)).round();
    }
    return 0;
  }

  int get _potonganPoinAmount {
    if (!_usePointsDiscount) return 0;
    final remainingCost = (_cartTotalHarga - _diskonEventAmount - _couponDiscount).clamp(0, _cartTotalHarga);
    // 1 Poin = Potongan Rp 1 (sesuai poin pelanggan, bukan ribuan)
    return widget.db.userPoints.clamp(0, remainingCost);
  }

  // ── Perhitungan Keranjang Belanja ──
  int get _cartTotalHarga => _cart.values.fold(0, (sum, i) => sum + i.subtotal);
  int get _cartTotalItems => _cart.values.fold(0, (sum, i) => sum + i.jumlah);
  int get _packagingFee => (_serviceType != OrderServiceType.dineIn) ? 2000 : 0;
  int get _currentDeliveryFee => (_serviceType == OrderServiceType.takeAway) ? _deliveryFee : 0;
  int get _grandTotal {
    final raw = _cartTotalHarga + _packagingFee + _currentDeliveryFee - _diskonEventAmount - _couponDiscount - _potonganPoinAmount;
    return raw > 0 ? raw : 0;
  }

  void _clearCoupons() {
    _appliedCoupons.clear();
    _couponStatusMsg = null;
    _couponInputCtrl.clear();
  }

  void _toggleCoupon(String code, {bool? forceAdd}) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;

    final validCodes = [
      'RASANTARA30',
      'HEMAT15K',
      'BEBASONGKIR',
      'RASANTARA10',
      'DISKONMEMBER',
      'HEMAT20',
      'MAKANENAK',
    ];

    if (!validCodes.contains(clean)) {
      _couponStatusMsg = 'Kode kupon "$code" tidak terdaftar';
      return;
    }

    if (forceAdd == true) {
      _appliedCoupons.add(clean);
      _couponStatusMsg = 'Kupon $clean berhasil diterapkan (${_appliedCoupons.length} kupon aktif)';
      return;
    }

    if (_appliedCoupons.contains(clean)) {
      _appliedCoupons.remove(clean);
      _couponStatusMsg = 'Kupon $clean dinonaktifkan';
    } else {
      _appliedCoupons.add(clean);
      _couponStatusMsg = 'Kupon $clean diterapkan (${_appliedCoupons.length} kupon aktif)';
    }
  }

  void _applyCoupon(String code) {
    _toggleCoupon(code, forceAdd: true);
  }

  // ── Mutasi Keranjang ──
  void _addToCart(MenuModel menu) {
    if (!menu.isTersedia) return;
    if (_serviceType == OrderServiceType.dineIn &&
        (_selectedTableNo == null || _selectedTableNo!.isEmpty)) {
      _showScanRequiredDialog();
      return;
    }
    setState(() {
      if (_cart.containsKey(menu.idMasakan)) {
        _cart[menu.idMasakan]!.jumlah += 1;
      } else {
        _cart[menu.idMasakan] = OrderItemModel(
          idDetailOrder: DateTime.now().millisecondsSinceEpoch + menu.idMasakan,
          menu: menu,
          jumlah: 1,
        );
      }
    });
  }

  void _showScanRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Scan QR Meja Diperlukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Untuk pesanan Makan di Tempat, Anda wajib memindai QR Code yang berada di atas meja makan Anda terlebih dahulu.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            SizedBox(height: 10),
            Text(
              'Arahkan kamera ke QR Meja untuk membuka akses pemilihan hidangan.',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _scanTableQr();
            },
            icon: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text('Pindai QR Meja Sekarang'),
          ),
        ],
      ),
    );
  }

  void _decrementCart(MenuModel menu) {
    setState(() {
      if (_cart.containsKey(menu.idMasakan)) {
        if (_cart[menu.idMasakan]!.jumlah > 1) {
          _cart[menu.idMasakan]!.jumlah -= 1;
        } else {
          _cart.remove(menu.idMasakan);
        }
      }
    });
  }

  void _setItemNote(int idMasakan, String note) {
    setState(() {
      if (_cart.containsKey(idMasakan)) {
        _cart[idMasakan]!.catatan = note;
      }
    });
  }

  // ── Fitur Lokasi GPS (OpenStreetMap Nominatim) ──
  Future<void> _getUserLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Layanan GPS pada perangkat belum aktif. Harap aktifkan GPS.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin akses lokasi ditolak.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak permanen. Buka setelan perangkat untuk mengizinkan.';
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      _currentPosition = position;
      final lat = position.latitude.toStringAsFixed(5);
      final lng = position.longitude.toStringAsFixed(5);

      String detectedAddress = 'Titik GPS: $lat, $lng';
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
        );
        final response = await http
            .get(url, headers: {'User-Agent': 'RasantaraRestoApp/1.0'})
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final displayName = data['display_name'];
          if (displayName != null && displayName.toString().isNotEmpty) {
            detectedAddress = displayName.toString();
          }
        }
      } catch (_) {}

      setState(() {
        _deliveryAddressController.text = detectedAddress;
      });
      widget.db.saveTakeAwayAddress(
        detectedAddress,
        lat: position.latitude,
        lng: position.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('Lokasi berhasil dideteksi: $lat, $lng'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Gagal membaca GPS: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  // ── Dialog Pemilih Peta OSM ──
  void _openOsmMapPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OsmMapWidget(
        initialLat: _currentPosition?.latitude ?? -6.2088,
        initialLng: _currentPosition?.longitude ?? 106.8456,
        onLocationSelected: (result) {
          setState(() {
            _deliveryAddressController.text = result.formattedAddress;
            _deliveryFee = result.deliveryFee;
            _deliveryDistanceKm = result.distanceKm;
            _deliveryEstimatedTime = result.estimatedTime;
          });
          widget.db.saveTakeAwayAddress(
            result.formattedAddress,
            lat: result.latitude,
            lng: result.longitude,
          );
        },
      ),
    );
  }

  // ── Scan QR Code Meja ──
  Future<void> _scanTableQr() async {
    final result = await QrScannerDialog.show(context);
    if (result != null && result.isNotEmpty) {
      setState(() {
        _serviceType = OrderServiceType.dineIn;
        _selectedTableNo = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEA580C),
            content: Text('QR Meja Terbaca: $result. Silakan pilih hidangan favorit.'),
          ),
        );
      }
    }
  }

  // ── Konfirmasi dan Submit Pesanan ──
  Future<void> _confirmAndSubmitOrder({String? paymentMethodId}) async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong, pilih menu terlebih dahulu.')),
      );
      return;
    }

    if (_serviceType == OrderServiceType.dineIn &&
        (_selectedTableNo == null || _selectedTableNo!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan scan QR Meja Anda terlebih dahulu untuk pesanan Makan di Tempat.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      _scanTableQr();
      return;
    }

    if (_serviceType == OrderServiceType.takeAway &&
        _deliveryAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat pengantaran belum diisi. Pilih di peta OSM atau ketik alamat.')),
      );
      return;
    }

    final payId = paymentMethodId ?? _selectedPaymentMethodId;
    ConnectedPaymentMethod? connectedMethod;
    String paymentMethodName = 'Tunai';

    if (payId == 'saldo_rasantara') {
      if (widget.db.userBalance < _grandTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text(
              'Saldo Akun Rasantara tidak mencukupi (${_currencyFmt.format(widget.db.userBalance)} < ${_currencyFmt.format(_grandTotal)}). Harap Top Up terlebih dahulu.',
            ),
          ),
        );
        return;
      }
      paymentMethodName = 'Saldo Rasantara';
    } else if (payId == 'dana') {
      paymentMethodName = 'DANA (Direct Debit)';
    } else if (payId == 'gopay') {
      paymentMethodName = 'GoPay';
    } else if (payId == 'm_banking') {
      paymentMethodName = 'M-Banking Virtual Account';
    } else if (payId == 'qris') {
      paymentMethodName = 'QRIS Dinamis';
    } else if (payId == 'tunai') {
      paymentMethodName = 'Tunai Kasir';
    } else {
      connectedMethod = widget.db.connectedPaymentMethods
          .where((p) => p.id == payId)
          .firstOrNull;
      if (connectedMethod != null) {
        if (connectedMethod.balance < _grandTotal) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDC2626),
              content: Text(
                'Saldo ${connectedMethod.displayName} tidak mencukupi (${_currencyFmt.format(connectedMethod.balance)} < ${_currencyFmt.format(_grandTotal)}). Harap Top Up di Menu Manage Payments.',
              ),
            ),
          );
          return;
        }
        paymentMethodName = '${connectedMethod.provider.label} (${connectedMethod.maskedNumber})';
      }
    }

    // Proteksi Keamanan Kunci Biometrik / PIN Transaksi jika diaktifkan di Pengaturan
    if (widget.db.appBiometricAuth) {
      final isAuth = await BiometricAuthDialog.authenticate(
        context: context,
        title: 'Verifikasi Pembayaran Pesanan',
        reason: 'Otorisasi sidik jari atau PIN diperlukan untuk memproses pesanan Anda.',
        amountFormatted: _currencyFmt.format(_grandTotal),
      );
      if (!isAuth) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran dibatalkan: Otorisasi biometrik / PIN ditolak.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    final custName = _customerNameController.text.trim().isEmpty
        ? 'Pelanggan'
        : _customerNameController.text.trim();
    final phone = _phoneController.text.trim();
    final userNotes = _orderNotesController.text.trim();

    String tableIdentifier;
    String fullOrderNotes;

    switch (_serviceType) {
      case OrderServiceType.dineIn:
        tableIdentifier = _selectedTableNo ?? 'Meja 01';
        fullOrderNotes = 'Dine-In ($tableIdentifier)${userNotes.isNotEmpty ? ' | Catatan: $userNotes' : ''}';
        break;
      case OrderServiceType.takeAway:
        tableIdentifier = 'Take Away (Antar)';
        final address = _deliveryAddressController.text.trim();
        fullOrderNotes =
            'Take Away: $address | Jarak: ${_deliveryDistanceKm.toStringAsFixed(1)}km | Ongkir: Rp $_deliveryFee${phone.isNotEmpty ? ' | Kontak: $phone' : ''}${userNotes.isNotEmpty ? ' | Driver: $userNotes' : ''}';
        break;
      case OrderServiceType.selfPickUp:
        tableIdentifier = 'Self Pick-Up (Counter)';
        fullOrderNotes =
            'Self Pick-Up di Counter${phone.isNotEmpty ? ' | Kontak: $phone' : ''}${userNotes.isNotEmpty ? ' | Catatan: $userNotes' : ''}';
        break;
    }

    // Hitung diskon yang diterapkan
    final effDiskonEvent = _diskonEventAmount;
    final effDiskonKupon = _couponDiscount;
    final effPotonganPoin = _potonganPoinAmount;
    final effKodeKupon = _couponCode.isNotEmpty ? _couponCode : null;

    // Buat order di database
    final order = widget.db.createOrder(
      noMeja: tableIdentifier,
      namaPelanggan: custName,
      keterangan: fullOrderNotes,
      items: _cart.values.toList(),
      diskonEvent: effDiskonEvent,
      diskonKupon: effDiskonKupon,
      potonganPoin: effPotonganPoin,
      kodeKupon: effKodeKupon,
    );

    // Potong poin jika digunakan (1 poin = Rp 1)
    if (effPotonganPoin > 0) {
      widget.db.deductPoints(effPotonganPoin);
    }

    // Jika dibayar dengan Saldo Rasantara
    if (payId == 'saldo_rasantara') {
      widget.db.deductBalance(
        _grandTotal,
        orderRef: 'ORD-${order.idOrder}',
        notes: 'Pesanan #${order.idOrder} ($tableIdentifier)',
      );
      widget.db.processTransaction(
        order: order,
        jumlahBayar: _grandTotal,
        metodePembayaran: paymentMethodName,
        diskonEvent: effDiskonEvent,
        diskonKupon: effDiskonKupon,
        potonganPoin: effPotonganPoin,
        kodeKupon: effKodeKupon,
      );
    } else if (connectedMethod != null) {
      // Jika dibayar dengan metode terkoneksi (DANA, GoPay, M-Banking), potong saldo dan catat transaksi lunas
      widget.db.deductPaymentMethodBalance(
        connectedMethod.id,
        _grandTotal,
        orderRef: 'ORD-${order.idOrder}',
        notes: 'Pesanan #${order.idOrder} ($tableIdentifier)',
      );
      widget.db.processTransaction(
        order: order,
        jumlahBayar: _grandTotal,
        metodePembayaran: paymentMethodName,
        diskonEvent: effDiskonEvent,
        diskonKupon: effDiskonKupon,
        potonganPoin: effPotonganPoin,
        kodeKupon: effKodeKupon,
      );
    }

    final savedAddress = _deliveryAddressController.text.trim();
    final savedDeliveryFee = _deliveryFee;
    final savedEstTime = _deliveryEstimatedTime;
    final isDeliveryOrder = _serviceType == OrderServiceType.takeAway;
    final grandTotalFinal = _grandTotal;

    if (savedAddress.isNotEmpty) {
      widget.db.saveTakeAwayAddress(savedAddress);
    }

    // Mainkan efek audio pesanan diterima
    AudioNotificationService().playOrderReceivedSound(enabled: widget.db.appSoundFx);

    // Kirim notifikasi sistem langsung ke Windows / HP
    if (widget.db.appNotifications) {
      AudioNotificationService.showSystemNotification(
        title: 'Pesanan Diterima Restoran #${order.idOrder}',
        message: 'Koki dapur Rasantara mulai menyiapkan hidangan pesanan Anda.',
      );
    }

    setState(() {
      _cart.clear();
      _orderNotesController.clear();
      // Alamat take away TIDAK di-clear agar tersimpan terus dan tidak reset
      _selectedTableNo = null; // Reset QR Meja ke awal
      _serviceType = OrderServiceType.takeAway; // Kembali ke tampilan awal (Take Away & Self Pick-Up)
    });

    if (!mounted) return;
    AppLoadingAnimation.show(context, message: 'Menyiapkan transaksi pesanan...');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    AppLoadingAnimation.hide(context);

    // 1. Jika metode QRIS, buka dialog pembayaran QRIS Midtrans
    if (payId == 'qris') {
      QrisPaymentDialog.show(
        context,
        order: order,
        totalAmount: grandTotalFinal,
        db: widget.db,
        onPaymentSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF16A34A),
              content: Text('Pembayaran QRIS sukses diterima! Pesanan diproses.'),
            ),
          );
          widget.onOrderSubmitted?.call();
          widget.onNavigateToTab?.call(0);
        },
      );
      return;
    }

    // 2. Jika metode M-Banking, buka dialog Virtual Account Midtrans
    if (payId == 'm_banking') {
      VirtualAccountPaymentDialog.show(
        context,
        order: order,
        totalAmount: grandTotalFinal,
        db: widget.db,
        onPaymentSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF16A34A),
              content: Text('Pembayaran Virtual Account terverifikasi lunas!'),
            ),
          );
          widget.onOrderSubmitted?.call();
          widget.onNavigateToTab?.call(0);
        },
      );
      return;
    }

    // 3. Jika metode DANA atau GoPay, buka dialog Midtrans Snap E-Wallet
    if (payId == 'dana' || payId == 'gopay') {
      SnapPaymentDialog.show(
        context,
        order: order,
        totalAmount: grandTotalFinal,
        providerName: payId == 'dana' ? 'DANA' : 'GoPay',
        db: widget.db,
        onPaymentSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text('Pembayaran ${payId.toUpperCase()} sukses diproses!'),
            ),
          );
          widget.onOrderSubmitted?.call();
          widget.onNavigateToTab?.call(0);
        },
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF16A34A),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isDeliveryOrder
                  ? 'Pesanan Take Away Diterima!'
                  : (_serviceType == OrderServiceType.selfPickUp
                      ? 'Pesanan Self Pick-Up Disiapkan!'
                      : 'Pesanan Meja Diteruskan!'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Nomor Pesanan: #${order.idOrder}\n${order.noMeja}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${order.totalItem} Item Hidangan',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                      Text(
                        _currencyFmt.format(order.totalHarga),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Metode Bayar:',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      Text(
                        paymentMethodName,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.textPrimary),
                      ),
                    ],
                  ),
                  if (connectedMethod != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Saldo ${connectedMethod.provider.label} terpotong ${_currencyFmt.format(_grandTotal)} (Sisa: ${_currencyFmt.format(connectedMethod.balance)})',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isDeliveryOrder)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEA580C),
                side: const BorderSide(color: Color(0xFFEA580C)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delivery_dining, size: 18),
              label: const Text('Lacak Pesanan (GoFood)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(ctx).pop();
                GoFoodTrackingDialog.show(
                  context,
                  order: order,
                  destinationAddress: savedAddress.isNotEmpty ? savedAddress : 'Alamat Pemesan',
                  deliveryFee: savedDeliveryFee,
                  estimatedTime: savedEstTime,
                );
              },
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.timeline_rounded, size: 16),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onOrderSubmitted?.call();
              widget.onNavigateToTab?.call(0);
            },
            label: const Text('Lihat Proses Pesanan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Modal Detail Catatan Item Menu ──
  void _openItemNoteDialog(OrderItemModel item) {
    final noteController = TextEditingController(text: item.catatan);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Catatan: ${item.menu.namaMasakan}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: noteController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Masukkan Catatan Pesanan',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () {
              _setItemNote(item.menu.idMasakan, noteController.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── Modal Detail Menu Lengkap (Gizi, Kalori, Bahan & Alergen) ──
  void _openMenuDetail(MenuModel menu) {
    final currentQty = _cart[menu.idMasakan]?.jumlah ?? 0;
    final currentNote = _cart[menu.idMasakan]?.catatan;

    MenuDetailDialog.show(
      context,
      menu: menu,
      initialQty: currentQty > 0 ? currentQty : 1,
      initialNote: currentNote,
      onConfirm: (quantity, note) {
        setState(() {
          if (quantity <= 0) {
            _cart.remove(menu.idMasakan);
          } else {
            _cart[menu.idMasakan] = OrderItemModel(
              idDetailOrder: _cart[menu.idMasakan]?.idDetailOrder ?? 0,
              menu: menu,
              jumlah: quantity,
              catatan: note,
            );
          }
        });
      },
    );
  }

  // ── Helper Tile Pilihan Pembayaran Vertikal ──
  Widget _buildPaymentRadioTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? (context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFF7ED))
              : context.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFEA580C) : context.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Sheet Ringkasan Keranjang & Checkout ──
  void _openCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final availableCouponsList = [
            {'code': 'RASANTARA30', 'tag': '30% OFF', 'label': 'Pesta Rasa Akhir Pekan', 'desc': 'Diskon 30% s.d. Rp 30.000'},
            {'code': 'HEMAT15K', 'tag': 'Rp 15RB', 'label': 'Diskon Pelanggan Setia', 'desc': 'Potongan langsung Rp 15.000'},
            {'code': 'BEBASONGKIR', 'tag': 'GRATIS', 'label': 'Bebas Ongkir Pengantaran', 'desc': 'Gratis ongkir s.d. Rp 10.000'},
            {'code': 'DISKONMEMBER', 'tag': 'MEMBER', 'label': 'Kupon Member Spesial', 'desc': 'Potongan langsung Rp 15.000'},
            {'code': 'HEMAT20', 'tag': '20% OFF', 'label': 'Pesta Kuliner 20%', 'desc': 'Diskon 20% s.d. Rp 30.000'},
            {'code': 'MAKANENAK', 'tag': 'Rp 10RB', 'label': 'Kupon Santap Nikmat', 'desc': 'Potongan langsung Rp 10.000'},
          ];

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: Column(
              children: [
                // Header (Fixed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rincian Pesanan Rasantara',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _serviceType.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFEA580C),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                // Scrollable Body (Mencegah seluruh bug overflow layar)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // GoFood Address & Delivery Instruction Card (Inspirasi Gojek)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFF7ED),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.location_on_rounded, color: Color(0xFFEA580C), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _serviceType == OrderServiceType.takeAway
                                              ? (_deliveryAddressController.text.isNotEmpty ? _deliveryAddressController.text : 'Pilih Alamat Pengantaran')
                                              : (_serviceType == OrderServiceType.dineIn
                                                  ? 'Makan di Meja Restoran (${_selectedTableNo ?? "Pilih Meja"})'
                                                  : 'Ambil Sendiri di Resto (Self Pick-Up)'),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _serviceType == OrderServiceType.takeAway
                                              ? (_deliveryDistanceKm > 0 ? '${_deliveryDistanceKm.toStringAsFixed(1)} km • $_deliveryEstimatedTime' : 'Pilih titik lokasi presisi di peta OSM')
                                              : 'Rasantara Kuliner Nusantara',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEA580C),
                                      side: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      if (_serviceType == OrderServiceType.takeAway) {
                                        _openOsmMapPicker();
                                      } else {
                                        _scanTableQr();
                                      }
                                    },
                                    child: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              if (_serviceType == OrderServiceType.takeAway) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                const SizedBox(height: 10),
                                const Text(
                                  'Instruksi Pengantaran Driver:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      'Tinggal di pintu',
                                      'Tinggal di pagar',
                                      'Titipkan satpam',
                                      'Chat pas sampai',
                                    ].map((instruction) {
                                      final isSelected = _orderNotesController.text.contains(instruction);
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          label: Text(instruction),
                                          selected: isSelected,
                                          selectedColor: const Color(0xFFFFF7ED),
                                          labelStyle: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                                          ),
                                          onSelected: (val) {
                                            setModalState(() {
                                              if (val) {
                                                _orderNotesController.text = _orderNotesController.text.isEmpty
                                                    ? instruction
                                                    : '${_orderNotesController.text}, $instruction';
                                              } else {
                                                _orderNotesController.text = _orderNotesController.text
                                                    .replaceAll(', $instruction', '')
                                                    .replaceAll(instruction, '')
                                                    .trim();
                                              }
                                            });
                                            setState(() {});
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 1. DAFTAR ITEM PESANAN
                        const Text(
                          'Menu yang Dipesan:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        if (_cart.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Keranjang pesanan kosong',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cart.values.length,
                            separatorBuilder: (context, index) => const Divider(height: 16),
                            itemBuilder: (c, idx) {
                              final item = _cart.values.elementAt(idx);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item.menu.gambarUrl.isNotEmpty
                                        ? Image.network(
                                            item.menu.gambarUrl,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => _menuImageFallback(),
                                          )
                                        : _menuImageFallback(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.menu.namaMasakan,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          _currencyFmt.format(item.menu.harga),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        if (item.catatan.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Catatan: "${item.catatan}"',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        InkWell(
                                          onTap: () {
                                            _openItemNoteDialog(item);
                                            setModalState(() {});
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.only(top: 3),
                                            child: Text(
                                              '+ Tambah/Ubah Catatan',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFEA580C),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFFEA580C)),
                                        onPressed: () {
                                          setState(() => _decrementCart(item.menu));
                                          setModalState(() {});
                                        },
                                      ),
                                      Text(
                                        '${item.jumlah}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.add_circle, size: 20, color: Color(0xFFEA580C)),
                                        onPressed: () {
                                          setState(() => _addToCart(item.menu));
                                          setModalState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),

                        // Banner GoFood Upsell (Inspirasi Image 3)
                        Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ada lagi yang mau dibeli?',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary),
                                    ),
                                    const Text(
                                      'Masih bisa nambah menu lain, ya.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEA580C),
                                  side: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Tambah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),
                        Divider(height: 1, color: context.borderSubtle),
                        const SizedBox(height: 16),

                        // 2. KUPON, EVENT & POIN PELANGGAN
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.fillSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.confirmation_number_outlined, size: 16, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pilih Kupon Promo & Event Restoran',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Multi-Kupon Selector (Bisa Menggunakan Lebih dari 1 Kupon Sekaligus)
                              Column(
                                children: availableCouponsList.map((c) {
                                  final code = c['code']!;
                                  final isApplied = _appliedCoupons.contains(code);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isApplied
                                          ? (context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFF7ED))
                                          : context.surfaceCard,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isApplied ? const Color(0xFFEA580C) : context.borderSubtle,
                                        width: isApplied ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      value: isApplied,
                                      dense: true,
                                      activeColor: const Color(0xFFEA580C),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      title: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF7ED),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFFEDD5)),
                                            ),
                                            child: Text(
                                              c['tag'] ?? 'PROMO',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              c['label']!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isApplied ? const Color(0xFFEA580C) : context.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        c['desc']!,
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onChanged: (val) {
                                        setModalState(() {
                                          _toggleCoupon(code);
                                        });
                                        setState(() {
                                          _toggleCoupon(code);
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),

                              if (_appliedCoupons.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF059669)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${_appliedCoupons.length} Kupon Aktif • Hemat ${_currencyFmt.format(_couponDiscount)}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          setModalState(() => _clearCoupons());
                                          setState(() => _clearCoupons());
                                        },
                                        child: const Text('Reset Kupon', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              // Input Manual Kode Promo Tambahan
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: TextField(
                                        controller: _couponInputCtrl,
                                        style: const TextStyle(fontSize: 12),
                                        textCapitalization: TextCapitalization.characters,
                                        decoration: InputDecoration(
                                          hintText: 'Punya kode promo lain? (cth: RASANTARA10)',
                                          hintStyle: const TextStyle(fontSize: 11),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          filled: true,
                                          fillColor: context.fillSubtle,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFEA580C),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        _applyCoupon(_couponInputCtrl.text);
                                      });
                                      setState(() {
                                        _applyCoupon(_couponInputCtrl.text);
                                      });
                                    },
                                    child: const Text('Terapkan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              if (_couponStatusMsg != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _couponStatusMsg!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _couponDiscount > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: 12),

                              // 3. Poin Pelanggan (1 Poin = Rp 1 Potongan)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: context.surfaceCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: context.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _usePointsDiscount,
                                      activeColor: const Color(0xFFEA580C),
                                      onChanged: widget.db.userPoints > 0
                                          ? (val) {
                                              setModalState(() => _usePointsDiscount = val ?? false);
                                              setState(() => _usePointsDiscount = val ?? false);
                                            }
                                          : null,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Gunakan Poin Kuliner (${widget.db.userPoints} Poin)',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary),
                                          ),
                                          const Text(
                                            '1 Poin = Rp 1 Potongan langsung harga makanan',
                                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_usePointsDiscount && _potonganPoinAmount > 0)
                                      Text(
                                        '- ${_currencyFmt.format(_potonganPoinAmount)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),

                        // 3. METODE PEMBAYARAN (LIST KE BAWAH / VERTICAL SELECT)
                        const Row(
                          children: [
                            Icon(Icons.payment_rounded, size: 16, color: Color(0xFFEA580C)),
                            SizedBox(width: 8),
                            Text(
                              'Pilih Metode Pembayaran:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Vertical List of Payment Options (List ke Bawah dengan Select)
                        Column(
                          children: [
                            _buildPaymentRadioTile(
                              id: 'dana',
                              title: 'DANA (Direct Debit SNAP BI)',
                              subtitle: 'Terkoneksi resmi • Saldo otomatis 1-klik',
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: const Color(0xFF118EEA),
                              isSelected: _selectedPaymentMethodId == 'dana',
                              onTap: () {
                                setModalState(() => _selectedPaymentMethodId = 'dana');
                                setState(() => _selectedPaymentMethodId = 'dana');
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildPaymentRadioTile(
                              id: 'gopay',
                              title: 'GoPay',
                              subtitle: 'E-Wallet instant payment terintegrasi',
                              icon: Icons.wallet_rounded,
                              iconColor: const Color(0xFF00AED6),
                              isSelected: _selectedPaymentMethodId == 'gopay',
                              onTap: () {
                                setModalState(() => _selectedPaymentMethodId = 'gopay');
                                setState(() => _selectedPaymentMethodId = 'gopay');
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildPaymentRadioTile(
                              id: 'm_banking',
                              title: 'M-Banking (BCA / Mandiri / BRI / BNI)',
                              subtitle: 'Virtual Account & Transfer Bank Otomatis',
                              icon: Icons.account_balance_rounded,
                              iconColor: const Color(0xFF4338CA),
                              isSelected: _selectedPaymentMethodId == 'm_banking',
                              onTap: () {
                                setModalState(() => _selectedPaymentMethodId = 'm_banking');
                                setState(() => _selectedPaymentMethodId = 'm_banking');
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildPaymentRadioTile(
                              id: 'qris',
                              title: 'QRIS Dinamis (All Payment)',
                              subtitle: 'Scan dari seluruh E-Wallet & M-Banking',
                              icon: Icons.qr_code_2_rounded,
                              iconColor: const Color(0xFFEA580C),
                              isSelected: _selectedPaymentMethodId == 'qris',
                              onTap: () {
                                setModalState(() => _selectedPaymentMethodId = 'qris');
                                setState(() => _selectedPaymentMethodId = 'qris');
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildPaymentRadioTile(
                              id: 'tunai',
                              title: 'Bayar Tunai di Kasir',
                              subtitle: 'Pelunasan langsung di kasir restoran',
                              icon: Icons.payments_outlined,
                              iconColor: const Color(0xFF16A34A),
                              isSelected: _selectedPaymentMethodId == 'tunai',
                              onTap: () {
                                setModalState(() => _selectedPaymentMethodId = 'tunai');
                                setState(() => _selectedPaymentMethodId = 'tunai');
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 14),

                        // 4. RINGKASAN BIAYA
                        _buildCostRow('Subtotal Hidangan ($_cartTotalItems item)', _currencyFmt.format(_cartTotalHarga)),
                        if (_diskonEventAmount > 0)
                          _buildCostRow('Diskon Event Promo', '- ${_currencyFmt.format(_diskonEventAmount)}', isHighlight: true),
                        if (_couponDiscount > 0)
                          _buildCostRow('Diskon Kupon ($_couponCode)', '- ${_currencyFmt.format(_couponDiscount)}', isHighlight: true),
                        if (_potonganPoinAmount > 0)
                          _buildCostRow('Potongan Poin Kuliner', '- ${_currencyFmt.format(_potonganPoinAmount)}', isHighlight: true),
                        if (_packagingFee > 0)
                          _buildCostRow('Biaya Kemasan Higienis', _currencyFmt.format(_packagingFee)),
                        if (_currentDeliveryFee > 0)
                          _buildCostRow('Ongkir Pengantaran (${_deliveryDistanceKm.toStringAsFixed(1)} km)', _currencyFmt.format(_currentDeliveryFee)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Pembayaran',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              _currencyFmt.format(_grandTotal),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFEA580C)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),

                // Pinned Bottom Bar
                // Pinned Bottom Bar (Inspirasi Gojek Image 3)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    border: Border(top: BorderSide(color: context.borderSubtle)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ringkasan Metode Bayar & Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _selectedPaymentMethodId == 'gopay'
                                        ? Icons.wallet_rounded
                                        : (_selectedPaymentMethodId == 'dana'
                                            ? Icons.account_balance_wallet_rounded
                                            : (_selectedPaymentMethodId == 'qris'
                                                ? Icons.qr_code_2_rounded
                                                : (_selectedPaymentMethodId == 'm_banking'
                                                    ? Icons.account_balance_rounded
                                                    : Icons.payments_outlined))),
                                    size: 18,
                                    color: _selectedPaymentMethodId == 'gopay' ? const Color(0xFF00AED6) : const Color(0xFFEA580C),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedPaymentMethodId == 'gopay'
                                            ? 'GoPay'
                                            : (_selectedPaymentMethodId == 'dana'
                                                ? 'DANA'
                                                : (_selectedPaymentMethodId == 'qris'
                                                    ? 'QRIS Dinamis'
                                                    : (_selectedPaymentMethodId == 'm_banking'
                                                        ? 'Virtual Account'
                                                        : 'Bayar Tunai'))),
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _currencyFmt.format(_grandTotal),
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: context.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFEDD5)),
                            ),
                            child: const Text(
                              'Midtrans Aktif',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tombol Utama Gojek Pill - Rasantara Orange & White
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C), // Rasantara Orange
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: _cart.isEmpty
                            ? null
                            : () {
                                Navigator.of(ctx).pop();
                                _confirmAndSubmitOrder(paymentMethodId: _selectedPaymentMethodId);
                              },
                        child: Text(
                          _serviceType == OrderServiceType.takeAway
                              ? 'Pesan dan antar sekarang'
                              : 'Pesan Sekarang (${_currencyFmt.format(_grandTotal)})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCostRow(String title, String val, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            ),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF16A34A) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuImageFallback() {
    return Container(
      width: 50,
      height: 50,
      color: const Color(0xFFFFF7ED),
      child: const Icon(Icons.restaurant_menu, color: Color(0xFFEA580C), size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menus = widget.db.menus.where((m) {
      final matchCat = _selectedCategory == MenuCategory.semua || m.kategori == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          m.namaMasakan.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.deskripsi.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    return PopScope(
      canPop: _serviceType != OrderServiceType.dineIn,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _serviceType == OrderServiceType.dineIn) {
          setState(() {
            _selectedTableNo = null;
            _serviceType = OrderServiceType.takeAway;
          });
        }
      },
      child: Scaffold(
        backgroundColor: context.surfaceBg,
        body: Column(
          children: [
            // ── 1. Tab Selector Tipe Layanan (Disembunyikan jika Makan di Tempat via scan QR) ──
            if (_serviceType != OrderServiceType.dineIn)
              Container(
                color: context.surfaceCard,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.fillSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [OrderServiceType.takeAway, OrderServiceType.selfPickUp].map((type) {
                      final isSelected = _serviceType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _serviceType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                type.icon,
                                size: 16,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                type.localizedLabel(context.isEnglish),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // ── 2. Card Informasi Layanan Terpilih ──
          _buildServiceConfigCard(),

          // ── 3. Search & Filter Bar Kategori ──
          _buildSearchAndCategoryBar(),

          // ── 4. Daftar Menu Masakan Nusantara ──
          Expanded(
            child: menus.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tidak ada hidangan bernama "$_searchQuery"'
                              : 'Belum ada hidangan di kategori ini',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : (_selectedCategory == MenuCategory.semua && _searchQuery.isEmpty)
                    ? _buildCategorizedView()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: menus.length,
                        itemBuilder: (ctx, index) {
                          final menu = menus[index];
                          return _buildMenuCard(menu);
                        },
                      ),
          ),
        ],
      ),

      // ── 5. Bottom Sticky Floating Cart Bar ──
      bottomSheet: _cart.isNotEmpty ? _buildFloatingCartBar() : null,
    ),
  );
}

  // ── Widget Card Pengaturan Layanan Sesuai Tipe ──
  Widget _buildServiceConfigCard() {
    return Container(
      color: context.surfaceCard,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFFFEDD5),
          ),
        ),
        child: Column(
          children: [
            if (_serviceType == OrderServiceType.dineIn) ...[
              if (_selectedTableNo != null && _selectedTableNo!.isNotEmpty)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF16A34A), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTableNo!,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary),
                          ),
                          Text(
                            context.t('Terkunci otomatis via scan QR Meja', 'Auto-locked via Table QR scan'),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFFEA580C),
                        side: const BorderSide(color: Color(0xFFEA580C)),
                      ),
                      onPressed: _scanTableQr,
                      icon: const Icon(Icons.qr_code_scanner, size: 14),
                      label: Text(context.t('Scan Ulang', 'Rescan'), style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: context.textSecondary,
                        side: BorderSide(color: context.borderSubtle),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedTableNo = null;
                          _serviceType = OrderServiceType.takeAway;
                        });
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 14),
                      label: Text(context.t('Ke Take Away', 'To Take Away'), style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _scanTableQr,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEA580C)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEA580C), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                context.t('Pindai QR di Meja Anda', 'Scan Table QR Code'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: context.textSecondary,
                        side: BorderSide(color: context.borderSubtle),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedTableNo = null;
                          _serviceType = OrderServiceType.takeAway;
                        });
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 14),
                      label: Text(context.t('Take Away', 'Take Away'), style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
            ] else if (_serviceType == OrderServiceType.takeAway) ...[
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFEA580C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _deliveryAddressController.text.isNotEmpty
                          ? _deliveryAddressController.text
                          : context.t('Pilih titik antar rumah di peta OpenStreetMap', 'Select delivery location on OpenStreetMap'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _deliveryAddressController.text.isNotEmpty
                            ? context.textPrimary
                            : context.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _openOsmMapPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(context.t('Peta OSM', 'OSM Map'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () async {
                      final selectedAddr = await ManageAddressesScreen.selectAddress(context, widget.db);
                      if (selectedAddr != null) {
                        setState(() {
                          _deliveryAddressController.text = selectedAddr.formattedFullAddress;
                          if (selectedAddr.recipientName.isNotEmpty) {
                            _customerNameController.text = selectedAddr.recipientName;
                          }
                          if (selectedAddr.recipientPhone.isNotEmpty) {
                            _phoneController.text = selectedAddr.recipientPhone;
                          }
                          if (selectedAddr.latitude != null && selectedAddr.longitude != null) {
                            final meters = Geolocator.distanceBetween(
                              -6.2088,
                              106.8456,
                              selectedAddr.latitude!,
                              selectedAddr.longitude!,
                            );
                            final dist = (meters / 1000.0).clamp(0.5, 30.0);
                            _deliveryDistanceKm = dist;
                            _deliveryFee = (8000 + (dist * 2500)).round();
                            _deliveryEstimatedTime = '${(15 + (dist * 4)).round()} - ${(25 + (dist * 5)).round()} Menit';
                          }
                        });
                        widget.db.saveTakeAwayAddress(
                          selectedAddr.formattedFullAddress,
                          lat: selectedAddr.latitude,
                          lng: selectedAddr.longitude,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bookmark_added_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(context.t('Alamat Saya', 'My Addresses'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: _isLoadingGps
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFFEA580C)),
                    tooltip: context.t('Gunakan GPS', 'Use GPS Location'),
                    onPressed: _isLoadingGps ? null : _getUserLocation,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${context.t('Jarak', 'Distance')}: ${_deliveryDistanceKm.toStringAsFixed(1)} km • Est. $_deliveryEstimatedTime',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Text(
                    '${context.t('Ongkir', 'Delivery Fee')}: ${_currencyFmt.format(_deliveryFee)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: Color(0xFFEA580C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t(
                        'Self Pick-Up di Counter Restoran Rasantara (Jl. Soekarno-Hatta No. 590, Buahbatu, Bandung)',
                        'Self Pick-Up at Rasantara Restaurant Counter (Jl. Soekarno-Hatta No. 590, Buahbatu, Bandung)',
                      ),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.t('Estimasi Waktu Siap: 15 - 20 Menit', 'Estimated Ready: 15 - 20 Mins'), style: TextStyle(fontSize: 11, color: context.textSecondary)),
                  Text(context.t('Biaya Kemasan: Rp 2.000', 'Packaging: Rp 2,000'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Widget Search Bar & Filter Chips ──
  Widget _buildSearchAndCategoryBar() {
    return Container(
      color: context.surfaceCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: context.fillSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderSubtle),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: context.t('Cari Menu', 'Search Menu'),
                hintStyle: TextStyle(fontSize: 13, color: context.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 16, color: context.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: MenuCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                final count = cat == MenuCategory.semua
                    ? widget.db.menus.length
                    : widget.db.menus.where((m) => m.kategori == cat).length;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text('${cat.localizedLabel(context.isEnglish)} ($count)'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFFEA580C) : context.textSecondary,
                    ),
                    backgroundColor: context.surfaceCard,
                    selectedColor: context.isDarkMode
                        ? const Color(0xFF7C2D12).withValues(alpha: 0.35)
                        : const Color(0xFFFFF7ED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFEA580C) : context.borderSubtle,
                      ),
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget Categorized Section View & Horizontal Paket Slider ──
  Widget _buildCategorizedView() {
    final query = _searchQuery.trim().toLowerCase();
    final allMenus = widget.db.menus.where((m) {
      final matchesQuery = query.isEmpty ||
          m.namaMasakan.toLowerCase().contains(query) ||
          m.deskripsi.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == MenuCategory.semua || m.kategori == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    final pakets = allMenus.where((m) => m.kategori == MenuCategory.paket || m.namaMasakan.toLowerCase().contains('paket')).toList();
    final makanans = allMenus.where((m) => m.kategori == MenuCategory.makanan && !m.namaMasakan.toLowerCase().contains('paket')).toList();
    final minumans = allMenus.where((m) => m.kategori == MenuCategory.minuman).toList();
    final addons = allMenus.where((m) => m.kategori == MenuCategory.addon).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        // 1. Flash Sale Banner 11.11 (Inspirasi Image 1)
        if (pakets.isNotEmpty)
          _buildGojekFlashSaleBanner(pakets),

        // State Kosong Jika Hasil Pencarian Tidak Ditemukan
        if (allMenus.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text(
                  '${context.t('Menu', 'Menu item')} "$_searchQuery" ${context.t('tidak ditemukan', 'not found')}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('Coba cari dengan kata kunci lain atau reset filter', 'Try searching with other keywords or reset filters'),
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedCategory = MenuCategory.semua;
                    });
                  },
                  child: Text(context.t('Reset Pencarian', 'Reset Search'), style: const TextStyle(color: Color(0xFFEA580C))),
                ),
              ],
            ),
          ),
        ],

        // 1. Paket Spesial Slider (Slide ke Kanan) dengan Foto
        if (pakets.isNotEmpty) ...[
          _buildCategoryHeader(
            context.t('Paket Spesial Rasantara', 'Rasantara Special Combos'),
            Icons.local_offer_rounded,
            context.t('Geser >', 'Slide >'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 245,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pakets.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) => _buildPaketCard(pakets[i]),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 2. Makanan Utama
        if (makanans.isNotEmpty) ...[
          _buildCategoryHeader(
            context.t('Makanan Utama', 'Main Courses'),
            Icons.lunch_dining_rounded,
            '${makanans.length} ${context.t('menu', 'items')}',
          ),
          const SizedBox(height: 8),
          ...makanans.map((m) => _buildMenuCard(m)),
          const SizedBox(height: 16),
        ],

        // 3. Minuman Segar & Hangat
        if (minumans.isNotEmpty) ...[
          _buildCategoryHeader(
            context.t('Minuman Segar & Hangat', 'Beverages & Drinks'),
            Icons.local_cafe_rounded,
            '${minumans.length} ${context.t('menu', 'items')}',
          ),
          const SizedBox(height: 8),
          ...minumans.map((m) => _buildMenuCard(m)),
          const SizedBox(height: 16),
        ],

        // 4. Camilan & Add-On / Menu Tambahan
        if (addons.isNotEmpty) ...[
          _buildCategoryHeader(
            context.t('Camilan & Add-On', 'Snacks & Extras'),
            Icons.bakery_dining_rounded,
            '${addons.length} ${context.t('menu', 'items')}',
          ),
          const SizedBox(height: 8),
          ...addons.map((m) => _buildMenuCard(m)),
        ],
      ],
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFEA580C)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.isDarkMode ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5),
            ),
          ),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaketCard(MenuModel menu) {
    final inCart = _cart[menu.idMasakan];
    final qty = inCart?.jumlah ?? 0;
    final photoUrl = menu.gambarUrl.isNotEmpty
        ? menu.gambarUrl
        : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&auto=format&fit=crop&q=80';

    return InkWell(
      onTap: () => _openMenuDetail(menu),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qty > 0 ? const Color(0xFFEA580C) : context.borderSubtle,
          width: qty > 0 ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto Paket Makanan
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  width: 220,
                  height: 105,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _menuImageFallback(),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    context.t('PAKET SPESIAL', 'SPECIAL COMBO'),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        menu.namaMasakan,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _currencyFmt.format(menu.harga),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEA580C), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  menu.deskripsi.isNotEmpty ? menu.deskripsi : 'Paket hemat komplit pilihan terbaik Rasantara.',
                  style: TextStyle(fontSize: 10.5, color: context.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: qty == 0
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _addToCart(menu),
                          icon: const Icon(Icons.add, size: 14, color: Colors.white),
                          label: Text(context.t('Tambah', 'Add'), style: const TextStyle(fontSize: 11, color: Colors.white)),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.remove_circle, color: Color(0xFFEA580C), size: 20),
                              onPressed: () => _decrementCart(menu),
                            ),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.add_circle, color: Color(0xFFEA580C), size: 20),
                              onPressed: () => _addToCart(menu),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  // ── Widget Card Menu Hidangan ──
  Widget _buildMenuCard(MenuModel menu) {
    final inCart = _cart[menu.idMasakan];
    final qty = inCart?.jumlah ?? 0;

    return InkWell(
      onTap: () => _openMenuDetail(menu),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qty > 0 ? const Color(0xFFFED7AA) : context.borderSubtle,
          width: qty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar Menu
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: menu.gambarUrl.isNotEmpty
                  ? Image.network(
                      menu.gambarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _menuImageFallback(),
                    )
                  : _menuImageFallback(),
            ),
          ),
          const SizedBox(width: 14),

          // Detail Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        menu.namaMasakan,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: menu.isTersedia ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        menu.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: menu.isTersedia ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(
                      '${(4.7 + (menu.idMasakan % 4) * 0.1).toStringAsFixed(1)} (1rb+) • 100+ terjual',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  menu.deskripsi,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Harga & Kontrol Stepper
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currencyFmt.format(menu.harga),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    if (!menu.isTersedia)
                      const Text(
                        'Habis',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                      )
                    else if (qty == 0)
                      InkWell(
                        onTap: () => _addToCart(menu),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEA580C), // Rasantara Orange
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 18, color: Colors.white),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: context.surfaceCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _decrementCart(menu),
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.remove, size: 16, color: Color(0xFFEA580C)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '$qty',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _addToCart(menu),
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.add, size: 16, color: Color(0xFFEA580C)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  // ── Flash Sale Card (Inspirasi Gojek Image 1) ──
  Widget _buildGojekFlashSaleBanner(List<MenuModel> flashMenus) {
    if (flashMenus.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24EA580C),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.t('Flash Sale Rasantara', 'Rasantara Flash Deals'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const FlashSaleCountdownTimer(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            context.t('Diskonnya s.d. 40%, serbu hidangan lezat sekarang!', 'Discounts up to 40%, grab tasty meals now!'),
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: flashMenus.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final m = flashMenus[i];
                final originalPrice = (m.harga * 1.35).round();
                return Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: context.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFFFEDD5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                            child: SizedBox(
                              height: 90,
                              width: 140,
                              child: m.gambarUrl.isNotEmpty
                                  ? Image.network(m.gambarUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => _menuImageFallback())
                                  : _menuImageFallback(),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '-35%',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.namaMasakan,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currencyFmt.format(originalPrice),
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _currencyFmt.format(m.harga),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                ),
                                InkWell(
                                  onTap: () => _addToCart(m),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEA580C),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget Sticky Bottom Cart Bar (Floating Pill Gaya Gojek) ──
  Widget _buildFloatingCartBar() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SafeArea(
        child: InkWell(
          onTap: _openCheckoutSheet,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33EA580C),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_cartTotalItems',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('Total Pesanan', 'Order Total'),
                              style: const TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _currencyFmt.format(_grandTotal),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('Lihat Keranjang', 'View Cart'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget countdown timer dinamis untuk banner Flash Sale Rasantara (berjalan real-time per detik)
class FlashSaleCountdownTimer extends StatefulWidget {
  const FlashSaleCountdownTimer({super.key});

  @override
  State<FlashSaleCountdownTimer> createState() => _FlashSaleCountdownTimerState();
}

class _FlashSaleCountdownTimerState extends State<FlashSaleCountdownTimer> {
  Timer? _ticker;
  int _remainingSeconds = 7200;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _calcRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds = _calcRemaining();
      });
    });
  }

  int _calcRemaining() {
    final now = DateTime.now();
    final totalSecondsToday = (now.hour * 3600) + (now.minute * 60) + now.second;
    return 7200 - (totalSecondsToday % 7200);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = (_remainingSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_remainingSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_filled_rounded,
            size: 11,
            color: Color(0xFFEA580C),
          ),
          const SizedBox(width: 4),
          Text(
            '$hours : $minutes : $seconds',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEA580C),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
