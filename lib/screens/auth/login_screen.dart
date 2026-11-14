import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/asset_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/version_provider.dart';
import '../../widgets/web_shortcut_guide_modal.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPass = false;
  bool _rememberMe = false;
  bool _loading = false;

  String _deviceId = 'unknown';
  String _appVersion = 'Versi 1.0.0 (build 1)';
  String _versiAppShort = 'V. 1.0.0';
  final String _updateStatusText = 'Aplikasi sudah versi terbaru';

  bool get _canLogin =>
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      !_loading;

  @override
  void initState() {
    super.initState();
    _initDeviceAndVersion();
    // Tampilkan panduan pintasan otomatis saat pertama kali buka di web
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(authProvider).sessionExpired) {
        AppToast.warning(
          context,
          'Sesi Anda telah berakhir. Silakan login kembali.',
          title: 'Sesi Berakhir',
        );
      }
      showShortcutGuide(context, auto: true);
    });
  }

  Future<void> _initDeviceAndVersion() async {
    // 1. Ambil Device ID
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

    // 2. Ambil Info Versi Aplikasi
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion =
              'Versi ${packageInfo.version} (build ${packageInfo.buildNumber})';
          _versiAppShort = 'V. ${packageInfo.version}';
        });
      }
    } catch (_) {}

    // 3. Periksa Remember Me & Check-Device API
    final storage = ref.read(tokenStorageProvider);
    final api = ref.read(apiClientProvider);

    try {
      final rememberFlag = await storage.getRememberMeFlag();
      if (mounted) {
        setState(() => _rememberMe = rememberFlag);
      }

      if (!rememberFlag) {
        _usernameController.text = '';
        return;
      }

      final rememberedUser = await storage.getRememberedUsername();
      if (rememberedUser != null && rememberedUser.isNotEmpty) {
        if (mounted) {
          setState(() => _usernameController.text = rememberedUser.toUpperCase());
        }
        return;
      }

      if (_deviceId != 'unknown') {
        final res =
            await api.dio.post('/check-device', data: {'deviceId': _deviceId});
        if (res.data != null &&
            res.data['success'] == true &&
            res.data['username'] != null) {
          final resolved = res.data['username'].toString().trim().toUpperCase();
          if (mounted) {
            setState(() => _usernameController.text = resolved);
          }
          await storage.setRememberedUsername(resolved);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_canLogin) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() => _loading = true);

    final success = await ref.read(authProvider.notifier).login(
      username,
      password,
      deviceId: _deviceId,
      versiApp: _versiAppShort,
    );

    if (mounted) {
      FocusScope.of(context).unfocus();
      setState(() => _loading = false);

      if (success) {
        final storage = ref.read(tokenStorageProvider);
        await storage.setRememberMeFlag(_rememberMe);
        if (_rememberMe) {
          await storage.setRememberedUsername(username);
        } else {
          await storage.clearRememberedUsername();
        }

        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) context.go('/');
      } else {
        final err = ref.read(authProvider).errorMessage ??
            'Login gagal. Periksa kembali akun Anda.';
        AppToast.error(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ResponsiveContainer(
              maxWidth: 420,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // 1. Icon Logo Aplikasi PlanToday Elegan
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color.fromRGBO(15, 23, 42, 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      AppAssets.logo,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. HEADER LOGO Teks Gradient
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: const Text(
                        'PlanToday',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // FORM CARD persis Screenshot Image 1
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color.fromRGBO(15, 23, 42, 0.08),
                        width: 1,
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title LOGIN
                        const Text(
                          'LOGIN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Label USERNAME
                        const Text(
                          'USERNAME',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Input Container USERNAME
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _usernameController,
                            enabled: !_loading,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              TextInputFormatter.withFunction(
                                (oldValue, newValue) => TextEditingValue(
                                  text: newValue.text.toUpperCase(),
                                  selection: newValue.selection,
                                ),
                              ),
                            ],
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: '...',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
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
                        const SizedBox(height: 16),

                        // Label PASSWORD
                        const Text(
                          'PASSWORD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Input Container PASSWORD
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color.fromRGBO(15, 23, 42, 0.06),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: !_showPass,
                                  enabled: !_loading,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _handleLogin(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '***',
                                    hintStyle: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
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
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => _showPass = !_showPass),
                                child: Icon(
                                  _showPass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Remember Me Checkbox
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _loading
                              ? null
                              : () => setState(
                                  () => _rememberMe = !_rememberMe),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: _rememberMe
                                        ? const Color(0xFF4F46E5)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: _rememberMe
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFF94A3B8),
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: _rememberMe
                                      ? const Icon(
                                          Icons.check,
                                          size: 13,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Remember Me',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Tombol Login Gradient
                        Opacity(
                          opacity: _canLogin ? 1.0 : 0.65,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _canLogin ? _handleLogin : null,
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Link Footer Register
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _loading
                              ? null
                              : () => context.push('/register'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text.rich(
                              TextSpan(
                                text: 'Belum punya akun? ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Register',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Catatan Versi & Status
                        () {
                          final versionState = ref.watch(versionProvider);
                          final displayVersion = versionState.currentVersion.isNotEmpty
                              ? 'Versi ${versionState.currentVersion} (build ${versionState.currentBuildNumber})'
                              : _appVersion;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayVersion,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              if (versionState.hasUpdate)
                                InkWell(
                                  onTap: () => ref
                                      .read(versionProvider.notifier)
                                      .applyUpdateAndReload(),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.download_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          kIsWeb
                                              ? 'Pembaruan v${versionState.latestVersion ?? ''} tersedia (Klik muat ulang)'
                                              : 'Pembaruan v${versionState.latestVersion ?? ''} tersedia (Unduh APK)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  _updateStatusText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          );
                        }(),
                        if (kIsWeb) ...[
                          const SizedBox(height: 14),
                          Center(
                            child: Material(
                              color: const Color(0xFFEEF2FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(
                                  color: Color(0xFFE0E7FF),
                                  width: 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => showShortcutGuide(context),
                                borderRadius: BorderRadius.circular(20),
                                hoverColor: const Color(0xFFE0E7FF).withValues(alpha: 0.6),
                                splashColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.devices_rounded,
                                        size: 15,
                                        color: Color(0xFF4F46E5),
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        'Cara Buat Pintasan di HP / PC',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF4338CA),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 15,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
