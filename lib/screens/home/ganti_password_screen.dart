import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';

class GantiPasswordScreen extends ConsumerStatefulWidget {
  const GantiPasswordScreen({super.key});

  @override
  ConsumerState<GantiPasswordScreen> createState() =>
      _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends ConsumerState<GantiPasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _showOld = false;
  bool _showNew = false;
  bool _loading = false;

  bool get _canSubmit =>
      _oldPasswordController.text.length >= 3 &&
      _newPasswordController.text.length >= 3 &&
      !_loading;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    final user = ref.read(authProvider).user;
    if (user?.nama == null || user!.nama.isEmpty) {
      AppToast.error(context, 'User belum login');
      return;
    }

    final oldPass = _oldPasswordController.text;
    final newPass = _newPasswordController.text;

    setState(() => _loading = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post(
        '/ganti-password',
        data: {
          'user': user.nama,
          'oldPassword': oldPass,
          'newPassword': newPass,
        },
      );

      if (mounted) {
        setState(() => _loading = false);

        if (response.data != null && response.data['success'] == true) {
          _oldPasswordController.clear();
          _newPasswordController.clear();
          _showSuccessModal();
        } else {
          final msg = response.data?['message'] ?? 'Gagal mengganti password';
          AppToast.error(context, msg.toString());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.error(context, 'Terjadi kesalahan koneksi ke server');
      }
    }
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 36,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Password Berhasil Diubah!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Silakan login kembali dengan password baru Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) context.go('/login');
                },
                child: const Text(
                  'OK, Login Ulang',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ResponsiveContainer(
                maxWidth: 420,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // HERO BOX Persis React Native
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
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color.fromRGBO(79, 70, 229, 0.12),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          // Header: Circular Back button + Title
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
                                          15,
                                          23,
                                          42,
                                          0.08,
                                        ),
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
                              const Text(
                                'Ganti Password',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Form Card Persis React Native
                          Container(
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
                                // Input: Password Lama
                                _buildLabel('Password Lama'),
                                Container(
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color.fromRGBO(
                                        15,
                                        23,
                                        42,
                                        0.08,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    right: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _oldPasswordController,
                                          obscureText: !_showOld,
                                          enabled: !_loading,
                                          textInputAction: TextInputAction.next,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Password lama...',
                                            hintStyle: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 14,
                                            ),
                                            filled: true,
                                            fillColor: Colors.transparent,
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(
                                          () => _showOld = !_showOld,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color.fromRGBO(
                                              15,
                                              23,
                                              42,
                                              0.04,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color.fromRGBO(
                                                15,
                                                23,
                                                42,
                                                0.08,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            _showOld ? 'HIDE' : 'SHOW',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11.5,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Input: Password Baru
                                _buildLabel('Password Baru'),
                                Container(
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color.fromRGBO(
                                        15,
                                        23,
                                        42,
                                        0.08,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    right: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.key_outlined,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _newPasswordController,
                                          obscureText: !_showNew,
                                          enabled: !_loading,
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: (_) => _handleSubmit(),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Password baru...',
                                            hintStyle: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 14,
                                            ),
                                            filled: true,
                                            fillColor: Colors.transparent,
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(
                                          () => _showNew = !_showNew,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color.fromRGBO(
                                              15,
                                              23,
                                              42,
                                              0.04,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color.fromRGBO(
                                                15,
                                                23,
                                                42,
                                                0.08,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            _showNew ? 'HIDE' : 'SHOW',
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11.5,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Tombol Simpan Gradient
                                Opacity(
                                  opacity: _canSubmit ? 1.0 : 0.65,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4F46E5),
                                          Color(0xFF06B6D4),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap:
                                            _canSubmit ? _handleSubmit : null,
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
                                                  'Simpan',
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
