import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../models/penawaran_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/penawaran_repository.dart';
import '../../widgets/customer_picker_modal.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class DraftDetailItem {
  final TextEditingController namaBarangController;
  final TextEditingController bahanController;
  final TextEditingController ukuranController;
  final TextEditingController panjangController;
  final TextEditingController lebarController;
  final TextEditingController qtyController;
  final TextEditingController hargaController;

  String noPermintaan = '';
  String nomorKalkulasi = '';
  bool isIncludePpn = false;

  DraftDetailItem()
      : namaBarangController = TextEditingController(),
        bahanController = TextEditingController(),
        ukuranController = TextEditingController(),
        panjangController = TextEditingController(),
        lebarController = TextEditingController(),
        qtyController = TextEditingController(),
        hargaController = TextEditingController();

  double get total {
    final q = double.tryParse(qtyController.text.trim()) ?? 0.0;
    final h = double.tryParse(
            hargaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0.0;
    return q * h;
  }

  void dispose() {
    namaBarangController.dispose();
    bahanController.dispose();
    ukuranController.dispose();
    panjangController.dispose();
    lebarController.dispose();
    qtyController.dispose();
    hargaController.dispose();
  }
}

class PenawaranCreateScreen extends ConsumerStatefulWidget {
  final PenawaranDetailData? initialDetail;

  const PenawaranCreateScreen({super.key, this.initialDetail});

  @override
  ConsumerState<PenawaranCreateScreen> createState() =>
      _PenawaranCreateScreenState();
}

