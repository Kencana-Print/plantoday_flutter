import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'web_compress_stub.dart'
    if (dart.library.js_interop) 'web_compress_web.dart' as web_compress;

class CompressedImageResult {
  final Uint8List bytes;
  final String name;

  const CompressedImageResult({
    required this.bytes,
    required this.name,
  });
}

/// Helper utilitas untuk kompresi gambar di sisi Frontend (Flutter) sebelum dikirim ke server.
/// Membatasi resolusi dan kualitas gambar saat pengambilan agar ukuran file berkurang ke kisaran 100-300 KB (< 500 KB).
class ImageCompressHelper {
  static const double maxWidth = 1024;
  static const double maxHeight = 1024;
  static const int imageQuality = 70;
  static const int targetMaxSizeBytes = 500 * 1024; // 500 KB

  /// Memilih gambar dari kamera atau galeri dengan kompresi bawaan platform.
  static Future<XFile?> pickCompressedImage(
    ImagePicker picker, {
    required ImageSource source,
  }) async {
    return await picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  /// Memilih dan memastikan bytes terkompresi dengan baik di Mobile maupun Web.
  /// Di Web (kIsWeb), image_picker sering mengabaikan maxWidth/imageQuality,
  /// fungsi ini akan meresize ulang gambar via canvas HTML menjadi JPEG ukuran optimal.
  static Future<CompressedImageResult?> pickAndCompress(
    ImagePicker picker, {
    required ImageSource source,
  }) async {
    final picked = await pickCompressedImage(picker, source: source);
    if (picked == null) return null;

    final rawBytes = await picked.readAsBytes();

    if (kIsWeb) {
      final processedBytes = await web_compress.compressImageForWeb(
        rawBytes,
        maxWidth: maxWidth.toInt(),
        maxHeight: maxHeight.toInt(),
        quality: imageQuality / 100.0,
      );
      final finalName = picked.name.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
      return CompressedImageResult(
        bytes: processedBytes,
        name: finalName,
      );
    }

    return CompressedImageResult(
      bytes: rawBytes,
      name: picked.name,
    );
  }
}
