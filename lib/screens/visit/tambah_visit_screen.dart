import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/image_compress_helper.dart';
import '../../core/utils/location_helper.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/visit_repository.dart';
import '../../widgets/customer_picker_modal.dart';

class TambahVisitScreen extends ConsumerStatefulWidget {
  final CustomerModel? initialCustomer;
  final String? initialDate;

  const TambahVisitScreen({
    super.key,
    this.initialCustomer,
    this.initialDate,
  });

  @override
  ConsumerState<TambahVisitScreen> createState() => _TambahVisitScreenState();
}

class _TambahVisitScreenState extends ConsumerState<TambahVisitScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  CustomerModel? _selectedCustomer;
  final _noteController = TextEditingController();
  final _catatanController = TextEditingController();

  double? _latitude;
  double? _longitude;
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isGettingGps = false;

  Uint8List? _imageBytes;
  String? _imageName;
  int? _imageSizeBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  int? _existingVisitId;
  bool _isCheckingDraft = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomer != null) {
      _selectedCustomer = widget.initialCustomer;
    }
    if (widget.initialDate != null && widget.initialDate!.isNotEmpty) {
      try {
        _selectedDate = DateFormat('yyyy-MM-dd').parse(widget.initialDate!);
      } catch (_) {}
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedCustomer != null) {
        _checkAndLoadExistingVisit();
      }
    });
  }

  Future<void> _checkAndLoadExistingVisit() async {
    if (_selectedCustomer == null) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final ymd = DateFormat('yyyy-MM-dd').format(_selectedDate);
    setState(() => _isCheckingDraft = true);

    try {
      final repo = ref.read(visitRepositoryProvider);
      final found = await repo.findExistingVisitOrDraft(
        user: user.nama,
        cusKode: _selectedCustomer!.kode,
        tanggal: ymd,
      );

      if (found != null && mounted) {
        setState(() {
          _existingVisitId = (found['id'] is int)
              ? found['id']
              : int.tryParse(found['id'].toString());
          if (_noteController.text.trim().isEmpty &&
              (found['note'] ?? '').toString().isNotEmpty) {
            _noteController.text = found['note'].toString();
          }
          if (_catatanController.text.trim().isEmpty &&
              (found['catatan'] ?? '').toString().isNotEmpty) {
            _catatanController.text = found['catatan'].toString();
          }
        });

        final tipe =
            found['status'] == 'DONE' ? 'Laporan Kunjungan' : 'Visit Plan';
        AppToast.info(context, '$tipe ditemukan, formulir terisi otomatis.');
      }
    } finally {
      if (mounted) setState(() => _isCheckingDraft = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _catatanController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _isGettingGps = true);
    final pos = await LocationHelper.getCurrentLocation(
      onError: (msg) {
        if (mounted) AppToast.error(context, msg);
      },
    );

    if (mounted) {
      setState(() {
        _isGettingGps = false;
        if (pos != null) {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _latitudeController.text = pos.latitude.toStringAsFixed(6);
          _longitudeController.text = pos.longitude.toStringAsFixed(6);
          AppToast.success(context, 'Lokasi berhasil didapatkan');
        }
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImageCompressHelper.pickCompressedImage(
        _picker,
        source: source,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _imageName = picked.name;
            _imageSizeBytes = bytes.length;
          });
          AppToast.success(context, 'Foto berhasil dipilih');
        }
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Gagal memilih foto');
    }
  }

  Future<void> _selectCustomer() async {
    final selected = await showCustomerPickerModal(context);
    if (selected != null && mounted) {
      setState(() {
        _selectedCustomer = selected;
        _existingVisitId = null;
      });
      _checkAndLoadExistingVisit();
    }
  }

  String _formatDisplayDate(DateTime date) {
    const bulan = [
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
    return '${date.day} ${bulan[date.month - 1]} ${date.year}';
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/visit');
    }
  }

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      AppToast.error(context, 'Customer harus dipilih terlebih dahulu');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final ymdFormat = DateFormat('yyyy-MM-dd');
    final todayYmd = ymdFormat.format(DateTime.now());
    final ymd = ymdFormat.format(_selectedDate);

    if (ymd.compareTo(todayYmd) < 0) {
      AppToast.error(
        context,
        'Tanggal visit tidak boleh kurang dari hari ini',
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = ref.read(authProvider).user;
    final repo = ref.read(visitRepositoryProvider);

    final finalLat = double.tryParse(_latitudeController.text.trim()) ?? _latitude;
    final finalLng = double.tryParse(_longitudeController.text.trim()) ?? _longitude;

    final bool success;
    if (_existingVisitId != null) {
      success = await repo.updateVisit(
        id: _existingVisitId!,
        note: _noteController.text.trim(),
        catatan: _catatanController.text.trim(),
        tanggal: ymd,
        latitude: finalLat,
        longitude: finalLng,
        photoBytes: _imageBytes,
        photoName: _imageName,
      );
    } else {
      success = await repo.createVisit(
        tanggal: ymd,
        customerKode: _selectedCustomer!.kode,
        customerNama: _selectedCustomer!.nama,
        note: _noteController.text.trim(),
        catatan: _catatanController.text.trim(),
        cabang: user?.cabang ?? '',
        sales: user?.nama ?? '',
        latitude: finalLat,
        longitude: finalLng,
        photoBytes: _imageBytes,
        photoName: _imageName,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        AppToast.success(
          context,
          _existingVisitId != null
              ? 'Visit berhasil diperbarui'
              : 'Visit berhasil disimpan',
        );
        context.pop(true);
      } else {
        AppToast.error(context, 'Gagal menyimpan visit');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final namaSales = user?.nama ?? '-';
    final cabang = user?.cabang ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = ResponsiveHelper.isDesktop(context);
            final isTablet = ResponsiveHelper.isTablet(context);
            final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
            final cardPadding = isDesktop ? 28.0 : (isTablet ? 24.0 : 20.0);

            // Widget Sales (Cabang)
            Widget buildSalesField() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales (Cabang)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.06),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$namaSales ($cabang)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Widget Tanggal Visit
            Widget buildTanggalField() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tanggal Visit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final todayDate = DateTime(now.year, now.month, now.day);
                      final firstAllowed = _selectedDate.isBefore(todayDate) ? _selectedDate : todayDate;

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: firstAllowed,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _checkAndLoadExistingVisit();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color.fromRGBO(15, 23, 42, 0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDisplayDate(_selectedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Icon(
                            Icons.edit_calendar_rounded,
                            size: 20,
                            color: Color(0xFF0F172A),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveHelper.formWidth(context),
                ),
                child: Column(
                  children: [
                    // 1. TOP HEADER (Responsif)
                    Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
                      child: Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleBack,
                            child: Container(
                              width: isDesktop ? 44 : 40,
                              height: isDesktop ? 44 : 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color.fromRGBO(15, 23, 42, 0.08),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(15, 23, 42, 0.03),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: isDesktop ? 26 : 24,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Visit',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Input Kunjungan',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isDesktop ? 44 : 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. FORM KONTEN (Card Responsif)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                        child: Form(
                          key: _formKey,
                          child: Container(
                            padding: EdgeInsets.all(cardPadding),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(15, 23, 42, 0.04),
                                  blurRadius: 18,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Di tablet/desktop: Sales dan Tanggal dalam 1 Row
                                if (isTablet || isDesktop)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: buildSalesField()),
                                      const SizedBox(width: 16),
                                      Expanded(child: buildTanggalField()),
                                    ],
                                  )
                                else ...[
                                  buildSalesField(),
                                  const SizedBox(height: 14),
                                  buildTanggalField(),
                                ],
                                const SizedBox(height: 14),

                                // Customer + Tombol Cari
                                const Text(
                                  'Customer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: _selectCustomer,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _selectedCustomer?.nama ?? 'Pilih Customer',
                                            style: TextStyle(
                                              color: _selectedCustomer != null
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFF94A3B8),
                                              fontWeight: _selectedCustomer != null
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 48,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFF1F5F9),
                                          foregroundColor: const Color(0xFF4F46E5),
                                          minimumSize: const Size(0, 48),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                        ),
                                        onPressed: _selectCustomer,
                                        child: const Text(
                                          'CARI',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedCustomer?.kode != null && _selectedCustomer!.kode.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kode: ${_selectedCustomer!.kode}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (_isCheckingDraft) ...[
                                  const SizedBox(height: 4),
                                  const Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Memeriksa draft / visit...',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ] else if (_existingVisitId != null) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    '• Mode: UPDATE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),

                                // Lokasi (Latitude & Longitude)
                                const Text(
                                  'Lokasi (Koordinat)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _latitudeController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'Latitude',
                                          hintStyle: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.location_on_outlined,
                                            size: 18,
                                            color: Color(0xFF06B6D4),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 14,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          _latitude = double.tryParse(val.trim());
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _longitudeController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'Longitude',
                                          hintStyle: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.location_on_outlined,
                                            size: 18,
                                            color: Color(0xFF06B6D4),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 14,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          _longitude = double.tryParse(val.trim());
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF06B6D4),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: _isGettingGps
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.my_location_rounded, size: 16),
                                    onPressed: _isGettingGps ? null : _fetchGpsLocation,
                                    label: Text(
                                      _isGettingGps ? 'MEMINTA LOKASI...' : 'AMBIL LOKASI GPS',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Foto Dokumentasi
                                const Text(
                                  'Foto',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (_imageBytes != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(
                                      _imageBytes!,
                                      height: isDesktop ? 220 : (isTablet ? 190 : 160),
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _imageSizeBytes != null
                                        ? 'Size: ${(_imageSizeBytes! / 1024).toStringAsFixed(0)} KB'
                                        : 'Size: -',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ] else ...[
                                  Container(
                                    height: isDesktop ? 130 : 100,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Belum ada foto',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            foregroundColor: const Color(0xFF4F46E5),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () => _pickImage(ImageSource.camera),
                                          child: const Text(
                                            'KAMERA',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            foregroundColor: const Color(0xFF4F46E5),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: () => _pickImage(ImageSource.gallery),
                                          child: const Text(
                                            'GALERI',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Keperluan & Hasil (2 Kolom di Desktop, tumpuk vertikal di Mobile/Tablet)
                                if (isDesktop)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Keperluan',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _noteController,
                                              maxLines: 4,
                                              decoration: InputDecoration(
                                                hintText: 'Tulis keperluan...',
                                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                                filled: true,
                                                fillColor: const Color(0xFFF1F5F9),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Hasil',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _catatanController,
                                              maxLines: 4,
                                              decoration: InputDecoration(
                                                hintText: 'Tulis hasil kunjungan...',
                                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                                filled: true,
                                                fillColor: const Color(0xFFF1F5F9),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  // Keperluan (note)
                                  const Text(
                                    'Keperluan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _noteController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Tulis keperluan...',
                                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Hasil (catatan)
                                  const Text(
                                    'Hasil',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _catatanController,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: 'Tulis hasil kunjungan...',
                                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      filled: true,
                                      fillColor: const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color.fromRGBO(15, 23, 42, 0.06)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),

                                // Tombol Simpan & Batal (Adaptif Tablet/Desktop)
                                if (isTablet || isDesktop)
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 48,
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFF64748B),
                                              backgroundColor: const Color(0xFFF1F5F9),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            onPressed: _handleBack,
                                            child: const Text(
                                              'Batal',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF4F46E5),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            onPressed: _isLoading ? null : _submit,
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : Text(
                                                    _existingVisitId != null ? 'UPDATE VISIT' : 'SIMPAN VISIT',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _isLoading ? null : _submit,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text(
                                              _existingVisitId != null ? 'UPDATE VISIT' : 'SIMPAN VISIT',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF64748B),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _handleBack,
                                      child: const Text(
                                        'Batal',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