class _PenawaranCreateScreenState extends ConsumerState<PenawaranCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialDetail != null;

  DateTime _selectedDate = DateTime.now();
  String? _selectedDivisi;
  String? _selectedTipe;
  String? _selectedPerusahaanKode;

  CustomerModel? _selectedCustomer;
  bool _isCustomerLockedByPermintaan = false;

  String _selectedSalesKode = '';
  String _selectedSalesNama = '';

  final _upController = TextEditingController();
  final _ttdController = TextEditingController();
  final _ttdJabatanController = TextEditingController();
  final _keteranganController = TextEditingController();
  final _noteController = TextEditingController();
  final _berlakuHariController = TextEditingController();

  int _statusHarga = 0; // 0 = Exclude PPN, 1 = Include PPN

  final List<DraftDetailItem> _items = [];
  bool _isLoading = false;

  static const _kPerusahaanTtdMap = {
    'KP': {
      'nama': 'CV. KENCANA PRINT',
      'ttd': 'Tri Yuliani, S.I.Kom',
      'jabatan': 'Supervisor Office Marketing',
    },
    'JA': {
      'nama': 'PT. JAYA ABADI MULIA',
      'ttd': 'Widi Hariyanto',
      'jabatan': 'Manager Marketing',
    },
    'MD': {
      'nama': 'PT. MADANI PRODUCTION',
      'ttd': 'Ariyani Trikusumastuti, S.E.',
      'jabatan': 'Chief Marketing Officer',
    },
  };

  final List<Map<String, String>> _divisiOptions = const [
    {'kode': '1', 'label': '1 - SPANDUK'},
    {'kode': '4', 'label': '4 - GARMEN'},
    {'kode': '5', 'label': '5 - MMT'},
  ];

  final List<String> _tipeOptions = const ['Medium', 'Premium'];

  final List<Map<String, String>> _perusahaanOptions = const [
    {'kode': 'KP', 'label': 'CV. KENCANA PRINT'},
    {'kode': 'JA', 'label': 'PT. JAYA ABADI MULIA'},
    {'kode': 'MD', 'label': 'PT. MADANI PRODUCTION'},
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    final initial = widget.initialDetail;

    if (initial != null && initial.header != null) {
      final h = initial.header!;
      try {
        if (h.tanggal.isNotEmpty) {
          final clean = h.tanggal.split('T')[0].split(' ')[0];
          _selectedDate = DateTime.tryParse(clean) ?? DateTime.now();
        }
      } catch (_) {
        _selectedDate = DateTime.now();
      }

      _selectedDivisi = h.divisi.isNotEmpty ? h.divisi : null;
      _selectedTipe = h.tipe.isNotEmpty ? h.tipe : null;
      _selectedPerusahaanKode =
          h.perusahaanKode.isNotEmpty ? h.perusahaanKode : null;

      if (h.customerKode.isNotEmpty || h.customer.isNotEmpty) {
        _selectedCustomer = CustomerModel(
          kode: h.customerKode,
          nama: h.customer,
          alamat: h.customerAlamat,
          kota: h.customerKota,
        );
      }

      _selectedSalesKode = h.salesKode.isNotEmpty
          ? h.salesKode
          : (user?.salesKode ?? user?.kode ?? '');
      _selectedSalesNama =
          h.sales.isNotEmpty ? h.sales : (user?.nama ?? '');

      _upController.text = h.up;
      _ttdController.text = h.ttd;
      _ttdJabatanController.text = h.ttdJabatan;
      _keteranganController.text = h.keterangan;
      _noteController.text = h.note;
      _statusHarga = h.statusHarga;

      if (initial.details.isNotEmpty) {
        for (final d in initial.details) {
          final it = DraftDetailItem();
          it.namaBarangController.text = d.namaBarang;
          it.bahanController.text = d.bahan;
          it.ukuranController.text = d.ukuran;
          it.panjangController.text =
              d.panjang > 0 ? d.panjang.toString() : '';
          it.lebarController.text = d.lebar > 0 ? d.lebar.toString() : '';
          it.qtyController.text =
              d.qty > 0 ? (d.qty == d.qty.roundToDouble() ? d.qty.toInt().toString() : d.qty.toString()) : '1';
          it.hargaController.text =
              d.harga > 0 ? d.harga.toInt().toString() : '0';
          it.noPermintaan = d.minta;
          _items.add(it);
        }
      } else {
        _items.add(DraftDetailItem());
      }
    } else {
      _selectedSalesKode = user?.salesKode ?? user?.kode ?? '';
      _selectedSalesNama = user?.nama ?? '';
      _items.add(DraftDetailItem());
    }
  }

  static String _formatTanggalIndonesia(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _applyPerusahaanTtd(String pKode) {
    final mapping = _kPerusahaanTtdMap[pKode];
    if (mapping != null) {
      _ttdController.text = mapping['ttd'] ?? '';
      _ttdJabatanController.text = mapping['jabatan'] ?? '';
    }
  }

  @override
  void dispose() {
    _upController.dispose();
    _ttdController.dispose();
    _ttdJabatanController.dispose();
    _keteranganController.dispose();
    _noteController.dispose();
    _berlakuHariController.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  void _addItemRow() {
    setState(() {
      _items.add(DraftDetailItem());
    });
  }

  void _removeItemRow(int index) {
    if (_items.length <= 1) {
      AppToast.warning(context, 'Minimal harus ada 1 item barang');
      return;
    }
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  void _updateBerlakuHari(String hariInput) {
    final cleanDigits = hariInput.replaceAll(RegExp(r'[^0-9]'), '');
    _berlakuHariController.value = TextEditingValue(
      text: cleanDigits,
      selection: TextSelection.collapsed(offset: cleanDigits.length),
    );

    final regex = RegExp(r'surat penawaran berlaku\s+\d*\s*hari', caseSensitive: false);
    final curNote = _noteController.text;

    if (cleanDigits.isEmpty) {
      _noteController.text = curNote.replaceAll(regex, '').trim();
    } else {
      final newSentence = 'Surat penawaran berlaku $cleanDigits hari';
      if (regex.hasMatch(curNote)) {
        _noteController.text = curNote.replaceAll(regex, newSentence);
      } else if (curNote.trim().isEmpty) {
        _noteController.text = newSentence;
      } else {
        _noteController.text = '$newSentence\n${curNote.trim()}';
      }
    }
  }

  void _handleNoteChange(String text) {
    final match = RegExp(r'surat penawaran berlaku\s+(\d+)\s+hari', caseSensitive: false).firstMatch(text);
    final parsedHari = match != null ? match.group(1) ?? '' : '';
    if (parsedHari != _berlakuHariController.text) {
      _berlakuHariController.text = parsedHari;
    }
  }

  Future<void> _selectCustomer() async {
    if (_isCustomerLockedByPermintaan) {
      AppToast.warning(
        context,
        'Customer terkunci karena rincian diambil dari No. Permintaan. Gunakan tombol Reset Detail jika ingin mengganti customer.',
      );
      return;
    }
    final selected = await showCustomerPickerModal(context);
    if (selected != null && mounted) {
      setState(() => _selectedCustomer = selected);
    }
  }

  void _resetDetailAndUnlockCustomer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Detail Barang?'),
        content: const Text(
          'Semua rincian barang akan dikosongkan dan kunci Customer akan dibuka kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                for (final it in _items) {
                  it.dispose();
                }
                _items.clear();
                _addItemRow();
                _isCustomerLockedByPermintaan = false;
                _selectedCustomer = null;
              });
              AppToast.success(context, 'Detail barang berhasil direset');
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermintaanHargaPicker(int rowIndex) async {
    final targetSalesKode = _selectedSalesKode.trim();
    if (targetSalesKode.isEmpty) {
      AppToast.warning(context, 'Sales belum dipilih');
      return;
    }

    final repo = ref.read(penawaranRepositoryProvider);
    String searchKeyword = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih No. Permintaan (DONE)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setModalState(() => searchKeyword = val);
                            },
                            decoration: const InputDecoration(
                              hintText: 'Cari nomor, item, customer...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: repo.getMasterPermintaanHargaForPenawaran(
                        salesKode: targetSalesKode,
                        customerKode: _selectedCustomer?.kode,
                        search: searchKeyword,
                        limit: 30,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                          );
                        }
                        final options = snapshot.data?['options'] as List<Map<String, dynamic>>? ?? [];
                        if (options.isEmpty) {
                          return const Center(
                            child: Text(
                              'Tidak ada permintaan harga DONE yang belum terpakai.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: options.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, idx) {
                            final item = options[idx];
                            final nomor = item['nomor']?.toString() ?? '-';
                            final customer = item['customer']?.toString() ?? '-';
                            final customerKode = item['customer_kode']?.toString() ?? '';
                            final namaBarang = item['nama_barang']?.toString() ?? '-';
                            final bahan = item['bahan']?.toString() ?? '';
                            final ukuran = item['ukuran']?.toString() ?? '';
                            final panjang = item['panjang']?.toString() ?? '0';
                            final lebar = item['lebar']?.toString() ?? '0';
                            final qty = item['qty']?.toString() ?? '1';
                            final hrgRef = double.tryParse(item['harga_referensi']?.toString() ?? '0') ?? 0.0;
                            final isIncPpn = item['is_include_ppn'] == 1 || item['is_include_ppn'] == true;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    nomor,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                  Text(
                                    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(hrgRef),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    customer,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  Text(
                                    '$namaBarang ${bahan.isNotEmpty ? '• $bahan' : ''}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                final target = _items[rowIndex];
                                setState(() {
                                  target.noPermintaan = nomor;
                                  target.namaBarangController.text = namaBarang;
                                  target.bahanController.text = bahan;
                                  target.ukuranController.text = ukuran;
                                  target.panjangController.text = panjang;
                                  target.lebarController.text = lebar;
                                  target.qtyController.text = qty;
                                  target.hargaController.text = hrgRef.toInt().toString();
                                  target.nomorKalkulasi = item['nomor_kalkulasi']?.toString() ?? '';
                                  target.isIncludePpn = isIncPpn;

                                  // Otomatis sinkronkan PPN dan Kunci Customer
                                  _statusHarga = isIncPpn ? 1 : 0;
                                  if (_selectedCustomer == null || _selectedCustomer!.kode != customerKode) {
                                    _selectedCustomer = CustomerModel(
                                      kode: customerKode,
                                      nama: customer,
                                      alamat: '',
                                      kota: '',
                                    );
                                  }
                                  _isCustomerLockedByPermintaan = true;

                                  final pickedDivisi = item['divisi']?.toString() ?? '';
                                  if (pickedDivisi.isNotEmpty &&
                                      _divisiOptions.any((opt) => opt['kode'] == pickedDivisi)) {
                                    _selectedDivisi = pickedDivisi;
                                  }
                                });
                                AppToast.success(context, 'Rincian no. $nomor berhasil dimuat');
                              },
                            );
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
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedPerusahaanKode == null || _selectedPerusahaanKode!.isEmpty) {
      AppToast.error(context, 'Perusahaan wajib dipilih');
      return;
    }

    if (_selectedDivisi == null || _selectedDivisi!.isEmpty) {
      AppToast.error(context, 'Divisi wajib dipilih');
      return;
    }

    if (_selectedTipe == null || _selectedTipe!.isEmpty) {
      AppToast.error(context, 'Tipe penawaran wajib dipilih');
      return;
    }

    if (_selectedCustomer == null) {
      AppToast.error(context, 'Customer wajib dipilih terlebih dahulu');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    for (int i = 0; i < _items.length; i++) {
      if (_items[i].namaBarangController.text.trim().isEmpty) {
        AppToast.error(context, 'Nama barang pada baris ke-${i + 1} wajib diisi');
        return;
      }
      final qty = double.tryParse(_items[i].qtyController.text) ?? 0;
      if (qty <= 0) {
        AppToast.error(context, 'Qty pada baris ke-${i + 1} harus lebih dari 0');
        return;
      }
    }

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(penawaranRepositoryProvider);
    final ymdFormat = DateFormat('yyyy-MM-dd');

    final detailsPayload = _items.map((it) {
      final q = double.tryParse(it.qtyController.text) ?? 1.0;
      final h = double.tryParse(it.hargaController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
      final p = double.tryParse(it.panjangController.text) ?? 0.0;
      final l = double.tryParse(it.lebarController.text) ?? 0.0;

      return {
        'nama_barang': it.namaBarangController.text.trim().toUpperCase(),
        'bahan': it.bahanController.text.trim().toUpperCase(),
        'ukuran': it.ukuranController.text.trim(),
        'panjang': p,
        'lebar': l,
        'satuan': 'PCS',
        'qty': q,
        'harga': h,
        'minta': it.noPermintaan.trim(),
      };
    }).toList();

    final payload = {
      'tanggal': ymdFormat.format(_selectedDate),
      'divisi': _selectedDivisi,
      'tipe': _selectedTipe,
      'perusahaan_kode': _selectedPerusahaanKode,
      'customer_kode': _selectedCustomer!.kode,
      'customer': _selectedCustomer!.nama,
      'sales_kode': _selectedSalesKode.isNotEmpty
          ? _selectedSalesKode
          : (user?.salesKode ?? user?.kode ?? ''),
      'sales': _selectedSalesNama.isNotEmpty ? _selectedSalesNama : (user?.nama ?? ''),
      'up': _upController.text.trim(),
      'ttd': _ttdController.text.trim(),
      'ttd_jabatan': _ttdJabatanController.text.trim(),
      'keterangan': _keteranganController.text.trim(),
      'note': _noteController.text.trim(),
      'status_harga': _statusHarga,
      'details': detailsPayload,
    };

    if (_isEditMode) {
      final targetNomor = widget.initialDetail!.header!.nomor;
      final result = await repo.updatePenawaran(targetNomor, payload);

      if (mounted) {
        setState(() => _isLoading = false);

        if (result.success) {
          AppToast.success(context, result.message);
          context.pop(true);
        } else {
          AppToast.error(context, result.message);
        }
      }
      return;
    }

    final resultNomor = await repo.createPenawaran(payload);

    if (mounted) {
      setState(() => _isLoading = false);

      if (resultNomor != null) {
        AppToast.success(context, 'Surat penawaran $resultNomor berhasil dibuat');
        context.pushReplacement('/penawaran/$resultNomor');
      } else {
        AppToast.error(context, 'Gagal membuat surat penawaran harga');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final grandTotal = _items.fold<double>(0.0, (acc, curr) => acc + curr.total);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditMode ? 'Edit Surat Penawaran' : 'Buat Surat Penawaran',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            if (_isEditMode && (widget.initialDetail?.header?.nomor.isNotEmpty ?? false))
              Text(
                'No: ${widget.initialDetail!.header!.nomor}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF4F46E5)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/penawaran');
            }
          },
        ),
        actions: [
          if (_isCustomerLockedByPermintaan)
            TextButton.icon(
              onPressed: _resetDetailAndUnlockCustomer,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFDC2626)),
              label: const Text(
                'Reset Detail',
                style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color.fromRGBO(15, 23, 42, 0.08))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL PENAWARAN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      currencyFormat.format(grandTotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              AppButton(
                text: _isEditMode ? 'Simpan Perubahan' : 'Simpan Penawaran',
                onPressed: _submit,
                isLoading: _isLoading,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveHelper.horizontalPadding(context),
            vertical: 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveHelper.formWidth(context),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // CARD INFORMASI UTAMA
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INFORMASI DOKUMEN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Tanggal Dokumen Penawaran
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tanggal Penawaran *',
                              suffixIcon: Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            child: Text(
                              _formatTanggalIndonesia(_selectedDate),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Perusahaan Penerbit Dokumen
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPerusahaanKode,
                          hint: const Text('Pilih Perusahaan...'),
                          decoration: const InputDecoration(labelText: 'Perusahaan *'),
                          items: _perusahaanOptions
                              .map((p) => DropdownMenuItem(value: p['kode'], child: Text(p['label']!)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedPerusahaanKode = v;
                              if (v != null) {
                                _applyPerusahaanTtd(v);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Divisi & Tipe
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedDivisi,
                                hint: const Text('Pilih Divisi...'),
                                decoration: const InputDecoration(labelText: 'Divisi *'),
                                items: _divisiOptions
                                    .map((d) => DropdownMenuItem(value: d['kode'], child: Text(d['label']!)))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() => _selectedDivisi = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedTipe,
                                hint: const Text('Pilih Tipe...'),
                                decoration: const InputDecoration(labelText: 'Tipe *'),
                                items: _tipeOptions
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() => _selectedTipe = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Customer Picker
                        InkWell(
                          onTap: _selectCustomer,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Customer *',
                              suffixIcon: Icon(
                                _isCustomerLockedByPermintaan ? Icons.lock_outline_rounded : Icons.search,
                                size: 18,
                                color: _isCustomerLockedByPermintaan
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF4F46E5),
                              ),
                            ),
                            child: Text(
                              _selectedCustomer?.nama ?? 'Pilih Customer...',
                              style: TextStyle(
                                color: _selectedCustomer != null
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF94A3B8),
                                fontWeight: _selectedCustomer != null ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        if (_isCustomerLockedByPermintaan)
                          const Padding(
                            padding: EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              'Customer dikunci sesuai referensi No. Permintaan Harga',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(height: 12),

                        // UP
                        TextFormField(
                          controller: _upController,
                          decoration: const InputDecoration(
                            labelText: 'Up. (Nama PIC)',
                            hintText: 'Up (contoh: Bpk. Bambang)',
                          ),
                        ),
                        const SizedBox(height: 12),

                        // TTD & Jabatan TTD
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ttdController,
                                decoration: const InputDecoration(
                                  labelText: 'Tanda Tangan *',
                                  hintText: 'Tanda Tangan',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _ttdJabatanController,
                                decoration: const InputDecoration(
                                  labelText: 'Jabatan Tanda Tangan',
                                  hintText: 'Jabatan Tanda Tangan',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Switch Status PPN (11%)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Status PPN',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    _statusHarga == 1 ? 'Harga sudah termasuk PPN 11%' : 'Harga belum termasuk PPN',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _statusHarga == 1,
                                activeThumbColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(() => _statusHarga = v ? 1 : 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Masa Berlaku Hari & Catatan
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _berlakuHariController,
                                keyboardType: TextInputType.number,
                                onChanged: _updateBerlakuHari,
                                decoration: const InputDecoration(
                                  labelText: 'Berlaku (Hari)',
                                  hintText: '14',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _keteranganController,
                                decoration: const InputDecoration(
                                  labelText: 'Keterangan',
                                  hintText: 'Keterangan',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Note Field
                        TextFormField(
                          controller: _noteController,
                          maxLines: 2,
                          onChanged: _handleNoteChange,
                          decoration: const InputDecoration(
                            labelText: 'Catatan Dokumen (Note)',
                            hintText: 'Surat penawaran berlaku ... hari',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // RINCIAN BARANG
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'RINCIAN BARANG',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addItemRow,
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF4F46E5)),
                        label: const Text(
                          'Tambah Baris',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final it = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Barang #${idx + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Row(
                                  children: [
                                    // Tombol Ambil dari No Permintaan Harga
                                    GestureDetector(
                                      onTap: () => _showPermintaanHargaPicker(idx),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: it.noPermintaan.isNotEmpty
                                              ? const Color(0xFFECFDF5)
                                              : const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: it.noPermintaan.isNotEmpty
                                                ? const Color(0xFFA7F3D0)
                                                : const Color(0xFFC7D2FE),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.link_rounded,
                                              size: 14,
                                              color: it.noPermintaan.isNotEmpty
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF4F46E5),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              it.noPermintaan.isNotEmpty ? it.noPermintaan : 'Pilih No. Minta',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: it.noPermintaan.isNotEmpty
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFF4F46E5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                      onPressed: () => _removeItemRow(idx),
                                      tooltip: 'Hapus Item',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 16),

                            // Nama Barang
                            TextFormField(
                              controller: it.namaBarangController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Barang *',
                                hintText: 'Nama Barang...',
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Bahan & Ukuran
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: it.bahanController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bahan',
                                      hintText: 'Bahan...',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: it.ukuranController,
                                    decoration: const InputDecoration(
                                      labelText: 'Ukuran',
                                      hintText: 'Contoh: L=40, XL=10',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Panjang & Lebar
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: it.panjangController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Panjang (M)',
                                      hintText: '0.00',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: it.lebarController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Lebar (M)',
                                      hintText: '0.00',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Qty & Harga
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: it.qtyController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Qty (Pcs) *',
                                      hintText: '0',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: it.hargaController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Harga Satuan (Rp) *',
                                      hintText: '0',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
