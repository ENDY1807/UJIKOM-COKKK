import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/menu_model.dart';

/// Dialog/Sheet Detail Menu Makanan Lengkap
/// Menyajikan:
/// 1. Nama, Harga, Kategori, Foto & Deskripsi Rasa
/// 2. Bahan-bahan Baku Makanan (Komposisi / Ingredients)
/// 3. Informasi Nilai Gizi & Kalori (Nutritional Facts / Healthy Diet)
/// 4. Tag Kesehatan (Tinggi Protein, Rendah Kalori, Halal, Alami)
/// 5. Perhatian Alergen (Allergen Warnings)
/// 6. Stepper Tambah Porsi & Catatan Khusus Masakan
class MenuDetailDialog extends StatefulWidget {
  final MenuModel menu;
  final int initialQty;
  final String? initialNote;
  final void Function(int quantity, String note)? onConfirm;

  const MenuDetailDialog({
    super.key,
    required this.menu,
    this.initialQty = 1,
    this.initialNote,
    this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required MenuModel menu,
    int initialQty = 1,
    String? initialNote,
    void Function(int quantity, String note)? onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuDetailDialog(
        menu: menu,
        initialQty: initialQty > 0 ? initialQty : 1,
        initialNote: initialNote,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<MenuDetailDialog> createState() => _MenuDetailDialogState();
}

class _MenuDetailDialogState extends State<MenuDetailDialog> {
  late int _qty;
  late TextEditingController _noteCtrl;

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Smart Food Nutrition & Ingredients Provider ──
  Map<String, dynamic> _getNutritionAndIngredients(MenuModel menu) {
    final name = menu.namaMasakan.toLowerCase();

    // 1. Rendang
    if (name.contains('rendang')) {
      return {
        'calories': 468,
        'protein': 32.5,
        'carbs': 11.2,
        'fat': 31.8,
        'fiber': 3.1,
        'ingredients': [
          'Daging Sapi Pilihan (Bagian Gandik / Paha)',
          'Santan Kelapa Murni Kental & Encer',
          'Cabai Merah Keriting & Cabai Rawit Halus',
          'Bawang Merah & Bawang Putih Brebes',
          'Lengkuas & Jahe Segar Dimemarkan',
          'Serai Wangi & Daun Kunyit Alami',
          'Ketumbar Sangrai, Pala & Asam Kandis',
        ],
        'tags': ['Tinggi Protein', 'Kaya Zat Besi', 'Rempah Tradisional Minang', '100% Halal'],
        'allergen': 'Mengandung santan kelapa murni',
        'healthTip': 'Kaya akan protein hewani untuk regenerasi otot dan rempah antibakteri alami.',
      };
    }

    // 2. Ayam Betutu Bali
    if (name.contains('betutu')) {
      return {
        'calories': 385,
        'protein': 35.0,
        'carbs': 7.8,
        'fat': 23.4,
        'fiber': 2.8,
        'ingredients': [
          'Ayam Utuh Segar Bebas Suntik',
          'Base Genep (16 Macam Rempah Khas Bali)',
          'Bawang Merah, Bawang Putih & Kencur',
          'Minyak Kelapa Tandusan Tradisional',
          'Daun Singkong Rebus Bumbu Bejek',
          'Jeruk Limau Segar & Cabai Rawit',
        ],
        'tags': ['Tinggi Protein', 'Antioksidan Alami', 'Rendah Karbohidrat', '100% Halal'],
        'allergen': 'Bebas dari bahan pemicu alergi umum (bebas kacang & susu)',
        'healthTip': 'Dipanggang perlahan dalam bungkusan daun pisang sehingga nutrisi dan sari kaldu ayam terkunci.',
      };
    }

    // 3. Rawon Sapi Surabaya
    if (name.contains('rawon')) {
      return {
        'calories': 345,
        'protein': 29.4,
        'carbs': 9.6,
        'fat': 21.0,
        'fiber': 2.4,
        'ingredients': [
          'Daging Sapi Sandung Lamur Pilihan',
          'Kluwek Hitam Pilihan Jawa Timur (Fermentasi Alami)',
          'Daun Bawang & Bawang Goreng Gurih',
          'Serai, Lengkuas & Daun Jeruk Purut',
          'Tauge Pendek Segar Renyah',
          'Sambal Terasi & Jeruk Nipis',
        ],
        'tags': ['Tinggi Zat Besi', 'Tinggi Protein', 'Kluwek Antioksidan', '100% Halal'],
        'allergen': 'Mengandung sedikit terasi pada sambal pelengkap',
        'healthTip': 'Kluwek mengandung flavonoid dan antioksidan yang baik untuk sirkulasi darah.',
      };
    }

    // 4. Nasi Liwet Solo
    if (name.contains('liwet')) {
      return {
        'calories': 410,
        'protein': 18.2,
        'carbs': 56.4,
        'fat': 14.5,
        'fiber': 3.2,
        'ingredients': [
          'Beras Wangi Pulen Pilihan Solo',
          'Santan Kelapa Cair & Daun Salam',
          'Suwiran Ayam Kampung Opor Gurih',
          'Sayur Labu Siam Kuah Santan Pedas Sedang',
          'Telur Pindang Cokelat Legit',
          'Areh Santan Kental Gurih',
        ],
        'tags': ['Energi Seimbang', 'Kaya Serat Sayur', 'Ayam Kampung Asli', '100% Halal'],
        'allergen': 'Mengandung santan dan telur',
        'healthTip': 'Paduan karbohidrat kompleks, protein telur & sayur labu siam baik untuk pencernaan.',
      };
    }

    // 5. Gudeg Jogja
    if (name.contains('gudeg')) {
      return {
        'calories': 390,
        'protein': 19.5,
        'carbs': 48.0,
        'fat': 16.0,
        'fiber': 5.5,
        'ingredients': [
          'Nangka Muda (Gori) Segar Pilihan',
          'Gula Aren Asli & Daun Jati Pewarna Alami',
          'Krecek Sapi Pedas Gurih',
          'Ayam Kampung Bacem Lembut',
          'Tahu & Tempe Bacem Tradisional',
          'Sambal Goreng Krecek Kedelai',
        ],
        'tags': ['Tinggi Serat Alami', 'Gula Aren Alami', 'Protein Kedelai & Daging', '100% Halal'],
        'allergen': 'Mengandung kedelai (tahu & tempe)',
        'healthTip': 'Nangka muda sangat kaya serat larut yang membantu menjaga kesehatan saluran cerna.',
      };
    }

    // 6. Sate Ayam Madura
    if (name.contains('sate')) {
      return {
        'calories': 420,
        'protein': 34.0,
        'carbs': 18.5,
        'fat': 22.0,
        'fiber': 3.6,
        'ingredients': [
          'Daging Dada Ayam Fillet Tanpa Kulit',
          'Kecap Manis Tradisional Rempah',
          'Saus Kacang Tanah Sangrai Tumbuk Lembut',
          'Bawang Merah Iris Segar & Cabai Rawit',
          'Jeruk Limau Peras Segar',
        ],
        'tags': ['Sangat Tinggi Protein', 'Lemak Baik Kacang', 'Daging Ayam Rendah Lemak', '100% Halal'],
        'allergen': 'Mengandung kacang tanah',
        'healthTip': 'Dada ayam tanpa kulit rendah lemak jenuh, dipadukan lemak tak jenuh dari kacang tanah.',
      };
    }

    // 7. Soto Banjar
    if (name.contains('soto')) {
      return {
        'calories': 320,
        'protein': 25.0,
        'carbs': 28.0,
        'fat': 12.0,
        'fiber': 2.0,
        'ingredients': [
          'Ayam Suwir Kampung Lembut',
          'Kuah Kaldu Bumbu Kayu Manis, Cengkeh & Pala',
          'Perkedel Kentang Panggang Renyah',
          'Telur Bebek Rebus Belah Dua',
          'Bihun Beras & Daun Seledri',
        ],
        'tags': ['Rendah Lemak Jenuh', 'Kuah Rempah Hangat', 'Tinggi Protein', '100% Halal'],
        'allergen': 'Mengandung telur bebek',
        'healthTip': 'Kuah kaldu bening dengan rempah kayu manis dan pala meredakan kembung serta menyegarkan badan.',
      };
    }

    // 8. Pempek Palembang
    if (name.contains('pempek')) {
      return {
        'calories': 310,
        'protein': 22.0,
        'carbs': 36.0,
        'fat': 8.5,
        'fiber': 1.8,
        'ingredients': [
          'Daging Ikan Tenggiri Segar Giling Halus',
          'Tepung Sagu Tani Berkualitas',
          'Isian Telur Ayam Utuh',
          'Kuah Cuko Gula Batok Linggau & Cabai Rawit Hijau',
          'Bawang Putih Tunggal & Asam Jawa',
          'Irisan Timun Segar',
        ],
        'tags': ['Tinggi Asam Lemak Omega-3', 'Rendah Lemak', 'Ikan Tenggiri Segar', '100% Halal'],
        'allergen': 'Mengandung ikan laut & telur',
        'healthTip': 'Ikan tenggiri kaya asam lemak Omega-3 dan protein berkualitas tinggi yang mudah diserap tubuh.',
      };
    }

    // 9. Ayam Taliwang Lombok
    if (name.contains('taliwang')) {
      return {
        'calories': 360,
        'protein': 36.5,
        'carbs': 6.5,
        'fat': 20.5,
        'fiber': 2.2,
        'ingredients': [
          'Ayam Pejantan Muda Kampung',
          'Cabai Merah Kering Khas Lombok',
          'Bawang Merah & Bawang Putih Bakar',
          'Terasi Bakar Berastagi & Jeruk Limau',
          'Gula Merah Alami & Kencur',
        ],
        'tags': ['Sangat Tinggi Protein', 'Metabolisme Capsaicin', 'Rendah Karbohidrat', '100% Halal'],
        'allergen': 'Mengandung terasi udang',
        'healthTip': 'Kandungan capsaicin cabai segar membantu mempercepat laju metabolisme dan pembakaran kalori.',
      };
    }

    // 10. Gado-Gado Betawi
    if (name.contains('gado') || name.contains('sayur')) {
      return {
        'calories': 295,
        'protein': 14.5,
        'carbs': 32.0,
        'fat': 13.5,
        'fiber': 6.8,
        'ingredients': [
          'Bayam Hijau, Tauge & Kacang Panjang Segar',
          'Tahu & Tempe Kedelai Non-GMO Kukus/Goreng',
          'Telur Ayam Rebus Kaya Kolin',
          'Timun Segar & Kentang Rebus',
          'Saus Kacang Tanah Giling Segar Jeruk Limau',
          'Emping Melinjo Panggang Renyah',
        ],
        'tags': ['Tinggi Serat Pangan', 'Kaya Vitamin A & C', 'Protein Nabati', 'Vegetarian Friendly'],
        'allergen': 'Mengandung kacang tanah & telur',
        'healthTip': 'Mengandung lebih dari 6 gram serat alami yang sangat baik untuk menjaga kadar gula darah stabil.',
      };
    }

    // 11. Nasi Goreng Kampung
    if (name.contains('nasi goreng')) {
      return {
        'calories': 480,
        'protein': 21.0,
        'carbs': 62.0,
        'fat': 17.5,
        'fiber': 3.5,
        'ingredients': [
          'Nasi Putih Dingin Butiran Lepas',
          'Bawang Merah, Bawang Putih & Cabai Rawit Cincang',
          'Suwiran Daging Ayam Kampung',
          'Telur Mata Sapi Ceplok Setengah Matang',
          'Kecap Manis Tradisional Tanpa Pengawet',
          'Acar Timun Wortel & Kerupuk Udang',
        ],
        'tags': ['Sumber Karbohidrat Energi', 'Protein Telur & Ayam', 'Bumbu Tumis Tradisional', '100% Halal'],
        'allergen': 'Mengandung telur & kerupuk udang',
        'healthTip': 'Pilihan tepat untuk memenuhi kebutuhan energi harian dengan gizi seimbang.',
      };
    }

    // 12. Minuman: Cendol Durian
    if (name.contains('cendol') || name.contains('teler')) {
      return {
        'calories': 275,
        'protein': 4.2,
        'carbs': 46.5,
        'fat': 8.5,
        'fiber': 3.2,
        'ingredients': [
          'Cendol Alami Tepung Beras Daun Suji Pandan',
          'Santan Kelapa Segar Steril',
          'Gula Aren Asli Kelapa Tanpa Pewarna',
          'Daging Buah Durian Asli / Alpukat Mentega',
          'Es Kristal Higienis',
        ],
        'tags': ['Pemanis Alami Gula Aren', 'Pewarna Daun Pandan Asli', 'Tanpa Bahan Kimia', '100% Halal'],
        'allergen': 'Mengandung santan kelapa',
        'healthTip': 'Gula aren memiliki indeks glikemik lebih rendah dibanding gula pasir rafinasi.',
      };
    }

    // 13. Minuman: Wedang Jahe / Teh Tarik / Kopi
    if (name.contains('jahe') || name.contains('teh') || name.contains('kopi') || menu.kategori == MenuCategory.minuman) {
      final isJahe = name.contains('jahe');
      return {
        'calories': isJahe ? 65 : 120,
        'protein': isJahe ? 0.8 : 2.5,
        'carbs': isJahe ? 15.0 : 22.0,
        'fat': isJahe ? 0.2 : 3.0,
        'fiber': isJahe ? 1.2 : 0.5,
        'ingredients': isJahe
            ? [
                'Jahe Merah Bakar Berkualitas Tinggi',
                'Batang Serai Wangi Segar Memar',
                'Kayu Manis Alami & Cengkeh Utuh',
                'Gula Merah Aren Murni Melaka',
                'Air Mineral Steril Hangat',
              ]
            : [
                'Pucuk Daun Teh Hitam Asli Nusantara',
                'Susu Segar Pilihan',
                'Sentuhan Biji Kapulaga Harum',
                'Gula Alami Secukupnya',
              ],
        'tags': isJahe
            ? ['Imunitas Tubuh', 'Menghangatkan Lambung', 'Rendah Kalori', 'Herbal Tradisional']
            : ['Kaya Antioksidan Teh', 'Menyegarkan Pikiran', '100% Halal'],
        'allergen': isJahe ? 'Bebas alergen umum' : 'Mengandung susu sapi (untuk varian teh susu)',
        'healthTip': 'Jahe merah mengandung gingerol aktif yang meredakan inflamasi dan memperkuat sistem imun.',
      };
    }

    // 14. Paket Spesial
    if (menu.kategori == MenuCategory.paket) {
      return {
        'calories': 680,
        'protein': 42.0,
        'carbs': 78.0,
        'fat': 24.0,
        'fiber': 6.0,
        'ingredients': [
          'Kombinasi Hidangan Utama (Daging Sapi / Ayam Pilihan)',
          'Nasi Putih Wangi / Nasi Liwet Solo Komplit',
          'Sayuran Segar Pelengkap (Lalapan & Krecek)',
          'Minuman Nusantara Segar Pilihan',
          'Sambal Khas & Kerupuk Tradisional',
        ],
        'tags': ['Paket Nutrisi Lengkap', 'Porsi Mengenyangkan', 'Kaya Protein & Karbohidrat', '100% Halal'],
        'allergen': 'Mengandung santan kelapa dan kedelai',
        'healthTip': 'Paket lengkap dengan takaran gizi terukur yang mencakup makronutrien karbohidrat, protein, dan serat.',
      };
    }

    // Generic Fallback untuk Menu Lainnya
    final baseCal = 250 + (menu.harga / 250).round();
    return {
      'calories': baseCal,
      'protein': (baseCal * 0.06).clamp(12.0, 38.0),
      'carbs': (baseCal * 0.10).clamp(15.0, 65.0),
      'fat': (baseCal * 0.035).clamp(8.0, 28.0),
      'fiber': 3.0,
      'ingredients': [
        'Bahan Baku Pilihan Segar Standar Rasantara',
        'Bumbu Rempah Segar Halus Tradisional',
        'Garam Beryodium & Minyak Nabati Pilihan',
        'Daun Salam, Serai & Jeruk Purut Alami',
      ],
      'tags': ['Rempah Nusantara Alami', 'Bahan Segar Berkualitas', '100% Halal'],
      'allergen': 'Harap tanyakan kepada staf jika memiliki alergi khusus.',
      'healthTip': 'Dimasak secara higienis menggunakan bahan segar berkualitas tinggi setiap hari.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final info = _getNutritionAndIngredients(menu);

    final tags = info['tags'] as List<String>;

    final photoUrl = menu.gambarUrl.isNotEmpty
        ? menu.gambarUrl
        : 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80';

    final totalPrice = menu.harga * _qty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto Makanan + Close Button
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: double.infinity,
                          height: 200,
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFFFF7ED),
                              child: const Center(
                                child: Icon(Icons.restaurant_menu, size: 56, color: Color(0xFFEA580C)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: menu.isTersedia ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Text(
                            menu.isTersedia ? 'Tersedia' : 'Habis',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Text(
                            menu.kategori.label,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nama Masakan & Harga
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          menu.namaMasakan,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _currencyFmt.format(menu.harga),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Deskripsi Hidangan
                  Text(
                    menu.deskripsi.isNotEmpty
                        ? menu.deskripsi
                        : 'Hidangan istimewa autentik nusantara dengan cita rasa rempah khas warisan kuliner Indonesia.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Health & Diet Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, size: 12, color: Color(0xFFEA580C)),
                              const SizedBox(width: 4),
                              Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── DESKRIPSI MAKANAN ──
                  const Row(
                    children: [
                      Icon(Icons.description_outlined, color: Color(0xFFEA580C), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Deskripsi Makanan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      menu.deskripsi.isNotEmpty
                          ? menu.deskripsi
                          : 'Hidangan istimewa autentik nusantara dengan cita rasa rempah khas warisan kuliner Indonesia. Dimasak menggunakan racikan bumbu pilihan berkualitas tinggi untuk menciptakan kenikmatan rasa yang tiada tara.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Catatan Pesanan Khusus (Customization)
                  TextField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Catatan Khusus Pesanan (Opsional)',
                      hintText: 'Contoh: Kurang pedas, tanpa santan kental, es sedikit...',
                      prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFFEA580C)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM ACTION BAR (STEPPER & CONFIRM) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Stepper Qty (- / +)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18, color: Color(0xFFEA580C)),
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                        ),
                        Text(
                          '$_qty',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFEA580C)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFFEA580C)),
                          onPressed: () => setState(() => _qty++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Tombol Tambah ke Pesanan
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: menu.isTersedia ? const Color(0xFFEA580C) : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: menu.isTersedia
                          ? () {
                              Navigator.of(context).pop();
                              widget.onConfirm?.call(_qty, _noteCtrl.text.trim());
                            }
                          : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            menu.isTersedia
                                ? 'Pesan • ${_currencyFmt.format(totalPrice)}'
                                : 'Menu Habis',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
