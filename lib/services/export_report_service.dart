import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import '../models/transaction_model.dart';
import 'file_downloader.dart';

class ExportReportService {
  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  /// URL Google Form resmi untuk ulasan dan masukan kepuasan pelanggan Restoran Rasantara
  static String customerFeedbackGFormUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLScw7B5X8_RasantaraResto_UlasanPelanggan/viewform';

  static Future<void> exportTransactionsPdf({
    required List<TransactionModel> transactions,
    required int totalOmzet,
    required String restaurantName,
    required String address,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        restaurantName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#EA580C'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        address,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'LAPORAN TRANSAKSI & PENJUALAN RESMI',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Dicetak: ${_dateFmt.format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Total: ${transactions.length} Transaksi',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Omzet: ${_currencyFmt.format(totalOmzet)}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#EA580C'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'ID TRX',
                'Tanggal',
                'Meja / Tipe',
                'Pelanggan',
                'Kasir',
                'Metode',
                'Total Bayar',
              ],
              data: transactions.map((t) {
                return [
                  '#TRX-${t.idTransaksi}',
                  _dateFmt.format(t.tanggal),
                  t.order.noMeja,
                  t.order.namaPelanggan.isEmpty ? 'Pelanggan' : t.order.namaPelanggan,
                  t.namaKasir,
                  t.metodePembayaran,
                  _currencyFmt.format(t.totalBayar),
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EA580C'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                6: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#EA580C'), width: 1),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TOTAL AKUMULASI PENDAPATAN',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        _currencyFmt.format(totalOmzet),
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#EA580C'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    final filename = 'Laporan_Penjualan_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final bytes = await pdf.save();

    if (kIsWeb) {
      downloadFileWeb(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: filename,
      );
    }
  }

  static Future<void> exportTransactionsExcelCsv({
    required List<TransactionModel> transactions,
  }) async {
    final List<List<dynamic>> rows = [];
    rows.add([
      'ID Transaksi',
      'Tanggal',
      'Waktu',
      'Nomor Meja / Layanan',
      'Nama Pelanggan',
      'Nama Kasir',
      'Metode Pembayaran',
      'Total Item',
      'Total Bayar (Rp)',
      'Jumlah Bayar (Rp)',
      'Kembalian (Rp)',
      'Rincian Menu',
    ]);

    for (final t in transactions) {
      final itemsStr = t.order.items.map((i) => '${i.jumlah}x ${i.menu.namaMasakan}').join('; ');
      rows.add([
        t.idTransaksi,
        DateFormat('yyyy-MM-dd').format(t.tanggal),
        DateFormat('HH:mm:ss').format(t.tanggal),
        t.order.noMeja,
        t.order.namaPelanggan,
        t.namaKasir,
        t.metodePembayaran,
        t.order.totalItem,
        t.totalBayar,
        t.jumlahBayar,
        t.kembalian,
        itemsStr,
      ]);
    }

    final filename = 'Laporan_Penjualan_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csvString'));

