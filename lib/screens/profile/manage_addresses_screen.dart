import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../models/user_address_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class ManageAddressesScreen extends StatefulWidget {
  final DatabaseService db;
  final bool selectMode; // Jika true, saat tap alamat langsung pop dan kembalikan UserAddressModel

  const ManageAddressesScreen({
    super.key,
    required this.db,
    this.selectMode = false,
  });

  static Future<UserAddressModel?> selectAddress(
    BuildContext context,
    DatabaseService db,
  ) async {
    return Navigator.of(context).push<UserAddressModel>(
      MaterialPageRoute(
        builder: (_) => ManageAddressesScreen(db: db, selectMode: true),
      ),
    );
  }

  static void navigate(BuildContext context, DatabaseService db) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageAddressesScreen(db: db, selectMode: false),
      ),
    );
  }

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshFromCloud();
  }

  Future<void> _refreshFromCloud() async {
    setState(() => _isLoading = true);
    await widget.db.syncUserAddresses();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = widget.db.userAddresses;

    return Scaffold(
      backgroundColor: context.surfaceBg,
      appBar: AppBar(
        title: Text(
          widget.selectMode ? 'Pilih Alamat Pengantaran' : 'Alamat Pengantaran Saya',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: context.surfaceCard,
        foregroundColor: context.textPrimary,
        actions: [
          IconButton(
            tooltip: 'Sinkronisasi Alamat',
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: _refreshFromCloud,
          ),
        ],
      ),
      body: addresses.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final addr = addresses[index];
                return _buildAddressCard(addr);
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          border: Border(top: BorderSide(color: context.borderSubtle)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text(
              'Tambah Alamat Baru',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _openAddressFormSheet(context),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 56,
                color: Color(0xFFEA580C),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Alamat Tersimpan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambahkan alamat rumah, kantor, atau tujuan pengantaran untuk memudahkan pemesanan Take Away & Delivery.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text('Tambah Alamat Pertama'),
              onPressed: () => _openAddressFormSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(UserAddressModel addr) {
    return InkWell(
      onTap: widget.selectMode
          ? () => Navigator.of(context).pop(addr)
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: addr.isPrimary
                ? const Color(0xFFEA580C)
                : context.borderSubtle,
            width: addr.isPrimary ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.fillSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getLabelIcon(addr.label),
                        size: 13,
                        color: context.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        addr.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (addr.isPrimary) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: const Text(
                      'Utama',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (val) {
                    if (val == 'primary') {
                      widget.db.setPrimaryAddress(addr.idAlamat);
                    } else if (val == 'edit') {
                      _openAddressFormSheet(context, existing: addr);
                    } else if (val == 'delete') {
                      _confirmDeleteAddress(addr);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!addr.isPrimary)
                      const PopupMenuItem(
                        value: 'primary',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Text('Jadikan Utama', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Ubah Alamat', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(fontSize: 13, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Nama & Telepon Penerima
            Row(
              children: [
                const Icon(Icons.person_pin_rounded, size: 15, color: Color(0xFFEA580C)),
                const SizedBox(width: 6),
                Text(
                  addr.recipientName.isNotEmpty ? addr.recipientName : 'Penerima',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                if (addr.recipientPhone.isNotEmpty) ...[
                  const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8))),
                  Text(
                    addr.recipientPhone,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Alamat Lengkap
            Text(
              addr.formattedFullAddress,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35),
            ),

            if (addr.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Patokan: ${addr.notes}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],

            if (addr.latitude != null && addr.longitude != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gps_fixed, size: 10, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          'GPS: ${addr.latitude!.toStringAsFixed(4)}, ${addr.longitude!.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            if (widget.selectMode) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.of(context).pop(addr),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Gunakan Alamat Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('rumah')) return Icons.home_rounded;
    if (lower.contains('kantor') || lower.contains('office')) return Icons.business_rounded;
    if (lower.contains('apart')) return Icons.apartment_rounded;
    if (lower.contains('kost')) return Icons.bed_rounded;
    if (lower.contains('teman')) return Icons.people_outline;
    if (lower.contains('keluarga') || lower.contains('orang tua')) return Icons.family_restroom;
    return Icons.place_outlined;
  }

  void _confirmDeleteAddress(UserAddressModel addr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Alamat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus alamat "${addr.label} - ${addr.recipientName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.db.removeUserAddress(addr.idAlamat);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alamat berhasil dihapus')),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Bottom Sheet Form Input Multi-Field + GPS 1-Tap + Link Gmaps ──
  void _openAddressFormSheet(BuildContext context, {UserAddressModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _AddressFormWidget(
        db: widget.db,
        existing: existing,
        onSaved: (saved) {
          Navigator.of(sheetCtx).pop();
          if (widget.selectMode) {
            Navigator.of(context).pop(saved);
          }
        },
      ),
    );
  }
}

// ── Widget Formulir Tambah/Ubah Alamat ──
class _AddressFormWidget extends StatefulWidget {
  final DatabaseService db;
  final UserAddressModel? existing;
  final ValueChanged<UserAddressModel> onSaved;

  const _AddressFormWidget({
    required this.db,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_AddressFormWidget> createState() => _AddressFormWidgetState();
}

class _AddressFormWidgetState extends State<_AddressFormWidget> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedLabel;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _provinceCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _districtCtrl;
  late TextEditingController _postalCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _gmapsLinkCtrl;

  double? _lat;
  double? _lng;
  bool _isPrimary = false;
  bool _isLocatingGps = false;
  bool _isParsingGmaps = false;

  final List<String> _labelPresets = ['Rumah', 'Kantor', 'Apartemen', 'Kost', 'Teman', 'Keluarga'];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    final currentUser = widget.db.currentUser;

    _selectedLabel = ex?.label ?? 'Rumah';
    _nameCtrl = TextEditingController(text: ex?.recipientName ?? currentUser?.namaUser ?? '');
    _phoneCtrl = TextEditingController(text: ex?.recipientPhone ?? '');
    _provinceCtrl = TextEditingController(text: ex?.province ?? '');
    _cityCtrl = TextEditingController(text: ex?.city ?? '');
    _districtCtrl = TextEditingController(text: ex?.district ?? '');
    _postalCtrl = TextEditingController(text: ex?.postalCode ?? '');
    _addressCtrl = TextEditingController(text: ex?.fullAddress ?? '');
    _notesCtrl = TextEditingController(text: ex?.notes ?? '');
    _gmapsLinkCtrl = TextEditingController(text: ex?.gmapsLink ?? '');
    _lat = ex?.latitude;
    _lng = ex?.longitude;
    _isPrimary = ex?.isPrimary ?? (widget.db.userAddresses.isEmpty);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _provinceCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _postalCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _gmapsLinkCtrl.dispose();
    super.dispose();
  }

  // 1-Tap GPS: Mendeteksi lokasi HP melalui Geolocator & Reverse Geocoding
  Future<void> _detectCurrentGpsLocation() async {
    setState(() => _isLocatingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Layanan GPS/Lokasi HP belum aktif. Harap nyalakan GPS.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin akses lokasi ditolak.')),
            );
          }
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lat = pos.latitude;
      _lng = pos.longitude;

      // Reverse geocoding OpenStreetMap Nominatim
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&addressdetails=1',
      );
      final res = await http.get(url, headers: {'User-Agent': 'RasantaraRestoranApp/1.0'});

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addressObj = data['address'] as Map<String, dynamic>? ?? {};

        final province = (addressObj['state'] ?? addressObj['region'] ?? '').toString();
        final city = (addressObj['city'] ?? addressObj['county'] ?? addressObj['town'] ?? '').toString();
        final district = (addressObj['suburb'] ?? addressObj['municipality'] ?? addressObj['neighbourhood'] ?? '').toString();
        final road = (addressObj['road'] ?? addressObj['footway'] ?? '').toString();
        final postcode = (addressObj['postcode'] ?? '').toString();
        final displayName = (data['display_name'] ?? '').toString();

        setState(() {
          if (province.isNotEmpty) _provinceCtrl.text = province;
          if (city.isNotEmpty) _cityCtrl.text = city;
          if (district.isNotEmpty) _districtCtrl.text = district;
          if (postcode.isNotEmpty) _postalCtrl.text = postcode;
          if (road.isNotEmpty) {
            _addressCtrl.text = road;
          } else if (displayName.isNotEmpty) {
            _addressCtrl.text = displayName.split(',').take(2).join(',').trim();
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lokasi GPS HP berhasil dipasang!')),
          );
        }
      } else {
        setState(() {
          _addressCtrl.text = 'Titik GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        });
      }
    } catch (e) {
      debugPrint('[AddressForm] GPS detect error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca GPS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  // Parse Google Maps Link
  Future<void> _parseGoogleMapsLink() async {
    final link = _gmapsLinkCtrl.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan link Google Maps terlebih dahulu')),
      );
      return;
    }

    setState(() => _isParsingGmaps = true);

    try {
      double? lat;
      double? lng;

      // Format 1: @-6.2088,106.8456
      final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      final atMatch = atRegex.firstMatch(link);
      if (atMatch != null) {
        lat = double.tryParse(atMatch.group(1)!);
        lng = double.tryParse(atMatch.group(2)!);
      }

      // Format 2: ?q=-6.2088,106.8456
      if (lat == null) {
        final qRegex = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
        final qMatch = qRegex.firstMatch(link);
        if (qMatch != null) {
          lat = double.tryParse(qMatch.group(1)!);
          lng = double.tryParse(qMatch.group(2)!);
        }
      }

      // Format 3: ll=-6.2088,106.8456
      if (lat == null) {
        final llRegex = RegExp(r'[?&]ll=(-?\d+\.\d+),(-?\d+\.\d+)');
        final llMatch = llRegex.firstMatch(link);
        if (llMatch != null) {
          lat = double.tryParse(llMatch.group(1)!);
          lng = double.tryParse(llMatch.group(2)!);
        }
      }

      if (lat != null && lng != null) {
        _lat = lat;
        _lng = lng;

        // Lakukan reverse geocode
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
        );
        final res = await http.get(url, headers: {'User-Agent': 'RasantaraRestoranApp/1.0'});
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final addressObj = data['address'] as Map<String, dynamic>? ?? {};

          final province = (addressObj['state'] ?? addressObj['region'] ?? '').toString();
          final city = (addressObj['city'] ?? addressObj['county'] ?? addressObj['town'] ?? '').toString();
          final district = (addressObj['suburb'] ?? addressObj['municipality'] ?? '').toString();
          final road = (addressObj['road'] ?? '').toString();

          setState(() {
            if (province.isNotEmpty) _provinceCtrl.text = province;
            if (city.isNotEmpty) _cityCtrl.text = city;
            if (district.isNotEmpty) _districtCtrl.text = district;
            if (road.isNotEmpty) _addressCtrl.text = road;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Koordinat dari Google Maps berhasil diekstrak!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Format link Google Maps diterima. Silakan lengkapi detail alamat.')),
          );
        }
      }
    } catch (e) {
      debugPrint('[AddressForm] parse gmaps link error: $e');
    } finally {
      if (mounted) setState(() => _isParsingGmaps = false);
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final newModel = UserAddressModel(
      idAlamat: widget.existing?.idAlamat ?? 0,
      idUser: widget.existing?.idUser ?? (widget.db.currentUser?.idUser ?? 1),
      label: _selectedLabel,
      recipientName: _nameCtrl.text.trim(),
      recipientPhone: _phoneCtrl.text.trim(),
      province: _provinceCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      postalCode: _postalCtrl.text.trim(),
      fullAddress: _addressCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      latitude: _lat,
      longitude: _lng,
      gmapsLink: _gmapsLinkCtrl.text.trim().isNotEmpty ? _gmapsLinkCtrl.text.trim() : null,
      isPrimary: _isPrimary,
    );

    UserAddressModel? result;
    if (widget.existing != null) {
      await widget.db.editUserAddress(newModel);
      result = newModel;
    } else {
      result = await widget.db.addUserAddress(newModel);
    }

    if (result != null) {
      widget.onSaved(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing != null ? 'Ubah Alamat Pengantaran' : 'Tambah Alamat Baru',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tombol Pintas Cepat (GPS 1-Tap & Link Gmaps)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEA580C),
                        side: const BorderSide(color: Color(0xFFEA580C)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isLocatingGps
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('Lokasi HP (GPS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _isLocatingGps ? null : _detectCurrentGpsLocation,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isParsingGmaps
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Tautkan Gmaps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _isParsingGmaps ? null : _parseGoogleMapsLink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Pilihan Label Alamat (Rumah, Kantor, Teman, dll.)
              const Text('Kategori Alamat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _labelPresets.map((label) {
                  final isSelected = _selectedLabel == label;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFFF7ED),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedLabel = label);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Input Nama & Telepon Penerima (Bisa untuk kirim ke orang lain / teman)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Penerima',
                        hintText: 'Nama Anda / Orang Lain',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'No. Telepon / WA',
                        hintText: '0812xxxx',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Link Google Maps (Opsional)
              TextFormField(
                controller: _gmapsLinkCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Link Google Maps (Opsional)',
                  hintText: 'https://maps.app.goo.gl/...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  prefixIcon: const Icon(Icons.map_outlined, size: 18),
                  suffixIcon: IconButton(
                    tooltip: 'Ekstrak Koordinat',
                    icon: const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF2563EB)),
                    onPressed: _parseGoogleMapsLink,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Multi-Input Wilayah: Provinsi & Kabupaten/Kota
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _provinceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Provinsi',
                        hintText: 'DKI Jakarta / Jabar',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Kota / Kabupaten',
                        hintText: 'Kota Bandung',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Kecamatan & Kode Pos
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _districtCtrl,
                      decoration: InputDecoration(
                        labelText: 'Kecamatan',
                        hintText: 'Nama Kecamatan',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _postalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Kode Pos',
                        hintText: '40132',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Detail Alamat Lengkap
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Alamat Lengkap (Jalan, No. Rumah, RT/RW)',
                  hintText: 'Jl. Merdeka No. 45, RT 02/05',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Alamat lengkap wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              // Catatan / Patokan
              TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Patokan / Catatan Pengiriman (Opsional)',
                  hintText: 'Pagar hitam, seberang masjid',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  prefixIcon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Switch Alamat Utama
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Jadikan sebagai Alamat Utama', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Otomatis terpilih saat memesan Take Away & Delivery', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                value: _isPrimary,
                activeThumbColor: const Color(0xFFEA580C),
                onChanged: (val) => setState(() => _isPrimary = val),
              ),
              const SizedBox(height: 16),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _handleSubmit,
                  child: Text(
                    widget.existing != null ? 'Perbarui Alamat' : 'Simpan Alamat',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
