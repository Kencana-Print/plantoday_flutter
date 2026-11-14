import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/app_toast.dart';
import '../core/utils/responsive_helper.dart';
import '../providers/version_provider.dart';

class WebUpdateBanner extends ConsumerStatefulWidget {
  final Widget child;

  const WebUpdateBanner({super.key, required this.child});

  @override
  ConsumerState<WebUpdateBanner> createState() => _WebUpdateBannerState();
}

class _WebUpdateBannerState extends ConsumerState<WebUpdateBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final versionState = ref.watch(versionProvider);
    final isMobile = ResponsiveHelper.isMobile(context);

    // Otomatis munculkan pop up panduan pemasangan saat download selesai 100%
    ref.listen<VersionState>(versionProvider, (previous, next) {
      if (previous != null &&
          previous.isDownloading &&
          !next.isDownloading &&
          next.isApkReady &&
          context.mounted) {
        _showInstallGuideDialog(context, next);
      }
    });

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: versionState.hasUpdate
                ? _buildTopBanner(context, versionState, isMobile)
                : const SizedBox(width: double.infinity, height: 0),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildTopBanner(
    BuildContext context,
    VersionState versionState,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.18),
            width: 1.0,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.card,
            AppColors.bgTop,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12.0 : 20.0,
                vertical: isMobile ? 8.0 : 9.0,
              ),
              child: isMobile
                  ? _buildMobileContent(versionState)
                  : _buildDesktopContent(versionState),
            ),
            // Smooth Moving Underline (Animated Shimmer Bar)
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                final t = _shimmerController.value;
                return Container(
                  height: 3.0,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-2.0 + (t * 4.0), 0),
                      end: Alignment(-0.5 + (t * 4.0), 0),
                      colors: const [
                        AppColors.primary,
                        AppColors.accent,
                        Color(0xFF38BDF8),
                        AppColors.accent,
                        AppColors.primary,
                      ],
                      tileMode: TileMode.mirror,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionBadge(VersionState versionState) {
    final label = versionState.fullLatestVersion.isNotEmpty
        ? 'v${versionState.fullLatestVersion}'
        : (versionState.latestVersion?.isNotEmpty == true
            ? 'v${versionState.latestVersion}'
            : '');
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildGradientReloadButton({
    required String label,
    required VoidCallback onPressed,
    IconData? iconData,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      height: fullWidth ? 38 : 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: AppShadows.button,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          iconData ?? (kIsWeb ? Icons.refresh_rounded : Icons.download_rounded),
          size: 15,
          color: Colors.white,
        ),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileContent(VersionState versionState) {
    // 1. Tampilan saat proses unduh APK sedang berlangsung
    if (versionState.isDownloading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mengunduh Pembaruan... ${(versionState.downloadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Text(
                versionState.formatProgressText(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: versionState.downloadProgress > 0
                  ? versionState.downloadProgress
                  : null,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      );
    }

    // 2. Tampilan normal banner
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Pembaruan Sistem Tersedia',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildVersionBadge(versionState),
                ],
              ),
            ),
            if (!versionState.isMandatory)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.muted,
                  size: 18,
                ),
                onPressed: () {
                  ref.read(versionProvider.notifier).dismissUpdateNotification();
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (kIsWeb)
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '⚠️ Simpan pekerjaan Anda terlebih dahulu',
                  style: TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' sebelum memuat ulang halaman.',
                ),
              ],
            ),
          )
        else
          Text(
            versionState.downloadError != null
                ? '⚠️ ${versionState.downloadError}'
                : (versionState.isApkReady
                    ? 'Berkas APK versi baru telah siap dipasang ke perangkat.'
                    : (versionState.releaseNotes?.isNotEmpty == true
                        ? versionState.releaseNotes!
                        : (versionState.isMandatory
                            ? '⚠️ Pembaruan penting wajib diunduh untuk melanjutkan pemakaian aplikasi.'
                            : 'Pembaruan aplikasi versi baru tersedia. Unduh dan pasang langsung dalam aplikasi.'))),
            style: TextStyle(
              color: versionState.downloadError != null
                  ? const Color(0xFFEF4444)
                  : AppColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        const SizedBox(height: 8),
        if (!kIsWeb && versionState.isApkReady)
          _buildGradientReloadButton(
            label: 'Pasang Pembaruan Sekarang',
            iconData: Icons.install_mobile_rounded,
            fullWidth: true,
            onPressed: () => _handleInstallApk(context),
          )
        else
          _buildGradientReloadButton(
            label: kIsWeb
                ? 'Muat Ulang Sekarang'
                : (versionState.downloadError != null
                    ? 'Coba Unduh Ulang'
                    : 'Unduh & Pasang Update'),
            iconData: kIsWeb ? Icons.refresh_rounded : Icons.download_rounded,
            fullWidth: true,
            onPressed: () {
              if (kIsWeb) {
                ref.read(versionProvider.notifier).applyUpdateAndReload();
              } else {
                ref.read(versionProvider.notifier).startDownloadApk();
              }
            },
          ),
      ],
    );
  }

  Widget _buildDesktopContent(VersionState versionState) {
    if (versionState.isDownloading) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Mengunduh Pembaruan... ${(versionState.downloadProgress * 100).toInt()}%',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: versionState.downloadProgress > 0
                    ? versionState.downloadProgress
                    : null,
                minHeight: 7,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            versionState.formatProgressText(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.system_update_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              const Text(
                'Pembaruan Sistem Tersedia',
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
              _buildVersionBadge(versionState),
              const SizedBox(width: 12),
              Expanded(
                child: kIsWeb
                    ? RichText(
                        overflow: TextOverflow.ellipsis,
                        text: const TextSpan(
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                          ),
                          children: [
                            TextSpan(
                              text: '⚠️ Simpan pekerjaan Anda terlebih dahulu',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' sebelum memuat ulang untuk menerapkan pembaruan.',
                            ),
                          ],
                        ),
                      )
                    : Text(
                        versionState.downloadError != null
                            ? '⚠️ ${versionState.downloadError}'
                            : (versionState.isApkReady
                                ? 'Berkas APK versi baru telah siap dipasang ke perangkat.'
                                : (versionState.releaseNotes?.isNotEmpty == true
                                    ? versionState.releaseNotes!
                                    : 'Pembaruan aplikasi versi baru telah tersedia di server.')),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: versionState.downloadError != null
                              ? const Color(0xFFEF4444)
                              : AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        if (!kIsWeb && versionState.isApkReady)
          _buildGradientReloadButton(
            label: 'Pasang Pembaruan',
            iconData: Icons.install_mobile_rounded,
            onPressed: () => _handleInstallApk(context),
          )
        else
          _buildGradientReloadButton(
            label: kIsWeb
                ? 'Muat Ulang'
                : (versionState.downloadError != null
                    ? 'Coba Lagi'
                    : 'Unduh & Pasang'),
            iconData: kIsWeb ? Icons.refresh_rounded : Icons.download_rounded,
            onPressed: () {
              if (kIsWeb) {
                ref.read(versionProvider.notifier).applyUpdateAndReload();
              } else {
                ref.read(versionProvider.notifier).startDownloadApk();
              }
            },
          ),
        if (!versionState.isMandatory) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.muted,
              size: 18,
            ),
            onPressed: () {
              ref.read(versionProvider.notifier).dismissUpdateNotification();
            },
            splashRadius: 18,
          ),
        ],
      ],
    );
  }

  /// Pop-up dialog edukasi dan panduan izin pemasangan APK yang ramah untuk user awam
  void _showInstallGuideDialog(
    BuildContext context,
    VersionState versionState,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !versionState.isMandatory,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.security_update_good_rounded,
                    color: Color(0xFF2563EB),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title & Badge
              const Center(
                child: Text(
                  'Pembaruan Siap Dipasang',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Versi Baru: v${versionState.fullLatestVersion}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Panduan Card Informatif untuk User Awam
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Petunjuk Pemasangan Cepat:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStepRow(
                      '1',
                      'Tekan tombol Lanjutkan Pasang di bawah.',
                    ),
                    const SizedBox(height: 8),
                    _buildStepRow(
                      '2',
                      'Jika muncul peringatan keamanan sistem Android, pilih tombol Setelan / Pengaturan.',
                    ),
                    const SizedBox(height: 8),
                    _buildStepRow(
                      '3',
                      'Aktifkan sakelar "Izinkan dari sumber ini", lalu tekan tombol Kembali dan pilih Instal.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Info Box Keamanan
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aman: Ini adalah prosedur resmi Android untuk memperbarui aplikasi internal perusahaan langsung tanpa melalui Play Store.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF166534),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tombol Aksi
              Row(
                children: [
                  if (!versionState.isMandatory) ...[
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Nanti',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 1,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _handleInstallApk(context);
                      },
                      icon: const Icon(Icons.install_mobile_rounded, size: 18),
                      label: const Text(
                        'Lanjutkan Pasang',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(versionProvider.notifier).openInBrowserFallback();
                  },
                  child: const Text(
                    'Kendala instalasi? Pasang manual lewat Browser',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      decoration: TextDecoration.underline,
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

  Future<void> _handleInstallApk(BuildContext context) async {
    final notifier = ref.read(versionProvider.notifier);

    AppToast.info(
      context,
      'Menyiapkan installer pembaruan...',
      title: 'Memasang Pembaruan',
      duration: const Duration(milliseconds: 1800),
    );

    final res = await notifier.installApk();
    if (!context.mounted) return;

    if (res != null) {
      if (res.isSuccess) {
        AppToast.success(
          context,
          'Membuka installer paket Android...',
          title: 'Pasang Pembaruan',
        );
      } else if (res.isNeedPermission) {
        AppToast.warning(
          context,
          'Harap aktifkan "Izinkan dari sumber ini" di Setelan Android, lalu kembali dan tekan Pasang Pembaruan.',
          title: 'Izin Dibutuhkan',
          duration: const Duration(seconds: 4),
        );
        _showInstallGuideDialog(context, ref.read(versionProvider));
      } else {
        AppToast.error(
          context,
          res.message ?? 'Gagal membuka installer paket.',
          title: 'Pemasangan Gagal',
        );
      }
    }
  }

  Widget _buildStepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2563EB),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
