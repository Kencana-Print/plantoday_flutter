import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/kurir_model.dart';
import '../providers/auth_provider.dart';

final kurirRepositoryProvider = Provider<KurirRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return KurirRepository(api);
});

class KurirRepository {
  final ApiClient _api;

  KurirRepository(this._api);

  Future<List<KurirRencanaItem>> getRencanaKirim({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.dio.get(
        ApiConfig.kurirRencanaKirim,
        queryParameters: {
          'tanggal_awal': startDate,
          'tanggal_akhir': endDate,
        },
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => KurirRencanaItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<KurirRencanaItem>> getJadwalKirim({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.dio.get(
        ApiConfig.kurirKirim,
        queryParameters: {
          'tanggal_awal': startDate,
          'tanggal_akhir': endDate,
        },
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => KurirRencanaItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<KurirRencanaItem>> getSelesaiKirim({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.dio.get(
        ApiConfig.kurirKirim,
        queryParameters: {
          'tanggal_awal': startDate,
          'tanggal_akhir': endDate,
          'status': 'delivered',
        },
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => KurirRencanaItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> createPengiriman(Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/kurir/pengiriman',
        data: payload,
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> prosesPengiriman({
    required int id,
    required String catatan,
    double? latitude,
    double? longitude,
    File? photo,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    try {
      final payload = <String, dynamic>{
        'status': 'delivered',
        'catatan': catatan,
      };
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final resStatus = await _api.dio.patch(
        '/kurir/pengiriman/$id/status',
        data: payload,
      );

      final isSuccess =
          resStatus.data != null && resStatus.data['success'] == true;

      if (isSuccess && (photoBytes != null || photo != null)) {
        try {
          final String resolvedFilename = photoName ??
              (photo != null
                  ? photo.path.split(RegExp(r'[/\\]')).last
                  : 'kurir_$id.jpg');
          final String ext = resolvedFilename.split('.').last.toLowerCase();
          final String subType = (ext == 'png') ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');

          final MultipartFile multipartFile;
          if (photoBytes != null) {
            multipartFile = MultipartFile.fromBytes(
              photoBytes,
              filename: resolvedFilename,
              contentType: DioMediaType('image', subType),
            );
          } else {
            multipartFile = await MultipartFile.fromFile(
              photo!.path,
              filename: resolvedFilename,
              contentType: DioMediaType('image', subType),
            );
          }

          final formData = FormData.fromMap({'file': multipartFile});
          await _api.dio.post('/kurir/pengiriman/$id/photo', data: formData);
        } catch (e) {
          // ignore: avoid_print
          print('Gagal upload foto kurir $id: $e');
        }
      }

      return isSuccess;
    } catch (_) {
      return false;
    }
  }
}
