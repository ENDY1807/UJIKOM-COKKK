import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import '../models/transaction_model.dart';
import '../models/menu_model.dart';
import 'file_downloader.dart';

class ExportReportService {
  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

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
    final csvString = excel.encode(rows);
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

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(72 * PdfPageFormat.mm, 200 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                restaurantName.toUpperCase(),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                address,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No. Trx: #TRX-${transaction.idTransaksi}', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(_dateFmt.format(transaction.tanggal), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Layanan: ${transaction.order.noMeja}', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Kasir: ${transaction.namaKasir}', style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              ...transaction.order.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text('${item.jumlah}x ${item.menu.namaMasakan}', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Text(_currencyFmt.format(item.subtotal), style: const pw.TextStyle(fontSize: 7)),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Tagihan', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_currencyFmt.format(transaction.totalBayar), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bayar (${transaction.metodePembayaran})', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(_currencyFmt.format(transaction.jumlahBayar), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kembalian', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(_currencyFmt.format(transaction.kembalian), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                data: 'TRX-${transaction.idTransaksi}-${transaction.order.noMeja}',
                barcode: pw.Barcode.qrCode(),
                width: 36,
                height: 36,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Terima Kasih Atas Kunjungan Anda\nRasakan Cita Rasa Nusantara',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              ),
            ],
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

  static Future<void> exportMenuPriceListPdf({
    required List<MenuModel> menus,
    String restaurantName = 'Rasantara Restaurant & Lounge',
    String address = 'Jl. Rasantara No. 18, Bandung • Telp: (022) 8765-4321',
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
                          fontSize: 9.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'DAFTAR MENU & PRICE LIST RESMI PELANGGAN',
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
                        'Total Menu: ${menus.length} Item',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Status: Berlaku Terkini',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColor.fromHex('#10B981'),
                          fontWeight: pw.FontWeight.bold,
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
                'No',
                'Nama Menu',
                'Kategori',
                'Deskripsi',
                'Status',
                'Harga Satuan',
              ],
              data: List.generate(menus.length, (i) {
                final m = menus[i];
                return [
                  (i + 1).toString(),
                  m.namaMasakan,
                  m.kategori.label,
                  m.deskripsi.isNotEmpty ? m.deskripsi : '-',
                  m.isTersedia ? 'Tersedia' : 'Habis',
                  _currencyFmt.format(m.harga),
                ];
              }),
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EA580C'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
              },
              headerAlignments: {
                0: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '* Harga sudah termasuk pajak & layanan restoran.',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Rasantara Point of Sale System',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#EA580C'),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    final filename = 'Price_List_Menu_Rasantara_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
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
}
