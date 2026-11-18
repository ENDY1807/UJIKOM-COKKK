import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Color, FontWeight, Offset, Paint, PaintingStyle, Radius, RRect, Rect, Size, TextPainter, TextSpan, TextStyle;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order_model.dart';
import '../models/table_model.dart';
import '../models/transaction_model.dart';
import 'file_downloader.dart';
import 'payment_gateway_service.dart';

class ExportReportService {
  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  // Palet Warna Struk Resmi (Const compile-time)
  static const PdfColor _cOrange = PdfColor.fromInt(0xFFEA580C);
  static const PdfColor _cWarmBg = PdfColor.fromInt(0xFFFFF7ED);
  static const PdfColor _cDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _cGrey = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _cMuted = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor _cBorder = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _cGreen = PdfColor.fromInt(0xFF16A34A);
  static const PdfColor _cDashed = PdfColor.fromInt(0xFFCBD5E1);

  /// URL Google Form resmi untuk ulasan dan masukan kepuasan pelanggan Restoran Rasantara
  static String customerFeedbackGFormUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLScdOIzQGEARA5Dg8zrQaAdoAADUDpU3n7eFxkgHAhck-cM1yg/viewform?usp=dialog';

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
                          color: _cOrange,
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
                          color: _cOrange,
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
              headerDecoration: const pw.BoxDecoration(
                color: _cOrange,
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
                    border: pw.Border.all(color: _cOrange, width: 1),
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
                          color: _cOrange,
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
    final csvString = rows.map((r) => r.map((c) {
      final str = c.toString().replaceAll('"', '""');
      return str.contains(',') || str.contains('"') || str.contains('\n') || str.contains(';') ? '"$str"' : str;
    }).join(',')).join('\r\n');
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

    final diskonMember = transaction.diskonMember > 0 ? transaction.diskonMember : order.diskonMember;

    final subtotal = order.totalHarga;
    final grandTotal = transaction.totalBayar;

    // Estimasi tinggi kertas termal dinamis agar proporsional dan tidak terpotong
    final itemsCount = order.items.length;
    final pageHeightMm = 210.0 + (itemsCount * 9.0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          76 * PdfPageFormat.mm,
          pageHeightMm * PdfPageFormat.mm,
          marginAll: 2 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(color: _cBorder, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── Header Struk Termal Resmi (Sesuai Desain Preview) ──
                pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(14, 16, 14, 12),
                  decoration: const pw.BoxDecoration(
                    color: _cWarmBg,
                    borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(16)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 38,
                        height: 38,
                        padding: const pw.EdgeInsets.all(7),
                        decoration: pw.BoxDecoration(
                          color: _cOrange,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.SvgImage(
                          svg: '''<svg viewBox="0 0 24 24" fill="white">
                            <path d="M8.1 13.34l2.83-2.83L3.91 3.5c-1.56 1.56-1.56 4.09 0 5.66l4.19 4.18zm6.78-1.81c1.53.71 3.68.21 5.27-1.38 1.91-1.91 2.28-4.65.81-6.12-1.46-1.46-4.2-1.1-6.12.81-1.59 1.59-2.09 3.74-1.38 5.27L3.7 19.87l1.41 1.41L12 14.41l6.88 6.88 1.41-1.41L13.41 13l1.47-1.47z"/>
                          </svg>''',
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'RASANTARA',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.5,
                          color: _cDark,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Cita Rasa Kuliner Nusantara',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _cOrange,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Bandung',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8, color: _cGrey),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Telp: (022) 756-4321  -  NPWPD: 98.765.432.1-429.000',
                        style: const pw.TextStyle(fontSize: 7.2, color: _cMuted),
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
                          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${item.jumlah}x',
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _cDark),
                              ),
                              pw.SizedBox(width: 5),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item.menu.namaMasakan,
                                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _cDark),
                                    ),
                                    if (item.catatan.isNotEmpty)
                                      pw.Text(
                                        'Catatan: ${item.catatan}',
                                        style: const pw.TextStyle(fontSize: 6.5, color: _cGrey),
                                      ),
                                  ],
                                ),
                              ),
                              pw.Text(
                                _currencyFmt.format(item.subtotal),
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _cDark),
                              ),
                            ],
                          ),
                        );
                      }),

                      _buildPdfDashedDivider(),

                      // ── Subtotal & Diskon ──
                      _buildPdfReceiptRow('Subtotal Hidangan', _currencyFmt.format(subtotal)),
                      if (diskonMember > 0)
                        _buildPdfReceiptRow('Diskon Pelanggan Langganan (VIP ${subtotal > 0 ? (diskonMember * 100 ~/ subtotal) : 10}%)', '- ${_currencyFmt.format(diskonMember)}', isBoldValue: true, valColor: _cGreen),
                      _buildPdfReceiptRow('Pajak Restoran PB1 (10%)', 'Sudah Termasuk', valColor: _cMuted),

                      _buildPdfDashedDivider(),

                      // ── Total Tagihan & Pembayaran ──
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL TAGIHAN',
                            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _cDark),
                          ),
                          pw.Text(
                            _currencyFmt.format(grandTotal),
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _cOrange),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      _buildPdfReceiptRow('Jumlah Dibayar', _currencyFmt.format(transaction.jumlahBayar)),
                      _buildPdfReceiptRow('Kembalian', _currencyFmt.format(transaction.kembalian), isBoldValue: true),

                      pw.SizedBox(height: 14),

                      // ── QR Code Ulasan Pelanggan (GForm Feedback) ──
                      pw.Center(
                        child: pw.BarcodeWidget(
                          data: customerFeedbackGFormUrl,
                          barcode: pw.Barcode.qrCode(),
                          width: 110,
                          height: 110,
                        ),
                      ),
                      pw.SizedBox(height: 10),
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

    final receiptFormat = PdfPageFormat(
      76 * PdfPageFormat.mm,
      pageHeightMm * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );

    // Langsung buka print spooler dengan ukuran kertas struk termal tanpa konfirmasi download
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => bytes,
      name: filename,
      format: receiptFormat,
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
            style: const pw.TextStyle(fontSize: 7.5, color: _cGrey),
          ),
          pw.Text(
            val,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valColor ?? _cDark,
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
              color: index % 2 == 0 ? PdfColors.white : _cDashed,
              height: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  /// Mencetak Lembar Tagihan QRIS Resmi untuk diberikan ke Meja / Pelanggan
  static Future<void> printQrisBill({
    required OrderModel order,
    String? qrisPayload,
  }) async {
    final pdf = pw.Document();
    final grandTotal = order.grandTotalSetelahDiskon;

    final payload = qrisPayload ??
        PaymentGatewayService.generateAspiEmvCoQris(
          orderId: 'ORDER-${order.idOrder}',
          amount: grandTotal,
          merchantName: PaymentGatewayConfig.defaultMerchantName,
          city: PaymentGatewayConfig.defaultCity,
          postalCode: PaymentGatewayConfig.defaultPostalCode,
          nmid: PaymentGatewayConfig.defaultNmid,
        );

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _cBorder, width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header Restoran
                pw.Text(
                  'RESTORAN RASANTARA',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _cOrange,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Autentik Cita Rasa Nusantara',
                  style: const pw.TextStyle(fontSize: 7, color: _cGrey),
                ),
                pw.SizedBox(height: 6),

                // Badge Tagihan QRIS
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: _cWarmBg,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: _cOrange, width: 0.5),
                  ),
                  child: pw.Text(
                    'LEMBAR PEMBAYARAN QRIS',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _cOrange,
                    ),
                  ),
                ),

                _buildPdfDashedDivider(),

                // Metadata Pesanan
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    children: [
                      _buildPdfReceiptRow('Layanan / Meja', order.noMeja, isBoldValue: true),
                      _buildPdfReceiptRow('No. Pesanan', '#ORD-${order.idOrder}'),
                      _buildPdfReceiptRow('Waktu Pesan', _dateFmt.format(order.tanggal)),
                      _buildPdfReceiptRow('Nama Tamu', order.namaPelanggan),
                      _buildPdfReceiptRow('Metode Pembayaran', 'QRIS (Nirsentuh)', isBoldValue: true, valColor: _cOrange),
                    ],
                  ),
                ),

                _buildPdfDashedDivider(),

                // Daftar Item Hidangan
                ...order.items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${item.jumlah}x ${item.menu.namaMasakan}',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _cDark,
                            ),
                          ),
                        ),
                        pw.Text(
                          _currencyFmt.format(item.subtotal),
                          style: const pw.TextStyle(fontSize: 7.5, color: _cDark),
                        ),
                      ],
                    ),
                  );
                }),

                if (order.totalDiskon > 0) ...[
                  _buildPdfDashedDivider(),
                  _buildPdfReceiptRow('Subtotal', _currencyFmt.format(order.totalHarga)),
                  _buildPdfReceiptRow('Diskon Promosi', '- ${_currencyFmt.format(order.totalDiskon)}', isBoldValue: true, valColor: _cGreen),
                ],

                _buildPdfDashedDivider(),

                // Total Tagihan
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL PEMBAYARAN',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _cDark,
                      ),
                    ),
                    pw.Text(
                      _currencyFmt.format(grandTotal),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _cOrange,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 8),

                // Area Barcode QRIS
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: _cBorder, width: 1),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.BarcodeWidget(
                    data: payload,
                    barcode: pw.Barcode.qrCode(),
                    width: 130,
                    height: 130,
                  ),
                ),

                pw.SizedBox(height: 5),
                pw.Text(
                  'NMID: ${PaymentGatewayConfig.defaultNmid}',
                  style: const pw.TextStyle(fontSize: 6.5, color: _cGrey),
                ),
                pw.Text(
                  'A.N: ${PaymentGatewayConfig.defaultMerchantName}',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _cDark,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Bisa di-scan menggunakan GoPay, OVO, DANA, ShopeePay, BCA, Livin Mandiri, atau Mobile Banking lainnya.',
                  style: const pw.TextStyle(fontSize: 6, color: _cGrey),
                  textAlign: pw.TextAlign.center,
                ),

                _buildPdfDashedDivider(),

                pw.Text(
                  'Tunjukkan bukti transfer ke kasir / pelayan\nTerima Kasih atas Kunjungan Anda!',
                  style: const pw.TextStyle(fontSize: 6.5, color: _cMuted),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    final filename = 'QRIS_Meja_${order.noMeja.replaceAll(' ', '_')}_ORD${order.idOrder}.pdf';
    final bytes = await pdf.save();

    const qrisFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    // Langsung buka print spooler dengan ukuran kertas struk termal tanpa konfirmasi download
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => bytes,
      name: filename,
      format: qrisFormat,
    );
  }

  /// Download Stiker QR Meja Satuan dalam format PDF Siap Cetak (Desain Kartu Meja)
  static Future<String?> downloadTableQrStickerPdf(TableModel table) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          100 * PdfPageFormat.mm,
          130 * PdfPageFormat.mm,
          marginAll: 6 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
              border: pw.Border.all(color: _cBorder, width: 1.5),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header Brand
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 20,
                      height: 20,
                      decoration: const pw.BoxDecoration(
                        color: _cOrange,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'R',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'RASANTARA',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                        color: _cDark,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),

                // QR Code
                pw.BarcodeWidget(
                  data: table.qrPayload,
                  barcode: pw.Barcode.qrCode(),
                  width: 140,
                  height: 140,
                ),
                pw.SizedBox(height: 12),

                // Nomor Meja
                pw.Text(
                  table.nomorMeja,
                  style: pw.TextStyle(
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                    color: _cDark,
                  ),
                ),
                pw.SizedBox(height: 3),

                // Subtitle
                pw.Text(
                  'Kapasitas ${table.kapasitas} Kursi • Pindai untuk Pesan Menu',
                  style: const pw.TextStyle(fontSize: 8.5, color: _cGrey),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    final filename = 'Stiker_QR_${table.nomorMeja.replaceAll(' ', '_')}.pdf';
    final bytes = await pdf.save();

    final savedPath = await saveFileToDevice(bytes: bytes, filename: filename);

    if (!kIsWeb) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat _) async => bytes,
        name: filename,
      );
    }

    return savedPath;
  }

  /// Download Gambar Stiker QR Meja Lengkap dalam format PNG Card (Desain Stiker Meja Rasantara)
  static Future<String?> downloadTableQrImagePng(TableModel table) async {
    const cardWidth = 520.0;
    const cardHeight = 630.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 1. Gambar Background Kartu Putih & Border Halus
    final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, cardWidth, cardHeight),
      const Radius.circular(26),
    );
    final fillPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRRect(cardRect, fillPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(cardRect, borderPaint);

    // 2. Load Logo Asset Rasantara
    ui.Image? logoImg;
    try {
      final data = await rootBundle.load('assets/images/Rasantara Cloche App Icon.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      logoImg = frame.image;
    } catch (_) {}

    // 3. Header: Logo + Teks "RASANTARA"
    final brandText = TextPainter(
      text: const TextSpan(
        text: 'RASANTARA',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    const logoSize = 36.0;
    const gap = 10.0;
    final totalHeaderWidth = logoSize + gap + brandText.width;
    final headerX = (cardWidth - totalHeaderWidth) / 2;
    const headerY = 32.0;

    if (logoImg != null) {
      final logoRect = Rect.fromLTWH(headerX, headerY, logoSize, logoSize);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(logoRect, const Radius.circular(8)));
      canvas.drawImageRect(
        logoImg,
        Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
        logoRect,
        Paint(),
      );
      canvas.restore();
    } else {
      final logoRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(headerX, headerY, logoSize, logoSize),
        const Radius.circular(8),
      );
      canvas.drawRRect(logoRect, Paint()..color = const Color(0xFFEA580C));
      final rPainter = TextPainter(
        text: const TextSpan(
          text: 'R',
          style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      rPainter.paint(
        canvas,
        Offset(headerX + (logoSize - rPainter.width) / 2, headerY + (logoSize - rPainter.height) / 2),
      );
    }

    final brandY = headerY + (logoSize - brandText.height) / 2;
    brandText.paint(canvas, Offset(headerX + logoSize + gap, brandY));

    // 4. QR Code di Tengah
    const qrSize = 360.0;
    final qrX = (cardWidth - qrSize) / 2;
    const qrY = 92.0;

    final painter = QrPainter(
      data: table.qrPayload,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF0F172A),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF0F172A),
      ),
    );

    canvas.save();
    canvas.translate(qrX, qrY);
    painter.paint(canvas, const Size(qrSize, qrSize));
    canvas.restore();

    // 5. Teks Nomor Meja
    final titleText = TextPainter(
      text: TextSpan(
        text: table.nomorMeja,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    const titleY = 485.0;
    titleText.paint(canvas, Offset((cardWidth - titleText.width) / 2, titleY));

    // 6. Teks Subtitle Kapasitas & Petunjuk
    final subtitleText = TextPainter(
      text: TextSpan(
        text: 'Kapasitas ${table.kapasitas} Kursi • Pindai untuk Pesan Menu',
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    const subtitleY = 542.0;
    subtitleText.paint(canvas, Offset((cardWidth - subtitleText.width) / 2, subtitleY));

    // 7. Render ke PNG Uint8List
    final picture = recorder.endRecording();
    final renderedImg = await picture.toImage(cardWidth.toInt(), cardHeight.toInt());
    final byteData = await renderedImg.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final filename = 'Stiker_QR_${table.nomorMeja.replaceAll(' ', '_')}.png';

    return await saveFileToDevice(bytes: bytes, filename: filename);
  }

  /// Download Semua Stiker QR Meja Restoran Sekaligus (A4 Sheet PDF)
  static Future<String?> downloadAllTablesQrPdf(List<TableModel> tables) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _cBorder, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'RASANTARA RESTORAN • LEMBAR STIKER QR MEJA',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: _cOrange),
                ),
                pw.Text(
                  'Total: ${tables.length} Meja',
                  style: const pw.TextStyle(fontSize: 10, color: _cGrey),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tables.map((t) {
                return pw.Container(
                  width: 165,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: _cOrange, width: 1.5),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'RASANTARA',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _cOrange),
                      ),
                      pw.SizedBox(height: 4),
                      pw.BarcodeWidget(
                        data: t.qrPayload,
                        barcode: pw.Barcode.qrCode(),
                        width: 80,
                        height: 80,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        t.nomorMeja,
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _cDark),
                      ),
                      pw.Text(
                        'Kapasitas ${t.kapasitas} Kursi',
                        style: const pw.TextStyle(fontSize: 7.5, color: _cGrey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    final filename = 'Semua_Stiker_QR_Meja_Rasantara.pdf';
    final bytes = await pdf.save();

    final savedPath = await saveFileToDevice(bytes: bytes, filename: filename);

    if (!kIsWeb) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat _) async => bytes,
        name: filename,
      );
    }

    return savedPath;
  }
}