    if (kIsWeb) {
      downloadFileWeb(
        bytes: bytes,
        filename: filename,
        mimeType: 'text/csv;charset=utf-8',
      );
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
    }
  }

  static Future<void> printReceiptPdf({
    required TransactionModel transaction,
    required String restaurantName,
    required String address,
  }) async {
    final pdf = pw.Document();
    final order = transaction.order;

    final diskonEvent = transaction.diskonEvent > 0 ? transaction.diskonEvent : order.diskonEvent;
    final diskonKupon = transaction.diskonKupon > 0 ? transaction.diskonKupon : order.diskonKupon;
    final potonganPoin = transaction.potonganPoin > 0 ? transaction.potonganPoin : order.potonganPoin;
    final diskonMember = transaction.diskonMember > 0 ? transaction.diskonMember : order.diskonMember;
    final kodeKupon = transaction.kodeKupon.isNotEmpty ? transaction.kodeKupon : order.kodeKupon;

    final subtotal = order.totalHarga;
    final grandTotal = transaction.totalBayar;

    // Estimasi tinggi kertas termal dinamis agar tidak terpotong
    final itemsCount = order.items.length;
    final pageHeightMm = 180.0 + (itemsCount * 7.0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          76 * PdfPageFormat.mm,
          pageHeightMm * PdfPageFormat.mm,
          marginAll: 3 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: const PdfColor.fromHex('#E2E8F0'), width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── Header Struk Termal Resmi (Orange Cloche Accent) ──
                pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromHex('#FFF7ED'),
                    borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(14)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 28,
                        height: 28,
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromHex('#EA580C'),
                          borderRadius: pw.BorderRadius.circular(7),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'R',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        restaurantName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.5,
                          color: const PdfColor.fromHex('#1E293B'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Cita Rasa Kuliner Nusantara',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromHex('#EA580C'),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        address,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.Text(
                        'Telp: (022) 756-4321 • NPWPD: 98.765.432.1-429.000',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColor.fromHex('#94A3B8')),
                      ),
                    ],
                  ),
                ),

                // Perforated Line
                _buildPdfDashedDivider(),

                // ── Metadata Transaksi ──
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfReceiptRow('No. Transaksi', '#TRX-${transaction.idTransaksi.toString().padLeft(5, '0')}'),
                      _buildPdfReceiptRow('No. Pesanan', '#ORD-${order.idOrder}'),
                      _buildPdfReceiptRow('Waktu Transaksi', _dateFmt.format(transaction.tanggal)),
                      _buildPdfReceiptRow('Layanan / Meja', order.noMeja),
                      _buildPdfReceiptRow('Nama Pelanggan', order.namaPelanggan),
                      _buildPdfReceiptRow('Kasir Pemroses', transaction.namaKasir),
                      _buildPdfReceiptRow('Metode Pembayaran', transaction.metodePembayaran, isBoldValue: true),

                      _buildPdfDashedDivider(),

                      // ── Daftar Menu Hidangan ──
                      ...order.items.map((item) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${item.jumlah}x',
                                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromHex('#1E293B')),
                              ),
                              pw.SizedBox(width: 4),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item.menu.namaMasakan,
                                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromHex('#1E293B')),
                                    ),
                                    if (item.catatan.isNotEmpty)
                                      pw.Text(
                                        'Catatan: ${item.catatan}',
                                        style: const pw.TextStyle(fontSize: 6, color: PdfColor.fromHex('#64748B')),
                                      ),
                                  ],
                                ),
                              ),
                              pw.Text(
                                _currencyFmt.format(item.subtotal),
                                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromHex('#1E293B')),
                              ),
                            ],
                          ),
                        );
                      }),

                      _buildPdfDashedDivider(),

                      // ── Subtotal & Diskon ──
                      _buildPdfReceiptRow('Subtotal Hidangan', _currencyFmt.format(subtotal)),
                      if (diskonEvent > 0)
                        _buildPdfReceiptRow('Diskon Event Promo', '- ${_currencyFmt.format(diskonEvent)}', isBoldValue: true, valColor: const PdfColor.fromHex('#16A34A')),
                      if (diskonMember > 0)
                        _buildPdfReceiptRow('Diskon Pelanggan Langganan (VIP 10%)', '- ${_currencyFmt.format(diskonMember)}', isBoldValue: true, valColor: const PdfColor.fromHex('#16A34A')),
                      if (diskonKupon > 0)
                        _buildPdfReceiptRow('Diskon Kupon ${kodeKupon.isNotEmpty ? "($kodeKupon)" : ""}', '- ${_currencyFmt.format(diskonKupon)}', isBoldValue: true, valColor: const PdfColor.fromHex('#16A34A')),
                      if (potonganPoin > 0)
                        _buildPdfReceiptRow('Potongan Poin Kuliner', '- ${_currencyFmt.format(potonganPoin)}', isBoldValue: true, valColor: const PdfColor.fromHex('#16A34A')),
                      _buildPdfReceiptRow('Pajak Restoran PB1 (10%)', 'Sudah Termasuk', valColor: const PdfColor.fromHex('#94A3B8')),

                      _buildPdfDashedDivider(),

                      // ── Total Tagihan & Pembayaran ──
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL TAGIHAN',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromHex('#1E293B')),
                          ),
                          pw.Text(
                            _currencyFmt.format(grandTotal),
                            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromHex('#EA580C')),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      _buildPdfReceiptRow('Jumlah Dibayar', _currencyFmt.format(transaction.jumlahBayar)),
                      _buildPdfReceiptRow('Kembalian', _currencyFmt.format(transaction.kembalian), isBoldValue: true),

                      pw.SizedBox(height: 12),

                      // ── QR Code Ulasan Pelanggan (GForm Feedback) ──
                      pw.Center(
                        child: pw.BarcodeWidget(
                          data: customerFeedbackGFormUrl,
                          barcode: pw.Barcode.qrCode(),
                          width: 54,
                          height: 54,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final filename = 'Struk_TRX_${transaction.idTransaksi}.pdf';
    final bytes = await pdf.save();

    if (kIsWeb) {
      downloadFileWeb(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/pdf',
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: filename,
    );
  }

  static pw.Widget _buildPdfReceiptRow(String title, String val, {bool isBoldValue = false, PdfColor? valColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#64748B')),
          ),
          pw.Text(
            val,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valColor ?? const PdfColor.fromHex('#1E293B'),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfDashedDivider() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 3.5),
      child: pw.Row(
        children: List.generate(
          28,
          (index) => pw.Expanded(
            child: pw.Container(
              color: index % 2 == 0 ? PdfColors.white : const PdfColor.fromHex('#CBD5E1'),
              height: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
