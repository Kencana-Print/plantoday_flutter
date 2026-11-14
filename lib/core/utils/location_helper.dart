import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationHelper {
  /// Mengambil koordinat lokasi GPS yang kompatibel dengan Web Browser dan Mobile.
  /// Memicu dialog izin browser dan memberikan feedback yang jelas ke pengguna.
  static Future<Position?> getCurrentLocation({
    required void Function(String message) onError,
  }) async {
    try {
      // 1. Cek apakah layanan lokasi aktif (khusus mobile)
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          onError('Layanan GPS perangkat belum aktif. Mohon aktifkan GPS.');
          return null;
        }
      }

      // 2. Cek dan minta izin lokasi ke Browser / Perangkat
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError(
            kIsWeb
                ? 'Izin lokasi belum diberikan. Mohon klik "Izinkan" (Allow) pada pop-up izin browser.'
                : 'Izin lokasi ditolak.',
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError(
          kIsWeb
              ? 'Izin lokasi diblokir oleh browser. Silakan klik ikon gembok / perizinan situs pada address bar browser untuk mengizinkan lokasi.'
              : 'Izin lokasi diblokir permanen. Mohon aktifkan izin di pengaturan aplikasi.',
        );
        return null;
      }

      // 3. Konfigurasi setting lokasi yang ramah browser
      // Pada Web Browser di laptop/PC, LocationAccuracy.high seringkali timeout karena tidak ada GPS satelit.
      // Gunakan medium/balanced dan timeout 20 detik agar browser dapat menggunakan WiFi/IP geolocation.
      final LocationSettings locationSettings = kIsWeb
          ? const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            );

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
        return position;
      } catch (locErr) {
        // Fallback untuk browser jika getCurrentPosition sempat gagal
        if (kIsWeb) {
          try {
            final lastPos = await Geolocator.getLastKnownPosition();
            if (lastPos != null) return lastPos;
          } catch (_) {}
        }
        onError(
          kIsWeb
              ? 'Browser belum dapat mendeteksi koordinat lokasi. Anda juga dapat mengetik koordinat manual pada field lokasi.'
              : 'Gagal mengambil koordinat lokasi: $locErr',
        );
        return null;
      }
    } catch (e) {
      onError('Gagal mengakses fitur lokasi: $e');
      return null;
    }
  }
}
