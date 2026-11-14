import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ??
      const String.fromEnvironment('API_BASE_URL');

  // Auth & User
  static const String login = '/login';
  static const String register = '/register';
  static const String gantiPassword = '/ganti-password';

  // Customer & CRM
  static const String rekapCalonCustomer = '/rekap-calon-customer';
  static const String calonCustomer = '/calon-customer';
  static const String visit = '/visits';
  static const String rekapVisit = '/rekap-visit';
  static const String visitPlan = '/visit-plan';
  static const String rekapVisitPlan = '/rekap-visit-plan';

  // Penawaran & Tracking
  static const String penawaran = '/penawaran';
  static const String trackingPenawaran = '/tracking-penawaran';
  static const String trackingMap = '/tracking-map';
  static const String trackingSpk = '/tracking-spk';

  // Permintaan Harga & Potensi
  static const String permintaanHarga = '/permintaan-harga';
  static const String potensi = '/potensi';

  // Kurir & Achievement
  static const String kurir = '/kurir';
  static const String kurirRencanaKirim = '/kurir/rencana-kirim';
  static const String kurirKirim = '/kurir/kirim';
  static const String achievement = '/achievement';

  // Media / Gambar
  static String get imageReadUrl =>
      dotenv.env['IMAGE_READ_URL'] ??
      const String.fromEnvironment('IMAGE_READ_URL');

  static String get imageUploadUrl =>
      dotenv.env['IMAGE_UPLOAD_URL'] ??
      const String.fromEnvironment('IMAGE_UPLOAD_URL');

  static String get imageBasePath =>
      dotenv.env['IMAGE_BASE_PATH'] ??
      const String.fromEnvironment(
        'IMAGE_BASE_PATH',
        defaultValue: '/images/mintaharga',
      );

  // Update Check URL
  static String get updateCheckUrl {
    final configured = dotenv.env['UPDATE_CHECK_URL'] ??
        const String.fromEnvironment('UPDATE_CHECK_URL');
    if (configured.isNotEmpty) return configured;
    final base = imageReadUrl.isNotEmpty ? imageReadUrl : 'http://103.94.238.252:8182';
    return '$base/releases/latest.json';
  }

  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String gantiPassword = '/ganti-password';

  // Customer
  static const String customer = '/customer';

  // Visit
  static const String visit = '/visit';
  static const String tambahVisit = '/visit/tambah';
  static const String visitPlan = '/visit-plan';

  // Penawaran
  static const String penawaran = '/penawaran';
  static const String trackingPenawaran = '/tracking-penawaran';
  static const String trackingMap = '/tracking-map';
  static const String trackingSpk = '/tracking-spk';

  // Permintaan Harga
  static const String permintaanHarga = '/permintaan-harga';
  static const String permintaanHargaKalkulasi = '/permintaan-harga/kalkulasi';

  // Potensi & Achievement
  static const String potensi = '/potensi';
  static const String achievement = '/achievement';

  // Kurir
  static const String kurir = '/kurir';
}

class StorageKeys {
  static const String token = 'auth_token';
  static const String userData = 'auth_user';
  static const String rememberMe = 'remember_me';
}
