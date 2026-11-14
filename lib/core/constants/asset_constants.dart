class AppAssets {
  static const String basePath = 'assets/images';

  // Logo Aplikasi
  static const String logo = '$basePath/logo.png';

  // Kop Surat Perusahaan (Header Dokumen)
  static const String kopJaya = '$basePath/jaya.jpg';
  static const String kopKp = '$basePath/kp.jpg';
  static const String kopMadani = '$basePath/madani.jpg';

  // Tanda Tangan Digital & Stempel Penawaran (Signature Asset)
  static const String penawaranSignJaya = '$basePath/pen_ja.jpg';
  static const String penawaranSignKp = '$basePath/pen_kp.jpg';
  static const String penawaranSignMadani = '$basePath/pen_md.jpg';

  // Alias backward-compatibility
  static const String penawaranJaya = penawaranSignJaya;
  static const String penawaranKp = penawaranSignKp;
  static const String penawaranMadani = penawaranSignMadani;

  /// Mendapatkan path gambar kop/header penawaran berdasarkan kode atau nama perusahaan
  static String getPenawaranKop(String perusahaanKodeOrName) {
    final s = perusahaanKodeOrName.toUpperCase().trim();
    if (s.contains('JAY') || s.contains('JA') || s.contains('JAYA ABADI')) {
      return kopJaya;
    } else if (s.contains('MAD') || s.contains('MD') || s.contains('MADANI')) {
      return kopMadani;
    }
    // Default Kencana Print
    return kopKp;
  }

  /// Mendapatkan path gambar tanda tangan digital & stempel penawaran
  static String getPenawaranSign(String perusahaanKodeOrName) {
    final s = perusahaanKodeOrName.toUpperCase().trim();
    if (s.contains('JAY') || s.contains('JA') || s.contains('JAYA ABADI')) {
      return penawaranSignJaya;
    } else if (s.contains('MAD') || s.contains('MD') || s.contains('MADANI')) {
      return penawaranSignMadani;
    }
    // Default Kencana Print
    return penawaranSignKp;
  }

  /// Mendapatkan path gambar kop surat umum berdasarkan kode perusahaan
  static String getKopSurat(String perusahaanKode) {
    final code = perusahaanKode.toUpperCase().trim();
    if (code.contains('JAY') || code.contains('JA') || code.contains('JAYA ABADI')) {
      return kopJaya;
    } else if (code.contains('MAD') || code.contains('MD') || code.contains('MADANI')) {
      return kopMadani;
    }
    // Default Kencana Print
    return kopKp;
  }
}
