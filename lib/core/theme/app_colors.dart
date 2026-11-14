import 'package:flutter/material.dart';

/// Design tokens sesuai DESIGN.md PlanToday Mobile
class AppColors {
  // Brand
  static const Color primary = Color(0xFF4F46E5); // Indigo (#4F46E5)
  static const Color accent = Color(0xFF06B6D4); // Cyan (#06B6D4)

  // Feedback
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0369A1);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningBorder = Color(0xFFFCD34D);
  static const Color warningText = Color(0xFF92400E);
  static const Color wa = Color(0xFF22C55E); // Hijau WhatsApp

  // Neutral
  static const Color ink = Color(0xFF0F172A); // Slate gelap (Teks utama)
  static const Color muted = Color(0xFF64748B); // Slate abu-abu (Teks sekunder)
  static const Color card = Color(0xFFFFFFFF);
  static const Color soft = Color(0xFFF1F5F9); // Latar lembut
  static const Color border = Color(0x140F172A); // rgba(15,23,42,0.08)
  static const Color overlay = Color(0x730F172A); // rgba(15,23,42,0.45)
  static const Color bgTop = Color(0xFFF7F9FF);
  static const Color bgBottom = Color(0xFFFFFFFF);
}

/// Token Status Transaksi Penawaran
class StatusColors {
  static const Color wait = Color(0xFFD97706); // Menunggu
  static const Color acc = Color(0xFF16A34A); // Diterima / Selesai
  static const Color tolak = Color(0xFFDC2626); // Ditolak
}

/// Token Status Perusahaan / Divisi
class CompanyStatusToken {
  final Color base;
  final Color text;
  final Color unselectedBg;
  final Color unselectedBorder;
  final Color unselectedText;

  const CompanyStatusToken({
    required this.base,
    required this.text,
    Color? unselectedBg,
    Color? unselectedBorder,
    Color? unselectedText,
  }) : unselectedBg = unselectedBg ?? const Color(0xFFF1F5F9),
       unselectedBorder = unselectedBorder ?? const Color(0xFFCBD5E1),
       unselectedText = unselectedText ?? text;
}

class CompanyStatusColors {
  static const belum = CompanyStatusToken(
    base: Color(0xFF6B7280),
    text: Color(0xFF374151),
    unselectedBg: Color(0xFFF8FAFC),
    unselectedBorder: Color(0xFFE2E8F0),
    unselectedText: Color(0xFF475569),
  );
  static const minta = CompanyStatusToken(
    base: Color(0xFFDC2626),
    text: Color(0xFF991B1B),
    unselectedBg: Color(0xFFFEF2F2),
    unselectedBorder: Color(0xFFFECACA),
    unselectedText: Color(0xFFDC2626),
  );
  static const wait = CompanyStatusToken(
    base: Color(0xFF16A34A),
    text: Color(0xFF15803D),
    unselectedBg: Color(0xFFF0FDF4),
    unselectedBorder: Color(0xFFBBF7D0),
    unselectedText: Color(0xFF15803D),
  );
  static const belumDiverifikasi = CompanyStatusToken(
    base: Color(0xFFE65100),
    text: Color(0xFFBF360C),
    unselectedBg: Color(0xFFFFF3E0),
    unselectedBorder: Color(0xFFFFCC80),
    unselectedText: Color(0xFFE65100),
  );
  static const nego = CompanyStatusToken(
    base: Color(0xFF6B21A8),
    text: Color(0xFF4A044E),
    unselectedBg: Color(0xFFFAF5FF),
    unselectedBorder: Color(0xFFE9D5FF),
    unselectedText: Color(0xFF6B21A8),
  );
  static const done = CompanyStatusToken(
    base: Color(0xFF18181B),
    text: Color(0xFF09090B),
    unselectedBg: Color(0xFFF1F5F9),
    unselectedBorder: Color(0xFFCBD5E1),
    unselectedText: Color(0xFF18181B),
  );
  static const cancel = CompanyStatusToken(
    base: Color(0xFF2563EB),
    text: Color(0xFF1D4ED8),
    unselectedBg: Color(0xFFEFF6FF),
    unselectedBorder: Color(0xFFBFDBFE),
    unselectedText: Color(0xFF1D4ED8),
  );
  static const def = CompanyStatusToken(
    base: Color(0xFF6366F1),
    text: Color(0xFF4F46E5),
    unselectedBg: Color(0xFFEEF2FF),
    unselectedBorder: Color(0xFFC7D2FE),
    unselectedText: Color(0xFF4338CA),
  );
}

class PermintaanHargaStatusHelper {
  static CompanyStatusToken getToken(String status) {
    switch (status.toUpperCase().trim()) {
      case 'BELUM DIVERIFIKASI':
      case 'BELUM_DIVERIFIKASI':
      case 'VERIF':
        return CompanyStatusColors.belumDiverifikasi;
      case 'BELUM':
        return CompanyStatusColors.belum;
      case 'MINTA':
        return CompanyStatusColors.minta;
      case 'WAIT':
        return CompanyStatusColors.wait;
      case 'NEGO':
        return CompanyStatusColors.nego;
      case 'DONE':
      case 'SELESAI':
        return CompanyStatusColors.done;
      case 'CANCEL':
        return CompanyStatusColors.cancel;
      default:
        return CompanyStatusColors.def;
    }
  }

  static String getDescription(String status) {
    switch (status.toUpperCase().trim()) {
      case 'BELUM DIVERIFIKASI':
      case 'BELUM_DIVERIFIKASI':
      case 'VERIF':
        return 'Menunggu verifikasi dari Finance';
      case 'BELUM':
        return 'Pengajuan ke MO terlebih dahulu';
      case 'MINTA':
        return 'Sedang dimintakan harga ke Finance';
      case 'WAIT':
        return 'Sudah diproses, menunggu acc';
      case 'NEGO':
        return 'Permintaan harga dibawah standar kalkulasi';
      case 'DONE':
      case 'SELESAI':
        return 'Permintaan harga telah selesai diproses';
      case 'CANCEL':
        return 'Permintaan harga dibatalkan';
      default:
        return '-';
    }
  }
}

class AppRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double card = 24.0;
}

class AppShadows {
  // Layered subtle shadow ala shadcn / Tailwind (elevation halus tanpa warna hitam pekat)
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.03),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.05),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> softCard = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.02),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.04),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color.fromRGBO(79, 70, 229, 0.20),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];
}
