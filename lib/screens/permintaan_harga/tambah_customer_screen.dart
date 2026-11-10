import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/permintaan_harga_repository.dart';
import '../../widgets/ui/app_card.dart';

class TambahCustomerPermintaanHargaScreen extends ConsumerStatefulWidget {
  final CustomerModel? initialCustomer;

  const TambahCustomerPermintaanHargaScreen({
    super.key,
    this.initialCustomer,
  });

  @override
  ConsumerState<TambahCustomerPermintaanHargaScreen> createState() =>
      _TambahCustomerPermintaanHargaScreenState();
}

class _TambahCustomerPermintaanHargaScreenState
    extends ConsumerState<TambahCustomerPermintaanHargaScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _kodeController;
  late final TextEditingController _namaController;
  late final TextEditingController _alamatController;
  late final TextEditingController _kotaController;
  late final TextEditingController _telpController;
  late final TextEditingController _cpController;
  late final TextEditingController _emailController;
  late final TextEditingController _jenisUsahaController;
  late final TextEditingController _npwpController;
  late final TextEditingController _namaNpwpController;
  late final TextEditingController _alamatNpwpController;
  late final TextEditingController _kotaNpwpController;

  String _korporasi = 'N';
  bool _isLoading = false;

  bool get _isEdit => widget.initialCustomer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCustomer;
    _kodeController = TextEditingController(text: c?.kode ?? '');
    _namaController = TextEditingController(text: c?.nama ?? '');
    _alamatController = TextEditingController(text: c?.alamat ?? '');
    _kotaController = TextEditingController(text: c?.kota ?? '');
    _telpController = TextEditingController(text: c?.telp ?? '');
    _cpController = TextEditingController(text: c?.cp ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _jenisUsahaController = TextEditingController(text: c?.jenisUsaha ?? '');
    _npwpController = TextEditingController(text: c?.npwp ?? '');
    _namaNpwpController = TextEditingController(text: c?.namaNpwp ?? '');
    _alamatNpwpController = TextEditingController(text: c?.alamatNpwp ?? '');
    _kotaNpwpController = TextEditingController(text: c?.kotaNpwp ?? '');
    _korporasi = (c?.korporasi == 'Y') ? 'Y' : 'N';
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    _alamatController.dispose();
    _kotaController.dispose();
    _telpController.dispose();
    _cpController.dispose();
    _emailController.dispose();
    _jenisUsahaController.dispose();
    _npwpController.dispose();
    _namaNpwpController.dispose();
    _alamatNpwpController.dispose();
    _kotaNpwpController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/customer');
    }
  }

  bool _isBasicEmail(String val) {
    final v = val.trim();
    if (v.isEmpty || v == '-') return true;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isBasicEmail(_emailController.text)) {
      AppToast.error(context, 'Format email tidak valid');
      return;
    }

    if (_korporasi == 'Y' &&
        (_jenisUsahaController.text.trim().isEmpty ||
            _npwpController.text.trim().isEmpty)) {
      AppToast.error(
        context,
        'Jenis Usaha dan NPWP wajib diisi untuk Korporasi',
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isEdit) {
      final c = widget.initialCustomer!;
      final customerRepo = ref.read(customerRepositoryProvider);
      final updatedCustomer = CustomerModel(
        id: c.id,
        kode: c.kode,
        nama: _namaController.text.trim(),
        alamat: _alamatController.text.trim(),
        kota: _kotaController.text.trim(),
        telp: _telpController.text.trim(),
        cp: _cpController.text.trim(),
        email: _emailController.text.trim(),
        korporasi: _korporasi,
        jenisUsaha: _jenisUsahaController.text.trim(),
        npwp: _npwpController.text.trim(),
        namaNpwp: _namaNpwpController.text.trim(),
        alamatNpwp: _alamatNpwpController.text.trim(),
        kotaNpwp: _kotaNpwpController.text.trim(),
      );

      final success = await customerRepo.updateCalonCustomer(
        c.kode,
        updatedCustomer,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          AppToast.success(context, 'Data customer berhasil diperbarui');
          context.pop(true);
        } else {
          AppToast.error(context, 'Gagal memperbarui data customer');
        }
      }
      return;
    }

    final user = ref.read(authProvider).user;
    final repo = ref.read(permintaanHargaRepositoryProvider);

    final payload = {
      'nama': _namaController.text.trim(),
      'alamat': _alamatController.text.trim(),
      'kota': _kotaController.text.trim(),
      'cus_telp': _telpController.text.trim(),
      'cus_cp': _cpController.text.trim(),
      'cus_email': _emailController.text.trim(),
      'user_create': user?.nama ?? '',
      'cus_korporasi': _korporasi,
      'cus_jenisusaha': _jenisUsahaController.text.trim(),
      'cus_npwp': _npwpController.text.trim(),
      'cus_nama_npwp': _namaNpwpController.text.trim(),
      'cus_alamat_npwp': _alamatNpwpController.text.trim(),
      'cus_kota_npwp': _kotaNpwpController.text.trim(),
    };

    final created = await repo.createPermintaanHargaCustomer(payload);

    if (mounted) {
      setState(() => _isLoading = false);

      if (created != null) {
        AppToast.success(
          context,
          'Customer ${created['nama'] ?? payload['nama']} berhasil ditambahkan',
        );
        context.pop(created);
      } else {
        AppToast.error(context, 'Gagal menambahkan customer');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKorporasi = _korporasi == 'Y';

    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = ResponsiveHelper.isDesktop(context);
            final isTablet = ResponsiveHelper.isTablet(context);
            final isWide = isDesktop || isTablet;
            final horizontalPadding = ResponsiveHelper.horizontalPadding(context);
            final maxFormWidth = ResponsiveHelper.formWidth(context);

            Widget buildNamaField() => TextFormField(
                  controller: _namaController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Customer *',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                );

            Widget buildKotaField() => TextFormField(
                  controller: _kotaController,
                  decoration: const InputDecoration(
                    labelText: 'Kota *',
                    prefixIcon: Icon(
                      Icons.location_city_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Kota wajib diisi' : null,
                );

            Widget buildTelpField() => TextFormField(
                  controller: _telpController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. Telp / WA *',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'No telp wajib diisi'
                      : null,
                );

            Widget buildCpField() => TextFormField(
                  controller: _cpController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Person *',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'CP wajib diisi' : null,
                );

            Widget buildJenisUsahaField() => TextFormField(
                  controller: _jenisUsahaController,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Usaha *',
                    prefixIcon: Icon(
                      Icons.storefront_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                );

            Widget buildNpwpField() => TextFormField(
                  controller: _npwpController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor NPWP *',
                    prefixIcon: Icon(
                      Icons.credit_card_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                );

            Widget buildNamaNpwpField() => TextFormField(
                  controller: _namaNpwpController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tertera di NPWP',
                    prefixIcon: Icon(
                      Icons.account_box_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                );

            Widget buildKotaNpwpField() => TextFormField(
                  controller: _kotaNpwpController,
                  decoration: const InputDecoration(
                    labelText: 'Kota NPWP',
                    prefixIcon: Icon(
                      Icons.map_outlined,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ),
                );

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxFormWidth),
                child: Column(
                  children: [
                    // 1. TOP HEADER (Adaptif Mobile/Tablet/Desktop)
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
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  _isEdit ? 'Edit Customer' : 'Tambah Customer',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isEdit
                                      ? 'Perbarui data & informasi perpajakan customer'
                                      : 'Input data customer & profil korporasi',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.muted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isDesktop ? 44 : 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. FORM BODY
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 8,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppCard(
                                padding: EdgeInsets.all(
                                  isDesktop ? 28.0 : (isTablet ? 24.0 : 20.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Informasi Utama',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    if (_isEdit) ...[
                                      TextFormField(
                                        controller: _kodeController,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Kode Customer',
                                          prefixIcon: Icon(
                                            Icons.qr_code,
                                            size: 20,
                                            color: AppColors.muted,
                                          ),
                                          filled: true,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],

                                    // Di Tablet/Desktop: Nama & Kota berdampingan
                                    if (isWide)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: buildNamaField(),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            flex: 2,
                                            child: buildKotaField(),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      buildNamaField(),
                                      const SizedBox(height: 14),
                                      buildKotaField(),
                                    ],
                                    const SizedBox(height: 14),

                                    TextFormField(
                                      controller: _alamatController,
                                      decoration: const InputDecoration(
                                        labelText: 'Alamat Lengkap *',
                                        prefixIcon: Icon(
                                          Icons.place_outlined,
                                          size: 20,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      maxLines: 2,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Alamat wajib diisi'
                                              : null,
                                    ),
                                    const SizedBox(height: 14),

                                    // Telp & Contact Person (2 kolom di layar >= 420px, vertikal di HP kecil)
                                    if (constraints.maxWidth >= 420)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: buildTelpField()),
                                          const SizedBox(width: 14),
                                          Expanded(child: buildCpField()),
                                        ],
                                      )
                                    else ...[
                                      buildTelpField(),
                                      const SizedBox(height: 14),
                                      buildCpField(),
                                    ],
                                    const SizedBox(height: 14),

                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Email *',
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          size: 20,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Email wajib diisi'
                                              : null,
                                    ),
                                    const SizedBox(height: 18),

                                    // Switch Korporasi
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.soft,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.medium,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Entitas Korporasi / Perusahaan?',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                          ),
                                          Switch(
                                            value: isKorporasi,
                                            activeThumbColor: AppColors.primary,
                                            onChanged: (val) {
                                              setState(
                                                () =>
                                                    _korporasi = val ? 'Y' : 'N',
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (isKorporasi) ...[
                                const SizedBox(height: 16),
                                AppCard(
                                  padding: EdgeInsets.all(
                                    isDesktop ? 28.0 : (isTablet ? 24.0 : 20.0),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'Data Perpajakan / NPWP',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      if (isWide)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: buildJenisUsahaField(),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(child: buildNpwpField()),
                                          ],
                                        )
                                      else ...[
                                        buildJenisUsahaField(),
                                        const SizedBox(height: 14),
                                        buildNpwpField(),
                                      ],
                                      const SizedBox(height: 14),

                                      if (isWide)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: buildNamaNpwpField(),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              flex: 2,
                                              child: buildKotaNpwpField(),
                                            ),
                                          ],
                                        )
                                      else ...[
                                        buildNamaNpwpField(),
                                        const SizedBox(height: 14),
                                        buildKotaNpwpField(),
                                      ],
                                      const SizedBox(height: 14),

                                      TextFormField(
                                        controller: _alamatNpwpController,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          labelText: 'Alamat NPWP',
                                          prefixIcon: Icon(
                                            Icons.home_work_outlined,
                                            size: 20,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Tombol Simpan & Batal Adaptif (Mobile vs Tablet/Desktop)
                              if (isWide)
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: SizedBox(
                                        height: 48,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.muted,
                                            backgroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              side: const BorderSide(
                                                color: AppColors.border,
                                              ),
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
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.accent,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: AppShadows.button,
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          onPressed:
                                              _isLoading ? null : _submit,
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  _isEdit
                                                      ? 'SIMPAN PERUBAHAN'
                                                      : 'SIMPAN CUSTOMER',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.accent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: AppShadows.button,
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _isLoading ? null : _submit,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _isEdit
                                                ? 'SIMPAN PERUBAHAN'
                                                : 'SIMPAN CUSTOMER',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.4,
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
                                      foregroundColor: AppColors.muted,
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
                              const SizedBox(height: 24),
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
