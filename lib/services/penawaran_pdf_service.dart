import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/asset_constants.dart';
import '../models/penawaran_model.dart';

enum PenawaranPdfTemplateKey {
  kencanaPrint,
  jayaAbadiMulia,
  madaniProduction,
}

class PenawaranPdfService {
  static const _kShortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  /// Format tanggal medium (contoh: 15 Okt 2026)
  static String _formatDate(String ymd) {
    if (ymd.isEmpty) return '-';
    try {
      final clean = ymd.trim().split('T')[0].split(' ')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null && m >= 1 && m <= 12) {
          return '$d ${_kShortMonths[m - 1]} $y';
        }
      }
      final dt = DateTime.parse(clean);
      return '${dt.day} ${_kShortMonths[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return ymd;
    }
  }

  /// Format angka tanpa prefix simbol "Rp "
  static String _formatNumber(num value) {
    final fmt = NumberFormat('#,##0', 'id_ID');
    return fmt.format(value);
  }

  /// Format Rupiah lengkap dengan prefix Rp.
  static String _fmtRupiah(num value) {
    return 'Rp. ${_formatNumber(value)}';
  }

  /// Resolusi template perusahaan
  static PenawaranPdfTemplateKey _resolveTemplate(
    String companyName,
    String companyCode,
  ) {
    final normName = companyName.trim().toLowerCase();
    final normCode = companyCode.trim().toUpperCase();

    if (normName.contains('jaya abadi') ||
        normName.contains('pt. jaya abadi mulia') ||
        normCode.contains('JAY') ||
        normCode.contains('JA')) {
      return PenawaranPdfTemplateKey.jayaAbadiMulia;
    }
    if (normName.contains('madani') ||
        normCode.contains('MD') ||
        normCode.contains('MAD')) {
      return PenawaranPdfTemplateKey.madaniProduction;
    }
    if (normName.contains('kencana') ||
        normCode.contains('KP') ||
        normCode.contains('KENCANA')) {
      return PenawaranPdfTemplateKey.kencanaPrint;
    }
    return PenawaranPdfTemplateKey.kencanaPrint;
  }

  /// Resolusi catatan PPN sama persis dengan Manksi Web
  static String _resolveTaxNote(PenawaranHeader header) {
    if (header.statusHarga == 1) {
      return '* Note : Harga sudah termasuk PPN 11%';
    }
    if (header.statusHarga == 0) {
      return '* Note : Harga belum termasuk PPN 11%';
    }
    if (header.statusHarga == 2) {
      return '';
    }

    final textToCheck = '${header.note} ${header.keterangan}'.toUpperCase();
    if (textToCheck.contains('SUDAH TERMASUK PPN') ||
        textToCheck.contains('INC PPN') ||
        textToCheck.contains('INCLUDE PPN')) {
      return '* Note : Harga sudah termasuk PPN 11%';
    }
    if (textToCheck.contains('BELUM TERMASUK PPN') ||
        textToCheck.contains('EXC PPN') ||
        textToCheck.contains('EXCLUDE PPN')) {
      return '* Note : Harga belum termasuk PPN 11%';
    }

    return '';
  }

  /// Parse klausul tambahan dari pen_tambahan (id 1 s/d 7)
  static List<String> _parseTambahan(
    PenawaranHeader header,
    PenawaranPdfTemplateKey template,
  ) {
    if (header.tambahan.trim().isEmpty) return [];
    final ids = header.tambahan.split(',').map((s) => s.trim()).toList();
    final result = <String>[];

    if (ids.isNotEmpty && template == PenawaranPdfTemplateKey.jayaAbadiMulia) {
      result.add('Keterangan :');
    }

    for (final id in ids) {
      switch (id) {
        case '1':
          result.add(
            '- Ukuran kaos ${header.panjang.toInt()} x ${header.lebar.toInt()} cm.',
          );
          break;
        case '2':
          result.add('- Sablon tidak luntur.');
          break;
        case '3':
          result.add('- Harga Include ongkos kirim (Free Ongkir).');
          break;
        case '4':
          result.add('- Bisa Packing sesuai alokasi.');
          break;
        case '5':
          result.add('- Selalu ada laporan setelah barang diterima.');
          break;
        case '6':
          result.add('- Garansi barang sesuai yang dipesan.');
          break;
        case '7':
          result.add(
            '- Dikarenakan proses drying, ukuran jadi spanduk/umbul akan mengalami penyusutan ±5 cm.',
          );
          break;
      }
    }
    return result;
  }

  /// Parse rincian sample dari pen_sample
  static List<String> _parseSample(PenawaranHeader header) {
    if (header.sample.trim().isEmpty) return [];
    final ids = header.sample
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return [];

    final div = header.divisi.trim();
    final result = <String>[];

    if (div == '4') {
      // Garmen
      final sampleGarmen = {
        1: 'Baju Uniform (Kemeja) : Rp 400.000',
        2: 'Celana : Rp 300.000',
        3: 'Celemek : Rp 200.000',
        4: 'Jaket : Rp 500.000',
        5: 'Jas Almamater : Rp 500.000',
        6: 'Kaos Krah : Rp 350.000',
        7: 'Kaos Oblong : Rp 200.000',
        8: 'Rompi : Rp 500.000',
        9: 'Wearpack : Rp 900.000',
      };
      result.add('- Rincian Biaya Sampel :');
      for (final id in ids) {
        if (sampleGarmen.containsKey(id)) {
          result.add('  ${sampleGarmen[id]}');
        }
      }
    } else if (div == '1') {
      // Spanduk
      final sampleSpanduk = {
        1: 'Pembuatan sampel dikenakan biaya Rp 1.000.000 / desain.',
        2: 'Jika ACC bisa dijadikan DP.',
        3: 'Jika ada revisi desain dikenakan biaya ganti film Rp 500.000.',
      };
      result.add('- Ketentuan Sample :');
      for (final id in ids) {
        if (sampleSpanduk.containsKey(id)) {
          result.add('  ${sampleSpanduk[id]}');
        }
      }
    } else if (div == '5') {
      // MMT
      result.add('- Ketentuan Sample :');
      result.add('  Harga sesuai pricelist ritailer.');
    }

    return result;
  }

  static Future<void> exportPenawaran({
    required PenawaranHeader header,
    required List<PenawaranDetailItem> details,
  }) async {
    // 1. Muat font Unicode (Roboto / OpenSans)
    pw.Font? regularFont;
    pw.Font? boldFont;
    pw.Font? italicFont;
    pw.Font? boldItalicFont;
    try {
      regularFont = await PdfGoogleFonts.robotoRegular();
      boldFont = await PdfGoogleFonts.robotoBold();
      italicFont = await PdfGoogleFonts.robotoItalic();
      boldItalicFont = await PdfGoogleFonts.robotoBoldItalic();
    } catch (_) {
      try {
        regularFont = await PdfGoogleFonts.openSansRegular();
        boldFont = await PdfGoogleFonts.openSansBold();
        italicFont = await PdfGoogleFonts.openSansItalic();
        boldItalicFont = await PdfGoogleFonts.openSansBoldItalic();
      } catch (_) {}
    }

    final theme = regularFont != null && boldFont != null
        ? pw.ThemeData.withFont(
            base: regularFont,
            bold: boldFont,
            italic: italicFont,
            boldItalic: boldItalicFont,
          )
        : pw.ThemeData.base();

    final pdf = pw.Document(theme: theme);

    // 2. Load Gambar Kop Header dan Stempel Digital Signature
    final companyKey = header.perusahaan.isNotEmpty
        ? header.perusahaan
        : header.perusahaanKode;
    pw.MemoryImage? kopImage;
    pw.MemoryImage? signImage;

    try {
      final kopPath = AppAssets.getPenawaranKop(companyKey);
      final kopBytes = await rootBundle.load(kopPath);
      kopImage = pw.MemoryImage(kopBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final signPath = AppAssets.getPenawaranSign(companyKey);
      final signBytes = await rootBundle.load(signPath);
      signImage = pw.MemoryImage(signBytes.buffer.asUint8List());
    } catch (_) {}

    final template = _resolveTemplate(header.perusahaan, header.perusahaanKode);
    final grandTotal = details.fold<double>(
      0.0,
      (acc, curr) => acc + curr.total,
    );
    final upLabel = header.up.trim().isNotEmpty
        ? header.up.trim()
        : (header.customer.isNotEmpty ? header.customer : '-');

    final ttdName = header.ttd.trim().isNotEmpty
        ? header.ttd.trim()
        : (template == PenawaranPdfTemplateKey.kencanaPrint ? 'Marketing' : '-');

    final ttdJabatan = header.ttdJabatan.trim().isNotEmpty
        ? header.ttdJabatan.trim()
        : (template == PenawaranPdfTemplateKey.kencanaPrint
            ? 'Supervisor Office Marketing'
            : '-');

    final isSigned = header.isApproved ||
        header.digitalSign.toUpperCase() == 'Y' ||
        header.approvalState.toUpperCase() == 'ACC';

    final taxNoteText = _resolveTaxNote(header);
    final note = header.note.trim().isNotEmpty ? header.note.trim() : '';

    // Warna border keliling halaman persis Manksi Web: JA = #002060, KP & MD = #eca100
    final pageBorderColor = template == PenawaranPdfTemplateKey.jayaAbadiMulia
        ? const PdfColor.fromInt(0xFF002060)
        : const PdfColor.fromInt(0xFFECA100);

    final tambahanList = _parseTambahan(header, template);
    final sampleList = _parseSample(header);

    // Perhitungan DP
    final dpNominal = header.dpPer > 0
        ? ((grandTotal > 0 ? grandTotal : header.nominal) * header.dpPer / 100)
            .roundToDouble()
        : 0.0;

    // Email perusahaan fallback
    final companyEmail = header.perushEmail.isNotEmpty
        ? header.perushEmail
        : (template == PenawaranPdfTemplateKey.jayaAbadiMulia
            ? 'm.officer@jayaabadimulia.co.id'
            : (template == PenawaranPdfTemplateKey.madaniProduction
                ? 'm.officer@madaniproduction.co.id'
                : 'solokencana2@gmail.com'));

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24), // Margin dalam bingkai
          buildBackground: (context) {
            // Bingkai luar keliling persis Manksi Web
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(
                margin: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pageBorderColor, width: 1.2),
                ),
              ),
            );
          },
        ),
        build: (pw.Context context) {
          return [
            // 1. HEADER (KOP PERUSAHAAN)
            if (template == PenawaranPdfTemplateKey.jayaAbadiMulia)
              _buildJayaAbadiHeader(header, kopImage)
            else if (template == PenawaranPdfTemplateKey.kencanaPrint)
              _buildKencanaPrintHeader(kopImage)
            else
              _buildMadaniHeader(kopImage),

            pw.SizedBox(height: 6),

            // 2. METADATA DOKUMEN (Kepada Yth & No/Tgl/Perihal)
            if (template == PenawaranPdfTemplateKey.jayaAbadiMulia)
              _buildJayaAbadiMeta(header, upLabel)
            else if (template == PenawaranPdfTemplateKey.kencanaPrint)
              _buildKencanaPrintMeta(header, upLabel)
            else
              _buildMadaniMeta(header, upLabel),

            pw.SizedBox(height: 6),

            // 3. PENGANTAR (INTRODUCING TEXT)
            if (template == PenawaranPdfTemplateKey.jayaAbadiMulia) ...[
              pw.Text(
                'Dengan Hormat,\n'
                'Pertama kami mengucapkan terima kasih atas kesempatan yang diberikan kepada kami untuk memberikan Surat Penawaran Harga kepada perusahaan yang Bapak / Ibu pimpin.\n'
                'Kami dari PT. Jaya Abadi Mulia yang bergerak di bidang penyedia material promosi dalam bidang printing dan garment bermaksud untuk memberikan penawaran harga atas beberapa pekerjaan yang tersebut di bawah ini :',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),
            ] else if (template == PenawaranPdfTemplateKey.kencanaPrint) ...[
              pw.Text('Dengan Hormat,',
                  style: const pw.TextStyle(fontSize: 8.5)),
              pw.SizedBox(height: 2),
              pw.Text(
                'Bersama dengan surat ini kami perusahaan yang bergerak di garmen, manual printing dan digital printing akan mengajukan penawaran harga untuk item-item barang tersebut di bawah ini:',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),
            ] else ...[
              pw.Text('Dengan Hormat,',
                  style: const pw.TextStyle(fontSize: 8.5)),
              pw.SizedBox(height: 2),
              pw.Text(
                'Bersama dengan surat ini kami perusahaan yang bergerak di garmen, manual printing dan digital printing akan mengajukan penawaran harga untuk item-item barang tersebut di bawah ini:',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),
            ],

            pw.SizedBox(height: 6),

            // 4. TABEL RINCIAN BARANG
            _buildGridTable(
              details: details,
              grandTotal: grandTotal > 0 ? grandTotal : header.nominal,
              cetakTotal: header.cetakTotal,
            ),

            // 5. TAX NOTE (Jika ada)
            if (taxNoteText.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                taxNoteText,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.black,
                ),
              ),
            ],

            pw.SizedBox(height: 5),

            // 6. BLOK BAWAH: KOLOM KIRI (CATATAN & PEMBAYARAN) + KOLOM KANAN (TANDA TANGAN)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- KOLOM KIRI (NOTE SECTION & PAYMENT) ---
                pw.Expanded(
                  flex: 66,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Kalimat Penutup
                      if (template == PenawaranPdfTemplateKey.jayaAbadiMulia) ...[
                        pw.Text(
                          'Keterangan lebih lanjut bisa menghubungi '
                          '${header.marketing.trim().isNotEmpty ? 'marketing kami ${header.marketing.trim()} di nomor ${header.marketingTelp.trim().isNotEmpty ? header.marketingTelp.trim() : (header.perushTelp.trim().isNotEmpty ? header.perushTelp.trim() : '0271-722998')}.' : 'kami di nomor ${header.perushTelp.trim().isNotEmpty ? header.perushTelp.trim() : '0271-722998'}.'}',
                          style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.2),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Demikian Surat Penawaran ini kami sampaikan, kabar baik dari Bapak/Ibu sangat kami nantikan. Atas perhatian dan kerja samanya kami ucapkan terima kasih.',
                          style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.2),
                        ),
                      ] else ...[
                        pw.Text(
                          'Demikian penawaran ini kami ajukan, apabila ada informasi yang perlu diketahui mengenai penawaran ini lebih lanjut maka Bapak/Ibu dapat menghubungi kami. Atas perhatian dan kerja samanya kami ucapkan terima kasih.',
                          style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.2),
                        ),
                      ],

                      // Note Box Kuning
                      if (note.isNotEmpty) ...[
                        pw.SizedBox(height: 5),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFFFF200), // Kuning Manksi Web
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (template != PenawaranPdfTemplateKey.jayaAbadiMulia)
                                pw.Text(
                                  'Note :',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              pw.Text(
                                note,
                                style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Klausul Finishing Jahit (*Harga include finishing jahit.*)
                      if (header.mx.toUpperCase() == 'Y') ...[
                        pw.SizedBox(height: 4),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFFFF200),
                          ),
                          child: pw.Text(
                            '*Harga include finishing jahit.*',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],

                      // Klausul Tambahan
                      if (tambahanList.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        ...tambahanList.map(
                          (t) => pw.Text(
                            t,
                            style: const pw.TextStyle(fontSize: 7.5),
                          ),
                        ),
                      ],

                      // Ketentuan Sampel
                      if (sampleList.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        ...sampleList.map(
                          (s) => pw.Text(
                            s,
                            style: const pw.TextStyle(fontSize: 7.5),
                          ),
                        ),
                      ],

                      // Tabel Rekening Pembayaran
                      if (header.rekening.isNotEmpty ||
                          header.bank.isNotEmpty ||
                          dpNominal > 0) ...[
                        pw.SizedBox(height: 6),
                        pw.Table(
                          columnWidths: {
                            0: const pw.FixedColumnWidth(110),
                            1: const pw.FlexColumnWidth(),
                          },
                          children: [
                            if (header.dpPer > 0)
                              pw.TableRow(
                                children: [
                                  pw.Text(
                                    template == PenawaranPdfTemplateKey.jayaAbadiMulia
                                        ? 'Mohon Untuk DP Sebesar'
                                        : 'DP',
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                  pw.Text(
                                    template == PenawaranPdfTemplateKey.jayaAbadiMulia
                                        ? _fmtRupiah(dpNominal)
                                        : ': ${header.dpPer.toInt()}% = ${_fmtRupiah(dpNominal)}',
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                ],
                              ),
                            if (header.rekening.isNotEmpty)
                              pw.TableRow(
                                children: [
                                  pw.Text('Rekening',
                                      style: const pw.TextStyle(fontSize: 8)),
                                  pw.Text(': ${header.rekening}',
                                      style: const pw.TextStyle(fontSize: 8)),
                                ],
                              ),
                            if (header.bank.isNotEmpty)
                              pw.TableRow(
                                children: [
                                  pw.Text('Bank',
                                      style: const pw.TextStyle(fontSize: 8)),
                                  pw.Text(': ${header.bank}',
                                      style: const pw.TextStyle(fontSize: 8)),
                                ],
                              ),
                            if (header.bankAtasnama.isNotEmpty ||
                                header.bankCabang.isNotEmpty)
                              pw.TableRow(
                                children: [
                                  pw.Text('A.n / Cbg',
                                      style: const pw.TextStyle(fontSize: 8)),
                                  pw.Text(
                                    ': ${header.bankAtasnama} / ${header.bankCabang}',
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (header.rekening.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Bukti Pembayaran mohon di email ke $companyEmail',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                pw.SizedBox(width: 14),

                // --- KOLOM KANAN (TANDA TANGAN RESMI & STEMPEL DIGITAL) ---
                pw.Expanded(
                  flex: 34,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Hormat Kami,',
                        style: const pw.TextStyle(fontSize: 8.5),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 3),
                      if (isSigned && signImage != null)
                        pw.Container(
                          height: 52,
                          alignment: pw.Alignment.bottomCenter,
                          child: pw.Image(
                            signImage,
                            width: 108,
                            height: 52,
                            fit: pw.BoxFit.contain,
                          ),
                        )
                      else
                        pw.SizedBox(height: 48),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        padding: const pw.EdgeInsets.only(bottom: 1),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: PdfColors.black,
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: pw.Text(
                          ttdName,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        ttdJabatan,
                        style: const pw.TextStyle(fontSize: 7.5),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 7. FOOTER KHUSUS JAYA ABADI MULIA
            if (template == PenawaranPdfTemplateKey.jayaAbadiMulia) ...[
              pw.SizedBox(height: 18),
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 1.5),
                  ),
                ),
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PT. Jaya Abadi Mulia',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Dk. Padokan RT 004 RW 004 Sawahan, Ngemplak Kb. Boyolali Jawa Tengah 57375',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.Text(
                      'Telp  0271-722998 / Fax  0271-722998',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.Text(
                      'www.jayaabadimulia.com',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );

    final safeName = header.nomor.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Penawaran_$safeName.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Penawaran_$safeName.pdf',
      );
    }
  }

  // --- TEMPLATE KOP: KENCANA PRINT ---
  static pw.Widget _buildKencanaPrintHeader(pw.MemoryImage? kopImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 46,
              child: kopImage != null
                  ? pw.Container(
                      alignment: pw.Alignment.topLeft,
                      child: pw.Image(
                        kopImage,
                        width: 240,
                        height: 64,
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Kencana Print',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFFD90429),
                          ),
                        ),
                        pw.Text(
                          'Semakin Nyala Semakin Nyata',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontStyle: pw.FontStyle.italic,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              flex: 54,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'OUR SERVICES :',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '- GARMENT (T-SHIRT, POLO SHIRT, KEMEJA, WEARPACK, Etc).',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    '- MANUAL PRINTING (SPANDUK/UMBUL KAIN).',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    '- DIGITAL PRINTING (X BANNER, ROLL BANNER, FLEXI, ALBATROS, TENDA, STICKER, Etc).',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 1),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
            ),
          ),
          child: pw.Text(
            'CV. Kencana Print',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text('Padokan RT 04 / 04 Sawahan Ngemplak',
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Telp  0271-740634  /  Fax  0271-740634',
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text('solokencana2@gmail.com',
            style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  // --- TEMPLATE KOP: JAYA ABADI MULIA ---
  // Sesuai Manksi Web: Logo JA di KIRI ATAS, Tanggal Surakarta di KANAN ATAS
  static pw.Widget _buildJayaAbadiHeader(
    PenawaranHeader header,
    pw.MemoryImage? kopImage,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (kopImage != null)
          pw.Container(
            alignment: pw.Alignment.topLeft,
            child: pw.Image(
              kopImage,
              width: 250,
              height: 60,
              fit: pw.BoxFit.contain,
            ),
          )
        else
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'PT. ',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFFD80F16),
                    ),
                  ),
                  pw.Text(
                    'Jaya Abadi Mulia',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Your Best Solutions Partner',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColor.fromInt(0xFFB11F1F),
                ),
              ),
            ],
          ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'Surakarta, ${_formatDate(header.tanggal)}',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // --- TEMPLATE KOP: MADANI PRODUCTION ---
  static pw.Widget _buildMadaniHeader(pw.MemoryImage? kopImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 46,
              child: kopImage != null
                  ? pw.Container(
                      alignment: pw.Alignment.topLeft,
                      child: pw.Image(
                        kopImage,
                        width: 230,
                        height: 58,
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  : pw.Text(
                      'PT. MADANI PRODUCTION',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              flex: 54,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'OUR SERVICES :',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '- GARMENT (T-SHIRT, POLO SHIRT, KEMEJA, WEARPACK, Etc).',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    '- MANUAL PRINTING (SPANDUK/UMBUL KAIN).',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    '- DIGITAL PRINTING (X BANNER, ROLL BANNER, FLEXI, ALBATROS, TENDA, STICKER, Etc).',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'PT. Madani Production',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          'Dusun Demen RT 003 RW 001, Kel. Jeron, Kec. Nogosari, Kab. Boyolali, Jawa Tengah',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          'Telp  0271-7889327  /  Fax  0271-7889327',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          'm.officer@madaniproduction.co.id',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }

  // --- META: KENCANA PRINT ---
  static pw.Widget _buildKencanaPrintMeta(
    PenawaranHeader header,
    String upLabel,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 58,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Kepada YTH',
                    style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 1),
                pw.Text(
                  header.customer.isNotEmpty ? header.customer : 'DARI WEB',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (header.customerAlamat.isNotEmpty)
                  pw.Text(header.customerAlamat,
                      style: const pw.TextStyle(fontSize: 7.5)),
                if (header.customerKota.isNotEmpty)
                  pw.Text(header.customerKota,
                      style: const pw.TextStyle(fontSize: 7.5)),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Up.   $upLabel',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 42,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildMetaRow('Tanggal', _formatDate(header.tanggal)),
              _buildMetaRow('Perihal', 'Penawaran Harga'),
              _buildMetaRow('No', header.nomor),
              _buildMetaRow(
                'Keterangan',
                header.keterangan.isNotEmpty ? header.keterangan : '-',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- META: JAYA ABADI MULIA ---
  static pw.Widget _buildJayaAbadiMeta(
    PenawaranHeader header,
    String upLabel,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Kepada Yth.', style: const pw.TextStyle(fontSize: 8.5)),
        pw.Text(
          upLabel,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          header.customer.isNotEmpty ? header.customer : '-',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        if (header.customerAlamat.isNotEmpty)
          pw.Text(header.customerAlamat,
              style: const pw.TextStyle(fontSize: 7.5)),
        if (header.customerKota.isNotEmpty)
          pw.Text(header.customerKota,
              style: const pw.TextStyle(fontSize: 7.5)),
        pw.SizedBox(height: 4),
        _buildMetaRow('Nomor', header.nomor, labelWidth: 80),
        _buildMetaRow('Perihal', 'Surat Penawaran Harga', labelWidth: 80),
        _buildMetaRow(
          'Keterangan',
          header.keterangan.isNotEmpty ? header.keterangan : '',
          labelWidth: 80,
        ),
      ],
    );
  }

  // --- META: MADANI PRODUCTION ---
  static pw.Widget _buildMadaniMeta(
    PenawaranHeader header,
    String upLabel,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 58,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Kepada YTH',
                    style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 1),
                pw.Text(
                  header.customer.isNotEmpty ? header.customer : '-',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (header.customerAlamat.isNotEmpty)
                  pw.Text(header.customerAlamat,
                      style: const pw.TextStyle(fontSize: 7.5)),
                if (header.customerKota.isNotEmpty)
                  pw.Text(header.customerKota,
                      style: const pw.TextStyle(fontSize: 7.5)),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Up. $upLabel',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 42,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildMetaRow('Tanggal', _formatDate(header.tanggal)),
              _buildMetaRow('Perihal', 'Penawaran Harga'),
              _buildMetaRow('No', header.nomor),
              _buildMetaRow(
                'Keterangan',
                header.keterangan.isNotEmpty ? header.keterangan : '',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- GRID TABLE ---
  static pw.Widget _buildGridTable({
    required List<PenawaranDetailItem> details,
    required double grandTotal,
    required int cetakTotal,
  }) {
    const totalColWidth = 76.0;

    return pw.Column(
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
          columnWidths: const {
            0: pw.FixedColumnWidth(22), // No
            1: pw.FlexColumnWidth(3.0), // Nama
            2: pw.FlexColumnWidth(2.0), // Bahan
            3: pw.FlexColumnWidth(1.5), // Ukuran
            4: pw.FixedColumnWidth(34), // Satuan
            5: pw.FixedColumnWidth(36), // Qty
            6: pw.FixedColumnWidth(66), // Harga
            7: pw.FixedColumnWidth(totalColWidth), // Total
          },
          children: [
            // Header Table
            pw.TableRow(
              children: [
                _buildTableCell('No', isHeader: true, align: pw.TextAlign.left),
                _buildTableCell('Nama', isHeader: true),
                _buildTableCell('Bahan', isHeader: true),
                _buildTableCell('Ukuran', isHeader: true),
                _buildTableCell('Satuan', isHeader: true),
                _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.right),
                _buildTableCell('Harga', isHeader: true, align: pw.TextAlign.right),
                _buildTableCell('Total', isHeader: true, align: pw.TextAlign.right),
              ],
            ),
            // Item Rows
            if (details.isEmpty)
              pw.TableRow(
                children: [
                  _buildTableCell(
                    'Tidak ada detail item.',
                    align: pw.TextAlign.center,
                  ),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                ],
              )
            else
              ...details.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final item = entry.value;
                final dimen = item.panjang > 0 || item.lebar > 0
                    ? '${item.panjang.toInt()} x ${item.lebar.toInt()}'
                    : (item.ukuran.isNotEmpty ? item.ukuran : '-');

                return pw.TableRow(
                  children: [
                    _buildTableCell('$index.', align: pw.TextAlign.right),
                    _buildTableCell(item.namaBarang),
                    _buildTableCell(item.bahan.isNotEmpty ? item.bahan : '-'),
                    _buildTableCell(dimen),
                    _buildTableCell(item.satuan.isNotEmpty ? item.satuan : '-'),
                    _buildTableCell(
                      _formatNumber(item.qty),
                      align: pw.TextAlign.right,
                    ),
                    _buildTableCell(
                      _formatNumber(item.harga),
                      align: pw.TextAlign.right,
                    ),
                    _buildTableCell(
                      _formatNumber(item.total),
                      align: pw.TextAlign.right,
                    ),
                  ],
                );
              }),
          ],
        ),
        // Grand Total Row ter-merge dari kolom No sampai Harga (colspan 7 sama persis Manksi Web)
        if (cetakTotal == 1)
          pw.Table(
            border: const pw.TableBorder(
              left: pw.BorderSide(color: PdfColors.black, width: 0.7),
              right: pw.BorderSide(color: PdfColors.black, width: 0.7),
              bottom: pw.BorderSide(color: PdfColors.black, width: 0.7),
              verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.7),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.0),
              1: pw.FixedColumnWidth(totalColWidth),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3.5,
                    ),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'Grand Total',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3.5,
                    ),
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      _formatNumber(grandTotal),
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildMetaRow(
    String label,
    String value, {
    double labelWidth = 62,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: labelWidth > 65
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 8)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
