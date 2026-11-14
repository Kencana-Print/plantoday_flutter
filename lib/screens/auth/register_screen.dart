import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _namaController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPass = false;
  bool _loading = false;
  String _deviceId = 'unknown';

  String _selectedJabatan = 'SALES';
  String _selectedCabang = 'PUSAT';

  final List<String> _jabatanOptions = ['SALES', 'KURIR'];
  final List<String> _cabangOptions = ['PUSAT', 'JATIM', 'JATENG', 'JAKARTA'];

  bool get _canSubmit =>
      _namaController.text.trim().isNotEmpty &&
      _passwordController.text.length >= 3 &&
      !_loading;

  @override
  void initState() {
    super.initState();
    _initDeviceId();
  }

  Future<void> _initDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        _deviceId = 'web-client';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'ios-device';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceId = windowsInfo.deviceId;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _namaController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showGlassSelectModal({
    required String title,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Handle persis React Native (sheetHandle)
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Title
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),

              // Option List (Sheet Items)
              ...options.map((opt) {
                final isActive = opt == currentValue;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelected(opt);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF4F46E5)
                            : const Color.fromRGBO(15, 23, 42, 0.06),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      opt,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                );
              }),

              // Tombol Tutup persis React Native
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color.fromRGBO(15, 23, 42, 0.06),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final nama = _namaController.text.trim();
    final password = _passwordController.text;

    if (nama.isEmpty || password.isEmpty) {
      AppToast.error(context, 'Nama dan password wajib diisi',
          title: 'Validasi');
      return;
    }

    if (password.length < 3) {
      AppToast.error(context, 'Password minimal 3 karakter',
          title: 'Validasi');
      return;
    }

    setState(() => _loading = true);

    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'nama': nama,
        'password': password,
        'jabatan': _selectedJabatan,
        'cabang': _selectedCabang,
        'deviceId': _deviceId,
      };

      final res = await api.dio.post('/register', data: payload);

      if (mounted) {
        setState(() => _loading = false);

        if (res.data != null && res.data['success'] == true) {
          AppToast.success(
            context,
            res.data['message']?.toString() ?? 'Registrasi Berhasil',
          );

          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) context.go('/login');
          });
        } else {
          final msg = res.data?['message']?.toString() ?? 'Registrasi Gagal';
          AppToast.error(context, msg);
        }
      }
    } on DioException catch (err) {
      if (mounted) {
        setState(() => _loading = false);
        final errorMsg =
            err.response?.data?['message'] ?? 'Gagal koneksi ke server';
        AppToast.error(context, errorMsg.toString());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.error(context, 'Terjadi kesalahan koneksi ke server');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F9FF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: ResponsiveContainer(
                maxWidth: 410,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // HERO Box ala Home di React Native
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.fromRGBO(79, 70, 229, 0.16),
                            Color.fromRGBO(6, 182, 212, 0.10),
                            Color.fromRGBO(255, 255, 255, 0.00),
                          ],
                        ),
                        color: const Color.fromRGBO(255, 255, 255, 0.50),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color.fromRGBO(79, 70, 229, 0.12),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          // Header: Back button + REGISTER & PLANTODAY
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => context.pop(),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color.fromRGBO(
                                            15, 23, 42, 0.08),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 18,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'REGISTER',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        Color(0xFF4F46E5),
                                        Color(0xFF06B6D4)
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ).createShader(bounds),
                                    child: const Text(
                                      'PLANTODAY',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.9,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Form Card (maxWidth: 380 persis React Native formCard)
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 380),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color.fromRGBO(15, 23, 42, 0.08),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.06),
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Daftar Akun Baru',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Label NAMA
                                _buildLabel('Nama'),
                                Container(
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color.fromRGBO(
                                          15, 23, 42, 0.08),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: _namaController,
                                    enabled: !_loading,
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Nama',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      filled: true,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // GlassSelect: JABATAN (Persis RN)
                                _buildLabel('Jabatan'),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _loading
                                      ? null
                                      : () => _showGlassSelectModal(
                                            title: 'JABATAN',
                                            currentValue: _selectedJabatan,
                                            options: _jabatanOptions,
                                            onSelected: (val) => setState(
                                                () => _selectedJabatan = val),
                                          ),
                                  child: Container(
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color.fromRGBO(
                                            15, 23, 42, 0.08),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedJabatan,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const Text(
                                          '▾',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // GlassSelect: CABANG (Persis RN)
                                _buildLabel('Cabang'),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _loading
                                      ? null
                                      : () => _showGlassSelectModal(
                                            title: 'CABANG',
                                            currentValue: _selectedCabang,
                                            options: _cabangOptions,
                                            onSelected: (val) => setState(
                                                () => _selectedCabang = val),
                                          ),
                                  child: Container(
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color.fromRGBO(
                                            15, 23, 42, 0.08),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedCabang,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        const Text(
                                          '▾',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Input: PASSWORD
                                _buildLabel('Password'),
                                Container(
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color.fromRGBO(
                                          15, 23, 42, 0.08),
                                    ),
                                  ),
                                  padding: const EdgeInsets.only(
                                      left: 12, right: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _passwordController,
                                          obscureText: !_showPass,
                                          enabled: !_loading,
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: (_) => _handleRegister(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Password',
                                            hintStyle: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            filled: true,
                                            fillColor: Colors.transparent,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      // Tombol SHOW / HIDE persis React Native
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(
                                            () => _showPass = !_showPass),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color.fromRGBO(
                                                15, 23, 42, 0.04),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color.fromRGBO(
                                                  15, 23, 42, 0.08),
                                            ),
                                          ),
                                          child: Text(
                                            _showPass ? 'HIDE' : 'SHOW',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Tombol Register Gradient persis React Native
                                Opacity(
                                  opacity: _canSubmit ? 1.0 : 0.65,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4F46E5),
                                          Color(0xFF06B6D4)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color.fromRGBO(
                                            255, 255, 255, 0.25),
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap:
                                            _canSubmit ? _handleRegister : null,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Center(
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Text(
                                                  'Register',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Link Footer Login
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _loading ? null : () => context.pop(),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4),
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'Sudah punya akun? ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Login',
                                            style: TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
