// ignore_for_file: unnecessary_string_interpolations

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/image_compress_helper.dart';
import '../../core/utils/responsive_helper.dart';
import '../../engines/ongkir_engine.dart';
import '../../models/permintaan_harga_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/customer_picker_modal.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/web_safe_network_image.dart';

class _DecimalTextInputFormatter extends TextInputFormatter {
  const _DecimalTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final isValid = RegExp(r'^\d*\.?\d*$').hasMatch(text);
    if (!isValid) {
      return oldValue;
    }
    final selectionIndex = newValue.selection.baseOffset;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selectionIndex <= text.length ? selectionIndex : text.length,
      ),
    );
  }
}

const _decimalInputFormatter = _DecimalTextInputFormatter();

String _formatNumberDisplay(num? value) {
  if (value == null) return '0';
  final f = NumberFormat('#,###', 'id_ID');
  return f.format(value);
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const _ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String textToProcess = newValue.text;
    int selectionEnd = newValue.selection.end;

    // Jika user menekan backspace tepat pada tanda titik pemisah ribuan
    if (oldValue.text.length == newValue.text.length + 1 &&
        oldValue.selection.end > 0 &&
        oldValue.selection.end <= oldValue.text.length &&
        oldValue.text[oldValue.selection.end - 1] == '.' &&
        selectionEnd > 0) {
      textToProcess =
          textToProcess.substring(0, selectionEnd - 1) +
          textToProcess.substring(selectionEnd);
      selectionEnd = selectionEnd - 1;
    }

    final cleanDigits = textToProcess.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(cleanDigits);
    if (number == null) return oldValue;

    final formatted = _formatNumberDisplay(number);

    // Hitung posisi kursor baru berdasarkan jumlah digit sebelum kursor
    int digitsBeforeCursor = 0;
    for (int i = 0; i < selectionEnd && i < textToProcess.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(textToProcess[i])) {
        digitsBeforeCursor++;
      }
    }

    int newOffset = 0;
    int digitsCount = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        digitsCount++;
      }
      if (digitsCount == digitsBeforeCursor) {
        newOffset = i + 1;
        break;
      }
    }
    if (digitsBeforeCursor == 0) newOffset = 0;
    if (newOffset > formatted.length) newOffset = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

const _thousandsSeparatorInputFormatter = _ThousandsSeparatorInputFormatter();

double _toNumDecimal(String val) {
  final normalized = val
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  if (normalized.isEmpty) return 0.0;
  final firstDot = normalized.indexOf('.');
  final safe = firstDot == -1
      ? normalized
      : normalized.substring(0, firstDot + 1) +
            normalized.substring(firstDot + 1).replaceAll('.', '');
  return double.tryParse(safe) ?? 0.0;
}

int _toNumCurrency(String val) {
  final cleaned = val.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(cleaned) ?? 0;
}

class PermintaanHargaFormScreen extends ConsumerStatefulWidget {
  final PermintaanHargaDetail? initialDetail;

  const PermintaanHargaFormScreen({super.key, this.initialDetail});

  @override
  ConsumerState<PermintaanHargaFormScreen> createState() =>
      _PermintaanHargaFormScreenState();
}

