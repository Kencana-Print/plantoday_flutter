import 'package:flutter/material.dart';

/// Helper responsif standar PlanToday (Mobile, Tablet, Desktop)
class ResponsiveHelper {
  // Breakpoint baku
  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1000.0;

  // Preset batas lebar baku (Desktop & Tablet)
  static const double maxContentWidth = 1100.0;     // Halaman List, Dashboard, Tracking, Rekap
  static const double maxFormWidth = 880.0;          // Halaman Form, Create, Edit, Detail Dokumen
  static const double maxTabletWidth = 760.0;        // Batas container halaman list di tablet
  static const double maxTabletFormWidth = 720.0;    // Batas container form di tablet
  static const double maxAuthWidth = 440.0;          // Login, Register, Ganti Password
  static const double maxDialogWidth = 520.0;        // Dialog Popup Modal

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// Lebar container otomatis untuk halaman list/browse/dashboard
  static double contentWidth(BuildContext context) {
    if (isDesktop(context)) return maxContentWidth;
    if (isTablet(context)) return maxTabletWidth;
    return double.infinity;
  }

  /// Lebar container otomatis untuk halaman form/create/detail
  static double formWidth(BuildContext context) {
    if (isDesktop(context)) return maxFormWidth;
    if (isTablet(context)) return maxTabletFormWidth;
    return double.infinity;
  }

  /// Padding horizontal terstandarisasi antar layar
  static double horizontalPadding(BuildContext context) {
    if (isDesktop(context)) return 32.0;
    if (isTablet(context)) return 24.0;
    return 16.0;
  }

  /// Nilai dinamis berdasarkan breakpoint layar aktif
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }
}

/// Widget pembangun tata letak adaptif (Mobile, Tablet, Desktop)
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context) && desktop != null) {
      return desktop!;
    }
    if (ResponsiveHelper.isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

/// Container pembatas lebar maksimal (terpusat) untuk Tablet dan Desktop
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveHelper.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
