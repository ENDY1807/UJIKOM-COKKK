import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

/// Model hasil seleksi lokasi peta OpenStreetMap
class OsmLocationResult {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final double distanceKm;
  final int deliveryFee;
  final String estimatedTime;

  const OsmLocationResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.distanceKm,
    required this.deliveryFee,
    required this.estimatedTime,
  });
}

/// Widget Peta Interaktif Open-Source OpenStreetMap (OSM)
/// Membaca peta seluruh dunia secara gratis dan open-source (tanpa Google Maps API key)
class OsmMapWidget extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final Function(OsmLocationResult) onLocationSelected;

  const OsmMapWidget({
    super.key,
    this.initialLat = -6.9431,
    this.initialLng = 107.6542,
    required this.onLocationSelected,
  });

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget> {
  static const double restoLat = -6.9431;
  static const double restoLng = 107.6542;

  late double _currentLat;
  late double _currentLng;
  int _zoom = 15;

  String _currentAddress = 'Mencari alamat lokasi...';
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  // Search autocomplete
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLat;
    _currentLng = widget.initialLng;
    _reverseGeocode(_currentLat, _currentLng);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Hitung jarak Haversine (km) dari Restoran Rasantara ke titik terpilih
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  // Hitung ongkos kirim GoFood (Rp 8.000 untuk <= 3km, +Rp 2.000/km berikutnya)
  int _calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 3.0) {
      return 8000;
    }
    final extraKm = (distanceKm - 3.0).ceil();
    return 8000 + (extraKm * 2000);
  }

  String _calculateEstimatedTime(double distanceKm) {
    final mins = (15 + (distanceKm * 3.5)).round();
    return '$mins - ${mins + 10} Menit';
  }

  // OpenStreetMap Nominatim Reverse Geocoding
  Future<void> _reverseGeocode(double lat, double lng) async {
    setState(() => _isLoadingAddress = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&zoom=18&addressdetails=1',
      );
      final response = await http
          .get(
            url,
            headers: {'User-Agent': 'Rasantara-Restoran-OpenStreetMap/1.0'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          if (mounted) {
            setState(() {
              _currentAddress = displayName;
              _isLoadingAddress = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentAddress =
            'Koordinat: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
        _isLoadingAddress = false;
      });
    }
  }

  // OpenStreetMap Nominatim Autocomplete Search
  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=id',
      );
      final response = await http
          .get(
            url,
            headers: {'User-Agent': 'Rasantara-Restoran-OpenStreetMap/1.0'},
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _searchResults = data;
            _isSearching = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  void _onPan(DragUpdateDetails details) {
    // Geser koordinat berdasarkan pergeseran piksel layar
    final double factor = 360.0 / (256.0 * math.pow(2, _zoom));
    setState(() {
      _currentLng -= details.delta.dx * factor;
      _currentLat += details.delta.dy * factor;
      _currentLat = _currentLat.clamp(-85.0, 85.0);
      _currentLng = (_currentLng + 180) % 360 - 180;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _reverseGeocode(_currentLat, _currentLng);
    });
  }

  void _zoomIn() {
    if (_zoom < 18) {
      setState(() => _zoom += 1);
    }
  }

  void _zoomOut() {
    if (_zoom > 4) {
      setState(() => _zoom -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = _calculateDistance(
      restoLat,
      restoLng,
      _currentLat,
      _currentLng,
    );
    final deliveryFee = _calculateDeliveryFee(distanceKm);
    final estimatedTime = _calculateEstimatedTime(distanceKm);

    return Container(
      height: 600,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Modal Grab Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Bar Pencarian OpenStreetMap
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari Alamat',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: Color(0xFFEA580C),
                        ),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              )
                            : (_searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchResults = []);
                                    },
                                  )
                                : null),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) {
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(
                          const Duration(milliseconds: 500),
                          () {
                            _searchPlaces(val);
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Tutup Peta',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Hasil Autocomplete Search
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = _searchResults[i];
                  final name = item['display_name'] ?? '';
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on,
                      color: Color(0xFFEA580C),
                      size: 18,
                    ),
                    title: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      final lat = double.tryParse(
                        item['lat']?.toString() ?? '',
                      );
                      final lon = double.tryParse(
                        item['lon']?.toString() ?? '',
                      );
                      if (lat != null && lon != null) {
                        setState(() {
                          _currentLat = lat;
                          _currentLng = lon;
                          _currentAddress = name;
                          _searchResults = [];
                          _searchController.text = name;
                        });
                      }
                    },
                  );
                },
              ),
            ),

          // Peta Interaktif OpenStreetMap
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onPanUpdate: _onPan,
                  child: ClipRect(child: _buildOsmTileGrid()),
                ),

                // Pin Tengah Antar Lokasi (Gojek / GoFood Style)
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, -22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Lokasi Pengantaran',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFEA580C),
                          size: 44,
                          shadows: [
                            Shadow(
                              color: Color(0x40000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Tombol Zoom In / Zoom Out (+ / -)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      _mapFloatingButton(Icons.add, _zoomIn, 'Perbesar Peta'),
                      const SizedBox(height: 8),
                      _mapFloatingButton(
                        Icons.remove,
                        _zoomOut,
                        'Perkecil Peta',
                      ),
                      const SizedBox(height: 8),
                      _mapFloatingButton(Icons.my_location, () {
                        setState(() {
                          _currentLat = widget.initialLat;
                          _currentLng = widget.initialLng;
                        });
                        _reverseGeocode(_currentLat, _currentLng);
                      }, 'Kembali ke Titik Awal'),
                    ],
                  ),
                ),

                // Label OpenStreetMap (Legal Attribution)
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors (Open Source)',
                      style: TextStyle(fontSize: 9, color: Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Sheet GoFood Info & Konfirmasi
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Alamat
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_pin,
                        color: Color(0xFFEA580C),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alamat Pengantaran Terpilih:',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_isLoadingAddress)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Membaca nama jalan OSM...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              _currentAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Rincian Jarak & Estimasi GoFood
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoPill(
                      Icons.straighten_rounded,
                      '${distanceKm.toStringAsFixed(1)} km',
                      'Jarak dari Resto',
                    ),
                    _infoPill(
                      Icons.access_time_rounded,
                      estimatedTime,
                      'Estimasi Tiba',
                    ),
                    _infoPill(
                      Icons.local_shipping_outlined,
                      'Rp ${deliveryFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                      'Ongkos Kirim',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Tombol Konfirmasi GoFood Style
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final result = OsmLocationResult(
                        latitude: _currentLat,
                        longitude: _currentLng,
                        formattedAddress: _currentAddress,
                        distanceKm: distanceKm,
                        deliveryFee: deliveryFee,
                        estimatedTime: estimatedTime,
                      );
                      widget.onLocationSelected(result);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Pilih Titik Antar Ini',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String value, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: const Color(0xFFEA580C)),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapFloatingButton(IconData icon, VoidCallback onTap, String tooltip) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Icon(icon, size: 20, color: const Color(0xFF334155)),
        ),
      ),
    );
  }

  // Render grid 3x3 tile raster OpenStreetMap
  Widget _buildOsmTileGrid() {
    final double n = math.pow(2.0, _zoom).toDouble();
    final double xExact = ((_currentLng + 180.0) / 360.0) * n;
    final double latRad = _currentLat * math.pi / 180.0;
    final double yExact =
        (1.0 -
            (math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) / math.pi)) /
        2.0 *
        n;

    final int xCenter = xExact.floor();
    final int yCenter = yExact.floor();

    final double xOffset = (xExact - xCenter) * 256.0;
    final double yOffset = (yExact - yCenter) * 256.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfW = constraints.maxWidth / 2;
        final halfH = constraints.maxHeight / 2;

        final tiles = <Widget>[];

        for (int dx = -2; dx <= 2; dx++) {
          for (int dy = -2; dy <= 2; dy++) {
            final int tileX = (xCenter + dx) % n.toInt();
            final int tileY = (yCenter + dy).clamp(0, n.toInt() - 1);

            final double left = halfW - xOffset + (dx * 256.0);
            final double top = halfH - yOffset + (dy * 256.0);

            tiles.add(
              Positioned(
                left: left,
                top: top,
                width: 256,
                height: 256,
                child: Image.network(
                  'https://tile.openstreetmap.org/$_zoom/$tileX/$tileY.png',
                  fit: BoxFit.cover,
                  headers: const {'User-Agent': 'Rasantara-Restoran-App/1.0'},
                  errorBuilder: (ctx, err, stack) {
                    return Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 24,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        }

        return Stack(children: tiles);
      },
    );
  }
}
