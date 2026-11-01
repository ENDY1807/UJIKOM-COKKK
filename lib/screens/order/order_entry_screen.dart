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
import 'gofood_tracking_dialog.dart';
import 'qr_scanner_dialog.dart';

enum OrderServiceType {
  dineIn('Makan di Tempat', Icons.table_restaurant_rounded),
  takeAway('Take Away', Icons.delivery_dining_rounded),
  selfPickUp('Self Pick-Up', Icons.shopping_bag_outlined);

  final String label;
  final IconData icon;
  const OrderServiceType(this.label, this.icon);
}

class OrderEntryScreen extends StatefulWidget {
  final DatabaseService db;
  final String? initialTableNo;

  const OrderEntryScreen({super.key, required this.db, this.initialTableNo});

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

  // ── Perhitungan Keranjang Belanja ──
  int get _cartTotalHarga => _cart.values.fold(0, (sum, i) => sum + i.subtotal);
  int get _cartTotalItems => _cart.values.fold(0, (sum, i) => sum + i.jumlah);
  int get _packagingFee => (_serviceType != OrderServiceType.dineIn) ? 2000 : 0;
  int get _currentDeliveryFee => (_serviceType == OrderServiceType.takeAway) ? _deliveryFee : 0;
  int get _grandTotal => _cartTotalHarga + _packagingFee + _currentDeliveryFee;

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
        backgroundColor: Colors.white,
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
  void _confirmAndSubmitOrder({String? paymentMethodId}) {
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

    if (payId == 'qris') {
      paymentMethodName = 'QRIS';
    } else if (payId == 'tunai') {
      paymentMethodName = 'Tunai';
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
                'Saldo ${connectedMethod.provider.label} tidak mencukupi (${_currencyFmt.format(connectedMethod.balance)} < ${_currencyFmt.format(_grandTotal)}). Harap Top Up di Menu Profil.',
              ),
            ),
          );
          return;
        }
        paymentMethodName = '${connectedMethod.provider.label} (${connectedMethod.maskedNumber})';
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

    // Buat order di database
    final order = widget.db.createOrder(
      noMeja: tableIdentifier,
      namaPelanggan: custName,
      keterangan: fullOrderNotes,
      items: _cart.values.toList(),
    );

    // Jika dibayar dengan metode terkoneksi (DANA, GoPay, M-Banking), potong saldo dan catat transaksi lunas
    if (connectedMethod != null) {
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
      );
    }

    final savedAddress = _deliveryAddressController.text.trim();
    final savedDeliveryFee = _deliveryFee;
    final savedEstTime = _deliveryEstimatedTime;
    final isDeliveryOrder = _serviceType == OrderServiceType.takeAway;
    final grandTotalFinal = _grandTotal;

    setState(() {
      _cart.clear();
      _orderNotesController.clear();
      if (_serviceType != OrderServiceType.dineIn) {
        _deliveryAddressController.clear();
      }
    });

    // Jika metode QRIS, buka dialog pembayaran QRIS Nasional interaktif
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
              content: Text('✓ Pembayaran QRIS Sukses Diterima! Pesanan Diproses.'),
            ),
          );
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
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
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  if (connectedMethod != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '✓ Saldo ${connectedMethod.provider.label} terpotong ${_currencyFmt.format(_grandTotal)} (Sisa: ${_currencyFmt.format(connectedMethod.balance)})',
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // ── Bottom Sheet Ringkasan Keranjang & Checkout ──
  void _openCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Drag Handle & Title
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rincian Pesanan Rasantara',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          _serviceType.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEA580C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Item List
                if (_cart.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Keranjang pesanan kosong',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
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
                                      width: 50,
                                      height: 50,
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
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
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
                                      padding: EdgeInsets.only(top: 4),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  ),

                const Divider(height: 20),

                // Pilihan Metode Pembayaran Terkoneksi Nyata (Tanpa teks oranye di baris judul)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilih Metode Pembayaran:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...widget.db.connectedPaymentMethods.map((method) {
                        final isSelected = _selectedPaymentMethodId == method.id;
                        final isEnough = method.balance >= _grandTotal;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() => _selectedPaymentMethodId = method.id);
                            setState(() => _selectedPaymentMethodId = method.id);
                          },
                          child: Container(
                            width: 145,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: method.provider.brandColor.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(method.provider.icon, color: method.provider.brandColor, size: 18),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFFEA580C)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      method.provider.label,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                      maxLines: 1,
                                    ),
                                    Text(
                                      _currencyFmt.format(method.balance),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isEnough ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedPaymentMethodId = 'qris');
                          setState(() => _selectedPaymentMethodId = 'qris');
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedPaymentMethodId == 'qris' ? const Color(0xFFFFF7ED) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedPaymentMethodId == 'qris' ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
                              width: _selectedPaymentMethodId == 'qris' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEA580C).withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFEA580C), size: 18),
                                  ),
                                  if (_selectedPaymentMethodId == 'qris')
                                    const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFFEA580C)),
                                ],
                              ),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('QRIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                                  Text('DANA H2H / All Pay', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedPaymentMethodId = 'tunai');
                          setState(() => _selectedPaymentMethodId = 'tunai');
                        },
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedPaymentMethodId == 'tunai' ? const Color(0xFFFFF7ED) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedPaymentMethodId == 'tunai' ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
                              width: _selectedPaymentMethodId == 'tunai' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.payments_outlined, color: Color(0xFF16A34A), size: 18),
                                  ),
                                  if (_selectedPaymentMethodId == 'tunai')
                                    const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFFEA580C)),
                                ],
                              ),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tunai Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                                  Text('Bayar langsung', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Indikator Saldo Kurang & Quick Top-Up Otomatis (Gaya GoFood / GrabFood)
                Builder(builder: (ctx) {
                  final curPay = widget.db.connectedPaymentMethods
                      .where((p) => p.id == _selectedPaymentMethodId)
                      .firstOrNull;
                  if (curPay != null && curPay.balance < _grandTotal) {
                    final defNeed = _grandTotal - curPay.balance;
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saldo ${curPay.provider.label} kurang ${_currencyFmt.format(defNeed)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              final topUpAmt = ((defNeed / 10000).ceil() * 10000);
                              widget.db.topUpPaymentMethod(curPay.id, topUpAmt);
                              setModalState(() {});
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF16A34A),
                                  content: Text('✓ Berhasil Top Up Cepat ${_currencyFmt.format(topUpAmt)} ke ${curPay.provider.label}!'),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '+ Top Up Cepat',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (curPay != null && curPay.provider == PaymentMethodProvider.dana) {
                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'DANA Gateway H2H Terhubung (Channel: 95221 • Store: ae70d112)',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                const Divider(height: 20),

                // Biaya Rincian
                Column(
                  children: [
                    _buildCostRow('Subtotal Hidangan ($_cartTotalItems item)', _currencyFmt.format(_cartTotalHarga)),
                    if (_packagingFee > 0)
                      _buildCostRow('Biaya Kemasan Higienis', _currencyFmt.format(_packagingFee)),
                    if (_currentDeliveryFee > 0)
                      _buildCostRow('Ongkir Pengantaran OSM (${_deliveryDistanceKm.toStringAsFixed(1)} km)', _currencyFmt.format(_currentDeliveryFee)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Pembayaran',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          _currencyFmt.format(_grandTotal),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tombol Eksekusi Order
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _cart.isEmpty
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _confirmAndSubmitOrder(paymentMethodId: _selectedPaymentMethodId);
                        },
                  child: Text(
                    'Kirim Pesanan Sekarang • ${_currencyFmt.format(_grandTotal)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCostRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pemesanan Rasantara',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          if (_serviceType == OrderServiceType.dineIn)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEA580C)),
              tooltip: 'Scan QR Meja',
              onPressed: _scanTableQr,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. Tab Selector Tipe Layanan (Disembunyikan jika Makan di Tempat via scan QR) ──
          if (_serviceType != OrderServiceType.dineIn)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
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
                                type.label,
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
    );
  }

  // ── Widget Card Pengaturan Layanan Sesuai Tipe ──
  Widget _buildServiceConfigCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFEDD5)),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          const Text(
                            'Terkunci otomatis via scan QR Meja',
                            style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
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
                      label: const Text('Scan Ulang', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                )
              else
                InkWell(
                  onTap: _scanTableQr,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEA580C)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEA580C), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Pindai QR di Meja Anda untuk Memesan',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                        ),
                      ],
                    ),
                  ),
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
                          : 'Pilih titik antar rumah di peta OpenStreetMap',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _deliveryAddressController.text.isNotEmpty
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF64748B),
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
                      child: const Row(
                        children: [
                          Icon(Icons.map_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Peta OSM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    tooltip: 'Gunakan GPS',
                    onPressed: _isLoadingGps ? null : _getUserLocation,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jarak: ${_deliveryDistanceKm.toStringAsFixed(1)} km • Est. $_deliveryEstimatedTime',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Ongkir: ${_currencyFmt.format(_deliveryFee)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                  ),
                ],
              ),
            ] else ...[
              const Row(
                children: [
                  Icon(Icons.storefront_rounded, color: Color(0xFFEA580C), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Self Pick-Up di Counter Restoran Rasantara (Jl. Soekarno-Hatta No. 590, Buahbatu, Bandung)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimasi Waktu Siap: 15 - 20 Menit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text('Biaya Kemasan: Rp 2.000', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari Menu',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
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
                    label: Text('${cat.label} ($count)'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                    ),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFFFF7ED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
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
                  'Menu "$_searchQuery" tidak ditemukan',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Coba cari dengan kata kunci lain atau reset filter',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                  child: const Text('Reset Pencarian', style: TextStyle(color: Color(0xFFEA580C))),
                ),
              ],
            ),
          ),
        ],

        // 1. Paket Spesial Slider (Slide ke Kanan) dengan Foto
        if (pakets.isNotEmpty) ...[
          _buildCategoryHeader('Paket Spesial Rasantara', Icons.local_offer_rounded, 'Geser >'),
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
          _buildCategoryHeader('Makanan Utama', Icons.lunch_dining_rounded, '${makanans.length} menu'),
          const SizedBox(height: 8),
          ...makanans.map((m) => _buildMenuCard(m)),
          const SizedBox(height: 16),
        ],

        // 3. Minuman Segar & Hangat
        if (minumans.isNotEmpty) ...[
          _buildCategoryHeader('Minuman Segar & Hangat', Icons.local_cafe_rounded, '${minumans.length} menu'),
          const SizedBox(height: 8),
          ...minumans.map((m) => _buildMenuCard(m)),
          const SizedBox(height: 16),
        ],

        // 4. Camilan & Add-On / Menu Tambahan
        if (addons.isNotEmpty) ...[
          _buildCategoryHeader('Camilan & Add-On', Icons.bakery_dining_rounded, '${addons.length} menu'),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
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

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qty > 0 ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
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
                  child: const Text(
                    'PAKET SPESIAL',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
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
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
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
                          label: const Text('Tambah', style: TextStyle(fontSize: 11, color: Colors.white)),
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
    );
  }

  // ── Widget Card Menu Hidangan ──
  Widget _buildMenuCard(MenuModel menu) {
    final inCart = _cart[menu.idMasakan];
    final qty = inCart?.jumlah ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qty > 0 ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
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
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Tambah',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _decrementCart(menu),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.remove, size: 16, color: Color(0xFFEA580C)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '$qty',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9A3412),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _addToCart(menu),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
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
    );
  }

  // ── Widget Sticky Bottom Cart Bar ──
  Widget _buildFloatingCartBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_cartTotalItems Item Terpilih (${_serviceType.label})',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFmt.format(_grandTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
              label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: _openCheckoutSheet,
            ),
          ],
        ),
      ),
    );
  }
}