class _PermintaanHargaFormScreenState
    extends ConsumerState<PermintaanHargaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Wizard Step: 1 = Spesifikasi, 2 = Kalkulasi, 3 = Review & Pengajuan
  int _currentStep = 1;

  bool get _isEditMode => widget.initialDetail != null;

  // Divisi: '1'=SPANDUK, '5'=MMT, '4'=GARMEN
  String _selectedDivisi = '1';

  // Customer & Sales
  final _customerNamaController = TextEditingController();
  String _selectedCustomerKode = '';
  List<Map<String, dynamic>> _customerSoHistory = [];
  bool _isSoHistoryExpanded = false;
  String _soSearchKeyword = '';

  // Data Umum Pekerjaan
  final _barangController = TextEditingController();
  final _qtyController = TextEditingController();
  DateTime _rencanaOrderDate = DateTime.now();
  final _keteranganController = TextEditingController();

  // Pra-Order (Opsional)
  String _praOrderNomor = '';
  Map<String, dynamic>? _selectedPraOrderDetail;
  String? _praOrderKainWarning;
  String? _praOrderRawKain;

  // SPANDUK (Divisi 1)
  String _spandukMetode = 'MANUAL'; // 'MANUAL' | 'MACHINE'
  double _spandukLebar = 90.0; // cm
  String _spandukJenisKain = 'POLYESTER 50/36';
  final _panjangController = TextEditingController(); // mtr
  final _lebarController = TextEditingController(
    text: '90',
  ); // cm untuk spanduk, mtr untuk MMT
  final List<int> _spandukFinishingIds = [];
  Map<String, dynamic>? _spandukResult;
  bool _spandukLoading = false;
  String _spandukCalculatedParams = '';

  // MMT (Divisi 5)
  String _mmtKategori = 'VYNIL'; // 'VYNIL' | 'HI-RES' | 'STICKER'
  String _mmtBahanKode = '260';
  String _mmtToppingKode = '';
  final _mmtToppingQtyController = TextEditingController(text: '1');
  bool _mmtIsNetto = false;
  final _mmtAlasanNettoController = TextEditingController();
  bool _mmtSelongsongVert = false;
  bool _mmtSelongsongHoriz = false;
  Map<String, dynamic>? _mmtResult;
  bool _mmtLoading = false;
  String _mmtCalculatedParams = '';

  // GARMEN (Divisi 4)
  String _garmenKodeModel = 'KH-0001'; // 'KH-0001' | 'KH-0002'
  String _garmenJenisKain = '';

  String _garmenWarna = 'muda'; // 'muda' | 'sedang' | 'tua'
  String _garmenWorkshop = 'MEDIUM'; // 'MEDIUM' | 'PREMIUM'
  String _garmenKategoriKain = 'COTTON';

  String _deriveGarmenKategoriKain(String jenisKain, [String? explicitKtg]) {
    final explicit = (explicitKtg ?? '').trim().toUpperCase();
    if (explicit.isNotEmpty && explicit != 'NULL') {
      if (explicit.contains('LACOST') || explicit.contains('PIQUE')) {
        return 'LACOST';
      }
      if (explicit.contains('PE') ||
          explicit.contains('HYGIT') ||
          explicit.contains('DRYFIT')) {
        return 'PE';
      }
      if (explicit.contains('COTTON') ||
          explicit.contains('COMBED') ||
          explicit.contains('CARDED') ||
          explicit.contains('TC')) {
        return 'COTTON';
      }
    }
    final jk = jenisKain.trim().toUpperCase();
    if (jk.contains('LACOST') || jk.contains('PIQUE')) {
      return 'LACOST';
    }
    if (jk.contains('PE') || jk.contains('HYGIT') || jk.contains('DRYFIT')) {
      return 'PE';
    }
    return 'COTTON';
  }

  final _ukuranController = TextEditingController();
  final _gramasiController = TextEditingController();
  final _finishingController = TextEditingController();
  String _mhSublim = '';

  List<Map<String, dynamic>> _garmenKainList = [];
  bool _garmenLoadingKain = false;
  List<Map<String, dynamic>> _garmenTambahanMaster = [];
  List<Map<String, dynamic>> _garmenCetakMaster = [];
  final List<Map<String, dynamic>> _garmenSelectedTambahan = [];
  final List<Map<String, dynamic>> _garmenSelectedCetak = [];
  Map<String, dynamic>? _garmenCalcResult;
  bool _garmenLoadingCalc = false;
  String _garmenCalculatedParams = '';

  // Accordion Tabel Strata Referensi
  bool _showSpandukStrataTabel = false;
  bool _showMmtStrataTabel = false;
  bool _showGarmenStrataTabel = false;

  // Kalkulator DTF / Bordir Garmen
  final _dtfBordirPanjangController = TextEditingController();
  final _dtfBordirLebarController = TextEditingController();
  final _dtfTarifCmController = TextEditingController();
  final _bordirTarifCmController = TextEditingController();

  // State Modal Cetak Garmen (disimpan di State utama agar tidak ter-reset saat resize / keyboard muncul di Web Browser)
  String _garmenCetakActiveCategory =
      'SABLON'; // 'SABLON' | 'SUBLIM' | 'DTF' | 'BORDIR'
  String _garmenCetakSablonSubCategory = 'ALL'; // 'ALL' | 'MEDIUM' | 'RUBBER'
  String _garmenCetakSearchQuery = '';

  // Helper gramasi dan sablon desc
  static String getGramasiByKain(String kainName) {
    final k = kainName.toUpperCase();
    final rangeMatch = RegExp(r'(\d{2,3}\s*-\s*\d{2,3})').firstMatch(k);
    if (rangeMatch != null) {
      return '${rangeMatch.group(1)!.replaceAll(RegExp(r'\s+'), '')} GR';
    }
    if (k.contains('30S') || k.contains('30 S')) return '140-150 GR';
    if (k.contains('24S') || k.contains('24 S')) return '175-185 GR';
    if (k.contains('20S') || k.contains('20 S')) return '190-200 GR';
    if (k.contains('LACOST') || k.contains('LACOSTE')) return '220-230 GR';
    if (k.contains('TC COM 28') || k.contains('TC 28')) return '150-160 GR';
    if (k.contains('DRYFIT') || k.contains('DRIFIT')) return '150-160 GR';
    if (k.contains('HYGIT') || k.contains('HYGET')) return '110-120 GR';
    if (k.contains('PE 20') || k.contains('PE 24')) return '170-180 GR';
    if (k.contains('PE 30')) return '130-140 GR';
    return '';
  }

  static String getSablonUkuranDesc(String ketStr) {
    final upper = ketStr.toUpperCase();
    if (RegExp(r'\bA3\b').hasMatch(upper)) return '29.7 × 42 cm';
    if (RegExp(r'\bA4\b').hasMatch(upper)) return '21 × 29.7 cm';
    if (RegExp(r'\bA5\b').hasMatch(upper)) return '14.8 × 21 cm';
    return '';
  }

  // --- SPANDUK MASTER OPTIONS GETTERS & HANDLERS (Identik React Native) ---
  List<String> get _availableSpandukMetode {
    final spandukList = _masterOptions?['spanduk'] as List<dynamic>?;
    if (spandukList != null && spandukList.isNotEmpty) {
      final list = spandukList
          .map((s) => s['metode']?.toString().trim().toUpperCase() ?? '')
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList();
      if (list.isNotEmpty) return list;
    }
    return ['MANUAL', 'MACHINE'];
  }

  List<String> get _availableSpandukKain {
    final spandukList = _masterOptions?['spanduk'] as List<dynamic>?;
    if (spandukList != null && spandukList.isNotEmpty) {
      final filtered = spandukList
          .where(
            (s) =>
                (s['metode']?.toString().trim().toUpperCase() ?? '') ==
                _spandukMetode.toUpperCase(),
          )
          .map((s) => s['jenis_kain']?.toString().trim() ?? '')
          .where((k) => k.isNotEmpty)
          .toSet()
          .toList();
      if (filtered.isNotEmpty) return filtered;
    }
    if (_spandukMetode.toUpperCase() == 'MACHINE') {
      return ['POLYESTER 50/36', 'OPTIC 70/40'];
    }
    return ['POLYESTER 50/36', 'OPTIC 70/40', 'TC 60/44'];
  }

  List<double> get _availableSpandukLebar {
    final selectedKain = _spandukJenisKain.trim().toUpperCase();
    final spandukList = _masterOptions?['spanduk'] as List<dynamic>?;
    if (spandukList != null && spandukList.isNotEmpty) {
      final filtered = spandukList
          .where((s) {
            final m = s['metode']?.toString().trim().toUpperCase() ?? '';
            final k = s['jenis_kain']?.toString().trim().toUpperCase() ?? '';
            return m == _spandukMetode.toUpperCase() && k == selectedKain;
          })
          .map((s) {
            final leb = s['lebar'];
            if (leb is num) return leb.toDouble();
            return double.tryParse(leb?.toString() ?? '') ?? 0.0;
          })
          .where((l) => l > 0)
          .toSet()
          .toList();
      filtered.sort();
      if (filtered.isNotEmpty) return filtered;
    }
    return [90.0, 115.0];
  }

  bool get _isManualSpandukNotAllowed {
    if (_selectedDivisi != '1') return false;
    if (_spandukMetode.toUpperCase() != 'MANUAL') return false;
    final numQty = _toNumCurrency(_qtyController.text);
    if (numQty <= 0) return false;
    final numPanjang = _toNumDecimal(_panjangController.text);
    final numLebar = _spandukLebar > 0 ? _spandukLebar : 90.0;
    final totalLuasM2 = numPanjang * (numLebar / 100.0) * numQty;
    final isManualAllowed = numQty >= 100 || totalLuasM2 >= 500;
    return !isManualAllowed;
  }

  void _handleSelectSpandukMetode(String metode) {
    setState(() {
      _spandukMetode = metode;
      final availableKain = _availableSpandukKain;
      if (!availableKain.any(
        (k) => k.toUpperCase() == _spandukJenisKain.toUpperCase(),
      )) {
        if (availableKain.isNotEmpty) {
          _spandukJenisKain = availableKain.first;
        }
      }
      final availableLebar = _availableSpandukLebar;
      if (!availableLebar.contains(_spandukLebar)) {
        if (availableLebar.isNotEmpty) {
          _spandukLebar = availableLebar.first;
          _lebarController.text = _spandukLebar.toInt().toString();
        }
      }
    });
  }

  void _handleSelectSpandukKain(String kain) {
    setState(() {
      _spandukJenisKain = kain;
      final availableLebar = _availableSpandukLebar;
      if (!availableLebar.contains(_spandukLebar)) {
        if (availableLebar.isNotEmpty) {
          _spandukLebar = availableLebar.first;
          _lebarController.text = _spandukLebar.toInt().toString();
        }
      }
    });
  }

  // Master Lookup Options dari Server
  Map<String, dynamic>? _masterOptions;

  // Pengiriman & Ongkos Kirim
  String? _ongkirMode; // null = belum dipilih, 'TANPA_ONGKIR', 'DENGAN_ONGKIR'
  String _alokasiOngkir = '';

  final _namaDaerahKirimController = TextEditingController();
  bool _isCustomOngkir = false;
  final _customOngkirValController = TextEditingController();

  // PPN 11% & Keterangan Kalkulasi
  bool _includePpn = true;
  bool _isBlinkingRecalc = false;
  final _keteranganKalkulasiController = TextEditingController(text: 'INC PPN');

  // Harga Pengajuan & Penyesuaian Sales
  int _hargaKalkulasi = 0;
  final _hargaMintaController = TextEditingController();
  final _alasanPengajuanController = TextEditingController();

  // Foto Lampiran
  Uint8List? _imageBytes;
  String? _imageName;
  int? _imageSizeBytes;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initFromInitialData();
    _qtyController.addListener(_onDimensionOrQtyChanged);
    _panjangController.addListener(_onDimensionOrQtyChanged);
    _lebarController.addListener(_onDimensionOrQtyChanged);
    _customOngkirValController.addListener(_onDimensionOrQtyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMasterOptions();
    });
  }

  void _onDimensionOrQtyChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initFromInitialData() {
    final d = widget.initialDetail;
    if (d == null) return;

    _selectedDivisi = d.divisi.isNotEmpty ? d.divisi : '1';
    _customerNamaController.text = d.cusNama;
    _selectedCustomerKode = d.cusKode;
    _barangController.text = d.nama;
    if (d.jmlOrder > 0) _qtyController.text = d.jmlOrder.toInt().toString();

    if (d.tanggal.isNotEmpty) {
      try {
        _rencanaOrderDate = DateTime.parse(d.tanggal);
      } catch (_) {}
    }

    if (d.panjang > 0) _panjangController.text = d.panjang.toString();
    if (d.lebar > 0) {
      if (_selectedDivisi == '1') {
        _spandukLebar = d.lebar > 10 ? d.lebar : d.lebar * 100;
        _lebarController.text = _spandukLebar.toInt().toString();
      } else {
        _lebarController.text = d.lebar.toString();
      }
    }

    if (d.kain.isNotEmpty) {
      if (_selectedDivisi == '1') {
        _spandukJenisKain = d.kain;
      } else if (_selectedDivisi == '4') {
        _garmenJenisKain = d.kain;
        _garmenKategoriKain = _deriveGarmenKategoriKain(d.kain);
      }
    }

    _keteranganController.text = d.keterangan;

    // Deteksi ongkir dari initial
    if (d.ongkir > 0) {
      _ongkirMode = 'DENGAN_ONGKIR';
      _alokasiOngkir = 'Custom';
      _isCustomOngkir = true;
      _customOngkirValController.text = d.ongkir.toInt().toString();
    } else if (d.keterangan.toLowerCase().contains('kirim ke')) {
      _ongkirMode = 'DENGAN_ONGKIR';
      _isCustomOngkir = false;
    } else if (d.keterangan.toLowerCase().contains('tanpa ongkir')) {
      _ongkirMode = 'TANPA_ONGKIR';
      _alokasiOngkir = 'Tanpa Ongkir';
    } else {
      _ongkirMode = 'TANPA_ONGKIR';
      _alokasiOngkir = 'Tanpa Ongkir';
    }

    // Deteksi PPN & Keterangan Kalkulasi
    final rawKet = d.ketKalkulasi;
    if (rawKet.isNotEmpty) {
      _keteranganKalkulasiController.text = rawKet;
      _includePpn = rawKet.toUpperCase().contains('INC PPN');
    }

    // Ekstrak Alasan Pengajuan jika ada: [ALASAN: ...]
    final matchAlasan = RegExp(
      r'\[ALASAN:\s*([^\]]+)\]',
      caseSensitive: false,
    ).firstMatch(rawKet);
    if (matchAlasan != null && matchAlasan.groupCount >= 1) {
      _alasanPengajuanController.text = matchAlasan.group(1)?.trim() ?? '';
    }

    // Ekstrak Netto jika ada (dukung format [NETTO: ...] dan Netto - Alasan: ...)
    final matchNetto =
        RegExp(
          r'\[NETTO:\s*([^\]]+)\]',
          caseSensitive: false,
        ).firstMatch(rawKet) ??
        RegExp(
          r'Netto\s*-\s*Alasan:\s*([^);]+)',
          caseSensitive: false,
        ).firstMatch(rawKet);
    if (matchNetto != null && matchNetto.groupCount >= 1) {
      _mmtIsNetto = true;
      _mmtAlasanNettoController.text = matchNetto.group(1)?.trim() ?? '';
    } else if (rawKet.toUpperCase().contains('NETTO')) {
      _mmtIsNetto = true;
    }

    // Deteksi Selongsong MMT
    final upperKet = rawKet.toUpperCase();
    if (upperKet.contains('SELONGSONG (V & H)') ||
        (upperKet.contains('SELONGSONG') &&
            upperKet.contains('V') &&
            upperKet.contains('H'))) {
      _mmtSelongsongVert = true;
      _mmtSelongsongHoriz = true;
    } else if (upperKet.contains('SELONGSONG V') ||
        upperKet.contains('SELONGSONG VERTIKAL')) {
      _mmtSelongsongVert = true;
    } else if (upperKet.contains('SELONGSONG H') ||
        upperKet.contains('SELONGSONG HORIZONTAL')) {
      _mmtSelongsongHoriz = true;
    }

    // Deteksi Spesifikasi & Topping MMT jika divisi 5
    if (_selectedDivisi == '5') {
      final matchSpec = RegExp(
        r'MMT\s+([A-Za-z0-9\-]+)\s+([A-Za-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(rawKet);
      if (matchSpec != null) {
        final kat = matchSpec.group(1)?.toUpperCase() ?? '';
        final bKode = matchSpec.group(2)?.toUpperCase() ?? '';
        if (kat == 'VYNIL' || kat == 'HI-RES' || kat == 'STICKER') {
          _mmtKategori = kat;
        }
        if (bKode.isNotEmpty) {
          _mmtBahanKode = bKode;
        }
      } else if (d.kain.isNotEmpty) {
        final upperKain = d.kain.toUpperCase();
        if (upperKain.contains('HI-RES') || upperKain.contains('BACKLITE')) {
          _mmtKategori = 'HI-RES';
        } else if (upperKain.contains('STICKER') ||
            upperKain.contains('GRAFTAC') ||
            upperKain.contains('RITRAMA') ||
            upperKain.contains('ORAJET') ||
            upperKain.contains('TRANSPARAN')) {
          _mmtKategori = 'STICKER';
        } else {
          _mmtKategori = 'VYNIL';
        }
        for (final b in _currentMmtBahanOptions) {
          if (upperKain.contains(b['kode']!.toUpperCase()) ||
              upperKain.contains(b['nama']!.toUpperCase())) {
            _mmtBahanKode = b['kode']!;
            break;
          }
        }
      }

      final matchTop = RegExp(
        r'\+\s*Top:\s*([^+\n\r;]+)',
        caseSensitive: false,
      ).firstMatch(rawKet);
      if (matchTop != null) {
        final topName = matchTop.group(1)?.trim() ?? '';
        final toppingList = _masterOptions?['topping'] as List<dynamic>?;
        if (toppingList != null) {
          for (final t in toppingList) {
            if ((t['nama'] ?? '').toString().toLowerCase() ==
                    topName.toLowerCase() ||
                (t['kode'] ?? '').toString().toLowerCase() ==
                    topName.toLowerCase()) {
              _mmtToppingKode = t['kode'].toString();
              break;
            }
          }
        }
      }
    }

    if (d.ukuran.isNotEmpty) _ukuranController.text = d.ukuran;
    if (d.gramasi.isNotEmpty) _gramasiController.text = d.gramasi;
    if (d.finishing.isNotEmpty) _finishingController.text = d.finishing;
    if (d.sublim.isNotEmpty) _mhSublim = d.sublim;
    if (d.warna.isNotEmpty) _garmenWarna = d.warna.toLowerCase();
    if (_selectedDivisi == '4') {
      final rawUpper = rawKet.toUpperCase();
      final resolvedKh = d.kodeKh;
      if (resolvedKh.isNotEmpty) {
        _garmenKodeModel = resolvedKh;
      } else if (rawUpper.contains('KH-0002') || rawUpper.contains('2 WARNA')) {
        _garmenKodeModel = 'KH-0002';
      } else if (rawUpper.contains('KH-0001') || rawUpper.contains('1 WARNA')) {
        _garmenKodeModel = 'KH-0001';
      }

      final w = d.workshop.trim().toUpperCase();
      if (w == 'P04' || w == 'PREMIUM') {
        _garmenWorkshop = 'PREMIUM';
      } else if (w == 'P01' || w == 'MEDIUM') {
        _garmenWorkshop = 'MEDIUM';
      } else if (rawUpper.contains('PREMIUM') || rawUpper.contains('P04')) {
        _garmenWorkshop = 'PREMIUM';
      } else {
        _garmenWorkshop = 'MEDIUM';
      }

      if (d.warna.trim().isNotEmpty) {
        _garmenWarna = d.warna.trim().toLowerCase();
      } else if (d.kalkulasiDetail?['komponen'] is List) {
        final kompList = d.kalkulasiDetail!['komponen'] as List;
        final firstWarna = kompList.firstWhere(
          (k) => (k['kk_warna']?.toString() ?? '').isNotEmpty,
          orElse: () => null,
        );
        if (firstWarna != null) {
          _garmenWarna = firstWarna['kk_warna'].toString().toLowerCase();
        }
      }

      // Panggil dan isi detail tambahan garmen
      _garmenSelectedTambahan.clear();
      _garmenSelectedTambahan.addAll(d.garmenTambahanList);

      // Panggil dan isi detail cetak garmen (Sablon, DTF, Bordir, Sublim, dll)
      _garmenSelectedCetak.clear();
      _garmenSelectedCetak.addAll(d.garmenCetakList);

      final tambahanKey = _garmenSelectedTambahan
          .map((t) => '${t['ket']}:${t['tarif']}')
          .join(';');
      final cetakKey = _garmenSelectedCetak
          .map((c) => '${c['jenis']}:${c['ket']}:${c['biaya']}')
          .join(';');
      _garmenCalculatedParams =
          '$_garmenKodeModel|$_garmenJenisKain|$_garmenWarna|${_qtyController.text}|$_garmenWorkshop|$tambahanKey|$cetakKey|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
    } else if (_selectedDivisi == '1') {
      final rawUpper = rawKet.toUpperCase();
      if (rawUpper.contains('MACHINE') ||
          rawUpper.contains('PRINT') ||
          rawUpper.contains('CETAK MESIN')) {
        _spandukMetode = 'MACHINE';
      } else if (rawUpper.contains('MANUAL') ||
          rawUpper.contains('SABLON') ||
          rawUpper.contains('SABLON MANUAL')) {
        _spandukMetode = 'MANUAL';
      }
    }
    if (d.proNomor.isNotEmpty) _praOrderNomor = d.proNomor;

    // Deteksi foto existing saat edit
    final rawJson = d.rawJson ?? {};
    final candidates = [
      rawJson['gambar_1_url'],
      rawJson['gambar1_url'],
      rawJson['img1'],
      rawJson['image1'],
      rawJson['mh_gambar1'],
      rawJson['gambar1'],
      d.gambar1Url,
      d.gambarUrl,
    ];
    for (final c in candidates) {
      if (c != null && c.toString().trim().isNotEmpty) {
        String res = c.toString().trim();
        if (!res.startsWith('http://') && !res.startsWith('https://')) {
          res = '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}/$res';
        }
        res = res
            .replaceFirst(
              'http://103.94.238.252:3005/image/mintaharga',
              '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}',
            )
            .replaceFirst(
              'http://103.94.238.252:8182/image/mintaharga',
              '${ApiConfig.imageReadUrl}${ApiConfig.imageBasePath}',
            );
        _existingImageUrl = '$res?t=${DateTime.now().millisecondsSinceEpoch}';
        break;
      }
    }

    _hargaKalkulasi = (d.hargaKalkulasi > 0 ? d.hargaKalkulasi : d.kalRpSistem)
        .toInt();
    if (d.harga > 0) {
      _hargaMintaController.text = _formatNumberDisplay(d.harga.toInt());
    } else if (_hargaKalkulasi > 0) {
      _hargaMintaController.text = _formatNumberDisplay(_hargaKalkulasi);
    }

    if (d.cusKode.isNotEmpty) {
      _fetchCustomerHistory(d.cusKode);
    }
  }

  @override
  void dispose() {
    _qtyController.removeListener(_onDimensionOrQtyChanged);
    _panjangController.removeListener(_onDimensionOrQtyChanged);
    _lebarController.removeListener(_onDimensionOrQtyChanged);
    _customOngkirValController.removeListener(_onDimensionOrQtyChanged);
    _customerNamaController.dispose();
    _barangController.dispose();
    _qtyController.dispose();
    _keteranganController.dispose();
    _panjangController.dispose();
    _lebarController.dispose();
    _ukuranController.dispose();
    _gramasiController.dispose();
    _finishingController.dispose();
    _mmtToppingQtyController.dispose();
    _mmtAlasanNettoController.dispose();
    _dtfBordirPanjangController.dispose();
    _dtfBordirLebarController.dispose();
    _dtfTarifCmController.dispose();
    _bordirTarifCmController.dispose();
    _namaDaerahKirimController.dispose();
    _customOngkirValController.dispose();
    _keteranganKalkulasiController.dispose();
    _hargaMintaController.dispose();
    _alasanPengajuanController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterOptions() async {
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final opts = await repo.getKalkulasiOptions();
      if (mounted && opts != null) {
        setState(() {
          _masterOptions = opts;

          if (_selectedDivisi == '1') {
            final availableKain = _availableSpandukKain;
            if (!availableKain.any(
              (k) => k.toUpperCase() == _spandukJenisKain.toUpperCase(),
            )) {
              if (availableKain.isNotEmpty) {
                _spandukJenisKain = availableKain.first;
              }
            }
            final availableLebar = _availableSpandukLebar;
            if (!availableLebar.contains(_spandukLebar)) {
              if (availableLebar.isNotEmpty) {
                _spandukLebar = availableLebar.first;
                _lebarController.text = _spandukLebar.toInt().toString();
              }
            }

            final initialFinishing = widget.initialDetail?.finishing;
            final tambahanOpts = opts['spandukTambahan'] as List<dynamic>?;
            if (initialFinishing != null &&
                initialFinishing.isNotEmpty &&
                tambahanOpts != null &&
                tambahanOpts.isNotEmpty) {
              final rawFinish = initialFinishing.toLowerCase();
              final matched = tambahanOpts
                  .where(
                    (it) =>
                        rawFinish.contains(it['nama'].toString().toLowerCase()),
                  )
                  .map(
                    (it) => it['id'] is int
                        ? it['id'] as int
                        : int.tryParse(it['id'].toString()) ?? 0,
                  )
                  .where((id) => id > 0)
                  .toList();
              if (matched.isNotEmpty) {
                _spandukFinishingIds.clear();
                _spandukFinishingIds.addAll(matched);
              }
            }
          } else if (_selectedDivisi == '5') {
            final rawKet = widget.initialDetail?.ketKalkulasi ?? '';
            final matchTop = RegExp(
              r'\+\s*Top:\s*([^+\n\r;]+)',
              caseSensitive: false,
            ).firstMatch(rawKet);
            if (matchTop != null) {
              final topName = matchTop.group(1)?.trim() ?? '';
              final toppingList = opts['topping'] as List<dynamic>?;
              if (toppingList != null) {
                for (final t in toppingList) {
                  if ((t['nama'] ?? '').toString().toLowerCase() ==
                          topName.toLowerCase() ||
                      (t['kode'] ?? '').toString().toLowerCase() ==
                          topName.toLowerCase()) {
                    _mmtToppingKode = t['kode'].toString();
                    break;
                  }
                }
              }
            }
          }
        });
      }
      if (_selectedDivisi == '4') {
        _loadGarmenLookups();
      }
    } catch (_) {}
  }

  Future<void> _loadGarmenLookups() async {
    setState(() => _garmenLoadingKain = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final kain = await repo.getJenisKainLookup(_garmenKodeModel);
      final tambahan = await repo.getTambahanLookup({
        'jenisKain': _garmenJenisKain,
        'kodeModel': _garmenKodeModel,
        'kategori': _garmenKategoriKain,
        'qty': _toNumCurrency(_qtyController.text),
      });
      final cetak = await repo.getCetakLookup({
        'jenisKain': _garmenJenisKain,
        'kategori': _garmenKategoriKain,
      });
      if (mounted) {
        setState(() {
          _garmenKainList = kain;
          _garmenTambahanMaster = tambahan;
          _garmenCetakMaster = cetak;
          _garmenLoadingKain = false;

          // Sinkronkan item cetak terpilih jika ada di master baru
          for (int i = 0; i < _garmenSelectedCetak.length; i++) {
            final selected = _garmenSelectedCetak[i];
            final matched = cetak.firstWhere(
              (c) =>
                  (c['mhb_ket'] ?? c['ket'] ?? c['nama'] ?? '') ==
                      selected['ket'] &&
                  (c['mhb_jenis'] ?? c['jenis'] ?? '')
                          .toString()
                          .toUpperCase() ==
                      (selected['jenis'] ?? '').toString().toUpperCase(),
              orElse: () => <String, dynamic>{},
            );
            if (matched.isNotEmpty) {
              final newBiaya =
                  ((matched['biaya'] ?? matched['mhb_biaya'] ?? 0) as num)
                      .toInt();
              _garmenSelectedCetak[i]['biaya'] = newBiaya;
            }
          }

          // Sinkronkan item tambahan terpilih jika ada di master baru
          for (int i = 0; i < _garmenSelectedTambahan.length; i++) {
            final selected = _garmenSelectedTambahan[i];
            final matched = tambahan.firstWhere(
              (t) =>
                  (t['mhb_ket'] ?? t['ket'] ?? t['nama'] ?? '')
                      .toString()
                      .toLowerCase() ==
                  (selected['ket'] ?? '').toString().toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            if (matched.isNotEmpty) {
              final newTarif = ((matched['biaya'] ??
                      matched['mhb_biaya'] ??
                      matched['tarif'] ??
                      0) as num)
                  .toInt();
              if (newTarif > 0) {
                _garmenSelectedTambahan[i]['tarif'] = newTarif;
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _garmenLoadingKain = false);
    }
  }

  Future<void> _loadGarmenCetakOptions() async {
    if (_selectedDivisi != '4') return;
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final cetak = await repo.getCetakLookup({
        'jenisKain': _garmenJenisKain,
        'kategori': _garmenKategoriKain,
      });
      if (!mounted) return;
      setState(() {
        _garmenCetakMaster = cetak;

        // Sinkronkan tarif paten DTF & Bordir dari database kencanaprint.tmintaharga_biaya
        final dtfItem = cetak.firstWhere(
          (c) =>
              (c['mhb_jenis'] ?? c['jenis'] ?? '').toString().toUpperCase() ==
              'DTF',
          orElse: () => <String, dynamic>{},
        );
        if (dtfItem['mhb_cm'] != null) {
          _dtfTarifCmController.text = dtfItem['mhb_cm'].toString();
        } else if (_dtfTarifCmController.text.isEmpty) {
          _dtfTarifCmController.text = '25';
        }

        final bordirItem = cetak.firstWhere(
          (c) =>
              (c['mhb_jenis'] ?? c['jenis'] ?? '').toString().toUpperCase() ==
              'BORDIR',
          orElse: () => <String, dynamic>{},
        );
        if (bordirItem['mhb_cm'] != null) {
          _bordirTarifCmController.text = bordirItem['mhb_cm'].toString();
        } else if (_bordirTarifCmController.text.isEmpty) {
          _bordirTarifCmController.text = '90';
        }

        // Sinkronkan item cetak terpilih jika ada di master baru
        for (int i = 0; i < _garmenSelectedCetak.length; i++) {
          final selected = _garmenSelectedCetak[i];
          final matched = cetak.firstWhere(
            (c) =>
                (c['mhb_ket'] ?? c['ket'] ?? c['nama'] ?? '') ==
                    selected['ket'] &&
                (c['mhb_jenis'] ?? c['jenis'] ?? '').toString().toUpperCase() ==
                    (selected['jenis'] ?? '').toString().toUpperCase(),
            orElse: () => <String, dynamic>{},
          );
          if (matched.isNotEmpty) {
            final newBiaya =
                ((matched['biaya'] ?? matched['mhb_biaya'] ?? 0) as num)
                    .toInt();
            _garmenSelectedCetak[i]['biaya'] = newBiaya;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _loadGarmenTambahanOptions() async {
    if (_selectedDivisi != '4') return;
    try {
      final effectiveKtg = _deriveGarmenKategoriKain(
        _garmenJenisKain,
        _garmenKategoriKain,
      );
      if (_garmenKategoriKain != effectiveKtg) {
        _garmenKategoriKain = effectiveKtg;
      }
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final data = await repo.getTambahanLookup({
        'jenisKain': _garmenJenisKain,
        'kodeModel': _garmenKodeModel,
        'kategori': effectiveKtg,
        'qty': _toNumCurrency(_qtyController.text),
      });
      if (!mounted) return;
      setState(() {
        _garmenTambahanMaster = data;
        for (int i = 0; i < _garmenSelectedTambahan.length; i++) {
          final selected = _garmenSelectedTambahan[i];
          final masterItem = data.firstWhere(
            (m) =>
                (m['mht_ket'] ?? m['mht_keterangan'] ?? m['nama'] ?? '') ==
                selected['ket'],
            orElse: () => <String, dynamic>{},
          );
          if (masterItem.isNotEmpty) {
            final newTarif =
                ((masterItem['tarif'] ?? masterItem['biaya'] ?? 0) as num)
                    .toInt();
            _garmenSelectedTambahan[i]['tarif'] = newTarif;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchCustomerHistory(String cusKode) async {
    if (cusKode.isEmpty) return;
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final list = await repo.getCustomerSoHistory(cusKode);
      if (mounted) {
        setState(() {
          _customerSoHistory = list;
        });
      }
    } catch (_) {}
  }

  // --- LOGIC ONGKIR & SYNC KETERANGAN ---
  List<OngkirMasterItem> get _activeOngkirMasterList {
    final rawList = _masterOptions?['ongkir'] as List<dynamic>?;
    if (rawList != null && rawList.isNotEmpty) {
      return rawList.map((o) {
        final m = o as Map<String, dynamic>;
        final alokasi = (m['alokasi'] ?? m['mho_alokasi'] ?? '').toString();
        final fallback = fallbackOngkirOptions.firstWhere(
          (f) => f.alokasi.toLowerCase() == alokasi.toLowerCase(),
          orElse: () => fallbackOngkirOptions.first,
        );
        return OngkirMasterItem(
          id: m['id'] is int
              ? m['id'] as int
              : int.tryParse(m['id']?.toString() ?? '0') ?? fallback.id,
          alokasi: alokasi.isNotEmpty ? alokasi : fallback.alokasi,
          hargaKg: (m['harga_kg'] as num?)?.toDouble() ?? fallback.hargaKg,
          minKg: (m['min_kg'] as num?)?.toDouble() ?? fallback.minKg,
          freeSpandukM:
              (m['free_spanduk_m'] as num?)?.toDouble() ??
              fallback.freeSpandukM,
          freeMmtM2:
              (m['free_mmt_m2'] as num?)?.toDouble() ?? fallback.freeMmtM2,
          freeGarmenPcs:
              (m['free_garmen_pcs'] as num?)?.toDouble() ??
              fallback.freeGarmenPcs,
          spandukMPerKg:
              (m['spanduk_m_per_kg'] as num?)?.toDouble() ??
              fallback.spandukMPerKg,
          mmtM2PerKg:
              (m['mmt_m2_per_kg'] as num?)?.toDouble() ?? fallback.mmtM2PerKg,
          garmenMedPcsPerKg:
              (m['garmen_med_pcs_per_kg'] as num?)?.toDouble() ??
              fallback.garmenMedPcsPerKg,
          garmenPremPcsPerKg:
              (m['garmen_prem_pcs_per_kg'] as num?)?.toDouble() ??
              fallback.garmenPremPcsPerKg,
          coverageDesc:
              (m['coverage_desc'] ?? m['mho_coverage_desc'])
                      ?.toString()
                      .isNotEmpty ==
                  true
              ? (m['coverage_desc'] ?? m['mho_coverage_desc']).toString()
              : fallback.coverageDesc,
          aliasKeywords:
              (m['alias_keywords'] is List &&
                  (m['alias_keywords'] as List).isNotEmpty)
              ? (m['alias_keywords'] as List).map((e) => e.toString()).toList()
              : fallback.aliasKeywords,
        );
      }).toList();
    }
    return fallbackOngkirOptions;
  }

  OngkirCalcResult get _currentOngkirResult {
    final qty = _toNumCurrency(_qtyController.text);
    final panjang = _toNumDecimal(_panjangController.text);
    final lebar = _toNumDecimal(_lebarController.text);
    final customVal = _toNumCurrency(_customOngkirValController.text);

    return OngkirEngine.hitungOngkirOtomatis(
      options: _activeOngkirMasterList,
      alokasi: _alokasiOngkir,
      divisi: _selectedDivisi,
      panjang: panjang,
      lebar: lebar,
      qty: qty.toDouble(),
      sublim: _mhSublim.isNotEmpty ? _mhSublim : _garmenWorkshop,
      customNominal: customVal,
      isCustom: _isCustomOngkir || _alokasiOngkir.toLowerCase() == 'custom',
    );
  }

  void _syncOngkirKet(String daerah) {
    final trimmed = daerah.trim();
    final regex = RegExp(
      r'(?:[;,.\s]*\b(?:include\s+)?(?:ongkir\s+)?kirim\s+ke\s+[^,;\n]+|[;,.\s]*\b(?:include\s+)?ongkir\s+ke\s+[^,;\n]+|[;,.\s]*\bTanpa Ongkir\b)',
      caseSensitive: false,
    );
    String cleanKet = _keteranganController.text.replaceAll(regex, '').trim();
    cleanKet = cleanKet.replaceAll(RegExp(r'^[;,.\s]+|[;,.\s]+$'), '');

    if (trimmed.toLowerCase() == 'tanpa ongkir') {
      _keteranganController.text =
          cleanKet.isEmpty ? 'Tanpa Ongkir' : '$cleanKet; Tanpa Ongkir';
    } else if (trimmed.isNotEmpty) {
      final inc = 'Include kirim ke $trimmed';
      _keteranganController.text =
          cleanKet.isEmpty ? inc : '$cleanKet; $inc';
    } else {
      _keteranganController.text = cleanKet;
    }
  }

  void _syncSelongsongKet(bool vert, bool horiz) {
    final hasSelongsong = vert || horiz;
    String current = _keteranganController.text.trim();
    if (hasSelongsong) {
      if (!current.toLowerCase().contains('plus selongsong')) {
        _keteranganController.text = current.isEmpty
            ? 'Plus Selongsong'
            : '$current, Plus Selongsong';
      }
    } else {
      current = current.replaceAll(
        RegExp(r',?\s*Plus Selongsong', caseSensitive: false),
        '',
      );
      current = current.replaceAll(RegExp(r'^,\s*'), '').trim();
      _keteranganController.text = current;
    }
  }

  // --- LOGIC TOGGLE PPN REAKTIF ---
  void _handleTogglePpn() {
    setState(() {
      _includePpn = !_includePpn;
      _isBlinkingRecalc = true;
      final clean = _keteranganKalkulasiController.text
          .replaceAll(
            RegExp(r'^(INC|EXC)\s*PPN[;,]?\s*', caseSensitive: false),
            '',
          )
          .trim();
      _keteranganKalkulasiController.text = _includePpn
          ? (_cleanKet(clean).isEmpty ? 'INC PPN;' : 'INC PPN; $clean')
          : (_cleanKet(clean).isEmpty ? 'EXC PPN;' : 'EXC PPN; $clean');

      // Update harga kalkulasi reaktif lokal
      final ongkirPcs = _currentOngkirResult.ongkirPerPcs;
      int rawDpp = 0;
      if (_selectedDivisi == '1' && _spandukResult != null) {
        final base =
            (_spandukResult!['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0;
        rawDpp = (base + ongkirPcs).round();
      } else if (_selectedDivisi == '5' && _mmtResult != null) {
        final base = (_mmtResult!['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0;
        rawDpp = (base + ongkirPcs).round();
      } else if (_selectedDivisi == '4' && _garmenCalcResult != null) {
        final base =
            (_garmenCalcResult!['hargaUpPerPcs'] ??
                    _garmenCalcResult!['hargaJualRevisi'] ??
                    _garmenCalcResult!['hargaJualPerPcs'] ??
                    _garmenCalcResult!['hargaJual'] ??
                    0)
                .toDouble();
        rawDpp = (base + ongkirPcs).round();
      } else if (_hargaKalkulasi > 0) {
        rawDpp = _includePpn
            ? _hargaKalkulasi
            : (_hargaKalkulasi / 1.11).round();
      }

      if (rawDpp > 0) {
        _hargaKalkulasi = _includePpn ? (rawDpp * 1.11).round() : rawDpp;
        if (_hargaMintaController.text.isEmpty ||
            _toNumCurrency(_hargaMintaController.text) == 0) {
          _hargaMintaController.text = _formatNumberDisplay(_hargaKalkulasi);
        }
      }
    });

    // Otomatis hitung ulang ke sistem API jika sudah ada kalkulasi sebelumnya
    if (_selectedDivisi == '1' && _spandukResult != null) {
      _executeHitungSpanduk();
    } else if (_selectedDivisi == '5' && _mmtResult != null) {
      _executeHitungMmt();
    } else if (_selectedDivisi == '4' && _garmenCalcResult != null) {
      _executeHitungGarmen();
    }

    // Reset blink state setelah 800ms
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isBlinkingRecalc = false);
      }
    });
  }

  String _cleanKet(String s) =>
      s.trim().replaceAll(RegExp(r'^[;,.\s]+|[;,.\s]+$'), '');

  // --- DETEKSI STALE CALCULATION ---
  bool get _isSpandukStale {
    if (_spandukResult == null || _spandukCalculatedParams.isEmpty) {
      return false;
    }
    final currentKey =
        '${_panjangController.text}|${_qtyController.text}|$_spandukMetode|$_spandukLebar|$_spandukJenisKain|${_spandukFinishingIds.join(',')}|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
    return _spandukCalculatedParams != currentKey;
  }

  bool get _isMmtStale {
    if (_mmtResult == null || _mmtCalculatedParams.isEmpty) {
      return false;
    }
    final currentKey =
        '${_panjangController.text}|${_lebarController.text}|${_qtyController.text}|$_mmtKategori|$_mmtBahanKode|$_mmtToppingKode|${_mmtToppingQtyController.text}|$_mmtIsNetto|$_mmtSelongsongVert|$_mmtSelongsongHoriz|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
    return _mmtCalculatedParams != currentKey;
  }

  bool get _isGarmenStale {
    if (_garmenCalcResult == null || _garmenCalculatedParams.isEmpty) {
      return false;
    }
    final tambahanKey = _garmenSelectedTambahan
        .map((t) => '${t['ket']}:${t['tarif']}')
        .join(';');
    final cetakKey = _garmenSelectedCetak
        .map((c) => '${c['jenis']}:${c['ket']}:${c['biaya']}')
        .join(';');
    final currentKey =
        '$_garmenKodeModel|$_garmenJenisKain|$_garmenWarna|${_qtyController.text}|$_garmenWorkshop|$tambahanKey|$cetakKey|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
    return _garmenCalculatedParams != currentKey;
  }

  // --- API EXECUTION KALKULASI ---
  Future<void> _executeHitungSpanduk() async {
    final numPanjang = _toNumDecimal(_panjangController.text);
    final numLebar = _spandukLebar;
    final numQty = _toNumCurrency(_qtyController.text);

    if (numPanjang <= 0 || numLebar <= 0 || numQty <= 0) {
      AppToast.error(
        context,
        'Panjang, Lebar, dan Jumlah Order wajib diisi dengan benar',
      );
      return;
    }

    final totalLuasM2 = numPanjang * (numLebar / 100.0) * numQty;
    final isManualAllowed = numQty >= 100 || totalLuasM2 >= 500;
    if (_spandukMetode == 'MANUAL' && !isManualAllowed) {
      AppToast.error(
        context,
        'Cetak Spanduk Manual minimal 100 pcs atau total luas 500 m² (saat ini: $numQty pcs / ${totalLuasM2.toStringAsFixed(1)} m²). Silakan gunakan metode Cetak Machine.',
      );
      return;
    }

    setState(() => _spandukLoading = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final res = await repo.calculateSpanduk({
        'metode': _spandukMetode,
        'lebar': numLebar,
        'jenisKain': _spandukJenisKain,
        'panjang': numPanjang,
        'qty': numQty,
        'finishingIds': _spandukFinishingIds,
      });

      if (res != null && mounted) {
        final base = (res['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0;
        final hrgDenganOngkir = base + _currentOngkirResult.ongkirPerPcs;
        final finalHrg = _includePpn
            ? (hrgDenganOngkir * 1.11).round()
            : hrgDenganOngkir.round();

        setState(() {
          _spandukResult = res;
          _spandukCalculatedParams =
              '${_panjangController.text}|${_qtyController.text}|$_spandukMetode|$_spandukLebar|$_spandukJenisKain|${_spandukFinishingIds.join(',')}|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
          _hargaKalkulasi = finalHrg;
          if (_hargaMintaController.text.isEmpty ||
              _toNumCurrency(_hargaMintaController.text) == 0) {
            _hargaMintaController.text = _formatNumberDisplay(finalHrg);
          }

          String finishingSpec = '';
          final items = res['finishing']?['items'] as List<dynamic>?;
          if (items != null && items.isNotEmpty) {
            finishingSpec =
                ' + ${items.map((it) => it['nama'].toString()).join(' + ')}';
          }
          final spec =
              'Spanduk $_spandukJenisKain ${_panjangController.text}m x ${_spandukLebar.toInt()}cm $finishingSpec';
          _keteranganKalkulasiController.text = _includePpn
              ? 'INC PPN; $spec'
              : 'EXC PPN; $spec';
        });
        AppToast.success(context, 'Kalkulasi Spanduk berhasil');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal menghitung kalkulasi spanduk: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _spandukLoading = false);
      }
    }
  }

  Future<void> _executeHitungMmt() async {
    final numPanjang = _toNumDecimal(_panjangController.text);
    final numLebar = _toNumDecimal(_lebarController.text);
    final numQty = _toNumCurrency(_qtyController.text);

    if (numPanjang <= 0 || numLebar <= 0 || numQty <= 0) {
      AppToast.error(
        context,
        'Panjang, Lebar, dan Jumlah Order wajib diisi dengan benar',
      );
      return;
    }

    setState(() => _mmtLoading = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final res = await repo.calculateMmt({
        'kategori': _mmtKategori,
        'bahanKode': _mmtBahanKode,
        'panjang': numPanjang,
        'lebar': numLebar,
        'qty': numQty,
        'toppingKode': _mmtToppingKode,
        'toppingQty': _toNumCurrency(_mmtToppingQtyController.text),
        'isNetto': _mmtIsNetto,
        'selongsongVertical': _mmtSelongsongVert,
        'selongsongHorizontal': _mmtSelongsongHoriz,
      });

      if (res != null && mounted) {
        final base = (res['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0;
        final hrgDenganOngkir = base + _currentOngkirResult.ongkirPerPcs;
        final finalHrg = _includePpn
            ? (hrgDenganOngkir * 1.11).round()
            : hrgDenganOngkir.round();

        setState(() {
          _mmtResult = res;
          _mmtCalculatedParams =
              '${_panjangController.text}|${_lebarController.text}|${_qtyController.text}|$_mmtKategori|$_mmtBahanKode|$_mmtToppingKode|${_mmtToppingQtyController.text}|$_mmtIsNetto|$_mmtSelongsongVert|$_mmtSelongsongHoriz|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
          _hargaKalkulasi = finalHrg;
          if (_hargaMintaController.text.isEmpty ||
              _toNumCurrency(_hargaMintaController.text) == 0) {
            _hargaMintaController.text = _formatNumberDisplay(finalHrg);
          }

          final nettoSpec = _mmtIsNetto
              ? (_mmtAlasanNettoController.text.trim().isNotEmpty
                    ? ' (Netto - Alasan: ${_mmtAlasanNettoController.text.trim()})'
                    : ' (Netto)')
              : '';
          String selText = '';
          if (_mmtSelongsongVert && _mmtSelongsongHoriz) {
            selText = ' + Plus Selongsong (V & H)';
          } else if (_mmtSelongsongVert) {
            selText = ' + Plus Selongsong Vertikal';
          } else if (_mmtSelongsongHoriz) {
            selText = ' + Plus Selongsong Horizontal';
          }
          final topName = res['topping']?['nama'] ?? _mmtToppingKode;
          final topText = (topName != null && topName.toString().isNotEmpty)
              ? ' + Top: $topName'
              : '';
          final spec =
              'MMT $_mmtKategori $_mmtBahanKode$nettoSpec$topText$selText';

          _keteranganKalkulasiController.text = _includePpn
              ? 'INC PPN; $spec'
              : 'EXC PPN; $spec';
        });
        AppToast.success(context, 'Kalkulasi MMT berhasil');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal menghitung kalkulasi MMT: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _mmtLoading = false);
      }
    }
  }

  Future<void> _executeHitungGarmen() async {
    final numQty = _toNumCurrency(_qtyController.text);
    if (numQty <= 0) {
      AppToast.error(context, 'Jumlah Order wajib diisi');
      return;
    }
    if (_garmenJenisKain.trim().isEmpty) {
      AppToast.error(
        context,
        'Silakan pilih jenis kain garmen terlebih dahulu',
      );
      return;
    }

    setState(() => _garmenLoadingCalc = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final res = await repo.calculateGarmen({
        'kodeModel': _garmenKodeModel,
        'jenisKain': _garmenJenisKain,
        'kategori': _garmenKategoriKain,
        'warna': _garmenWarna,
        'qty': numQty,
        'tambahanList': _garmenSelectedTambahan,
        'cetakList': _garmenSelectedCetak,
        'workshop': _garmenWorkshop,
      });

      if (res != null && mounted) {
        final base =
            (res['hargaUpPerPcs'] ??
                    res['hargaJualRevisi'] ??
                    res['hargaJualPerPcs'] ??
                    res['hargaJual'] ??
                    0)
                .toDouble();
        final hrgDenganOngkir = base + _currentOngkirResult.ongkirPerPcs;
        final finalHrg = _includePpn
            ? (hrgDenganOngkir * 1.11).round()
            : hrgDenganOngkir.round();

        setState(() {
          _garmenCalcResult = res;
          final tambahanKey = _garmenSelectedTambahan
              .map((t) => '${t['ket']}:${t['tarif']}')
              .join(';');
          final cetakKey = _garmenSelectedCetak
              .map((c) => '${c['jenis']}:${c['ket']}:${c['biaya']}')
              .join(';');
          _garmenCalculatedParams =
              '$_garmenKodeModel|$_garmenJenisKain|$_garmenWarna|${_qtyController.text}|$_garmenWorkshop|$tambahanKey|$cetakKey|$_includePpn|${_currentOngkirResult.ongkirPerPcs}';
          _hargaKalkulasi = finalHrg;
          if (_hargaMintaController.text.isEmpty ||
              _toNumCurrency(_hargaMintaController.text) == 0) {
            _hargaMintaController.text = _formatNumberDisplay(finalHrg);
          }

          final spec =
              'Garmen ($_garmenWorkshop) $_garmenJenisKain warna $_garmenWarna ';
          _keteranganKalkulasiController.text = _includePpn
              ? 'INC PPN; $spec'
              : 'EXC PPN; $spec';
        });
        AppToast.success(context, 'Kalkulasi Garmen berhasil');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Gagal menghitung kalkulasi Garmen: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _garmenLoadingCalc = false);
      }
    }
  }

  // --- PRA-ORDER INTEGRATION ---
  void _showPraOrderPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PraOrderPickerSheet(
        onSelect: (item) async {
          final no =
              item['nomor']?.toString() ?? item['pro_nomor']?.toString() ?? '';
          await _applySelectedPraOrder(no, item);
        },
      ),
    );
  }

  Future<void> _applySelectedPraOrder(
    String nomor,
    Map<String, dynamic> fallback,
  ) async {
    final repo = ref.read(permintaanHargaRepositoryProvider);
    Map<String, dynamic>? detail;
    try {
      detail = await repo.getPraOrderDetail(nomor);
    } catch (_) {}
    final data = detail ?? fallback;

    final targetDivisi = data['divisi']?.toString() ?? _selectedDivisi;

    // Pastikan master kain garmen sudah dimuat jika divisi tujuan adalah Garmen
    if (targetDivisi == '4' && _garmenKainList.isEmpty) {
      try {
        final kainLookup = await repo.getJenisKainLookup(_garmenKodeModel);
        if (kainLookup.isNotEmpty) {
          _garmenKainList = kainLookup;
        }
      } catch (_) {}
    }

    final rawKain = (data['kain']?.toString() ?? '').trim();
    String? kainWarning;
    String? rawKainNotMatched;
    String matchedKainName = '';
    String matchedKtg = '';

    if (rawKain.isNotEmpty) {
      if (targetDivisi == '4') {
        final matched = _garmenKainList.firstWhere((item) {
          final name =
              (item['mhk_kain'] ?? item['Jeniskain'] ?? item['nama'] ?? '')
                  .toString()
                  .trim()
                  .toUpperCase();
          return name == rawKain.toUpperCase();
        }, orElse: () => <String, dynamic>{});
        if (matched.isNotEmpty) {
          matchedKainName =
              (matched['mhk_kain'] ?? matched['Jeniskain'] ?? rawKain)
                  .toString();
          matchedKtg =
              (matched['mhk_ktg'] ?? matched['Kategori'] ?? matched['ktg'])
                  ?.toString() ??
              '';
        } else {
          rawKainNotMatched = rawKain;
          kainWarning =
              'Jenis kain "$rawKain" dari Pra-Order belum terdaftar di master garmen. Silakan pilih kain pengganti di master harga.';
        }
      } else if (targetDivisi == '1') {
        final available = _availableSpandukKain;
        final matched = available.firstWhere(
          (k) => k.trim().toUpperCase() == rawKain.toUpperCase(),
          orElse: () => '',
        );
        if (matched.isNotEmpty) {
          matchedKainName = matched;
        } else {
          rawKainNotMatched = rawKain;
          kainWarning =
              'Jenis kain "$rawKain" dari Pra-Order belum terdaftar di master Spanduk.';
        }
      } else if (targetDivisi == '5') {
        final bList = _currentMmtBahanOptions;
        final matched = bList.firstWhere((b) {
          final kode = (b['kode'] ?? '').toString().trim().toUpperCase();
          final nama = (b['nama'] ?? '').toString().trim().toUpperCase();
          final r = rawKain.toUpperCase();
          return r.contains(kode) || r.contains(nama) || kode == r || nama == r;
        }, orElse: () => <String, String>{});
        if (matched.isNotEmpty) {
          matchedKainName = matched['kode'] ?? rawKain;
        } else {
          rawKainNotMatched = rawKain;
          kainWarning =
              'Jenis bahan "$rawKain" dari Pra-Order belum terdaftar di master MMT.';
        }
      }
    }

    setState(() {
      _praOrderNomor = nomor;
      _selectedPraOrderDetail = data;
      _praOrderKainWarning = kainWarning;
      _praOrderRawKain = rawKainNotMatched;

      final cusNama =
          data['cusNama']?.toString() ??
          data['cus_nama']?.toString() ??
          data['customer']?.toString() ??
          '';
      final cusKode =
          data['cusKode']?.toString() ??
          data['cus_kode']?.toString() ??
          data['customer_kode']?.toString() ??
          '';
      if (cusNama.isNotEmpty) _customerNamaController.text = cusNama;
      if (cusKode.isNotEmpty) _selectedCustomerKode = cusKode;

      if (targetDivisi.isNotEmpty) {
        _selectedDivisi = targetDivisi;
        if (targetDivisi == '4') _loadGarmenLookups();
      }

      final namaPekerjaan =
          data['namaPekerjaan']?.toString() ??
          data['nama_pekerjaan']?.toString() ??
          data['nama']?.toString() ??
          '';
      if (namaPekerjaan.isNotEmpty) _barangController.text = namaPekerjaan;

      final qty =
          (data['rencanaOrder'] as num?)?.toDouble() ??
          (data['qtyRencana'] as num?)?.toDouble() ??
          (data['rencana_order'] as num?)?.toDouble() ??
          (data['jml_order'] as num?)?.toDouble() ??
          0;
      if (qty > 0) _qtyController.text = qty.toInt().toString();

      if (matchedKainName.isNotEmpty) {
        if (_selectedDivisi == '1') {
          _spandukJenisKain = matchedKainName;
        } else if (_selectedDivisi == '4') {
          _garmenJenisKain = matchedKainName;
          _garmenKategoriKain = _deriveGarmenKategoriKain(
            matchedKainName,
            matchedKtg,
          );
        } else if (_selectedDivisi == '5') {
          _mmtBahanKode = matchedKainName;
        }
      } else if (rawKainNotMatched != null) {
        if (_selectedDivisi == '4') {
          _garmenJenisKain = ''; // Kosongkan agar user wajib memilih di master
        }
      }

      final finishing = data['finishing']?.toString() ?? '';
      if (finishing.isNotEmpty) _finishingController.text = finishing;

      final ukuran = data['ukuran']?.toString() ?? '';
      if (ukuran.isNotEmpty) _ukuranController.text = ukuran;

      final List<String> ketParts = [];
      if (rawKainNotMatched != null) {
        final divisiLabel = _selectedDivisi == '4'
            ? 'Garmen'
            : (_selectedDivisi == '5' ? 'MMT' : 'Spanduk');
        ketParts.add(
          '[Kain Pra-Order: $rawKainNotMatched (Belum ada di master $divisiLabel, mohon sesuaikan)]',
        );
      }
      final spesifikasi = data['spesifikasi']?.toString() ?? '';
      final keterangan = data['keterangan']?.toString() ?? '';
      final deadline =
          data['catatanDeadline']?.toString() ??
          data['catatan_deadline']?.toString() ??
          '';

      if (spesifikasi.isNotEmpty) ketParts.add('Spesifikasi: $spesifikasi');
      if (keterangan.isNotEmpty) ketParts.add('Ket: $keterangan');
      if (deadline.isNotEmpty) ketParts.add('Deadline: $deadline');

      if (ketParts.isNotEmpty) {
        final combined = ketParts.join(' | ');
        _keteranganController.text = _keteranganController.text.isEmpty
            ? combined
            : '${_keteranganController.text}\n$combined';
      }
    });

    if (_selectedCustomerKode.isNotEmpty) {
      _fetchCustomerHistory(_selectedCustomerKode);
    }
    if (mounted) {
      if (rawKainNotMatched != null) {
        final divisiLabel = targetDivisi == '4'
            ? 'Garmen'
            : (targetDivisi == '5' ? 'MMT' : 'Spanduk');
        _showPraOrderKainWarningDialog(
          nomor: nomor,
          kainPraOrder: rawKainNotMatched,
          divisiNama: divisiLabel,
        );
      } else {
        AppToast.success(context, 'Data Pra-Order $nomor berhasil diterapkan');
      }
    }
  }

  void _showPraOrderKainWarningDialog({
    required String nomor,
    required String kainPraOrder,
    required String divisiNama,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Kain Belum di Master',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Data Pra-Order '),
                  TextSpan(
                    text: nomor,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' berhasil ditarik, namun jenis kain '),
                  TextSpan(
                    text: '"$kainPraOrder"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  TextSpan(
                    text: ' belum terdaftar pada master kalkulasi $divisiNama.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Field Jenis Kain dikosongkan agar Anda dapat memilih kain pengganti yang sesuai.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Spesifikasi kain asli sudah otomatis dicatat pada kolom Keterangan.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Mengerti',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          if (_selectedDivisi == '4')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showGarmenKainPickerModal();
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Pilih Kain Garmen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _clearPraOrder() {
    setState(() {
      _praOrderNomor = '';
      _selectedPraOrderDetail = null;
      _praOrderKainWarning = null;
      _praOrderRawKain = null;
    });
    AppToast.info(context, 'Kaitan Pra Order dilepas');
  }

  // --- IMAGE PICKER ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final res = await ImageCompressHelper.pickAndCompress(
        _picker,
        source: source,
      );
      if (res != null) {
        setState(() {
          _imageBytes = res.bytes;
          _imageName = res.name;
          _imageSizeBytes = res.bytes.length;
        });
        if (mounted) AppToast.success(context, 'Foto berhasil dipilih');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Gagal memilih foto');
    }
  }

  // --- VALIDASI SPESIFIKASI STEP 1 ---
  String? _validateSpesifikasiInput() {
    if (_customerNamaController.text.trim().isEmpty) {
      return 'Customer wajib dipilih terlebih dahulu';
    }
    if (_barangController.text.trim().isEmpty) {
      return 'Nama pekerjaan / barang wajib diisi';
    }
    if (_selectedDivisi.trim().isEmpty) {
      return 'Divisi pekerjaan wajib dipilih';
    }

    final qty = _toNumCurrency(_qtyController.text);
    if (qty <= 0) {
      return 'Jumlah order (pcs) harus lebih besar dari 0';
    }

    // 1. Validasi Spesifik Divisi GARMEN (4)
    if (_selectedDivisi == '4') {
      if (_garmenKodeModel.trim().isEmpty) {
        return 'Model garmen wajib dipilih (1 Warna atau 2 Warna)';
      }
      if (_garmenJenisKain.trim().isEmpty) {
        return 'Silakan pilih jenis kain garmen terlebih dahulu';
      }
      if (_garmenWarna.trim().isEmpty) {
        return 'Kategori warna garmen wajib dipilih (Muda, Sedang, atau Tua)';
      }
      if (_garmenWorkshop.trim().isEmpty) {
        return 'Workshop garmen wajib dipilih (Medium atau Premium)';
      }
    }
    // 2. Validasi Spesifik Divisi SPANDUK (1)
    else if (_selectedDivisi == '1') {
      if (_spandukMetode.trim().isEmpty) {
        return 'Metode cetak spanduk wajib dipilih (Manual atau Machine)';
      }
      if (_spandukJenisKain.trim().isEmpty) {
        return 'Jenis kain spanduk wajib dipilih';
      }
      final lebarSpanduk = _spandukLebar > 0
          ? _spandukLebar
          : _toNumDecimal(_lebarController.text);
      if (lebarSpanduk <= 0) {
        return 'Pilihan lebar spanduk wajib dipilih';
      }
      if (_toNumDecimal(_panjangController.text) <= 0) {
        return 'Panjang spanduk (Mtr) wajib diisi lebih besar dari 0';
      }
      if (_isManualSpandukNotAllowed) {
        final numPanjang = _toNumDecimal(_panjangController.text);
        final numLebar = _spandukLebar > 0 ? _spandukLebar : 90.0;
        final totalLuasM2 = numPanjang * (numLebar / 100.0) * qty;
        return 'Cetak Spanduk Manual minimal 100 pcs atau total luas 500 m² (saat ini: $qty pcs / ${totalLuasM2.toStringAsFixed(1)} m²). Silakan gunakan metode Cetak Machine.';
      }
    }
    // 3. Validasi Spesifik Divisi MMT (5)
    else if (_selectedDivisi == '5') {
      if (_mmtKategori.trim().isEmpty) {
        return 'Kategori MMT wajib dipilih';
      }
      if (_mmtBahanKode.trim().isEmpty) {
        return 'Pilihan bahan MMT wajib dipilih';
      }
      if (_toNumDecimal(_panjangController.text) <= 0) {
        return 'Panjang MMT (Mtr) wajib diisi lebih besar dari 0';
      }
      if (_toNumDecimal(_lebarController.text) <= 0) {
        return 'Lebar MMT (Mtr) wajib diisi lebih besar dari 0';
      }
      if (_mmtIsNetto && _mmtAlasanNettoController.text.trim().isEmpty) {
        return 'Mohon isi alasan penggunaan Harga Netto MMT terlebih dahulu';
      }
    }

    // 4. Validasi Pengiriman & Ongkir (Wajib Diisi)
    if (_ongkirMode == null) {
      return 'Pengiriman & Ongkir wajib dipilih (Tanpa Ongkir atau Dengan Ongkir)';
    }
    if (_ongkirMode == 'DENGAN_ONGKIR') {
      final customVal = _toNumCurrency(_customOngkirValController.text);
      if (_namaDaerahKirimController.text.trim().isEmpty &&
          (!_isCustomOngkir || customVal <= 0)) {
        return 'Kota/daerah tujuan pengiriman wajib diisi jika memilih Dengan Ongkir';
      }
    }

    return null;
  }

  // --- STEP TRANSITION ---
  void _goToStep2() {
    _formKey.currentState?.validate();
    final errorMessage = _validateSpesifikasiInput();
    if (errorMessage != null) {
      AppToast.error(context, errorMessage);
      return;
    }

    setState(() {
      _currentStep = 2;
    });

    // Auto trigger kalkulasi pertama kali jika belum pernah dihitung
    if (_selectedDivisi == '1' && _spandukResult == null) {
      _executeHitungSpanduk();
    } else if (_selectedDivisi == '5' && _mmtResult == null) {
      _executeHitungMmt();
    } else if (_selectedDivisi == '4' && _garmenCalcResult == null) {
      _executeHitungGarmen();
    }
  }

  void _goToStep3() {
    if (_selectedDivisi == '5' &&
        _mmtIsNetto &&
        _mmtAlasanNettoController.text.trim().isEmpty) {
      AppToast.error(
        context,
        'Mohon isi alasan penggunaan Harga Netto terlebih dahulu',
      );
      return;
    }
    setState(() {
      _currentStep = 3;
    });
  }

  // --- SUBMIT FINAL ---
  Future<void> _showConfirmSubmitDialog({required bool isBypass}) async {
    final qty = _toNumCurrency(_qtyController.text);
    final int finalHargaPengajuan = _toNumCurrency(_hargaMintaController.text);

    final int unitCalc = isBypass ? 0 : _hargaKalkulasi;
    final bool isUnderCalc =
        unitCalc > 0 && (finalHargaPengajuan == 0 || finalHargaPengajuan < unitCalc);
    if (!isBypass &&
        isUnderCalc &&
        _alasanPengajuanController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      AppToast.warning(
        context,
        'Harga pengajuan di bawah rekomendasi sistem (Status: NEGO). Mohon isi alasan permintaan harga.',
      );
      return;
    }

    final int diff = unitCalc - finalHargaPengajuan;
    final int totalDiff = diff * qty;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                _isEditMode
                    ? 'Konfirmasi Perubahan'
                    : 'Konfirmasi Permintaan Harga',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Box Ringkasan Data
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildConfirmRow(
                      'Customer',
                      _customerNamaController.text.isNotEmpty
                          ? _customerNamaController.text
                          : '-',
                    ),
                    const SizedBox(height: 6),
                    _buildConfirmRow(
                      'Pekerjaan',
                      _barangController.text.isNotEmpty
                          ? _barangController.text
                          : '-',
                    ),
                    const SizedBox(height: 6),
                    _buildConfirmRow(
                      'Jumlah Order',
                      '${_formatNumberDisplay(qty)} Pcs',
                    ),
                    const SizedBox(height: 6),
                    _buildConfirmRow(
                      'Harga Permintaan',
                      'Rp ${_formatNumberDisplay(finalHargaPengajuan)} /pcs',
                      valueColor: const Color(0xFF059669),
                      isBold: true,
                    ),
                    if (_currentOngkirResult.totalOngkir > 0) ...[
                      const SizedBox(height: 6),
                      _buildConfirmRow(
                        'Ongkir',
                        'Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} / Pcs',
                      ),
                    ],
                    const SizedBox(height: 6),
                    _buildConfirmRow(
                      'Total Order (${_formatNumberDisplay(qty)} Pcs)',
                      'Rp ${_formatNumberDisplay(_currentOngkirResult.totalOngkir + (finalHargaPengajuan * qty))}',
                      fontSize: 16,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Keterangan Status DONE / WAIT / MINTA / NEGO
              if (unitCalc <= 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'STATUS: BELUM',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Permintaan harga dibuat tanpa kalkulasi, akan melalui MO terlebih dahulu.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (isUnderCalc)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STATUS: NEGO (Memerlukan Persetujuan)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              finalHargaPengajuan == 0
                                  ? 'Harga permintaan diisi Rp 0, permintaan harga diajukan sebagai NEGO dan memerlukan persetujuan.'
                                  : 'Harga permintaan harga lebih rendah Rp ${_formatNumberDisplay(diff)}/pcs ( - Rp ${_formatNumberDisplay(totalDiff)} ) dari kalkulasi harga.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (_selectedDivisi == '1' || _selectedDivisi == '5')
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'STATUS: DONE (Otomatis Disetujui)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Harga permintaan memenuhi atau di atas standar kalkulasi sistem.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        size: 18,
                        color: Color(0xFFE65100),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'STATUS: BELUM DIVERIFIKASI',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE65100),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Harga permintaan memenuhi atau di atas standar kalkulasi sistem, menunggu verifikasi finance.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFBF360C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Konfirmasi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _executeSubmit(isDirectBypass: isBypass);
    }
  }

  Widget _buildConfirmRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    double? fontSize,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Future<void> _executeSubmit({required bool isDirectBypass}) async {
    setState(() => _isSubmitting = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(permintaanHargaRepositoryProvider);
    final ymdFormat = DateFormat('yyyy-MM-dd');

    final qty = _toNumCurrency(_qtyController.text);
    final int finalHargaPengajuan = _toNumCurrency(_hargaMintaController.text);
    final int finalHargaKalkulasi = isDirectBypass ? 0 : _hargaKalkulasi;

    // Susun String ket_kalkulasi sesuai spesifikasi React Native
    String finalKetKalkulasi = _keteranganKalkulasiController.text.trim();
    if (_selectedDivisi == '5' &&
        _mmtIsNetto &&
        _mmtAlasanNettoController.text.trim().isNotEmpty) {
      final alasanNetto = _mmtAlasanNettoController.text.trim();
      if (!finalKetKalkulasi.contains(alasanNetto)) {
        if (finalKetKalkulasi.contains('(Netto)')) {
          finalKetKalkulasi = finalKetKalkulasi.replaceAll(
            '(Netto)',
            '(Netto - Alasan: $alasanNetto)',
          );
        } else {
          finalKetKalkulasi = '$finalKetKalkulasi [Alasan Netto: $alasanNetto]';
        }
      }
    }

    String cleanKet = finalKetKalkulasi
        .replaceAll(
          RegExp(r'^(INC|EXC)\s*PPN[;,]?\s*', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'^\[ALASAN:[^\]]+\]\s*;?\s*', caseSensitive: false),
          '',
        )
        .trim();

    final List<String> ketParts = [];
    ketParts.add(_includePpn ? 'INC PPN' : 'EXC PPN');
    if (_alasanPengajuanController.text.trim().isNotEmpty) {
      ketParts.add('[ALASAN: ${_alasanPengajuanController.text.trim()}]');
    }
    if (cleanKet.isNotEmpty) {
      ketParts.add(cleanKet);
    }
    finalKetKalkulasi = ketParts.join('; ');

    // Nama Kain Submit
    String finalSubmitKain = _selectedDivisi == '1'
        ? _spandukJenisKain
        : (_selectedDivisi == '5'
              ? (_currentMmtBahanOptions.firstWhere(
                      (b) => b['kode'] == _mmtBahanKode,
                      orElse: () => {'nama': '$_mmtKategori $_mmtBahanKode'},
                    )['nama'] ??
                    '$_mmtKategori $_mmtBahanKode')
              : _garmenJenisKain);

    final payload = <String, dynamic>{
      'mh_divisi': _selectedDivisi,
      'mh_cus_kode': _selectedCustomerKode,
      'mh_cus_nama': _customerNamaController.text.trim(),
      'mh_sal_kode': user?.salesKode ?? user?.kode ?? '',
      'mh_nama': _barangController.text.trim(),
      'mh_jmlorder': qty,
      'mh_harga': finalHargaPengajuan,
      'mh_ongkir': _currentOngkirResult.totalOngkir,
      'kald_rpkirim': _currentOngkirResult.ongkirPerPcs,
      'mh_harga_kalkulasi': finalHargaKalkulasi,
      'mh_ket_kalkulasi': isDirectBypass ? '' : finalKetKalkulasi,
      'mh_budget': 0,
      'mh_dateorder': ymdFormat.format(_rencanaOrderDate),
      'mh_kain': finalSubmitKain,
      'mh_panjang': _toNumDecimal(_panjangController.text),
      'mh_lebar': _selectedDivisi == '1'
          ? _spandukLebar
          : _toNumDecimal(_lebarController.text),
      'mh_ukuran': _ukuranController.text.trim(),
      'mh_gramasi': _gramasiController.text.trim(),
      'mh_finishing': _finishingController.text.trim(),
      'mh_sublim': _mhSublim,
      'mh_warna': _selectedDivisi == '4' ? _garmenWarna.toUpperCase() : '',
      'mh_ket': _keteranganController.text.trim(),
      if (_praOrderNomor.isNotEmpty) 'mh_pro_nomor': _praOrderNomor,
      if (_selectedDivisi == '4') ...{
        'kal_kh_kode': _garmenKodeModel,
        'kal_rpallowance':
            _garmenCalcResult?['komponenBiaya']?['allowanceRp'] ?? 0,
        'kal_allowance':
            _garmenCalcResult?['komponenBiaya']?['allowancePersen'] ?? 0,
        'kal_rplaba': _garmenCalcResult?['strataAktif']?['marginRp'] ?? 0,
        'kal_laba': _garmenCalcResult?['strataAktif']?['persen'] ?? 0,
        'kal_ketbeli': _garmenCalcResult?['babaran']?['body'] != null
            ? '$_garmenJenisKain ${_garmenCalcResult!['babaran']['body']}/kg'
            : _garmenJenisKain,
        'garmen_model': _garmenKodeModel,
        'garmen_kain': _garmenJenisKain,
        'garmen_warna': _garmenWarna,
        'garmen_tambahan': _garmenSelectedTambahan,
        'garmen_cetak': _garmenSelectedCetak,
        'mh_workshop': _garmenWorkshop == 'PREMIUM' ? 'P04' : 'P01',
        'garmen_workshop': _garmenWorkshop == 'PREMIUM' ? 'P04' : 'P01',
      },
    };

    bool isSuccess = false;
    String targetNomor = widget.initialDetail?.nomor ?? '';

    if (_isEditMode) {
      isSuccess = await repo.updatePermintaanHarga(targetNomor, payload);
    } else {
      final res = await repo.createPermintaanHarga(payload);
      if (res != null) {
        isSuccess = true;
        targetNomor =
            res['nomor']?.toString() ?? res['mh_nomor']?.toString() ?? '';
      }
    }

    bool isImageUploadSuccess = true;
    if (isSuccess && _imageBytes != null && targetNomor.isNotEmpty) {
      try {
        final uploadedUrl = await repo.uploadImage(
          targetNomor,
          null,
          slot: 1,
          fileBytes: _imageBytes,
          fileName: _imageName,
        );
        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          isImageUploadSuccess = false;
        }
      } catch (_) {
        isImageUploadSuccess = false;
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (isSuccess) {
        final isDone =
            !isDirectBypass &&
            finalHargaKalkulasi > 0 &&
            finalHargaPengajuan > 0 &&
            finalHargaPengajuan >= finalHargaKalkulasi;
        final isNego =
            !isDirectBypass &&
            finalHargaKalkulasi > 0 &&
            (finalHargaPengajuan == 0 ||
                finalHargaPengajuan < finalHargaKalkulasi);

        final isAutoDoneDivisi =
            _selectedDivisi == '1' || _selectedDivisi == '5';
        final successMessage = _isEditMode
            ? 'Permintaan harga berhasil diperbarui'
            : (isDirectBypass || finalHargaKalkulasi <= 0
                  ? 'Permintaan harga berhasil diajukan (Status: BELUM)'
                  : (isDone
                        ? (isAutoDoneDivisi
                            ? 'Permintaan harga berhasil diajukan (Status: DONE - Disetujui Otomatis)'
                            : 'Permintaan harga berhasil diajukan (Status: BELUM DIVERIFIKASI)')
                        : (isNego
                              ? 'Permintaan harga berhasil diajukan (Status: NEGO - Menunggu Persetujuan)'
                              : 'Permintaan harga berhasil disimpan')));

        AppToast.success(context, successMessage);
        if (!isImageUploadSuccess) {
          AppToast.warning(
            context,
            'Data tersimpan, namun upload lampiran foto gagal. Anda dapat mengunggah ulang via menu Edit.',
          );
        }
        context.pop(true);
      } else {
        AppToast.error(
          context,
          'Gagal menyimpan permintaan harga. Silakan periksa koneksi Anda.',
        );
      }
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              _isEditMode ? 'Edit Permintaan Harga' : 'Buat Permintaan Harga',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              _isEditMode
                  ? 'No. MH: ${widget.initialDetail?.nomor}'
                  : 'Nomor dibuat otomatis oleh sistem',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Stepper Progress Bar
            _buildStepperBar(),

            // Wizard Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ResponsiveHelper.formWidth(context)),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentStep == 1)
                            _buildStep1Spesifikasi()
                          else if (_currentStep == 2)
                            _buildStep2Kalkulasi()
                          else
                            _buildStep3Review(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Sticky Footer Action Navigation Bar (Hanya untuk Langkah 1 & 2)
            if (_currentStep != 3) _buildStickyFooter(),
          ],
        ),
      ),
    );
  }

  // --- STEPPER BAR WIDGET ---
  Widget _buildStepperBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ResponsiveHelper.formWidth(context)),
          child: Row(
            children: [
              _buildStepItem(
                1,
                'Spesifikasi',
                _currentStep == 1,
                _currentStep > 1,
                () => setState(() => _currentStep = 1),
              ),
              _buildStepLine(_currentStep >= 2),
              _buildStepItem(
                2,
                'Kalkulasi Harga',
                _currentStep == 2,
                _currentStep > 2,
                _goToStep2,
              ),
              _buildStepLine(_currentStep >= 3),
              _buildStepItem(3, 'Review', _currentStep == 3, false, () {
                if (_currentStep >= 2) _goToStep3();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(
    int step,
    String label,
    bool isActive,
    bool isPassed,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed
                    ? const Color(0xFF10B981)
                    : (isActive
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFF1F5F9)),
                border: Border.all(
                  color: isActive || isPassed
                      ? Colors.transparent
                      : const Color(0xFFCBD5E1),
                ),
              ),
              alignment: Alignment.center,
              child: isPassed
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                color: isActive
                    ? const Color(0xFF4F46E5)
                    : (isPassed
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isPassed) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: isPassed ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
      ),
    );
  }

  // --- STICKY FOOTER NAVIGATION BAR (LANGKAH 1 & 2) ---
  Widget _buildStickyFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ResponsiveHelper.formWidth(context)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _currentStep == 1
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                          text: 'Kalkulasi Harga ➔',
                          width: double.infinity,
                          height: 44,
                          onPressed: _goToStep2,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            _formKey.currentState?.validate();
                            final errorMessage = _validateSpesifikasiInput();
                            if (errorMessage != null) {
                              AppToast.error(context, errorMessage);
                              return;
                            }
                            _showConfirmSubmitDialog(isBypass: true);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Buat Permintaan Harga (Tanpa Kalkulasi)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmallScreen = constraints.maxWidth < 360;
                        return Row(
                          children: [
                            Expanded(
                              flex: isSmallScreen ? 5 : 4,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                onPressed: () =>
                                    setState(() => _currentStep = 1),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 16,
                                  color: Color(0xFF475569),
                                ),
                                label: Text(
                                  isSmallScreen ? 'Spek' : 'Ubah Spek',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: isSmallScreen ? 7 : 6,
                              child: AppButton(
                                text: isSmallScreen
                                    ? 'Ke Review ➔'
                                    : 'Lanjut ke Review ➔',
                                onPressed: _goToStep3,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // --- STEP 1: DETAIL & SPESIFIKASI WIDGET ---
  Widget _buildStep1Spesifikasi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Card Pra Order (Opsional)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.playlist_add_check_rounded,
                        size: 20,
                        color: Color(0xFF4F46E5),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Pra Order',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Opsional',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_praOrderNomor.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _praOrderNomor,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                    if (_selectedPraOrderDetail?['divisiNama'] !=
                                            null ||
                                        _selectedPraOrderDetail?['divisi'] !=
                                            null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          (_selectedPraOrderDetail?['divisiNama'] ??
                                                  (_selectedPraOrderDetail?['divisi'] ==
                                                          '4'
                                                      ? 'GARMEN'
                                                      : (_selectedPraOrderDetail?['divisi'] ==
                                                                '5'
                                                            ? 'MMT'
                                                            : 'SPANDUK')))
                                              .toString(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if ((_selectedPraOrderDetail?['namaPekerjaan'] ??
                                        _selectedPraOrderDetail?['nama_pekerjaan'] ??
                                        _barangController.text)
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    (_selectedPraOrderDetail?['namaPekerjaan'] ??
                                            _selectedPraOrderDetail?['nama_pekerjaan'] ??
                                            _barangController.text)
                                        .toString(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (_customerNamaController
                                    .text
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _customerNamaController.text,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF334155),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  _qtyController.text.isNotEmpty
                                      ? 'Rencana Order: ${_formatNumberDisplay(_toNumCurrency(_qtyController.text))} pcs'
                                      : 'Rencana Order: -',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: _showPraOrderPickerModal,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.sync_rounded,
                                        size: 15,
                                        color: Color(0xFF4F46E5),
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Ganti',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _clearPraOrder,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_praOrderKainWarning != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Kain Pra-Order: ${_praOrderRawKain ?? "-"} (Belum ada di master)',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                              if (_selectedDivisi == '4') ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _showGarmenKainPickerModal,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                    child: const Text(
                                      'Pilih Kain',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: _showPraOrderPickerModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pilih Dari Dokumen Pra-Order...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Card 1: Informasi Pekerjaan
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditMode &&
                  (widget.initialDetail?.nomor.isNotEmpty ?? false)) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Text(
                    'No. MH: ${widget.initialDetail!.nomor}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],

              const Text(
                '1. Informasi Pekerjaan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),

              // Customer Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: const TextSpan(
                      text: 'Nama Customer ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      children: [
                        TextSpan(
                          text: '*',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final refresh = await context.push<bool>(
                        '/permintaan-harga/tambah-customer',
                      );
                      if (refresh == true && _selectedCustomerKode.isNotEmpty) {
                        _fetchCustomerHistory(_selectedCustomerKode);
                      }
                    },
                    child: const Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 14,
                          color: Color(0xFF4F46E5),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '+ Customer Baru',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showCustomerPickerModal(context);
                  if (picked != null) {
                    setState(() {
                      _customerNamaController.text = picked.nama;
                      _selectedCustomerKode = picked.kode;
                    });
                    _fetchCustomerHistory(picked.kode);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _customerNamaController.text.isNotEmpty
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _customerNamaController.text.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _customerNamaController.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedCustomerKode.isNotEmpty)
                                    Text(
                                      'Kode: $_selectedCustomerKode',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              )
                            : const Text(
                                'Pilih customer...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                      ),
                      if (_customerNamaController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _customerNamaController.clear();
                              _selectedCustomerKode = '';
                              _customerSoHistory = [];
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF4F46E5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Nama Pekerjaan
              RichText(
                text: const TextSpan(
                  text: 'Nama Pekerjaan ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _barangController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Banner HUT RI 2x1m',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama pekerjaan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),

              // Tanggal
              RichText(
                text: const TextSpan(
                  text: 'Tanggal ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd-MM-yyyy').format(_rencanaOrderDate),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Divisi Selector
              RichText(
                text: const TextSpan(
                  text: 'Divisi ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildDivisiChip('1', '1 - SPANDUK'),
                  const SizedBox(width: 8),
                  _buildDivisiChip('5', '5 - MMT'),
                  const SizedBox(width: 8),
                  _buildDivisiChip('4', '4 - GARMEN'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Card 2: Spesifikasi Produk & Dimensi
        if (_selectedDivisi == '4')
          _buildCardSpesifikasiGarmen()
        else if (_selectedDivisi == '1')
          _buildCardSpesifikasiSpanduk()
        else
          _buildCardSpesifikasiMmt(),
      ],
    );
  }

  // --- CARD 2: GARMEN ---
  Widget _buildCardSpesifikasiGarmen() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Spesifikasi Garmen',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Model (1 Warna / 2 Warna)
          RichText(
            text: const TextSpan(
              text: 'Model ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSelectablePill(
                  '1 Warna',
                  _garmenKodeModel == 'KH-0001',
                  () => setState(() => _garmenKodeModel = 'KH-0001'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSelectablePill(
                  '2 Warna',
                  _garmenKodeModel == 'KH-0002',
                  () => setState(() => _garmenKodeModel = 'KH-0002'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Jenis Kain Garmen
          RichText(
            text: const TextSpan(
              text: 'Jenis Kain ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _showGarmenKainPickerModal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      (_praOrderKainWarning != null && _garmenJenisKain.isEmpty)
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFCBD5E1),
                  width:
                      (_praOrderKainWarning != null && _garmenJenisKain.isEmpty)
                      ? 1.5
                      : 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _garmenJenisKain.isNotEmpty
                        ? _garmenJenisKain
                        : 'Pilih jenis kain garmen...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _garmenJenisKain.isNotEmpty
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _garmenJenisKain.isNotEmpty
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_praOrderKainWarning != null && _garmenJenisKain.isEmpty) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 13,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Kain pra-order "$_praOrderRawKain" belum ada di master. Wajib pilih jenis kain.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Kategori Warna
          RichText(
            text: const TextSpan(
              text: 'Kategori Warna ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSelectablePill(
                  'Muda',
                  _garmenWarna == 'muda',
                  () => setState(() => _garmenWarna = 'muda'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSelectablePill(
                  'Sedang',
                  _garmenWarna == 'sedang',
                  () => setState(() => _garmenWarna = 'sedang'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSelectablePill(
                  'Tua',
                  _garmenWarna == 'tua',
                  () => setState(() => _garmenWarna = 'tua'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Workshop Garmen
          RichText(
            text: const TextSpan(
              text: 'Workshop Garmen ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSelectablePill(
                  'Medium (P01)',
                  _garmenWorkshop == 'MEDIUM',
                  () => setState(() => _garmenWorkshop = 'MEDIUM'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSelectablePill(
                  'Premium (P04)',
                  _garmenWorkshop == 'PREMIUM',
                  () => setState(() => _garmenWorkshop = 'PREMIUM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Jumlah Order
          RichText(
            text: const TextSpan(
              text: 'Jumlah Order (Pcs) ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.format_list_numbered_rounded, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Rincian Ukuran / Size (Opsional)
          Row(
            children: const [
              Text(
                'Rincian Ukuran / Size',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '(Opsional)',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _ukuranController,
            decoration: const InputDecoration(
              hintText: 'Misal: XL= 3, L = 2, M = 5',
              prefixIcon: Icon(Icons.straighten_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Gramasi Kain (Otomatis / Opsional)
          Row(
            children: const [
              Text(
                'Gramasi',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '(Otomatis / Opsional)',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _gramasiController,
            decoration: const InputDecoration(
              hintText: 'Misal: 140-150 GR',
              prefixIcon: Icon(Icons.line_weight_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Finishing Garmen (Opsional)
          Row(
            children: const [
              Text(
                'Finishing',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '(Opsional)',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _finishingController,
            decoration: const InputDecoration(
              hintText: 'Misal: Lipat rapi, packing plastik',
              prefixIcon: Icon(Icons.checkroom_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Sublim Garmen (Opsional)
          Row(
            children: const [
              Text(
                'Sublim',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '(Opsional) Tidak Mempengaruhi Kalkulasi Harga',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(
              () => _mhSublim = _mhSublim == 'PREMIUM' ? '' : 'PREMIUM',
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _mhSublim == 'PREMIUM'
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: _mhSublim == 'PREMIUM'
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _mhSublim == 'PREMIUM'
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _mhSublim == 'PREMIUM'
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tambahan Biaya Aksesoris
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambahan Aksesoris',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: _showGarmenTambahanPickerModal,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Tambah Aksesoris',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (_garmenSelectedTambahan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: _garmenSelectedTambahan.map((t) {
                return Chip(
                  backgroundColor: const Color(0xFFF1F5F9),
                  label: Text(
                    '${t['ket']} (+Rp ${_formatNumberDisplay(t['tarif'])})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() {
                      _garmenSelectedTambahan.remove(t);
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),

          // Biaya Cetak Garmen
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambahan Cetak',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: _showGarmenCetakPickerModal,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Tambah Cetak',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (_garmenSelectedCetak.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: _garmenSelectedCetak.map((c) {
                final ukDesc = getSablonUkuranDesc(c['ket'] ?? '');
                return Chip(
                  backgroundColor: const Color(0xFFEFF6FF),
                  label: Text(
                    '${c['jenis']}: ${c['ket']} (Rp ${_formatNumberDisplay(c['biaya'])}${ukDesc.isNotEmpty ? ' • $ukDesc' : ''})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() {
                      _garmenSelectedCetak.remove(c);
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),

          // Pengiriman & Keterangan
          _buildPengirimanDanKeteranganSection(),
        ],
      ),
    );
  }

  // --- CARD 2: SPANDUK ---
  Widget _buildCardSpesifikasiSpanduk() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Dimensi & Kuantitas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Metode Cetak
          RichText(
            text: const TextSpan(
              text: 'Metode Cetak ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: _availableSpandukMetode.map((met) {
              final isSel = _spandukMetode.toUpperCase() == met.toUpperCase();
              final label = met.toUpperCase() == 'MANUAL'
                  ? 'Manual'
                  : 'Machine';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSelectablePill(
                    label,
                    isSel,
                    () => _handleSelectSpandukMetode(met),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Pilihan Jenis Kain Spanduk Dinamis berdasarkan Metode Cetak (Divisi 1)
          RichText(
            text: const TextSpan(
              text: 'Jenis Kain Spanduk ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSpandukKain.map((kain) {
              final isSel =
                  _spandukJenisKain.toUpperCase() == kain.toUpperCase();
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _handleSelectSpandukKain(kain),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFCBD5E1),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    kain,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Pilihan Lebar Dinamis yang Difilter Berdasarkan Metode & Jenis Kain (Divisi 1)
          RichText(
            text: TextSpan(
              text: 'Pilihan Lebar Jenis (${_spandukJenisKain.toUpperCase()}) ',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSpandukLebar.map((leb) {
              final isSel = _spandukLebar == leb;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _spandukLebar = leb;
                    _lebarController.text = leb.toInt().toString();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFCBD5E1),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '${leb.toInt()} cm',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Dimensi Panjang (Mtr)
          RichText(
            text: const TextSpan(
              text: 'Panjang (Mtr) ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _panjangController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalInputFormatter],
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.straighten_rounded, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          RichText(
            text: const TextSpan(
              text: 'Jumlah Order (Pcs) ',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              children: [
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '0',
              prefixIcon: const Icon(
                Icons.format_list_numbered_rounded,
                size: 20,
              ),
              enabledBorder: _isManualSpandukNotAllowed
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.5,
                      ),
                    )
                  : null,
              focusedBorder: _isManualSpandukNotAllowed
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFDC2626),
                        width: 2,
                      ),
                    )
                  : null,
              fillColor: _isManualSpandukNotAllowed
                  ? const Color(0xFFFEF2F2)
                  : null,
              filled: _isManualSpandukNotAllowed,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_isManualSpandukNotAllowed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Ketentuan Cetak Manual Belum Terpenuhi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _showManualSpandukModal,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _handleSelectSpandukMetode('MACHINE'),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                    label: const Text(
                      'Beralih ke Cetak Machine',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                      shadowColor: const Color(0x59D97706),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Info Keterangan Luas Spesifikasi (seperti pada React Native)
          Builder(
            builder: (context) {
              final numPanjang = _toNumDecimal(_panjangController.text);
              final numLebar =
                  (_toNumDecimal(_lebarController.text) > 0
                      ? _toNumDecimal(_lebarController.text)
                      : _spandukLebar) /
                  100.0;
              final numQty = _toNumCurrency(_qtyController.text);
              final luasPerPcs = numPanjang * numLebar;
              final totalLuas = luasPerPcs * (numQty > 0 ? numQty : 1);

              if (luasPerPcs <= 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                  bottom: 4,
                  left: 2,
                  right: 2,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.straighten_rounded,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    RichText(
                      text: TextSpan(
                        text: 'Luas: ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        children: [
                          TextSpan(
                            text: '${luasPerPcs.toStringAsFixed(2)} m²/pcs',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (numQty > 0) ...[
                            const TextSpan(text: '   •   Total: '),
                            TextSpan(
                              text: '${totalLuas.toStringAsFixed(1)} m²',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Finishing (Tanpa Kalkulasi)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Finishing (Tanpa Kalkulasi)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () => _showFinishingInfoDialog('tanpa_kalkulasi'),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _finishingController,
            decoration: const InputDecoration(
              hintText: 'Contoh: Mata ayam 4 pojok, Jahit selongsong',
              prefixIcon: Icon(Icons.checkroom_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Finishing Tambahan Spanduk
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Finishing Tambahan Spanduk (Include Kalkulasi)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () => _showFinishingInfoDialog('include_kalkulasi'),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildSpandukFinishingChecklist(),
          const SizedBox(height: 12),

          // Pengiriman & Keterangan
          _buildPengirimanDanKeteranganSection(),
        ],
      ),
    );
  }

  // --- CARD 2: MMT ---
  Widget _buildCardSpesifikasiMmt() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Dimensi & Kuantitas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Kategori MMT
          const Text(
            'Kategori MMT *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: _availableMmtKategori.map((kat) {
              final isSel = _mmtKategori == kat;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildSelectablePill(
                    kat,
                    isSel,
                    () => _selectMmtKategori(kat),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Bahan MMT (Chip Buttons seperti React Native)
          const Text(
            'Pilihan Bahan MMT *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentMmtBahanOptions.map((b) {
              final isSel = _mmtBahanKode == b['kode'];
              return InkWell(
                onTap: () {
                  setState(() => _mmtBahanKode = b['kode']!);
                  _updateMmtKeteranganKalkulasi();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    b['nama'] ?? b['kode']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Dimensi P x L & Qty
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _panjangController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalInputFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Panjang (Mtr) *',
                    hintText: '0',
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _updateMmtKeteranganKalkulasi();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _lebarController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalInputFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Lebar (Mtr) *',
                    hintText: '0',
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _updateMmtKeteranganKalkulasi();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Jumlah Order (Pcs) *',
              hintText: '0',
              prefixIcon: Icon(Icons.format_list_numbered_rounded, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // Info Luas Spesifikasi
          Builder(
            builder: (context) {
              final p = _toNumDecimal(_panjangController.text);
              final l = _toNumDecimal(_lebarController.text);
              final q = _toNumCurrency(_qtyController.text);
              final luasPerPcs = p * l;
              final totalLuas = luasPerPcs * (q > 0 ? q : 1);
              if (luasPerPcs <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.straighten_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Luas: ${luasPerPcs.toStringAsFixed(2)} m² • Total: ${totalLuas.toStringAsFixed(2)} m²',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Aksesoris Tambahan (Topping) MMT
          const Text(
            'Aksesoris Tambahan (Opsional)',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _mmtToppingKode,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text(
                      'Tanpa Aksesoris Tambahan (Standard)',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ),
                  ..._availableMmtToppingOptions.map((top) {
                    final kode = top['kode']?.toString() ?? '';
                    final nama = top['nama']?.toString() ?? kode;
                    final hrg = (top['harga'] as num?)?.toDouble() ?? 0.0;
                    final hrgStr = hrg > 0
                        ? ' (+Rp ${_formatNumberDisplay(hrg.toInt())})'
                        : '';
                    return DropdownMenuItem(
                      value: kode,
                      child: Text(
                        '$nama$hrgStr',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: (v) {
                  setState(() => _mmtToppingKode = v ?? '');
                  _updateMmtKeteranganKalkulasi();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Selongsong MMT
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _mmtSelongsongVert
                        ? const Color(0xFFF0F9FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _mmtSelongsongVert
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    dense: true,
                    title: Text(
                      'Selongsong Vertikal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _mmtSelongsongVert
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _mmtSelongsongVert
                            ? const Color(0xFF0369A1)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      '0,2 x P (${_panjangController.text.isEmpty ? "0" : _panjangController.text} m)',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    value: _mmtSelongsongVert,
                    activeColor: const Color(0xFF0284C7),
                    onChanged: (v) {
                      setState(() {
                        _mmtSelongsongVert = v ?? false;
                        _syncSelongsongKet(
                          _mmtSelongsongVert,
                          _mmtSelongsongHoriz,
                        );
                      });
                      _updateMmtKeteranganKalkulasi();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _mmtSelongsongHoriz
                        ? const Color(0xFFF0F9FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _mmtSelongsongHoriz
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    dense: true,
                    title: Text(
                      'Selongsong Horizontal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _mmtSelongsongHoriz
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _mmtSelongsongHoriz
                            ? const Color(0xFF0369A1)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      '0,2 x L (${_lebarController.text.isEmpty ? "0" : _lebarController.text} m)',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    value: _mmtSelongsongHoriz,
                    activeColor: const Color(0xFF0284C7),
                    onChanged: (v) {
                      setState(() {
                        _mmtSelongsongHoriz = v ?? false;
                        _syncSelongsongKet(
                          _mmtSelongsongVert,
                          _mmtSelongsongHoriz,
                        );
                      });
                      _updateMmtKeteranganKalkulasi();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Toggle Harga Netto MMT
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Gunakan Harga Netto MMT',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            value: _mmtIsNetto,
            onChanged: (v) {
              setState(() {
                _mmtIsNetto = v;
                if (!_mmtIsNetto) {
                  _mmtAlasanNettoController.clear();
                }
              });
              _updateMmtKeteranganKalkulasi();
            },
          ),
          if (_mmtIsNetto) ...[
            TextFormField(
              controller: _mmtAlasanNettoController,
              decoration: const InputDecoration(
                labelText: 'Alasan Penggunaan Harga Netto *',
                hintText: 'Wajib diisi jika menggunakan netto...',
              ),
              onChanged: (_) => _updateMmtKeteranganKalkulasi(),
            ),
            const SizedBox(height: 12),
          ],

          // Pengiriman & Keterangan
          _buildPengirimanDanKeteranganSection(),
        ],
      ),
    );
  }

  // --- REUSABLE PENGIRIMAN & KETERANGAN SECTION ---
  Widget _buildPengirimanDanKeteranganSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: const TextSpan(
                text: 'Pengiriman & Ongkir ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                children: [
                  TextSpan(
                    text: '*',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: _showKetentuanOngkirModal,
              child: Row(
                children: const [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 14,
                    color: Color(0xFF4F46E5),
                  ),
                  SizedBox(width: 3),
                  Text(
                    'Ketentuan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Toggle Mode: Tanpa Ongkir vs Dengan Ongkir
        Row(
          children: [
            Expanded(
              child: _buildSelectablePill(
                'Tanpa Ongkir',
                _ongkirMode == 'TANPA_ONGKIR',
                () {
                  setState(() {
                    _ongkirMode = 'TANPA_ONGKIR';
                    _alokasiOngkir = 'Tanpa Ongkir';
                    _isCustomOngkir = false;
                    _customOngkirValController.clear();
                    _namaDaerahKirimController.clear();
                  });
                  _syncOngkirKet('Tanpa Ongkir');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSelectablePill(
                'Dengan Ongkir',
                _ongkirMode == 'DENGAN_ONGKIR',
                () {
                  setState(() {
                    _ongkirMode = 'DENGAN_ONGKIR';
                    if (_alokasiOngkir == 'Tanpa Ongkir' || _alokasiOngkir.isEmpty) {
                      _alokasiOngkir = '';
                    }
                  });
                  _syncOngkirKet(_namaDaerahKirimController.text.trim());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_ongkirMode == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Wajib dipilih: Tentukan opsi pengiriman Tanpa Ongkir atau Dengan Ongkir.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_ongkirMode == 'TANPA_ONGKIR')
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tanpa Ongkos Kirim',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Rp 0',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Field Input Kota / Daerah Tujuan (Modern UI/UX)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _namaDaerahKirimController.text.isNotEmpty
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFCBD5E1),
                width: _namaDaerahKirimController.text.isNotEmpty ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 20,
                    color: _namaDaerahKirimController.text.isNotEmpty
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _namaDaerahKirimController,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Ketik kota tujuan (misal: Malang, Jambi...)',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) {
                      _syncOngkirKet(v);
                      if (v.trim().isNotEmpty) {
                        final detected = OngkirEngine.detectAlokasiFromText(
                          v,
                          _activeOngkirMasterList,
                        );
                        if (detected != null) {
                          _alokasiOngkir = detected.alokasi;
                          _isCustomOngkir = false;
                        }
                      }
                      setState(() {});
                    },
                  ),
                ),
                if (_namaDaerahKirimController.text.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      _namaDaerahKirimController.clear();
                      _syncOngkirKet('');
                      setState(() {});
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Status Badge Alokasi Otomatis (Smart Feedback)
          if (_namaDaerahKirimController.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'Alokasi Terdeteksi: ',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF334155),
                        ),
                        children: [
                          TextSpan(
                            text: _alokasiOngkir,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      _currentOngkirResult.isFreeCharge
                          ? 'Bebas Ongkir'
                          : 'Rp ${_formatNumberDisplay(_currentOngkirResult.tarifPerKg.toInt())}/kg',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: _currentOngkirResult.isFreeCharge
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Ringkasan Estimasi Ongkir Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentOngkirResult.isFreeCharge
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimasi Berat Pesanan',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_currentOngkirResult.totalBeratKg} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_currentOngkirResult.beratDihitungKg >
                                _currentOngkirResult.totalBeratKg &&
                            _currentOngkirResult.totalBeratKg > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '(Min: ${_currentOngkirResult.beratDihitungKg.toStringAsFixed(0)} kg)',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentOngkirResult.isFreeCharge
                              ? 'Bebas Ongkir'
                              : 'Biaya Ongkir',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _currentOngkirResult.isFreeCharge
                                ? const Color(0xFF15803D)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _currentOngkirResult.isFreeCharge
                              ? 'Memenuhi syarat bebas ongkir'
                              : '+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} / pcs',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _currentOngkirResult.isFreeCharge
                                ? const Color(0xFF166534)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Rp ${_formatNumberDisplay(_currentOngkirResult.totalOngkir)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _currentOngkirResult.isFreeCharge
                            ? const Color(0xFF15803D)
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        const Text(
          'Keterangan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _keteranganController,
          minLines: 4,
          maxLines: 7,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF0F172A),
          ),
          decoration: const InputDecoration(
            hintText: 'Tambahkan keterangan permintaan harga...',
            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        _buildPhotoUploadSection(),
      ],
    );
  }

  // --- STEP 2: KALKULASI & REVIEW HARGA WIDGET ---
  Widget _buildStep2Kalkulasi() {
    final bool isStale = _selectedDivisi == '1'
        ? _isSpandukStale
        : (_selectedDivisi == '5' ? _isMmtStale : _isGarmenStale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Box Ringkasan Spesifikasi Terinput (specSummaryBox)
        _buildSpecSummaryBox(),
        const SizedBox(height: 12),

        // 2. Banner Peringatan Perubahan Data (Stale)
        if (isStale) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Spesifikasi Diubah Pasca-Hitung',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        'Parameter spesifikasi telah berubah. Mohon lakukan hitung ulang kalkulasi.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3. Tombol Hitung Ulang / Refresh Kalkulasi Sistem (Blink Efek & Reaktif Status PPN)
        _buildHitungUlangButton(),
        const SizedBox(height: 10),

        // 4. Toggle Card PPN 11% (Diletakkan tepat di bawah tombol hitung ulang)
        _buildPpnCard(),
        const SizedBox(height: 14),

        // 5. Hasil Kalkulasi Rincian per Divisi
        if (_selectedDivisi == '1' && _spandukResult != null) ...[
          _buildSpandukKalkulasiResultCard(),
          const SizedBox(height: 10),
          _buildSpandukStrataAccordion(),
        ] else if (_selectedDivisi == '5') ...[
          _buildMmtEngineAdjustmentCard(),
          const SizedBox(height: 12),
          if (_mmtResult != null) ...[
            _buildMmtKalkulasiResultCard(),
            const SizedBox(height: 10),
            _buildMmtStrataAccordion(),
          ],
        ] else if (_selectedDivisi == '4') ...[
          _buildGarmenTambahanDanCetakCard(),
          const SizedBox(height: 12),
          if (_garmenCalcResult != null) ...[
            _buildGarmenKalkulasiResultCard(),
            const SizedBox(height: 10),
            _buildGarmenStrataAccordion(),
          ],
        ] else ...[
          // Default Card Rekomendasi Sistem (Gradient) jika belum dihitung secara detail
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'HARGA KALKULASI SISTEM',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rp ${_formatNumberDisplay(_hargaKalkulasi)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Termasuk Ongkir: Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)}/pcs • ${_includePpn ? "INC PPN (11%)" : "EXC PPN"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- RESULT BOX & ACCORDION STRATA HELPER WIDGETS ---

  // 1. Spanduk Result Box
  Widget _buildSpandukKalkulasiResultCard() {
    final res = _spandukResult!;
    final totalMeter = res['totalMeter'] ?? 0;
    final biayaCetak =
        (res['biayaCetakPerPcs'] ?? res['tarifPerMeter'] ?? 0) as num;
    final items = res['finishing']?['items'] as List<dynamic>? ?? [];
    final qty = _toNumCurrency(_qtyController.text);
    final dppPerPcs =
        ((res['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0) +
        _currentOngkirResult.ongkirPerPcs;
    final finalPerPcs = _includePpn
        ? (dppPerPcs * 1.11).round()
        : dppPerPcs.round();
    final ppnTotal = _includePpn ? ((dppPerPcs * 0.11).round() * qty) : 0;
    final totalOrderKeseluruhan = finalPerPcs * qty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildResultItemRow('Total Panjang Kain:', '$totalMeter Meter'),
          _buildResultItemRow(
            'Tarif Bahan:',
            'Rp ${_formatNumberDisplay(biayaCetak)} /Pcs',
            valueColor: const Color(0xFF0284C7),
          ),
          for (final fi in items)
            _buildResultItemRow(
              'Finishing (${fi['nama']}):',
              '+Rp ${_formatNumberDisplay(fi['biayaPerPcs'] ?? 0)} /Pcs',
              valueColor: const Color(0xFF0284C7),
            ),
          _buildResultItemRow(
            'Ongkir (${_currentOngkirResult.alokasi}):',
            _currentOngkirResult.isFreeCharge
                ? 'Rp. 0'
                : '+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} /Pcs',
            valueColor: _currentOngkirResult.isFreeCharge
                ? const Color(0xFF15803D)
                : const Color(0xFF0284C7),
            isBold: true,
          ),
          const Divider(height: 14, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hasil Kalkulasi Sistem:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Rp ${_formatNumberDisplay(finalPerPcs)} /Pcs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _includePpn
                      ? const Color(0xFF15803D)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          if (_includePpn) ...[
            const SizedBox(height: 4),
            _buildResultItemRow(
              'Biaya PPN 11%:',
              '+Rp ${_formatNumberDisplay(ppnTotal)}',
              valueColor: const Color(0xFF047857),
              isBold: true,
            ),
          ],
          const SizedBox(height: 4),
          _buildResultItemRow(
            'Total Order (${_formatNumberDisplay(qty)} pcs):',
            'Rp ${_formatNumberDisplay(totalOrderKeseluruhan)}',
            valueColor: const Color(0xFF0F172A),
            isBold: true,
          ),
        ],
      ),
    );
  }

  // Accordion Strata Spanduk
  Widget _buildSpandukStrataAccordion() {
    final list = _spandukResult?['tabelReferensi'] as List<dynamic>? ?? [];
    final activeId = _spandukResult?['strataAktif']?['id'];

    return Column(
      children: [
        InkWell(
          onTap: () => setState(
            () => _showSpandukStrataTabel = !_showSpandukStrataTabel,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.table_chart_rounded,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tabel Master Bahan Spanduk',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showSpandukStrataTabel
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_showSpandukStrataTabel && list.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Panjang',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Tarif/Mtr',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final s in list) ...[
                  Builder(
                    builder: (ctx) {
                      final qmin = s['qmin'] ?? 0;
                      final qmax = s['qmax'] ?? 999999;
                      final bool isActive =
                          activeId != null && s['id'] == activeId;
                      final String label = qmax >= 99999
                          ? '≥ $qmin M'
                          : '$qmin - $qmax M';
                      final tarif = s['harga'] ?? s['tarif'] ?? s['up'] ?? 0;

                      return Container(
                        color: isActive
                            ? const Color(0xFFE0F2FE)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Rp ${_formatNumberDisplay(tarif)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Engine Adjustment Card untuk MMT di Step 2 (Selaras dengan React Native)
  Widget _buildMmtEngineAdjustmentCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, size: 18, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text(
                'Penyesuaian Mesin & Spesifikasi MMT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Kategori Mesin / Resolusi
          const Text(
            'Kategori Mesin / Resolusi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: _availableMmtKategori.map((kat) {
              final isSel = _mmtKategori == kat;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildSelectablePill(kat, isSel, () {
                    _selectMmtKategori(kat);
                    _executeHitungMmt();
                  }),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Pilihan Bahan (Chips)
          const Text(
            'Pilihan Bahan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _currentMmtBahanOptions.map((b) {
              final isSel = _mmtBahanKode == b['kode'];
              return InkWell(
                onTap: () {
                  setState(() => _mmtBahanKode = b['kode']!);
                  _updateMmtKeteranganKalkulasi();
                  _executeHitungMmt();
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    b['kode']!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Aksesoris Tambahan (Topping)
          const Text(
            'Aksesoris Tambahan (Opsional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _mmtToppingKode,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text(
                      'Tanpa Aksesoris Tambahan (Standard)',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  ..._availableMmtToppingOptions.map((top) {
                    final kode = top['kode']?.toString() ?? '';
                    final nama = top['nama']?.toString() ?? kode;
                    final hrg = (top['harga'] as num?)?.toDouble() ?? 0.0;
                    final hrgStr = hrg > 0
                        ? ' (+Rp ${_formatNumberDisplay(hrg.toInt())})'
                        : '';
                    return DropdownMenuItem(
                      value: kode,
                      child: Text(
                        '$nama$hrgStr',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: (v) {
                  setState(() => _mmtToppingKode = v ?? '');
                  _updateMmtKeteranganKalkulasi();
                  _executeHitungMmt();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Finishing Selongsong
          const Text(
            'Finishing Termasuk Kalkulasi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          // Selongsong Vertikal
          Container(
            decoration: BoxDecoration(
              color: _mmtSelongsongVert
                  ? const Color(0xFFF0F9FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _mmtSelongsongVert
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
              dense: true,
              title: Text(
                'Selongsong Vertikal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _mmtSelongsongVert
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: _mmtSelongsongVert
                      ? const Color(0xFF0369A1)
                      : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                '0,2 x P (${_panjangController.text.isEmpty ? "0" : _panjangController.text} m) x tarif/m²',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              secondary:
                  (_mmtResult?['selongsong']?['isVertical'] == true &&
                      (_mmtResult?['selongsong']?['biayaVerticalPerPcs'] ?? 0) >
                          0)
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        '+Rp ${_formatNumberDisplay(_mmtResult!['selongsong']['biayaVerticalPerPcs'])}/pcs',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    )
                  : null,
              value: _mmtSelongsongVert,
              activeColor: const Color(0xFF0284C7),
              onChanged: (v) {
                setState(() {
                  _mmtSelongsongVert = v ?? false;
                  _syncSelongsongKet(_mmtSelongsongVert, _mmtSelongsongHoriz);
                });
                _updateMmtKeteranganKalkulasi();
                _executeHitungMmt();
              },
            ),
          ),
          const SizedBox(height: 6),

          // Selongsong Horizontal
          Container(
            decoration: BoxDecoration(
              color: _mmtSelongsongHoriz
                  ? const Color(0xFFF0F9FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _mmtSelongsongHoriz
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
              dense: true,
              title: Text(
                'Selongsong Horizontal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _mmtSelongsongHoriz
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: _mmtSelongsongHoriz
                      ? const Color(0xFF0369A1)
                      : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                '0,2 x L (${_lebarController.text.isEmpty ? "0" : _lebarController.text} m) x tarif/m²',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              secondary:
                  (_mmtResult?['selongsong']?['isHorizontal'] == true &&
                      (_mmtResult?['selongsong']?['biayaHorizontalPerPcs'] ??
                              0) >
                          0)
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        '+Rp ${_formatNumberDisplay(_mmtResult!['selongsong']['biayaHorizontalPerPcs'])}/pcs',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    )
                  : null,
              value: _mmtSelongsongHoriz,
              activeColor: const Color(0xFF0284C7),
              onChanged: (v) {
                setState(() {
                  _mmtSelongsongHoriz = v ?? false;
                  _syncSelongsongKet(_mmtSelongsongVert, _mmtSelongsongHoriz);
                });
                _updateMmtKeteranganKalkulasi();
                _executeHitungMmt();
              },
            ),
          ),
          const SizedBox(height: 10),

          // Checklist Harga Netto MMT
          Container(
            decoration: BoxDecoration(
              color: _mmtIsNetto
                  ? const Color(0xFFFAF5FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _mmtIsNetto
                    ? const Color(0xFFA855F7)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
              dense: true,
              title: Text(
                'Harga Netto',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _mmtIsNetto ? FontWeight.w700 : FontWeight.w500,
                  color: _mmtIsNetto
                      ? const Color(0xFF7E22CE)
                      : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                _mmtIsNetto
                    ? 'Menggunakan tarif Netto (flat rate)'
                    : 'Menggunakan tarif berstrata kuantiti',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              secondary: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _mmtIsNetto
                      ? const Color(0xFFF3E8FF)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _mmtIsNetto
                        ? const Color(0xFFE9D5FF)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  _mmtIsNetto ? 'NETTO' : 'REGULER',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _mmtIsNetto
                        ? const Color(0xFF7E22CE)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              value: _mmtIsNetto,
              activeColor: const Color(0xFF9333EA),
              onChanged: (v) {
                setState(() {
                  _mmtIsNetto = v ?? false;
                  if (!_mmtIsNetto) {
                    _mmtAlasanNettoController.clear();
                  }
                });
                _updateMmtKeteranganKalkulasi();
                _executeHitungMmt();
              },
            ),
          ),
          if (_mmtIsNetto) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 16,
                        color: Color(0xFF9333EA),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Alasan Penggunaan Harga Netto *',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B21A8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _mmtAlasanNettoController,
                    decoration: const InputDecoration(
                      hintText:
                          'Wajib diisi: Berikan alasan penggunaan tarif Netto',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (_) => _updateMmtKeteranganKalkulasi(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 2. MMT Result Box
  Widget _buildMmtKalkulasiResultCard() {
    final res = _mmtResult!;
    final luasPerPcs = res['luasPerPcs'] ?? 0;
    final totalLuas = res['totalLuas'] ?? 0;
    final tarifPerM2 = (res['tarifPerM2'] ?? 0) as num;
    final qty = _toNumCurrency(_qtyController.text);
    final topping = res['topping'];
    final selongsong = res['selongsong'];
    final dppPerPcs =
        ((res['hargaSatuanPcs'] as num?)?.toDouble() ?? 0.0) +
        _currentOngkirResult.ongkirPerPcs;
    final finalPerPcs = _includePpn
        ? (dppPerPcs * 1.11).round()
        : dppPerPcs.round();
    final ppnTotal = _includePpn ? ((dppPerPcs * 0.11).round() * qty) : 0;
    final totalOrderKeseluruhan = finalPerPcs * qty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildResultItemRow(
            'Luas (${_panjangController.text} m x ${_lebarController.text} m):',
            '$luasPerPcs m² / Pcs',
            isBold: true,
          ),
          _buildResultItemRow(
            'Total Luas ($qty pcs):',
            '$totalLuas m²',
            valueColor: const Color(0xFF0284C7),
            isBold: true,
          ),
          _buildResultItemRow(
            'Tarif per m²:',
            'Rp ${_formatNumberDisplay(tarifPerM2)} /m²',
            valueColor: const Color(0xFF0284C7),
          ),
          if (topping != null)
            _buildResultItemRow(
              'Biaya Topping:',
              '+Rp ${_formatNumberDisplay(topping['hargaSatuan'] ?? topping['totalHarga'] ?? 0)} /pcs',
              valueColor: const Color(0xFFD97706),
            ),
          if (selongsong != null && (selongsong['isVertical'] == true))
            _buildResultItemRow(
              'Selongsong Vertikal (0,2 x ${_panjangController.text}m):',
              '+Rp ${_formatNumberDisplay(selongsong['biayaVerticalPerPcs'] ?? 0)} /pcs',
              valueColor: const Color(0xFF0284C7),
            ),
          if (selongsong != null && (selongsong['isHorizontal'] == true))
            _buildResultItemRow(
              'Selongsong Horizontal (0,2 x ${_lebarController.text}m):',
              '+Rp ${_formatNumberDisplay(selongsong['biayaHorizontalPerPcs'] ?? 0)} /pcs',
              valueColor: const Color(0xFF0284C7),
            ),
          _buildResultItemRow(
            'Ongkir (${_currentOngkirResult.alokasi}):',
            _currentOngkirResult.isFreeCharge
                ? 'Rp. 0'
                : '+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} /Pcs',
            valueColor: _currentOngkirResult.isFreeCharge
                ? const Color(0xFF15803D)
                : const Color(0xFF0284C7),
            isBold: true,
          ),
          const Divider(height: 14, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Kalkulasi Sistem:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Rp ${_formatNumberDisplay(finalPerPcs)} /Pcs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _includePpn
                      ? const Color(0xFF15803D)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          if (_includePpn) ...[
            const SizedBox(height: 4),
            _buildResultItemRow(
              'Biaya PPN 11%:',
              '+Rp ${_formatNumberDisplay(ppnTotal)}',
              valueColor: const Color(0xFF047857),
              isBold: true,
            ),
          ],
          const SizedBox(height: 4),
          _buildResultItemRow(
            'Total Order (${_formatNumberDisplay(qty)} pcs):',
            'Rp ${_formatNumberDisplay(totalOrderKeseluruhan)}',
            valueColor: const Color(0xFF0F172A),
            isBold: true,
          ),
        ],
      ),
    );
  }

  // Accordion Strata MMT
  Widget _buildMmtStrataAccordion() {
    final list = _mmtResult?['tabelReferensi'] as List<dynamic>? ?? [];
    final activeId = _mmtResult?['strataAktif']?['id'];

    return Column(
      children: [
        InkWell(
          onTap: () =>
              setState(() => _showMmtStrataTabel = !_showMmtStrataTabel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.table_chart_rounded,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tabel Master Bahan MMT',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showMmtStrataTabel
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_showMmtStrataTabel && list.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Rentang Luas',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Tarif/m²',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final s in list) ...[
                  Builder(
                    builder: (ctx) {
                      final bool isNetto = s['is_netto'] == true;
                      final qmin = s['qmin'] ?? 0;
                      final qmax = s['qmax'] ?? 999999;
                      final bool isActive =
                          activeId != null && s['id'] == activeId;
                      final String label = isNetto
                          ? 'Harga Netto'
                          : (qmax >= 99999 ? '≥ $qmin m²' : '$qmin - $qmax m²');
                      final tarif = s['harga'] ?? s['tarif'] ?? s['up'] ?? 0;

                      return Container(
                        color: isActive
                            ? const Color(0xFFE0F2FE)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Rp ${_formatNumberDisplay(tarif)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Card Mandiri Tambahan Aksesoris & Cetak Garmen di Step 2
  Widget _buildGarmenTambahanDanCetakCard() {
    final qtyOrder = _toNumCurrency(_qtyController.text);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambahan Aksesoris & Cetak',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '${_garmenSelectedTambahan.length + _garmenSelectedCetak.length} Item Terpilih',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // 1. Tambahan Biaya Aksesoris
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambahan Aksesoris',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              InkWell(
                onTap: _showGarmenTambahanPickerModal,
                child: const Text(
                  '+ Tambah Aksesoris',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_garmenSelectedTambahan.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Belum ada aksesoris tambahan dipilih',
                style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF94A3B8),
                ),
              ),
            )
          else
            Column(
              children: _garmenSelectedTambahan.map((sItem) {
                final tarif = (sItem['tarif'] as num?)?.toInt() ?? 0;
                final sub = tarif * qtyOrder;
                return Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sItem['ket'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Rp ${_formatNumberDisplay(tarif)}/pcs x $qtyOrder pcs',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${_formatNumberDisplay(sub)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                        onPressed: () {
                          setState(() {
                            _garmenSelectedTambahan.remove(sItem);
                          });
                          _executeHitungGarmen();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // 2. Cetak (Sablon / DTF / Bordir / Sublim)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cetak (Sablon / DTF / Bordir)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              InkWell(
                onTap: _showGarmenCetakPickerModal,
                child: const Text(
                  '+ Tambah Cetak',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_garmenSelectedCetak.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Belum ada sablon/cetak tambahan dipilih',
                style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF94A3B8),
                ),
              ),
            )
          else
            Column(
              children: _garmenSelectedCetak.map((cItem) {
                final biaya = (cItem['biaya'] as num?)?.toInt() ?? 0;
                final sub = biaya * qtyOrder;
                final ukDesc = getSablonUkuranDesc(cItem['ket'] ?? '');
                return Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${cItem['jenis']} - ${cItem['ket']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Rp ${_formatNumberDisplay(biaya)}/pcs x $qtyOrder pcs${ukDesc.isNotEmpty ? ' • Ukuran: $ukDesc' : ''}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Rp ${_formatNumberDisplay(sub)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                        onPressed: () {
                          setState(() {
                            _garmenSelectedCetak.remove(cItem);
                          });
                          _executeHitungGarmen();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // 3. Garmen Result Box
  Widget _buildGarmenKalkulasiResultCard() {
    final res = _garmenCalcResult!;
    final qty = _toNumCurrency(_qtyController.text);
    final refList =
        (res['tabelReferensi'] ?? res['tanggaMargin'] ?? []) as List<dynamic>;
    final activeTier = refList.firstWhere(
      (t) =>
          (t['tier'] != null && t['tier'] == res['strataAktif']?['tier']) ||
          ((t['qmin'] ?? t['minOrder'] ?? 0) <= qty &&
              (t['qmax'] ?? t['maxOrder'] ?? 999999) >= qty),
      orElse: () => null,
    );
    final hargaBahanSatuan = activeTier != null
        ? (activeTier['up'] ?? activeTier['hargaUp'] ?? 0)
        : ((res['hpp'] ?? 0) + (res['strataAktif']?['marginRp'] ?? 0));

    final tambahanPerPcs =
        (res['tambahan']?['totalPerPcs'] ?? res['biayaTambahan'] ?? 0) as num;
    final cetakPerPcs =
        (res['cetak']?['totalPerPcs'] ?? res['biayaCetak'] ?? 0) as num;
    final rawHrg =
        (res['hargaUpPerPcs'] ??
                res['hargaJualRevisi'] ??
                res['hargaJualPerPcs'] ??
                res['hargaJual'] ??
                0)
            as num;
    final dppPerPcs = rawHrg.toDouble() + _currentOngkirResult.ongkirPerPcs;
    final finalPerPcs = _includePpn
        ? (dppPerPcs * 1.11).round()
        : dppPerPcs.round();
    final ppnTotal = _includePpn ? ((dppPerPcs * 0.11).round() * qty) : 0;
    final totalOrderKeseluruhan = finalPerPcs * qty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildResultItemRow(
            'Harga Bahan:',
            'Rp ${_formatNumberDisplay(hargaBahanSatuan)} / Pcs',
            valueColor: const Color(0xFF0284C7),
            isBold: true,
          ),
          if (tambahanPerPcs > 0)
            _buildResultItemRow(
              'Biaya Tambahan:',
              '+Rp ${_formatNumberDisplay(tambahanPerPcs)} / Pcs',
              valueColor: const Color(0xFFD97706),
              isBold: true,
            ),
          if (cetakPerPcs > 0)
            _buildResultItemRow(
              'Tambahan Cetak:',
              '+Rp ${_formatNumberDisplay(cetakPerPcs)} / Pcs',
              valueColor: const Color(0xFFD97706),
              isBold: true,
            ),
          _buildResultItemRow(
            'Ongkir (${_currentOngkirResult.alokasi}):',
            _currentOngkirResult.isFreeCharge
                ? 'Rp. 0'
                : '+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)} /Pcs',
            valueColor: _currentOngkirResult.isFreeCharge
                ? const Color(0xFF15803D)
                : const Color(0xFF0284C7),
            isBold: true,
          ),
          const Divider(height: 14, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Kalkulasi Sistem:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Rp ${_formatNumberDisplay(finalPerPcs)} /Pcs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _includePpn
                      ? const Color(0xFF15803D)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          if (_includePpn) ...[
            const SizedBox(height: 4),
            _buildResultItemRow(
              'Biaya PPN 11%:',
              '+Rp ${_formatNumberDisplay(ppnTotal)}',
              valueColor: const Color(0xFF047857),
              isBold: true,
            ),
          ],
          const SizedBox(height: 4),
          _buildResultItemRow(
            'Total Order (${_formatNumberDisplay(qty)} pcs):',
            'Rp ${_formatNumberDisplay(totalOrderKeseluruhan)}',
            valueColor: const Color(0xFF0F172A),
            isBold: true,
          ),
        ],
      ),
    );
  }

  // Accordion Strata Garmen
  Widget _buildGarmenStrataAccordion() {
    final list =
        ((_garmenCalcResult?['tabelReferensi'] ??
                _garmenCalcResult?['tanggaMargin'] ??
                [])
            as List<dynamic>);
    final qty = _toNumCurrency(_qtyController.text);
    final activeTier = _garmenCalcResult?['strataAktif']?['tier'];

    return Column(
      children: [
        InkWell(
          onTap: () =>
              setState(() => _showGarmenStrataTabel = !_showGarmenStrataTabel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.table_chart_rounded,
                      size: 16,
                      color: Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tabel Harga Bahan ($_garmenJenisKain | ${_garmenKodeModel == 'KH-0001' ? '1 Warna' : '2 Warna'} | ${_garmenWarna.toUpperCase()})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showGarmenStrataTabel
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_showGarmenStrataTabel && list.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Rentang Qty',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Harga / Pcs',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final tier in list) ...[
                  Builder(
                    builder: (ctx) {
                      final qmin =
                          (tier['qmin'] ?? tier['minOrder'] ?? 0) as num;
                      final qmax =
                          (tier['qmax'] ?? tier['maxOrder'] ?? 999999) as num;
                      final bool isActive =
                          (tier['tier'] != null &&
                              tier['tier'] == activeTier) ||
                          (qty >= qmin && qty <= qmax);
                      final String label =
                          tier['label']?.toString() ??
                          '${_formatNumberDisplay(qmin)} - ${qmax >= 999999 ? "≥ 1000" : _formatNumberDisplay(qmax)} pcs';
                      final hargaTier =
                          (tier['up'] ?? tier['hargaUp'] ?? 0) as num;

                      return Container(
                        color: isActive
                            ? const Color(0xFFE0F2FE)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Rp ${_formatNumberDisplay(hargaTier)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFF0369A1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultItemRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    double? letterSpacing = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF334155),
              letterSpacing: letterSpacing,
            ),
          ),
        ],
      ),
    );
  }

  // --- TOMBOL HITUNG ULANG (WARNA & TULISAN KONSTAN, DILENGKAPI EFEK BLINK) ---
  Widget _buildHitungUlangButton() {
    final isLoading = _spandukLoading || _mmtLoading || _garmenLoadingCalc;
    const Color buttonColor = Color(0xFF4F46E5);

    final Color bgColor = _isBlinkingRecalc
        ? const Color(0xFFC7D2FE)
        : const Color(0xFFEEF2FF);

    final Color borderColor = _isBlinkingRecalc
        ? const Color(0xFF3730A3)
        : const Color(0xFF6366F1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: _isBlinkingRecalc ? 2.0 : 1.2,
        ),
        boxShadow: _isBlinkingRecalc
            ? [
                BoxShadow(
                  color: buttonColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: buttonColor.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading
              ? null
              : () {
                  if (_selectedDivisi == '1') _executeHitungSpanduk();
                  if (_selectedDivisi == '5') _executeHitungMmt();
                  if (_selectedDivisi == '4') _executeHitungGarmen();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: buttonColor,
                    ),
                  )
                else
                  AnimatedRotation(
                    turns: _isBlinkingRecalc ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: buttonColor,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 8),
                const Text(
                  'Hitung Ulang',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: buttonColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- CHECKBOX CARD PPN 11% (IDENTIK DENGAN REACT NATIVE) ---
  Widget _buildPpnCard() {
    return InkWell(
      onTap: () => _handleTogglePpn(),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _includePpn
              ? const Color(0xFFF0FDF4)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _includePpn
                ? const Color(0xFF86EFAC)
                : const Color(0xFFE2E8F0),
            width: _includePpn ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _includePpn
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: _includePpn
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+ PPN 11% (INC PPN)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _includePpn
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: _includePpn
                          ? const Color(0xFF15803D)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _includePpn
                        ? 'Kalkulasi sudah termasuk PPN 11%'
                        : 'Kalkulasi belum termasuk PPN',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: _includePpn
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _includePpn ? 'INC PPN;' : 'EXC PPN;',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: _includePpn
                      ? const Color(0xFF166534)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BOX RINGKASAN SPESIFIKASI DI LANGKAH 2 ---
  Widget _buildSpecSummaryBox() {
    final divisiLabel = _selectedDivisi == '1'
        ? 'Spanduk'
        : (_selectedDivisi == '5'
              ? 'MMT'
              : (_selectedDivisi == '4' ? 'Garmen' : 'Lainnya'));

    // 1. Bahan & Dimensi / Spesifikasi Teknis
    String labelBahan = 'Bahan / Kain';
    String specBahan = '-';
    String labelUkuran = 'Ukuran (P x L)';
    String specUkuran = '-';

    if (_selectedDivisi == '1') {
      labelBahan = 'Kain Spanduk';
      final metodeStr = _spandukMetode.trim().isNotEmpty
          ? (_spandukMetode.trim().toUpperCase() == 'MANUAL'
                ? 'Manual'
                : 'Machine')
          : '';
      if (_spandukJenisKain.isNotEmpty) {
        specBahan = metodeStr.isNotEmpty
            ? '$_spandukJenisKain ($metodeStr)'
            : _spandukJenisKain;
      } else {
        specBahan = '-';
      }
      labelUkuran = 'Ukuran (P x L)';
      final pStr = _panjangController.text.trim().isNotEmpty
          ? _panjangController.text.trim()
          : '0';
      specUkuran = '$pStr m x ${_spandukLebar.toInt()} cm';
    } else if (_selectedDivisi == '4') {
      labelBahan = 'Jenis Kain';
      specBahan = _garmenJenisKain.isNotEmpty ? _garmenJenisKain : '-';
      labelUkuran = 'Model & Warna';
      final modelStr = _garmenKodeModel == 'KH-0001'
          ? '1 Warna'
          : (_garmenKodeModel == 'KH-0002' ? '2 Warna' : _garmenKodeModel);
      final warnaStr = _garmenWarna.isNotEmpty ? _garmenWarna : '-';
      specUkuran = '$modelStr ($warnaStr)';
    } else if (_selectedDivisi == '5') {
      labelBahan = 'Bahan MMT';
      String bahanNama = _mmtBahanKode;
      final foundBahan = _currentMmtBahanOptions
          .cast<Map<String, dynamic>?>()
          .firstWhere((b) => b?['kode'] == _mmtBahanKode, orElse: () => null);
      if (foundBahan != null &&
          foundBahan['nama'] != null &&
          foundBahan['nama'].toString().isNotEmpty) {
        bahanNama = foundBahan['nama'].toString();
      }
      specBahan = _mmtKategori.isNotEmpty
          ? '$_mmtKategori - $bahanNama'
          : (bahanNama.isNotEmpty ? bahanNama : '-');
      labelUkuran = 'Ukuran (P x L)';
      final pStr = _panjangController.text.trim().isNotEmpty
          ? _panjangController.text.trim()
          : '0';
      final lStr = _lebarController.text.trim().isNotEmpty
          ? _lebarController.text.trim()
          : '0';
      specUkuran = '$pStr m x $lStr m';
    } else {
      specBahan = _spandukJenisKain.isNotEmpty ? _spandukJenisKain : '-';
      specUkuran = '${_panjangController.text} m x ${_lebarController.text} m';
    }

    // Finishing text
    String finishingText = _finishingController.text.trim();
    if (_selectedDivisi == '1' && _spandukFinishingIds.isNotEmpty) {
      final opts = (_masterOptions?['spandukTambahan'] as List<dynamic>?) ?? [];
      final names = _spandukFinishingIds
          .map((id) {
            final found = opts.cast<Map<String, dynamic>?>().firstWhere(
              (o) => (o?['id'] ?? o?['fi_id']) == id,
              orElse: () => null,
            );
            return (found?['nama'] ?? found?['fi_nama'] ?? '').toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();

      if (names.isNotEmpty) {
        final joined = names.join(', ');
        if (finishingText.isEmpty) {
          finishingText = joined;
        } else if (!finishingText.toLowerCase().contains(
          joined.toLowerCase(),
        )) {
          finishingText = '$finishingText (+ $joined)';
        }
      }
    }

    // Opsi Khusus Divisi (Workshop di Garmen, Topping/Opsi Cetak di MMT, Sublim di Spanduk)
    String extraLabel = '';
    String extraValue = '';
    if (_selectedDivisi == '4') {
      if (_garmenWorkshop.trim().isNotEmpty) {
        extraLabel = 'WORKSHOP';
        extraValue = _garmenWorkshop.trim();
      }
    } else if (_selectedDivisi == '5') {
      if (_mmtToppingKode.trim().isNotEmpty) {
        extraLabel = 'TOPPING';
        final topQty = _mmtToppingQtyController.text.trim().isNotEmpty
            ? _mmtToppingQtyController.text.trim()
            : '1';
        extraValue = '$_mmtToppingKode ($topQty Pcs)';
      } else if (_mmtIsNetto) {
        extraLabel = 'OPSI CETAK';
        extraValue = _mmtAlasanNettoController.text.trim().isNotEmpty
            ? 'Netto (${_mmtAlasanNettoController.text.trim()})'
            : 'Netto';
      } else if (_mmtSelongsongVert || _mmtSelongsongHoriz) {
        extraLabel = 'OPSI CETAK';
        if (_mmtSelongsongVert && _mmtSelongsongHoriz) {
          extraValue = 'Selongsong (V & H)';
        } else if (_mmtSelongsongVert) {
          extraValue = 'Selongsong Vertikal';
        } else {
          extraValue = 'Selongsong Horizontal';
        }
      }
    }

    // Fallback Sublim jika belum ada extraValue dan sublim terisi
    if (extraValue.isEmpty && _mhSublim.trim().isNotEmpty) {
      extraLabel = 'SUBLIM';
      extraValue = _mhSublim.trim();
    }

    // Pengiriman & Ongkir
    String alokasiTeks = _alokasiOngkir;
    if (_namaDaerahKirimController.text.trim().isNotEmpty &&
        _alokasiOngkir != 'Tanpa Ongkir') {
      alokasiTeks =
          '$_alokasiOngkir (${_namaDaerahKirimController.text.trim()})';
    }

    final isFreeOngkir =
        _alokasiOngkir == 'Tanpa Ongkir' || _currentOngkirResult.isFreeCharge;
    final ongkirDisplay = isFreeOngkir
        ? 'Rp. 0'
        : 'Rp ${_formatNumberDisplay(_currentOngkirResult.totalOngkir)} (+Rp ${_formatNumberDisplay(_currentOngkirResult.ongkirPerPcs)}/pcs)';

    final keteranganTeks = _keteranganController.text.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Baris: Judul Sederhana & Tombol Ubah
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detail Terinput',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _currentStep = 1),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Ubah',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFDBEAFE)),
          const SizedBox(height: 8),
          // Baris 1: Customer & Nama Pekerjaan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSpecInfoCell(
                  label: 'CUSTOMER',
                  value: _customerNamaController.text.trim().isNotEmpty
                      ? _customerNamaController.text.trim()
                      : '-',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSpecInfoCell(
                  label: 'NAMA PEKERJAAN',
                  value: _barangController.text.trim().isNotEmpty
                      ? _barangController.text.trim()
                      : '-',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Baris 2: Divisi & Tanggal Order
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSpecInfoCell(label: 'DIVISI', value: divisiLabel),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSpecInfoCell(
                  label: 'TANGGAL',
                  value: DateFormat('dd-MM-yyyy').format(_rencanaOrderDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Baris 3: Spesifikasi Bahan & Dimensi Ukuran
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSpecInfoCell(label: labelBahan, value: specBahan),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSpecInfoCell(
                  label: labelUkuran,
                  value: specUkuran,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Baris 4: Kuantitas Order & Opsi Spesifik Divisi / Finishing
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSpecInfoCell(
                  label: 'JUMLAH ORDER',
                  value:
                      '${_formatNumberDisplay(_toNumCurrency(_qtyController.text))} Pcs',
                  valueColor: const Color(0xFF4F46E5),
                  valueFontWeight: FontWeight.w800,
                ),
              ),
              if (extraValue.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSpecInfoCell(
                    label: extraLabel,
                    value: extraValue,
                  ),
                ),
              ],
              if (finishingText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSpecInfoCell(
                    label: 'FINISHING',
                    value: finishingText,
                  ),
                ),
              ],
              if (extraValue.isEmpty && finishingText.isEmpty) ...[
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Baris 5: Pengiriman & Estimasi Ongkir
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSpecInfoCell(
                  label: 'PENGIRIMAN',
                  value: alokasiTeks,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSpecInfoCell(
                  label: 'ESTIMASI ONGKIR',
                  value: ongkirDisplay,
                  valueColor: isFreeOngkir
                      ? const Color(0xFF15803D)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
          ),

          // Baris Khusus Divisi Garmen: Tambahan Aksesoris & Cetak Terinput (Terlihat oleh User)
          if (_selectedDivisi == '4') ...[
            if (_garmenSelectedTambahan.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSpecInfoCell(
                      label: 'AKSESORIS TERINPUT',
                      value: _garmenSelectedTambahan
                          .map(
                            (e) =>
                                '${e['ket']} (+Rp ${_formatNumberDisplay(e['tarif'] ?? 0)})',
                          )
                          .join(', '),
                      valueColor: const Color(0xFF4F46E5),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
            if (_garmenSelectedCetak.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSpecInfoCell(
                      label: 'CETAK / SABLON TERINPUT',
                      value: _garmenSelectedCetak
                          .map(
                            (e) =>
                                '${e['jenis']} - ${e['ket']} (+Rp ${_formatNumberDisplay(e['biaya'] ?? 0)})',
                          )
                          .join(', '),
                      valueColor: const Color(0xFF7C3AED),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ],

          // Baris 6: Keterangan Tambahan
          if (keteranganTeks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFDBEAFE))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KETERANGAN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    keteranganTeks,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecInfoCell({
    required String label,
    required String value,
    Color? valueColor,
    FontWeight valueFontWeight = FontWeight.w700,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value.isNotEmpty ? value : '-',
          style: TextStyle(
            fontSize: 12,
            fontWeight: valueFontWeight,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPhotoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lampiran Foto Contoh Produk',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Maks. 1 MB',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_imageBytes != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _imageBytes!,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _imageBytes = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${((_imageSizeBytes ?? 0) / 1024).toStringAsFixed(0)} KB (Siap Unggah)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          )
        else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  height: 140,
                  child: WebSafeNetworkImage(
                    imageUrl: _existingImageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _existingImageUrl = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Foto Terpasang (Ketuk tombol di bawah untuk ganti)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(
                        Icons.photo_camera_rounded,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                      label: const Text(
                        'Kamera',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(
                        Icons.photo_library_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                      label: const Text(
                        'Galeri',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '* Unggah sample desain (Opsional)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // --- STEP 3: REVIEW & PENGAJUAN WIDGET ---
  Widget _buildStep3Review() {
    final finalHarga = _toNumCurrency(_hargaMintaController.text);
    final qty = _toNumCurrency(_qtyController.text);
    final divisiLabel = _selectedDivisi == '1'
        ? 'Spanduk'
        : (_selectedDivisi == '5' ? 'MMT' : 'Garmen');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Resume Pengajuan Permintaan Harga
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.fact_check_rounded,
                      size: 16,
                      color: Color(0xFF15803D),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Resume Pengajuan Permintaan Harga',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Lampiran Foto Contoh Produk (1 Slot)
              _buildPhotoUploadSection(),
              const Divider(height: 20),

              // Section Customer & Pekerjaan
              const Text(
                'Customer & Pekerjaan',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              _buildReviewRow(
                'Customer:',
                _customerNamaController.text,
                isBold: true,
              ),
              _buildReviewRow(
                'Nama Pekerjaan:',
                _barangController.text,
                isBold: true,
              ),
              _buildReviewRow('Divisi:', divisiLabel),
              _buildReviewRow(
                'Tanggal:',
                DateFormat('dd-MM-yyyy').format(_rencanaOrderDate),
                isBold: true,
              ),
              const Divider(height: 20),

              // Section Spesifikasi Detail
              const Text(
                'Spesifikasi Detail',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              if (_selectedDivisi == '4') ...[
                _buildReviewRow(
                  'Model:',
                  _garmenKodeModel == 'KH-0001' ? '1 Warna' : '2 Warna',
                  isBold: true,
                ),
                _buildReviewRow(
                  'Kain & Warna:',
                  '$_garmenJenisKain ($_garmenWarna)',
                ),
              ] else if (_selectedDivisi == '1') ...[
                _buildReviewRow(
                  'Jenis Kain Spanduk:',
                  _spandukJenisKain,
                  isBold: true,
                ),
                _buildReviewRow(
                  'Ukuran (P x L):',
                  '${_panjangController.text} m x ${_spandukLebar.toInt()} cm',
                ),
              ] else ...[
                _buildReviewRow(
                  'Kategori & Bahan:',
                  '$_mmtKategori - $_mmtBahanKode',
                  isBold: true,
                ),
                _buildReviewRow(
                  'Ukuran (P x L):',
                  '${_panjangController.text} m x ${_lebarController.text} m',
                ),
                _buildReviewRow(
                  'Tipe Tarif:',
                  _mmtIsNetto ? 'Harga Netto' : 'Harga Standar (Strata)',
                ),
                if (_mmtIsNetto && _mmtAlasanNettoController.text.isNotEmpty)
                  _buildReviewRow(
                    'Alasan Netto:',
                    _mmtAlasanNettoController.text,
                    valueColor: const Color(0xFF7E22CE),
                    isBold: true,
                  ),
              ],
              if (_ukuranController.text.trim().isNotEmpty)
                _buildReviewRow(
                  'Rincian Ukuran / Size:',
                  _ukuranController.text.trim(),
                ),
              if (_gramasiController.text.trim().isNotEmpty)
                _buildReviewRow('Gramasi:', _gramasiController.text.trim()),
              if (_finishingController.text.trim().isNotEmpty)
                _buildReviewRow('Finishing:', _finishingController.text.trim()),
              if (_mhSublim == 'PREMIUM')
                _buildReviewRow(
                  'Sublim:',
                  'Ya (Sublim Premium)',
                  valueColor: const Color(0xFF15803D),
                  isBold: true,
                ),
              _buildReviewRow(
                'Jumlah Order:',
                '$qty Pcs',
                isBold: true,
                valueColor: const Color(0xFF4F46E5),
                fontSize: 13,
              ),
              if (_keteranganController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detail Terinput:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _keteranganController.text.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 20),

              // Final Price Summary Box (reviewPriceBox)
              Builder(
                builder: (context) {
                  final num ongkirPcs = _currentOngkirResult.isFreeCharge
                      ? 0
                      : _currentOngkirResult.ongkirPerPcs;
                  final num totalOngkir = _currentOngkirResult.isFreeCharge
                      ? 0
                      : _currentOngkirResult.totalOngkir;
                  final bool hasOngkir =
                      !_currentOngkirResult.isFreeCharge &&
                      _currentOngkirResult.totalOngkir > 0;

                  final int dppPerPcs = _includePpn
                      ? (_hargaKalkulasi / 1.11).round()
                      : _hargaKalkulasi;
                  final int ppnPerPcs = _includePpn
                      ? (_hargaKalkulasi - dppPerPcs)
                      : 0;
                  final int hargaDasarProduksiPerPcs = (dppPerPcs - ongkirPcs)
                      .clamp(0, double.infinity)
                      .round();

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF86EFAC),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card & Badges
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.calculate_rounded,
                              size: 22,
                              color: Color(0xFF15803D),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HASIL KALKULASI SISTEM',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Badges Status Include PPN & Ongkir
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            // Badge PPN
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _includePpn
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _includePpn
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFBAE6FD),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _includePpn
                                        ? Icons.check_circle_rounded
                                        : Icons.info_outline_rounded,
                                    size: 13,
                                    color: _includePpn
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF0369A1),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _includePpn
                                        ? 'Termasuk PPN (11%)'
                                        : 'Non PPN (Exclude)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _includePpn
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF0369A1),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Badge Ongkir
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _currentOngkirResult.isFreeCharge
                                    ? const Color(0xFFDCFCE7)
                                    : (hasOngkir
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _currentOngkirResult.isFreeCharge
                                      ? const Color(0xFF86EFAC)
                                      : (hasOngkir
                                            ? const Color(0xFFFDE68A)
                                            : const Color(0xFFCBD5E1)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _currentOngkirResult.isFreeCharge
                                        ? Icons.local_shipping_rounded
                                        : (hasOngkir
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                    .remove_circle_outline_rounded),
                                    size: 13,
                                    color: _currentOngkirResult.isFreeCharge
                                        ? const Color(0xFF15803D)
                                        : (hasOngkir
                                              ? const Color(0xFFB45309)
                                              : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _currentOngkirResult.isFreeCharge
                                        ? 'Bebas Ongkir'
                                        : (hasOngkir
                                              ? 'Termasuk Ongkir (${_currentOngkirResult.alokasi})'
                                              : 'Tanpa Ongkir'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _currentOngkirResult.isFreeCharge
                                          ? const Color(0xFF15803D)
                                          : (hasOngkir
                                                ? const Color(0xFF92400E)
                                                : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 20, color: Color(0xFFBBF7D0)),

                        // 1. Biaya Produksi / Harga Dasar
                        _buildReviewRow(
                          '• Kalkulasi (Non PPN):',
                          'Rp ${_formatNumberDisplay(hargaDasarProduksiPerPcs)} /Pcs',
                          fontSize: 12,
                          letterSpacing: 1,
                          valueColor: const Color(0xFF334155),
                        ),
                        const SizedBox(height: 3),

                        // 2. Ongkir
                        _buildReviewRow(
                          '• Biaya Ongkir (${_currentOngkirResult.alokasi}):',
                          _currentOngkirResult.isFreeCharge
                              ? 'Rp 0 (Gratis Ongkir)'
                              : (hasOngkir
                                    ? '+ Rp ${_formatNumberDisplay(ongkirPcs)} /Pcs'
                                    : 'Rp 0 (Tanpa Pengiriman)'),
                          fontSize: 12,
                          valueColor: hasOngkir
                              ? const Color(0xFFB45309)
                              : const Color(0xFF334155),
                        ),
                        const SizedBox(height: 3),

                        // 3. PPN 11%
                        _buildReviewRow(
                          '• PPN (11%):',
                          _includePpn
                              ? '+ Rp ${_formatNumberDisplay(ppnPerPcs)} /Pcs'
                              : 'Rp 0 (Exc PPN)',
                          fontSize: 12,
                          valueColor: _includePpn
                              ? const Color(0xFF15803D)
                              : const Color(0xFF334155),
                        ),

                        const Divider(height: 18, color: Color(0xFFBBF7D0)),

                        // HASIL TOTAL PER PCS & KESELURUHAN
                        _buildReviewRow(
                          'Hasil Kalkulasi Sistem (Final /Pcs):',
                          'Rp ${_formatNumberDisplay(_hargaKalkulasi)} /Pcs',
                          isBold: true,
                          valueColor: const Color(0xFF15803D),
                          fontSize: 14.5,
                        ),
                        const SizedBox(height: 4),
                        _buildReviewRow(
                          'Total Order ($qty Pcs):',
                          'Rp ${_formatNumberDisplay(_hargaKalkulasi * qty)}',
                          isBold: true,
                          valueColor: const Color(0xFF15803D),
                          fontSize: 16,
                        ),

                        const SizedBox(height: 10),

                        // CALLOUT BOX INFORMASI PENJELAS
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_rounded,
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Harga di atas SUDAH INCLUDE '
                                  '${hasOngkir ? "ongkir ke ${_namaDaerahKirimController.text.isNotEmpty ? _namaDaerahKirimController.text : "tujuan"} (Rp ${_formatNumberDisplay(totalOngkir)})" : (_currentOngkirResult.isFreeCharge ? "Gratis Ongkir" : "tanpa ongkir")}'
                                  ' dan ${_includePpn ? "sudah termasuk PPN 11%" : "belum termasuk PPN"}.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.35,
                                    color: Color(0xFF166534),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_keteranganKalkulasiController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFDCFCE7,
                              ).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ket. Kalkulasi:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _keteranganKalkulasiController.text,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Riwayat Order Customer (Collapsible Dropdown)
        AppCard(
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(
                  () => _isSoHistoryExpanded = !_isSoHistoryExpanded,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 22,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Riwayat Order Customer',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${_customerSoHistory.length} SO',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _customerNamaController.text.isNotEmpty
                                  ? _customerNamaController.text
                                  : 'Belum dipilih',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(
                      _isSoHistoryExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: const Color(0xFF0284C7),
                    ),
                  ],
                ),
              ),

              if (_isSoHistoryExpanded) ...[
                const Divider(height: 16),
                if (_customerSoHistory.isNotEmpty) ...[
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            onChanged: (v) =>
                                setState(() => _soSearchKeyword = v),
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Cari nomor SO, pekerjaan, detail...',
                              hintStyle: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (_customerSoHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Customer ini belum memiliki riwayat order sebelumnya.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  )
                else if (_filteredSoHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Tidak ada riwayat SO yang cocok dengan pencarian.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredSoHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final so = _filteredSoHistory[i];
                      final soNomor = so['so_nomor']?.toString() ?? '-';
                      final divisiNama = so['divisi_nama']?.toString() ?? '';
                      final tgl =
                          so['so_tanggal_fmt']?.toString() ??
                          so['so_tanggal']?.toString() ??
                          '';
                      final namaPekerjaan =
                          so['so_nama']?.toString() ??
                          so['so_nama2']?.toString() ??
                          so['nama_barang']?.toString() ??
                          'Pekerjaan Tanpa Nama';
                      final numQty = (so['so_jumlah'] ?? so['qty'] ?? 0) as num;
                      final numHarga =
                          (so['so_harga'] ?? so['harga'] ?? 0) as num;
                      final totalNominal = numQty * numHarga;
                      final kain = so['so_kain']?.toString() ?? '';
                      final ukuran =
                          so['so_ukuran']?.toString() ??
                          (so['so_panjang'] != null || so['so_lebar'] != null
                              ? '${so['so_panjang']}m x ${so['so_lebar']}m'
                              : '');
                      final finishing = so['so_finishing']?.toString() ?? '';
                      final ket = so['so_ket']?.toString() ?? '';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header SO Item
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFBAE6FD),
                                    ),
                                  ),
                                  child: Text(
                                    soNomor,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                                if (divisiNama.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFDDD6FE),
                                      ),
                                    ),
                                    child: Text(
                                      divisiNama,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  tgl,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Nama Item Pekerjaan
                            Text(
                              namaPekerjaan,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Qty, Harga Satuan, & Total Nominal SO
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      text: 'Qty: ',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _formatNumberDisplay(numQty),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Rp ${_formatNumberDisplay(numHarga)}/pcs',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  Text(
                                    'Total: Rp ${_formatNumberDisplay(totalNominal)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Spesifikasi Lengkap SO (Box)
                            if (kain.isNotEmpty ||
                                ukuran.isNotEmpty ||
                                finishing.isNotEmpty ||
                                ket.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (kain.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          '• Bahan/Kain: $kain',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    if (ukuran.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          '• Ukuran: $ukuran',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    if (finishing.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          '• Finishing: $finishing',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    if (ket.isNotEmpty)
                                      Text(
                                        '• Keterangan: $ket',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Permintaan Harga Custom & Pengajuan
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.monetization_on_rounded,
                    size: 20,
                    color: Color(0xFF4F46E5),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Permintaan Harga Sales',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info Pembanding Harga Standar Kalkulasi
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Kalkulasi Sistem (${_includePpn ? "Inc. PPN" : "Exc. PPN"}${!_currentOngkirResult.isFreeCharge && _currentOngkirResult.totalOngkir > 0 ? " & Ongkir" : ""}):',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Text(
                          'Rp ${_formatNumberDisplay(_hargaKalkulasi)} /pcs',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total ($qty Pcs):',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          'Rp ${_formatNumberDisplay(_hargaKalkulasi * qty)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              RichText(
                text: const TextSpan(
                  text: 'Permintaan Harga Sales',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _hargaMintaController,
                keyboardType: TextInputType.number,
                inputFormatters: const [_thousandsSeparatorInputFormatter],
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Masukkan harga pengajuan...',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Nilai Permintaan: Rp ${_formatNumberDisplay(finalHarga * qty)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),

              // Alasan Permintaan Harga
              RichText(
                text: TextSpan(
                  text: 'Alasan Permintaan Harga ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: (finalHarga == 0 || finalHarga < _hargaKalkulasi) &&
                              _hargaKalkulasi > 0
                          ? '(Wajib Diisi)*'
                          : '(Opsional)',
                      style: TextStyle(
                        fontSize: 11,
                        color: (finalHarga == 0 ||
                                    finalHarga < _hargaKalkulasi) &&
                                _hargaKalkulasi > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _alasanPengajuanController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'Contoh: Diskon repeat order partai besar, menyesuaikan SO terakhir, penyesuaian budget klien...',
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(height: 12),

              // Keterangan Kalkulasi
              RichText(
                text: const TextSpan(
                  text: 'Keterangan Kalkulasi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: ' (Opsional)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _keteranganKalkulasiController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Keterangan kalkulasi otomatis...',
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Tombol Aksi Bawah Review
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 360;
            return Row(
              children: [
                Expanded(
                  flex: isSmallScreen ? 5 : 4,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => setState(() => _currentStep = 2),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Color(0xFF475569),
                    ),
                    label: Text(
                      isSmallScreen ? 'Hitung' : 'Hitung Ulang',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: isSmallScreen ? 7 : 6,
                  child: AppButton(
                    text: _isEditMode ? 'Simpan Perubahan' : 'Kirim Pengajuan',
                    icon: Icons.send_rounded,
                    isLoading: _isSubmitting,
                    onPressed: () => _showConfirmSubmitDialog(isBypass: false),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- RESET FIELD SAAT GANTI DIVISI ---
  void _onDivisiChanged(String newDivisi) {
    if (_selectedDivisi == newDivisi) return;

    setState(() {
      _selectedDivisi = newDivisi;

      // 1. Reset field spesifikasi Spanduk (Divisi 1)
      _spandukMetode = 'MANUAL';
      _spandukLebar = 90.0;
      _spandukJenisKain = '';
      _spandukFinishingIds.clear();
      _spandukResult = null;
      _spandukCalculatedParams = '';
      _showSpandukStrataTabel = false;

      // 2. Reset field spesifikasi MMT (Divisi 5)
      _mmtKategori = 'VYNIL';
      _mmtBahanKode = '';
      _mmtToppingKode = '';
      _mmtToppingQtyController.text = '1';
      _mmtIsNetto = false;
      _mmtAlasanNettoController.clear();
      _mmtSelongsongVert = false;
      _mmtSelongsongHoriz = false;
      _mmtResult = null;
      _mmtCalculatedParams = '';
      _showMmtStrataTabel = false;

      // 3. Reset field dimensi umum (Panjang & Lebar) yang dipakai Spanduk / MMT
      _panjangController.clear();
      _lebarController.clear();

      // 4. Reset field spesifikasi Garmen (Divisi 4)
      _garmenKodeModel = 'KH-0001';
      _garmenJenisKain = '';
      _garmenWarna = 'muda';
      _garmenWorkshop = 'MEDIUM';
      _garmenKategoriKain = 'COTTON';
      _ukuranController.clear();
      _gramasiController.clear();
      _finishingController.clear();
      _mhSublim = '';
      _garmenSelectedTambahan.clear();
      _garmenSelectedCetak.clear();
      _garmenCalcResult = null;
      _garmenCalculatedParams = '';
      _showGarmenStrataTabel = false;
      _dtfBordirPanjangController.clear();
      _dtfBordirLebarController.clear();
      _dtfTarifCmController.clear();
      _bordirTarifCmController.clear();
      _garmenCetakActiveCategory = 'SABLON';
      _garmenCetakSablonSubCategory = 'ALL';
      _garmenCetakSearchQuery = '';

      // 5. Reset hasil kalkulasi sistem & pengajuan harga
      _hargaKalkulasi = 0;
      _hargaMintaController.clear();
      _alasanPengajuanController.clear();
      _keteranganKalkulasiController.text = 'INC PPN';
      _isCustomOngkir = false;
      _customOngkirValController.clear();

      // 6. Reset pra-order jika divisi pra-order berbeda dengan divisi baru
      if (_selectedPraOrderDetail != null) {
        final poDiv = (_selectedPraOrderDetail?['divisi'] ?? '').toString();
        if (poDiv.isNotEmpty && poDiv != newDivisi) {
          _praOrderNomor = '';
          _selectedPraOrderDetail = null;
          _praOrderKainWarning = null;
          _praOrderRawKain = null;
        }
      }

      // 7. Jika pindah ke Garmen, muat lookup/master kain
      if (newDivisi == '4') {
        _loadGarmenLookups();
      }
    });
  }

  // --- HELPER WIDGETS ---
  Widget _buildDivisiChip(String kode, String label) {
    final isSelected = _selectedDivisi == kode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onDivisiChanged(kode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectablePill(
    String title,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  void _showFinishingInfoDialog(String type) {
    final bool isInclude = type == 'include_kalkulasi';
    final Color primaryColor = isInclude
        ? const Color(0xFF0284C7)
        : const Color(0xFF475569);
    final Color iconBgColor = isInclude
        ? const Color(0xFFE0F2FE)
        : const Color(0xFFF1F5F9);
    final Color boxBgColor = isInclude
        ? const Color(0xFFF0F9FF)
        : const Color(0xFFF8FAFC);
    final Color boxBorderColor = isInclude
        ? const Color(0xFFBAE6FD)
        : const Color(0xFFE2E8F0);
    final Color textColor = isInclude
        ? const Color(0xFF0369A1)
        : const Color(0xFF334155);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Modal
              Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isInclude
                              ? Icons.calculate_rounded
                              : Icons.edit_note_rounded,
                          size: 26,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isInclude
                            ? 'Finishing Include Kalkulasi'
                            : 'Finishing Tanpa Kalkulasi',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info Section Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: boxBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: boxBorderColor),
                ),
                child: Text(
                  isInclude
                      ? 'Pilihan akan memengaruhi kalkulasi harga.'
                      : 'Inputan tidak akan memengaruhi kalkulasi harga.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Mengerti
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Mengerti',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualSpandukModal() {
    final numPanjang = _toNumDecimal(_panjangController.text);
    final numLebar = _spandukLebar > 0 ? _spandukLebar : 90.0;
    final numQty = _toNumCurrency(_qtyController.text);
    final totalLuasM2 = numPanjang * (numLebar / 100.0) * numQty;
    final isLuasQualify = totalLuasM2 >= 500;
    final isQtyQualify = numQty >= 100;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Modal
              Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFBEB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_rounded,
                          size: 26,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ketentuan Cetak Spanduk Manual',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Syarat Menggunakan Cetak Manual Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Syarat Menggunakan Cetak Manual:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pesanan harus memenuhi salah satu kriteria berikut:',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('• ', style: TextStyle(color: Color(0xFF92400E))),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Jumlah Order: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: 'Minimal '),
                                TextSpan(
                                  text: '100 Pcs',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('• ', style: TextStyle(color: Color(0xFF92400E))),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Total Luas: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: 'Minimal '),
                                TextSpan(
                                  text: '500 m²',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                TextSpan(text: ' (Panjang × Lebar × Qty)'),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Status Pesanan Saat Ini Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Pesanan Saat Ini:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jumlah Order',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '${_formatNumberDisplay(numQty)} Pcs ${isQtyQualify ? "(≥ 100 Pcs)" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isQtyQualify
                                ? const Color(0xFF15803D)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ukuran',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '$numPanjang m × ${numLebar.toInt()} cm',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Luas',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${totalLuasM2.toStringAsFixed(1)} m²',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isLuasQualify
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLuasQualify
                                  ? '(Memenuhi minimal 500 m²)'
                                  : '(Belum mencapai 500 m²)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isLuasQualify
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Beralih ke Cetak Machine
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _handleSelectSpandukMetode('MACHINE');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Beralih ke Cetak Machine',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpandukFinishingChecklist() {
    final options =
        (_masterOptions?['spandukTambahan'] as List<dynamic>?) ??
        [
          {'id': 1, 'nama': 'Obras'},
          {'id': 2, 'nama': 'Tali Samping'},
          {'id': 3, 'nama': 'Mata Ayam (Ring)'},
        ];

    return Wrap(
      spacing: 6,
      children: options.map((it) {
        final id = it['id'] is int
            ? it['id'] as int
            : int.tryParse(it['id'].toString()) ?? 0;
        final name = it['nama']?.toString() ?? '';
        final isChecked = _spandukFinishingIds.contains(id);

        return FilterChip(
          label: Text(
            name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          selected: isChecked,
          selectedColor: const Color(0xFFEEF2FF),
          checkmarkColor: const Color(0xFF4F46E5),
          onSelected: (val) {
            setState(() {
              if (val) {
                _spandukFinishingIds.add(id);
              } else {
                _spandukFinishingIds.remove(id);
              }

              // Sinkronkan pilihan finishing ke inputan Finishing (Tanpa Kalkulasi)
              final selectedNames = options
                  .where((item) {
                    final itemId = item['id'] is int
                        ? item['id'] as int
                        : int.tryParse(item['id'].toString()) ?? 0;
                    return _spandukFinishingIds.contains(itemId);
                  })
                  .map((item) => item['nama']?.toString() ?? '')
                  .where((n) => n.isNotEmpty)
                  .toList();
              _finishingController.text = selectedNames.join(', ');
            });
          },
        );
      }).toList(),
    );
  }

  List<String> get _availableMmtKategori {
    final rawMmt = _masterOptions?['mmt'] as List<dynamic>?;
    if (rawMmt != null && rawMmt.isNotEmpty) {
      final setKategori = <String>{};
      for (final m in rawMmt) {
        final kat = m['kategori']?.toString().trim();
        if (kat != null && kat.isNotEmpty) {
          setKategori.add(kat);
        }
      }
      if (setKategori.isNotEmpty) return setKategori.toList();
    }
    return ['VYNIL', 'HI-RES', 'STICKER'];
  }

  List<Map<String, dynamic>> get _availableMmtToppingOptions {
    final raw = _masterOptions?['topping'] as List<dynamic>?;
    if (raw != null) {
      return raw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) {
            final kode = (item['kode'] ?? '').toString().toUpperCase();
            final nama = (item['nama'] ?? '').toString().toUpperCase();
            final kat = (item['kategori'] ?? '').toString().toUpperCase();
            return !kode.contains('SELONGSONG') &&
                !nama.contains('SELONGSONG') &&
                !kat.contains('SELONGSONG');
          })
          .toList();
    }
    return [];
  }

  List<Map<String, String>> get _currentMmtBahanOptions {
    final rawMmt = _masterOptions?['mmt'] as List<dynamic>?;
    if (rawMmt != null && rawMmt.isNotEmpty) {
      final filtered = rawMmt
          .where((m) => m['kategori'] == _mmtKategori)
          .toList();
      if (filtered.isNotEmpty) {
        return filtered.map((m) {
          final kode = m['bahan_kode']?.toString() ?? '';
          final nama = m['nama_bahan']?.toString() ?? kode;
          return {'kode': kode, 'nama': nama};
        }).toList();
      }
    }
    if (_mmtKategori == 'VYNIL') {
      return [
        {'kode': '260', 'nama': 'Frontlite 260'},
        {'kode': '280', 'nama': 'Frontlite 280'},
        {'kode': '340', 'nama': 'Frontlite 340'},
        {'kode': '440', 'nama': 'Frontlite 440'},
        {'kode': 'KORCIN', 'nama': 'Frontlite Korcin'},
      ];
    } else if (_mmtKategori == 'HI-RES') {
      return [
        {'kode': '340', 'nama': 'Hi-Res 340'},
        {'kode': '440', 'nama': 'Hi-Res 440'},
        {'kode': 'KORCIN', 'nama': 'Hi-Res Korcin'},
        {'kode': 'BACKLITE', 'nama': 'Backlite'},
      ];
    }
    return [
      {'kode': 'GRAFTAC', 'nama': 'Sticker Graftac'},
      {'kode': 'RITRAMA', 'nama': 'Sticker Ritrama'},
      {'kode': 'ORAJET', 'nama': 'Sticker Orajet'},
      {'kode': 'TRANSPARAN', 'nama': 'Sticker Transparan'},
    ];
  }

  void _selectMmtKategori(String kat) {
    setState(() {
      _mmtKategori = kat;
      final options = _currentMmtBahanOptions;
      if (options.isNotEmpty) {
        _mmtBahanKode = options.first['kode'] ?? '';
      } else if (kat == 'VYNIL') {
        _mmtBahanKode = '260';
      } else if (kat == 'HI-RES') {
        _mmtBahanKode = '340';
      } else {
        _mmtBahanKode = 'GRAFTAC';
      }
    });
    _updateMmtKeteranganKalkulasi();
  }

  void _updateMmtKeteranganKalkulasi() {
    if (_selectedDivisi != '5') return;
    final nettoSpec = _mmtIsNetto
        ? (_mmtAlasanNettoController.text.trim().isNotEmpty
              ? ' (Netto - Alasan: ${_mmtAlasanNettoController.text.trim()})'
              : ' (Netto)')
        : '';
    String selText = '';
    if (_mmtSelongsongVert && _mmtSelongsongHoriz) {
      selText = ' + Plus Selongsong (V & H)';
    } else if (_mmtSelongsongVert) {
      selText = ' + Plus Selongsong Vertikal';
    } else if (_mmtSelongsongHoriz) {
      selText = ' + Plus Selongsong Horizontal';
    }
    String topText = '';
    if (_mmtToppingKode.isNotEmpty) {
      final toppingList = _availableMmtToppingOptions;
      final found = toppingList.firstWhere(
        (t) => t['kode']?.toString() == _mmtToppingKode,
        orElse: () => {'nama': _mmtToppingKode},
      );
      final tNama = found['nama']?.toString() ?? _mmtToppingKode;
      topText = ' + Top: $tNama';
    }
    final spec = 'MMT $_mmtKategori $_mmtBahanKode$nettoSpec$topText$selText';
    _keteranganKalkulasiController.text = _includePpn
        ? 'INC PPN; $spec'
        : 'EXC PPN; $spec';
  }

  List<Map<String, dynamic>> get _filteredSoHistory {
    if (_soSearchKeyword.trim().isEmpty) return _customerSoHistory;
    final q = _soSearchKeyword.toLowerCase().trim();
    return _customerSoHistory.where((so) {
      final no = (so['so_nomor'] ?? '').toString().toLowerCase();
      final item = (so['so_nama'] ?? so['nama_barang'] ?? '')
          .toString()
          .toLowerCase();
      return no.contains(q) || item.contains(q);
    }).toList();
  }

  void _showGarmenKainPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _garmenKainList.where((item) {
              final name =
                  (item['mhk_kain'] ?? item['Jeniskain'] ?? item['nama'] ?? '')
                      .toString();
              return search.isEmpty ||
                  name.toLowerCase().contains(search.toLowerCase());
            }).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih Jenis Kain Garmen',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setModalState(() => search = v),
                              style: const TextStyle(fontSize: 12.5),
                              decoration: const InputDecoration(
                                hintText: 'Cari jenis kain...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (search.isNotEmpty)
                            GestureDetector(
                              onTap: () => setModalState(() => search = ''),
                              child: const Icon(
                                Icons.cancel,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _garmenLoadingKain
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada jenis kain yang cocok',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (c, idx) {
                                final item = filtered[idx];
                                final name =
                                    (item['mhk_kain'] ??
                                            item['Jeniskain'] ??
                                            item['nama'] ??
                                            '')
                                        .toString();

                                return ListTile(
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onTap: () {
                                    final derivedKtg =
                                        _deriveGarmenKategoriKain(
                                          name,
                                          (item['mhk_ktg'] ??
                                                  item['Kategori'] ??
                                                  item['ktg'] ??
                                                  item['mhk_kategori'] ??
                                                  item['kategori'])
                                              ?.toString(),
                                        );
                                    setState(() {
                                      _garmenJenisKain = name;
                                      _praOrderKainWarning = null;
                                      _garmenKategoriKain = derivedKtg;
                                      final autoGramasi = getGramasiByKain(
                                        name,
                                      );
                                      if (autoGramasi.isNotEmpty &&
                                          _gramasiController.text.isEmpty) {
                                        _gramasiController.text = autoGramasi;
                                      }
                                    });
                                    _loadGarmenCetakOptions();
                                    _loadGarmenTambahanOptions();
                                    Navigator.pop(ctx);
                                    if (_currentStep == 2) {
                                      _executeHitungGarmen();
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showGarmenTambahanPickerModal() {
    final effectiveKtg = _deriveGarmenKategoriKain(
      _garmenJenisKain,
      _garmenKategoriKain,
    );
    if (_garmenKategoriKain != effectiveKtg) {
      _garmenKategoriKain = effectiveKtg;
      _loadGarmenTambahanOptions();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Tambahan Aksesoris',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Kategori: ${_garmenKategoriKain.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: _garmenTambahanMaster.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (c, idx) {
                    final item = _garmenTambahanMaster[idx];
                    final ket =
                        item['mha_ket'] ?? item['ket'] ?? item['nama'] ?? '';
                    final tarif = (item['mha_rp'] ?? item['tarif'] ?? 0) as num;
                    return ListTile(
                      title: Text(
                        ket,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text('Rp ${_formatNumberDisplay(tarif)}'),
                      onTap: () {
                        setState(() {
                          _garmenSelectedTambahan.add({
                            'ket': ket,
                            'tarif': tarif.toInt(),
                          });
                        });
                        Navigator.pop(ctx);
                        if (_currentStep == 2) {
                          _executeHitungGarmen();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGarmenCetakPickerModal() {
    if (_garmenCetakMaster.isEmpty) {
      _loadGarmenCetakOptions();
    }

    final isDesktopOrTablet = MediaQuery.of(context).size.width >= 600;

    if (isDesktopOrTablet) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: StatefulBuilder(
              builder: (modalCtx, setModalState) {
                return _buildGarmenCetakModalContent(
                  modalCtx,
                  setModalState,
                  isDialog: true,
                );
              },
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return _buildGarmenCetakModalContent(
              modalCtx,
              setModalState,
              isDialog: false,
            );
          },
        );
      },
    );
  }

  Widget _buildGarmenCetakModalContent(
    BuildContext ctx,
    StateSetter setModalState, {
    required bool isDialog,
  }) {
    final activeCategory = _garmenCetakActiveCategory;
    final sablonSubCategory = _garmenCetakSablonSubCategory;
    final searchQuery = _garmenCetakSearchQuery;

    final isDtfOrBordir = activeCategory == 'DTF' || activeCategory == 'BORDIR';

    // Master item untuk DTF / Bordir
    final masterItem = _garmenCetakMaster.firstWhere(
      (c) =>
          (c['mhb_jenis'] ?? c['jenis'] ?? '').toString().toUpperCase() ==
          activeCategory,
      orElse: () => <String, dynamic>{},
    );
    final defaultTarif =
        (masterItem['mhb_cm'] as num?)?.toDouble() ??
        (activeCategory == 'DTF' ? 25.0 : 90.0);
    final minTarif =
        (masterItem['mhb_min'] as num?)?.toDouble() ??
        (activeCategory == 'DTF' ? 1000.0 : 2500.0);

    // Perhitungan DTF / Bordir (Kunci paten dari database kencanaprint.tmintaharga_biaya)
    final pj = _toNumDecimal(_dtfBordirPanjangController.text);
    final lb = _toNumDecimal(_dtfBordirLebarController.text);
    final luas = pj * lb;

    final effectiveTarif = defaultTarif;
    final biayaMurni = luas * effectiveTarif;
    final isMinApplied = luas > 0 && biayaMurni < minTarif;
    final biayaPerPcs = luas > 0
        ? (isMinApplied ? minTarif : biayaMurni.roundToDouble())
        : 0.0;
    final qtyOrder = _toNumCurrency(_qtyController.text);
    final totalBiayaOrder = biayaPerPcs * qtyOrder;

    // List item untuk Sablon / Sublim
    final filteredList = _garmenCetakMaster.where((cItem) {
      final j = (cItem['mhb_jenis'] ?? cItem['jenis'] ?? '')
          .toString()
          .toUpperCase();
      if (j != activeCategory) return false;

      final ket = (cItem['mhb_ket'] ?? cItem['ket'] ?? cItem['nama'] ?? '')
          .toString()
          .toUpperCase();

      if (activeCategory == 'SABLON') {
        if (sablonSubCategory != 'ALL' && !ket.contains(sablonSubCategory)) {
          return false;
        }

        if (searchQuery.trim().isEmpty) {
          final curKtg = _garmenKategoriKain.toUpperCase();
          final isPe =
              curKtg.contains('PE') ||
              curKtg.contains('HYGIT') ||
              curKtg.contains('DRYFIT');
          final isLacost = curKtg.contains('LACOST');

          if (isPe) {
            if (!ket.endsWith(' PE')) {
              return false;
            }
          } else if (isLacost) {
            if (ket.endsWith(' PE') || ket.endsWith(' COTTON')) {
              return false;
            }
          } else {
            if (ket.endsWith(' PE') || ket.endsWith(' LACOST')) {
              return false;
            }
          }
        }
      }

      if (searchQuery.trim().isNotEmpty) {
        return ket.toLowerCase().contains(searchQuery.toLowerCase().trim());
      }

      return true;
    }).toList();

    final bodyWidget = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDialog
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: isDialog ? Border.all(color: const Color(0xFFE2E8F0)) : null,
        boxShadow: isDialog
            ? const [
                BoxShadow(
                  color: Color.fromRGBO(15, 23, 42, 0.18),
                  blurRadius: 32,
                  offset: Offset(0, 14),
                ),
              ]
            : null,
      ),
      constraints: BoxConstraints(
        maxHeight: isDialog ? 680 : MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambahan Cetak',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Category Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildCetakTabItem('Sablon', 'SABLON', activeCategory, (cat) {
                  setModalState(() => _garmenCetakActiveCategory = cat);
                }),
                _buildCetakTabItem('Sublim', 'SUBLIM', activeCategory, (cat) {
                  setModalState(() => _garmenCetakActiveCategory = cat);
                }),
                _buildCetakTabItem('DTF', 'DTF', activeCategory, (cat) {
                  setModalState(() => _garmenCetakActiveCategory = cat);
                }),
                _buildCetakTabItem('Bordir', 'BORDIR', activeCategory, (cat) {
                  setModalState(() => _garmenCetakActiveCategory = cat);
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // TAMPILAN 1: KALKULATOR UKURAN KHUSUS DTF & BORDIR
          if (isDtfOrBordir) ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Input Dimensi (Panjang x Lebar cm)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Panjang (cm) *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _dtfBordirPanjangController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [_decimalInputFormatter],
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  suffixText: 'cm',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lebar (cm) *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _dtfBordirLebarController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [_decimalInputFormatter],
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  suffixText: 'cm',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Ringkasan Estimasi Biaya DTF / Bordir
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Ukuran Desain:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              Text(
                                '${pj.toStringAsFixed(1)} x ${lb.toStringAsFixed(1)} cm',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Luas Desain:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              Text(
                                '${luas.toStringAsFixed(1)} cm²',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Biaya Satuan / Pcs:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Rp ${_formatNumberDisplay(biayaPerPcs.toInt())} /pcs',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                  if (isMinApplied) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(Min: Rp ${minTarif.toInt()})',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFB45309),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 12, color: Color(0xFFBFDBFE)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total ($qtyOrder pcs):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              Text(
                                'Rp ${_formatNumberDisplay(totalBiayaOrder.toInt())}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol Terapkan DTF / Bordir
                    ElevatedButton(
                      onPressed: biayaPerPcs <= 0
                          ? null
                          : () {
                              final label = '$activeCategory ${pj}x$lb cm';
                              setState(() {
                                _garmenSelectedCetak.add({
                                  'jenis': activeCategory,
                                  'ket': label,
                                  'biaya': biayaPerPcs.toInt(),
                                });
                              });
                              Navigator.pop(ctx);
                              if (_currentStep == 2) {
                                _executeHitungGarmen();
                              }
                              AppToast.success(
                                context,
                                '$label berhasil ditambahkan (+Rp ${_formatNumberDisplay(biayaPerPcs.toInt())}/pcs)',
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                      child: Text(
                        'Terapkan Ukuran & Biaya $activeCategory Ini',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // TAMPILAN 2: LIST SABLON / SUBLIM
            if (activeCategory == 'SABLON') ...[
              Row(
                children: [
                  _buildSubCategoryChip(
                    'Semua',
                    'ALL',
                    sablonSubCategory,
                    (s) =>
                        setModalState(() => _garmenCetakSablonSubCategory = s),
                  ),
                  const SizedBox(width: 6),
                  _buildSubCategoryChip(
                    'Medium',
                    'MEDIUM',
                    sablonSubCategory,
                    (s) =>
                        setModalState(() => _garmenCetakSablonSubCategory = s),
                  ),
                  const SizedBox(width: 6),
                  _buildSubCategoryChip(
                    'Rubber',
                    'RUBBER',
                    sablonSubCategory,
                    (s) =>
                        setModalState(() => _garmenCetakSablonSubCategory = s),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Search input
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          setModalState(() => _garmenCetakSearchQuery = v),
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Cari jenis / ukuran...',
                        hintStyle: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: filteredList.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada pilihan cetak yang cocok',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredList.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (c, idx) {
                        final item = filteredList[idx];
                        final jenis =
                            (item['mhb_jenis'] ??
                                    item['jenis'] ??
                                    activeCategory)
                                .toString()
                                .toUpperCase();
                        final ket =
                            (item['mhb_ket'] ??
                                    item['ket'] ??
                                    item['nama'] ??
                                    jenis)
                                .toString();
                        final biaya =
                            ((item['mhb_rp'] ??
                                        item['mhb_biaya'] ??
                                        item['biaya'] ??
                                        0)
                                    as num)
                                .toInt();
                        final desc = getSablonUkuranDesc(ket);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          title: Text(
                            ket,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: desc.isNotEmpty
                              ? Text(
                                  desc,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                )
                              : null,
                          trailing: Text(
                            'Rp ${_formatNumberDisplay(biaya)} /pcs',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _garmenSelectedCetak.add({
                                'jenis': jenis,
                                'ket': ket,
                                'biaya': biaya,
                              });
                            });
                            Navigator.pop(ctx);
                            if (_currentStep == 2) {
                              _executeHitungGarmen();
                            }
                            AppToast.success(
                              context,
                              '$ket ditambahkan (+Rp ${_formatNumberDisplay(biaya)}/pcs)',
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );

    return isDialog ? bodyWidget : SafeArea(child: bodyWidget);
  }

  static Widget _buildCetakTabItem(
    String label,
    String key,
    String active,
    ValueChanged<String> onTap,
  ) {
    final isSelected = active == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildSubCategoryChip(
    String label,
    String key,
    String active,
    ValueChanged<String> onTap,
  ) {
    final isSelected = active == key;
    return GestureDetector(
      onTap: () => onTap(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFC4B5FD)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF6D28D9)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _showKetentuanOngkirModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Drag Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Color(0xFF0284C7),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Ketentuan Ongkos Kirim',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Panduan konversi bobot, minimal kirim & tarif',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seksi 1: Rasio Berat
                      _buildOngkirCard(
                        title: '1. Rasio Konversi Berat Pesanan',
                        icon: Icons.scale_rounded,
                        accentColor: const Color(0xFF4F46E5),
                        bgColor: const Color(0xFFF8FAFC),
                        borderColor: const Color(0xFFE2E8F0),
                        child: Column(
                          children: [
                            _buildKonversiRow(
                              divisi: 'SPANDUK',
                              tagColor: const Color(0xFFEEF2FF),
                              tagTextColor: const Color(0xFF4F46E5),
                              rumus: '10 meter = 1 kg',
                              unitKet: '0.1 kg / meter',
                            ),
                            const Divider(height: 12, color: Color(0xFFE2E8F0)),
                            _buildKonversiRow(
                              divisi: 'MMT',
                              tagColor: const Color(0xFFE0F2FE),
                              tagTextColor: const Color(0xFF0284C7),
                              rumus: '2 m² = 1 kg',
                              unitKet: '0.5 kg / m²',
                            ),
                            const Divider(height: 12, color: Color(0xFFE2E8F0)),
                            _buildKonversiRow(
                              divisi: 'GARMEN MEDIUM',
                              tagColor: const Color(0xFFF5F3FF),
                              tagTextColor: const Color(0xFF7C3AED),
                              rumus: '5 pcs = 1 kg',
                              unitKet: '0.2 kg / pcs',
                            ),
                            const Divider(height: 12, color: Color(0xFFE2E8F0)),
                            _buildKonversiRow(
                              divisi: 'GARMEN PREMIUM',
                              tagColor: const Color(0xFFFEF3C7),
                              tagTextColor: const Color(0xFFB45309),
                              rumus: '3 pcs = 1 kg',
                              unitKet: '0.33 kg / pcs',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Seksi 2: Aturan Minimal
                      _buildOngkirCard(
                        title: '2. Aturan Minimum Berat Kirim',
                        icon: Icons.inventory_2_rounded,
                        accentColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFF8FAFC),
                        borderColor: const Color(0xFFE2E8F0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFBAE6FD),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Pulau Jawa',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Min 20 Kg',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Order < 20 kg dihitung 20 kg',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Luar Jawa',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Min 40 Kg',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Sumatra, Bali, Sulawesi, dll',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Seksi 3: Syarat Gratis Ongkir
                      _buildOngkirCard(
                        title: '3. Syarat Bebas Ongkir',
                        icon: Icons.verified_rounded,
                        accentColor: const Color(0xFF15803D),
                        bgColor: const Color(0xFFF0FDF4),
                        borderColor: const Color(0xFFBBF7D0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFBBF7D0),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Icon(
                                    Icons.place_rounded,
                                    size: 15,
                                    color: Color(0xFF16A34A),
                                  ),
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Kota Utama: Jakarta (Jabodetabek), Bandung, Yogya, Sidoarjo, Surabaya, Solo Raya.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildSyaratFreePill('Spanduk', '≥ 1.000 M'),
                                const SizedBox(width: 6),
                                _buildSyaratFreePill('MMT', '≥ 500 m²'),
                                const SizedBox(width: 6),
                                _buildSyaratFreePill('Garmen', '≥ 300 Pcs'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Seksi 4: Tarif Daerah Berbayar
                      _buildOngkirCard(
                        title: '4. Tarif Kirim Pulau di Indonesia',
                        icon: Icons.map_rounded,
                        accentColor: const Color(0xFF334155),
                        bgColor: const Color(0xFFF8FAFC),
                        borderColor: const Color(0xFFE2E8F0),
                        child: Column(
                          children: [
                            _buildTarifRow(
                              'Jawa Lainnya',
                              'Rp 5.000 /kg',
                              'Min 20 kg',
                            ),
                            const Divider(height: 10, color: Color(0xFFE2E8F0)),
                            _buildTarifRow('Bali', 'Rp 8.000 /kg', 'Min 40 kg'),
                            const Divider(height: 10, color: Color(0xFFE2E8F0)),
                            _buildTarifRow(
                              'Sumatra',
                              'Rp 10.000 /kg',
                              'Min 40 kg',
                            ),
                            const Divider(height: 10, color: Color(0xFFE2E8F0)),
                            _buildTarifRow(
                              'Sulawesi',
                              'Rp 10.000 /kg',
                              'Min 40 kg',
                            ),
                            const Divider(height: 10, color: Color(0xFFE2E8F0)),
                            _buildTarifRow(
                              'Nusa Tenggara',
                              'Rp 10.000 /kg',
                              'Min 40 kg',
                            ),
                            const Divider(height: 10, color: Color(0xFFE2E8F0)),
                            _buildTarifRow(
                              'Kalimantan',
                              'Rp 15.000 /kg',
                              'Min 40 kg',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Tombol Tutup
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildOngkirCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accentColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  static Widget _buildKonversiRow({
    required String divisi,
    required Color tagColor,
    required Color tagTextColor,
    required String rumus,
    required String unitKet,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                divisi,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: tagTextColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              rumus,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            unitKet,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildSyaratFreePill(String nama, String target) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          children: [
            Text(
              nama,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF166534),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              target,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildTarifRow(String daerah, String tarif, String min) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          daerah,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        Row(
          children: [
            Text(
              tarif,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                min,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double fontSize = 12.5,
    double? letterSpacing = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: true,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                color: valueColor ?? const Color(0xFF0F172A),
                letterSpacing: letterSpacing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PraOrderPickerSheet extends ConsumerStatefulWidget {
  final Future<void> Function(Map<String, dynamic> item) onSelect;

  const _PraOrderPickerSheet({required this.onSelect});

  @override
  ConsumerState<_PraOrderPickerSheet> createState() =>
      _PraOrderPickerSheetState();
}

class _PraOrderPickerSheetState extends ConsumerState<_PraOrderPickerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _list = [];
  bool _isLoading = true;
  bool _fetchingDetail = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchList('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchList(String keyword) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(permintaanHargaRepositoryProvider);
      final res = await repo.getPraOrderList(keyword);
      if (mounted) {
        setState(() {
          _list = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _list = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchList(val.trim());
    });
  }

  String _formatDateOrderDisplay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        return DateFormat('dd-MM-yyyy').format(parsed);
      }
      final clean = dateStr.split('T')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  String _formatThousands(num value) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Modal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.playlist_add_check_rounded,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Pilih Pra Order',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'Ketik nomor, customer, atau pekerjaan...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: const Icon(
                              Icons.cancel_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // List Pra Order / Loading / Empty
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Memuat data pra order...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _list.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: Color(0xFFCBD5E1),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Pra Order Tidak Ditemukan',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            bottomInset + 16,
                          ),
                          itemCount: _list.length,
                          itemBuilder: (context, index) {
                            final item = _list[index];
                            return _buildPraOrderItemCard(item);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Overlay Loading saat menerapkan detail
        if (_fetchingDetail)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Menerapkan Data Pra Order...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPraOrderItemCard(Map<String, dynamic> item) {
    final no =
        item['nomor']?.toString() ?? item['pro_nomor']?.toString() ?? '-';
    final divisi = item['divisi']?.toString() ?? '1';
    final divisiNama =
        item['divisiNama']?.toString() ??
        (divisi == '4' ? 'GARMEN' : (divisi == '5' ? 'MMT' : 'SPANDUK'));
    final tanggal = _formatDateOrderDisplay(
      item['tanggal']?.toString() ?? item['pro_tanggal']?.toString(),
    );
    final namaPekerjaan =
        item['namaPekerjaan']?.toString() ??
        item['nama_pekerjaan']?.toString() ??
        '-';
    final cusNama =
        item['cusNama']?.toString() ?? item['cus_nama']?.toString() ?? '-';
    final qty =
        (item['qtyRencana'] as num?)?.toDouble() ??
        (item['rencanaOrder'] as num?)?.toDouble() ??
        (item['pro_qty_rencana'] as num?)?.toDouble() ??
        0;
    final sudahDipakaiOleh =
        item['sudahDipakaiOleh']?.toString() ??
        item['pro_mh_nomor']?.toString();

    Color divBgColor;
    Color divTextColor;
    if (divisi == '4') {
      divBgColor = const Color(0xFFFEF3C7);
      divTextColor = const Color(0xFFB45309);
    } else if (divisi == '5') {
      divBgColor = const Color(0xFFEDE9FE);
      divTextColor = const Color(0xFF6D28D9);
    } else {
      divBgColor = const Color(0xFFDCFCE7);
      divTextColor = const Color(0xFF15803D);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            setState(() => _fetchingDetail = true);
            try {
              await widget.onSelect(item);
              if (mounted) Navigator.pop(context);
            } finally {
              if (mounted) setState(() => _fetchingDetail = false);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        no,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: divBgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        divisiNama,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: divTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        tanggal,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Nama Pekerjaan
                Text(
                  namaPekerjaan,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),

                // Customer Row
                Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        cusNama,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Qty Text
                Text(
                  qty > 0
                      ? 'Rencana Order: ${_formatThousands(qty)} pcs'
                      : 'Rencana Order: -',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),

                // Badge Sudah Terpakai (jika ada)
                if (sudahDipakaiOleh != null &&
                    sudahDipakaiOleh.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 13,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sudah terpakai pada $sudahDipakaiOleh',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
