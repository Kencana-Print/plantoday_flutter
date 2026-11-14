import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'shortcut_guide_dismissed';

/// Membuka modal panduan pintasan web dengan transisi halus dan delay lembut.
Future<void> showShortcutGuide(
  BuildContext context, {
  bool auto = false,
}) async {
  if (!kIsWeb) return;

  if (auto) {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) return;

    // Beri jeda waktu lembut (1.5 detik) agar tampilan halaman utama/login
    // tampil stabil terlebih dahulu dan tidak mengejutkan pengguna.
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  if (!context.mounted) return;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup Panduan Pintasan',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (ctx, anim1, anim2) => const _ShortcutGuideDialog(),
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(
        parent: anim1,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 3.0 * curved.value,
          sigmaY: 3.0 * curved.value,
        ),
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.96,
                end: 1.0,
              ).animate(curved),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

class _ShortcutGuideDialog extends StatefulWidget {
  const _ShortcutGuideDialog();

  @override
  State<_ShortcutGuideDialog> createState() => _ShortcutGuideDialogState();
}

class _ShortcutGuideDialogState extends State<_ShortcutGuideDialog> {
  int _activeTab = 0; // 0: Android, 1: iPhone, 2: PC/Laptop
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    // Default tab menyesuaikan layar
    final isDesktop =
        kIsWeb &&
        MediaQueryData.fromView(
              WidgetsBinding.instance.platformDispatcher.views.first,
            ).size.width >
            720;
    _activeTab = isDesktop ? 2 : 0;
  }

  Future<void> _handleClose() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color.fromRGBO(15, 23, 42, 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(15, 23, 42, 0.10),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Icon + Title + Close
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pasang Pintasan Layar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Akses instan seperti aplikasi tanpa ketik URL',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleClose,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Segmented Bar Pilihan Perangkat (Modern Pill)
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildTabItem(0, Icons.android_rounded, 'Android'),
                    _buildTabItem(1, Icons.apple_rounded, 'iOS'),
                    _buildTabItem(2, Icons.laptop_mac_rounded, 'PC / Laptop'),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Step Timeline Content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _activeTab == 0
                    ? _buildStepList([
                        const _StepData(
                          icon: Icons.more_vert_rounded,
                          title: 'Menu Browser (⋮)',
                          desc:
                              'Ketuk titik tiga di kanan atas layar browser Chrome.',
                        ),
                        const _StepData(
                          icon: Icons.add_to_home_screen_rounded,
                          title: 'Tambahkan ke Layar Utama',
                          desc:
                              'Pilih menu "Tambahkan ke Layar Utama" (Add to Home screen).',
                        ),
                        const _StepData(
                          icon: Icons.check_circle_rounded,
                          title: 'Selesai',
                          desc: 'Ketuk "Tambah", pintasan otomatis terpasang.',
                        ),
                      ])
                    : _activeTab == 1
                    ? _buildStepList([
                        const _StepData(
                          icon: Icons.ios_share_rounded,
                          title: 'Tombol Bagikan (Share)',
                          desc:
                              'Di Safari, ketuk tombol kotak berpanah atas di bar bawah.',
                        ),
                        const _StepData(
                          icon: Icons.add_box_outlined,
                          title: 'Tambah ke Layar Utama',
                          desc:
                              'Gulir ke bawah dan ketuk opsi "Tambah ke Layar Utama".',
                        ),
                        const _StepData(
                          icon: Icons.check_circle_rounded,
                          title: 'Selesai',
                          desc:
                              'Ketuk "Tambah" di kanan atas — pintasan otomatis terpasang.',
                        ),
                      ])
                    : _buildStepList([
                        const _StepData(
                          icon: Icons.more_vert_rounded,
                          title: 'Menu Browser (⋮)',
                          desc:
                              'Klik titik tiga di kanan atas Chrome atau Edge laptop.',
                        ),
                        const _StepData(
                          icon: Icons.shortcut_rounded,
                          title: 'Buat Pintasan...',
                          desc:
                              'Pilih "Simpan & Bagikan" / "Alat" lalu klik "Buat Pintasan".',
                        ),
                        const _StepData(
                          icon: Icons.check_circle_rounded,
                          title: 'Selesai',
                          desc:
                              'Klik "Buat", ikon PlanToday akan muncul di desktop komputer.',
                        ),
                      ]),
              ),
              const SizedBox(height: 16),

              // Checkbox Jangan Tampilkan Lagi
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                child: Row(
                  children: [
                    Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: _dontShowAgain
                            ? const Color(0xFF6366F1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _dontShowAgain
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF94A3B8),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _dontShowAgain
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Jangan tampilkan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tombol Tutup Gradient
              Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleClose,
                    borderRadius: BorderRadius.circular(12),
                    child: const Center(
                      child: Text(
                        'Mengerti',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
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

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(15, 23, 42, 0.06),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepList(List<_StepData> steps) {
    return Column(
      key: ValueKey(_activeTab),
      children: steps.asMap().entries.map((entry) {
        final idx = entry.key;
        final step = entry.value;
        final isLast = idx == steps.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge nomor & icon bulat
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE0E7FF)),
                ),
                child: Icon(
                  step.icon,
                  size: 16,
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 12),
              // Deskripsi langkah
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${idx + 1}. ${step.title}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.desc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StepData {
  final IconData icon;
  final String title;
  final String desc;

  const _StepData({
    required this.icon,
    required this.title,
    required this.desc,
  });
}
