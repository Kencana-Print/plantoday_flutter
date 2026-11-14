import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/image_compress_helper.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/kurir_model.dart';
import '../../repositories/kurir_repository.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class ProsesPengirimanScreen extends ConsumerStatefulWidget {
  final KurirRencanaItem item;

  const ProsesPengirimanScreen({super.key, required this.item});

  @override
  ConsumerState<ProsesPengirimanScreen> createState() =>
      _ProsesPengirimanScreenState();
}

class _ProsesPengirimanScreenState
    extends ConsumerState<ProsesPengirimanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _catatanController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isGettingGps = false;

  Uint8List? _photoBytes;
  String? _photoName;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchGpsLocation();
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _isGettingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
            _isGettingGps = false;
          });
        }
      } else {
        if (mounted) setState(() => _isGettingGps = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isGettingGps = false);
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
        setState(() {
          _photoBytes = bytes;
          _photoName = picked.name;
        });
      }
    } catch (_) {}
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Text(
                'Ambil Bukti Penerimaan Barang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Divider(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Kamera',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF00B4D8),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Galeri Foto',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photoBytes == null) {
      AppToast.error(
        context,
        'Foto bukti penerimaan barang wajib dilampirkan',
      );
      return;
    }

    setState(() => _isLoading = true);

    final repo = ref.read(kurirRepositoryProvider);
    final success = await repo.prosesPengiriman(
      id: widget.item.id,
      catatan: _catatanController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      photoBytes: _photoBytes,
      photoName: _photoName,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        AppToast.success(context, 'Pengiriman berhasil diselesaikan');
        context.pop(true);
      } else {
        AppToast.error(
          context,
          'Gagal memproses pengiriman. Periksa koneksi.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
            final maxContainerWidth = ResponsiveHelper.formWidth(context);

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContainerWidth),
                child: Column(
                  children: [
                    // 1. TOP HEADER
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        12,
                        horizontalPadding,
                        0,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.pop(),
                            child: Container(
                              width: 42,
                              height: 42,
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
                              child: const Icon(
                                Icons.chevron_left_rounded,
                                size: 26,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: const [
                                Text(
                                  'Proses Pengiriman',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Konfirmasi serah terima barang ke penerima',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 42),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. FORM KONTEN
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 6,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // INFO PENERIMA CARD
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          widget.item.kodePengiriman,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF4F46E5),
                                          ),
                                        ),
                                        Text(
                                          '${widget.item.tanggalPlan} ${widget.item.jamPlan}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tujuan: ${widget.item.receiver}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (widget.item.sender.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Dari: ${widget.item.sender}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                    if (widget.item.note.isNotEmpty) ...[
                                      const Divider(
                                          height: 18,
                                          color: Color(0xFFF1F5F9)),
                                      Text(
                                        'Keterangan: ${widget.item.note}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // FORM BUKTI SERAH TERIMA
                              AppCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Bukti Serah Terima Barang',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // GPS Lokasi Card
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color.fromRGBO(
                                              15, 23, 42, 0.06),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4F46E5)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.pin_drop_rounded,
                                              color: Color(0xFF4F46E5),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Koordinat GPS Penyerahan',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _isGettingGps
                                                      ? 'Mendeteksi titik GPS...'
                                                      : (_latitude != null &&
                                                              _longitude != null
                                                          ? 'Lat: ${_latitude!.toStringAsFixed(5)}, Long: ${_longitude!.toStringAsFixed(5)}'
                                                          : 'GPS belum terdeteksi'),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _latitude != null
                                                        ? const Color(0xFF10B981)
                                                        : const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.my_location_rounded,
                                              size: 20,
                                              color: Color(0xFF4F46E5),
                                            ),
                                            onPressed: _fetchGpsLocation,
                                            tooltip: 'Ambil Titik Lokasi',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // Foto Serah Terima (Web-Safe Memory Preview)
                                    const Text(
                                      'Foto Bukti Serah Terima *',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _showImageSourceDialog,
                                      child: Container(
                                        height: 160,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color.fromRGBO(
                                                15, 23, 42, 0.08),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: _photoBytes != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: Image.memory(
                                                  _photoBytes!,
                                                  width: double.infinity,
                                                  height: 160,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.add_a_photo_outlined,
                                                    size: 32,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  SizedBox(height: 6),
                                                  Text(
                                                    'Ambil Foto Bukti Penerimaan Barang',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // Catatan Penerimaan
                                    const Text(
                                      'Nama Penerima / Catatan Serah Terima *',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _catatanController,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Contoh: Diterima oleh Bpk. Budi (Security)...',
                                        prefixIcon: Icon(Icons.badge_outlined,
                                            size: 20),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Catatan / nama penerima wajib diisi'
                                              : null,
                                    ),
                                    const SizedBox(height: 20),

                                    // Tombol Konfirmasi Selesai
                                    AppButton(
                                      text:
                                          'Selesaikan Pengiriman (Delivered)',
                                      isLoading: _isLoading,
                                      onPressed: _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
