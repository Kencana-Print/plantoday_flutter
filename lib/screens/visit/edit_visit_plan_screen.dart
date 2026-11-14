import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/location_helper.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/visit_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/visit_repository.dart';

class EditVisitPlanScreen extends ConsumerStatefulWidget {
  final VisitModel plan;

  const EditVisitPlanScreen({super.key, required this.plan});

  @override
  ConsumerState<EditVisitPlanScreen> createState() =>
      _EditVisitPlanScreenState();
}

class _EditVisitPlanScreenState extends ConsumerState<EditVisitPlanScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late final TextEditingController _noteController;
  late final TextEditingController _catatanController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  double? _latitude;
  double? _longitude;
  bool _isGettingGps = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _noteController = TextEditingController(text: p.note);
    _catatanController = TextEditingController(text: p.catatan);
    _latitude = p.latitude;
    _longitude = p.longitude;
    _latitudeController = TextEditingController(
      text: p.latitude != null ? p.latitude!.toStringAsFixed(6) : '',
    );
    _longitudeController = TextEditingController(
      text: p.longitude != null ? p.longitude!.toStringAsFixed(6) : '',
    );

    try {
      _selectedDate = DateFormat('yyyy-MM-dd').parse(p.tanggal);
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
      context.go('/visit-plan');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.plan.id == null) {
      AppToast.error(context, 'ID rencana kunjungan tidak valid');
      return;
    }

    final ymdFormat = DateFormat('yyyy-MM-dd');
    final todayYmd = ymdFormat.format(DateTime.now());
    final ymd = ymdFormat.format(_selectedDate);

    if (ymd.compareTo(todayYmd) < 0) {
      AppToast.error(
        context,
        'Tanggal plan tidak boleh kurang dari hari ini',
      );
      return;
    }

    setState(() => _isLoading = true);

    final repo = ref.read(visitRepositoryProvider);

    final finalLat = double.tryParse(_latitudeController.text.trim()) ?? _latitude;
    final finalLng = double.tryParse(_longitudeController.text.trim()) ?? _longitude;

    final success = await repo.updateVisitPlan(
      id: widget.plan.id!,
      tanggalPlan: ymd,
      note: _noteController.text.trim(),
      catatan: _catatanController.text.trim(),
      latitude: finalLat,
      longitude: finalLng,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        AppToast.success(
          context,
          'Rencana kunjungan berhasil diperbarui',
        );
        context.pop(true);
      } else {
        AppToast.error(context, 'Gagal memperbarui visit plan');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isManager = (user?.jabatan ?? '').toUpperCase() == 'MANAGER';
    final namaSales = (widget.plan.salesName != null && widget.plan.salesName!.isNotEmpty)
        ? widget.plan.salesName!
        : (user?.nama ?? '-');
    final cabang = user?.cabang ?? '-';
    final p = widget.plan;

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

            // Widget Tanggal Rencana Visit
            Widget buildTanggalField() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tanggal Rencana Visit',
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
                                  isManager ? 'Detail Visit Plan' : 'Edit Visit Plan',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isManager ? 'Rincian rencana kunjungan sales' : 'Perbarui Rencana Kunjungan',
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
                                const SizedBox(height: 8),

                                // Card Warning Jam 08:00
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Rencana kunjungan untuk hari yang sama hanya dapat diinput sebelum jam 08:00 pagi.',
                                          style: TextStyle(
                                            color: Color(0xFFD97706),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                                    p.cusNama.isNotEmpty ? p.cusNama : 'Customer',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (p.cusKode != null && p.cusKode!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Kode: ${p.cusKode!}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
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
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: 'Tulis keperluan kunjungan...',
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
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Keperluan kunjungan wajib diisi'
                                          : null,
                                ),
                                const SizedBox(height: 14),

                                // Catatan Tambahan (opsional)
                                const Text(
                                  'Catatan Tambahan',
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
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Tulis catatan tambahan jika ada...',
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

                                // Lokasi (Latitude & Longitude)
                                const Text(
                                  'Lokasi Rencana (Opsional)',
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
                                                      'UPDATE RENCANA',
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
                                                'UPDATE RENCANA',
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
