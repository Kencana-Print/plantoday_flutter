import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/image_compress_helper.dart';
import '../../core/utils/location_helper.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/visit_repository.dart';

class EditVisitScreen extends ConsumerStatefulWidget {
  final VisitModel visit;

  const EditVisitScreen({super.key, required this.visit});

  @override
  ConsumerState<EditVisitScreen> createState() => _EditVisitScreenState();
}

class _EditVisitScreenState extends ConsumerState<EditVisitScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late final TextEditingController _noteController;
  late final TextEditingController _catatanController;

  double? _latitude;
  double? _longitude;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  bool _isGettingGps = false;

  Uint8List? _newPhotoBytes;
  String? _newPhotoName;
  int? _newPhotoSizeBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    _noteController = TextEditingController(text: v.note);
    _catatanController = TextEditingController(text: v.catatan);
    _latitude = v.latitude;
    _longitude = v.longitude;
    _latitudeController = TextEditingController(
      text: _latitude != null ? _latitude!.toStringAsFixed(6) : '',
    );
    _longitudeController = TextEditingController(
      text: _longitude != null ? _longitude!.toStringAsFixed(6) : '',
    );

    try {
      _selectedDate = DateFormat('yyyy-MM-dd').parse(v.tanggal);
    } catch (_) {
      _selectedDate = DateTime.now();
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
            _newPhotoBytes = bytes;
            _newPhotoName = picked.name;
            _newPhotoSizeBytes = bytes.length;
          });
          AppToast.success(context, 'Foto berhasil dipilih');
        }
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Gagal memilih foto');
    }
  }

  Future<void> _bukaGoogleMaps() async {
    if (_latitude == null || _longitude == null) {
      AppToast.error(context, 'Koordinat lokasi belum tersedia');
      return;
    }
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) AppToast.error(context, 'Tidak dapat membuka Google Maps');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Gagal membuka Google Maps');
    }
  }

  void _showImagePreviewDialog(String? networkUrl, Uint8List? localBytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: localBytes != null
                  ? Image.memory(localBytes, fit: BoxFit.contain)
                  : Image.network(
                      networkUrl ?? '',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Container(
                        height: 200,
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const Text('Foto tidak dapat dimuat'),
                      ),
                    ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
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
    if (!_formKey.currentState!.validate()) return;
    if (widget.visit.id == null) {
      AppToast.error(context, 'ID kunjungan tidak valid');
      return;
    }

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

    final repo = ref.read(visitRepositoryProvider);

    final finalLat = double.tryParse(_latitudeController.text.trim()) ?? _latitude;
    final finalLng = double.tryParse(_longitudeController.text.trim()) ?? _longitude;

    final success = await repo.updateVisit(
      id: widget.visit.id!,
      note: _noteController.text.trim(),
      catatan: _catatanController.text.trim(),
      tanggal: ymd,
      latitude: finalLat,
      longitude: finalLng,
      photoBytes: _newPhotoBytes,
      photoName: _newPhotoName,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        AppToast.success(context, 'Visit diperbarui');
        context.pop(true);
      } else {
        AppToast.error(context, 'Gagal memperbarui visit');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isManager = (user?.jabatan ?? '').toUpperCase() == 'MANAGER';
    final namaSales = (widget.visit.salesName != null && widget.visit.salesName!.isNotEmpty)
        ? widget.visit.salesName!
        : (user?.nama ?? '-');
    final cabang = user?.cabang ?? '-';
    final v = widget.visit;

    final photoUrlResolved = (v.fotoUrl != null && v.fotoUrl!.isNotEmpty)
        ? (v.fotoUrl!.startsWith('http') ? v.fotoUrl! : '${ApiConfig.imageReadUrl}${v.fotoUrl}')
        : null;

    final hasValidCoord = _latitude != null &&
        _longitude != null &&
        _latitude != 0 &&
        _longitude != 0;

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
                    onTap: isManager
                        ? null
                        : () async {
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
                          if (!isManager)
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
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.formWidth(context)),
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
                                  isManager ? 'Detail Visit' : 'Visit',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isManager ? 'Informasi kunjungan sales' : 'Edit Kunjungan',
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

                                // Customer
                                const Text(
                                  'Customer',
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
                                  child: Text(
                                    v.cusNama.isNotEmpty ? v.cusNama : 'Customer',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (v.cusKode != null && v.cusKode!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kode: ${v.cusKode!}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
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
                                        readOnly: isManager,
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
                                        readOnly: isManager,
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
                                if (!isManager) ...[
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
                                ],
                                const SizedBox(height: 8),

                                // Info Peta & Tombol Buka Google Maps
                                if (hasValidCoord) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.06)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '📍 ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4F46E5),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: _bukaGoogleMaps,
                                          icon: const Icon(Icons.navigation_rounded, size: 14),
                                          label: const Text(
                                            'Buka Google Maps',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.location_off_rounded, size: 16, color: Color(0xFF64748B)),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Koordinat belum tersedia.',
                                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                if (_newPhotoBytes != null || photoUrlResolved != null) ...[
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _showImagePreviewDialog(photoUrlResolved, _newPhotoBytes),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: _newPhotoBytes != null
                                              ? Image.memory(
                                                  _newPhotoBytes!,
                                                  height: isDesktop ? 220 : (isTablet ? 190 : 160),
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.network(
                                                  photoUrlResolved!,
                                                  height: isDesktop ? 220 : (isTablet ? 190 : 160),
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (ctx, err, stack) => Container(
                                                    height: 160,
                                                    color: const Color(0xFFF1F5F9),
                                                    alignment: Alignment.center,
                                                    child: const Text('Foto gagal dimuat'),
                                                  ),
                                                ),
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          right: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                                SizedBox(width: 4),
                                                Text('Lihat Foto', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _newPhotoSizeBytes != null
                                        ? 'Size: ${(_newPhotoSizeBytes! / 1024).toStringAsFixed(0)} KB'
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
                                if (!isManager) ...[
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
                                ],
                                const SizedBox(height: 14),

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
                                  readOnly: isManager,
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
                                  readOnly: isManager,
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
                                const SizedBox(height: 24),

                                // Tombol Simpan & Batal (Adaptif Tablet/Desktop)
                                if (!isManager) ...[
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
                                                  : const Text(
                                                      'UPDATE VISIT',
                                                      style: TextStyle(
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
                                            : const Text(
                                                'UPDATE VISIT',
                                                style: TextStyle(
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
                                ] else ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        foregroundColor: const Color(0xFF334155),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: _handleBack,
                                      child: const Text(
                                        'Kembali',
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
