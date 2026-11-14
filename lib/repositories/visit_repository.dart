import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/visit_model.dart';
import '../providers/auth_provider.dart';

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return VisitRepository(api);
});

class VisitRepository {
  final ApiClient _api;

  VisitRepository(this._api);

  Future<List<VisitModel>> getVisitList({
    required String cabang,
    required String sales,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'user': sales,
        'tanggal_awal': startDate,
        'tanggal_akhir': endDate,
      };
      if (cabang.isNotEmpty) {
        queryParams['cabang'] = cabang;
      }

      final response = await _api.dio.get(
        ApiConfig.rekapVisit,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        final list = data['data'] as List;
        return list
            .map((item) {
              if (item is Map<String, dynamic>) {
                return VisitModel.fromJson(item);
              } else if (item is Map) {
                return VisitModel.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<VisitModel>()
            .toList();
      }
      return [];
    } catch (e, stack) {
      debugPrint('[VisitRepository] getVisitList error: $e\n$stack');
      return [];
    }
  }

  Future<List<VisitModel>> getVisitPlanList({
    required String cabang,
    required String sales,
    required String startDate,
    required String endDate,
    bool isManager = false,
  }) async {
    try {
      if (!isManager && sales.trim().isEmpty) {
        return [];
      }
      if (startDate.trim().isEmpty || endDate.trim().isEmpty) {
        return [];
      }

      final queryParams = <String, dynamic>{
        'user': sales.trim(),
        'cabang': cabang.isNotEmpty ? cabang : 'PUSAT',
        'tanggal_awal': startDate,
        'tanggal_akhir': endDate,
        'is_manager': isManager ? 'true' : 'false',
      };

      final response = await _api.dio.get(
        ApiConfig.rekapVisitPlan,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        final list = data['data'] as List;
        return list
            .map((item) {
              if (item is Map<String, dynamic>) {
                return VisitModel.fromJson(item);
              } else if (item is Map) {
                return VisitModel.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<VisitModel>()
            .toList();
      }
      return [];
    } catch (e, stack) {
      debugPrint('[VisitRepository] getVisitPlanList error: $e\n$stack');
      return [];
    }
  }

  Future<bool> createVisit({
    required String tanggal,
    required String customerKode,
    required String customerNama,
    required String note,
    required String catatan,
    required String cabang,
    required String sales,
    double? latitude,
    double? longitude,
    File? photo,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    try {
      final payload = <String, dynamic>{
        'user': sales,
        'cus_kode': customerKode,
        'tanggal': tanggal,
        'note': note,
        'catatan': catatan,
      };
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final response = await _api.dio.post(ApiConfig.visit, data: payload);
      final isSuccess = response.data != null && response.data['success'] == true;

      final createdId = response.data?['data']?['id'] ?? response.data?['id'];
      if (isSuccess && (photoBytes != null || photo != null) && createdId != null) {
        try {
          final String resolvedFilename = (photoName != null && photoName.isNotEmpty)
              ? photoName
              : (photo != null
                  ? photo.path.split(RegExp(r'[/\\]')).last
                  : 'visit_$createdId.jpg');
          final String ext = resolvedFilename.split('.').last.toLowerCase();
          final String subType = (ext == 'png') ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');

          final MultipartFile multipartFile = photoBytes != null
              ? MultipartFile.fromBytes(
                  photoBytes,
                  filename: resolvedFilename,
                  contentType: DioMediaType('image', subType),
                )
              : await MultipartFile.fromFile(
                  photo!.path,
                  filename: resolvedFilename,
                  contentType: DioMediaType('image', subType),
                );
          final formData = FormData.fromMap({'file': multipartFile});
          await _api.dio.post('${ApiConfig.visit}/$createdId/photo', data: formData);
        } catch (e) {
          // ignore: avoid_print
          print('Gagal upload foto visit $createdId: $e');
        }
      }

      return isSuccess;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateVisit({
    required int id,
    required String note,
    required String catatan,
    required String tanggal,
    double? latitude,
    double? longitude,
    File? photo,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    try {
      final payload = <String, dynamic>{
        'note': note,
        'catatan': catatan,
        'tanggal': tanggal,
      };
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final response = await _api.dio.put('${ApiConfig.visit}/$id', data: payload);
      final isSuccess = response.data != null && response.data['success'] == true;

      if (isSuccess && (photoBytes != null || photo != null)) {
        try {
          final String resolvedFilename = (photoName != null && photoName.isNotEmpty)
              ? photoName
              : (photo != null
                  ? photo.path.split(RegExp(r'[/\\]')).last
                  : 'visit_$id.jpg');
          final String ext = resolvedFilename.split('.').last.toLowerCase();
          final String subType = (ext == 'png') ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');

          final MultipartFile multipartFile = photoBytes != null
              ? MultipartFile.fromBytes(
                  photoBytes,
                  filename: resolvedFilename,
                  contentType: DioMediaType('image', subType),
                )
              : await MultipartFile.fromFile(
                  photo!.path,
                  filename: resolvedFilename,
                  contentType: DioMediaType('image', subType),
                );
          final formData = FormData.fromMap({'file': multipartFile});
          await _api.dio.post('${ApiConfig.visit}/$id/photo', data: formData);
        } catch (e) {
          // ignore: avoid_print
          print('Gagal upload foto update visit $id: $e');
        }
      }

      return isSuccess;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getVisitDraft({
    required String user,
    required String cusKode,
    required String tanggal,
  }) async {
    try {
      final response = await _api.dio.get(
        '/visit/draft',
        queryParameters: {
          'user': user,
          'cus_kode': cusKode,
          'tanggal': tanggal,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && data is Map<String, dynamic>) {
          return data;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> findExistingVisitOrDraft({
    required String user,
    required String cusKode,
    required String tanggal,
  }) async {
    try {
      final rekapResp = await _api.dio.get(
        ApiConfig.rekapVisit,
        queryParameters: {
          'user': user,
          'tanggal': tanggal,
        },
      );
      if (rekapResp.data != null && rekapResp.data['data'] is List) {
        final list = rekapResp.data['data'] as List;
        final foundDone = list.firstWhere(
          (x) => x is Map && x['cus_kode']?.toString().trim() == cusKode.trim(),
          orElse: () => null,
        );
        if (foundDone != null && foundDone is Map<String, dynamic>) {
          return {
            'id': foundDone['id'],
            'note': foundDone['note'] ?? '',
            'catatan': foundDone['catatan'] ?? '',
            'status': 'DONE',
          };
        }
      }
    } catch (_) {}

    try {
      final draft = await getVisitDraft(
        user: user,
        cusKode: cusKode,
        tanggal: tanggal,
      );
      if (draft != null && draft['id'] != null) {
        return {
          'id': draft['id'],
          'note': draft['note'] ?? '',
          'catatan': draft['catatan'] ?? '',
          'status': 'DRAFT',
        };
      }
    } catch (_) {}

    return null;
  }

  Future<bool> createVisitPlan({
    required String cusKode,
    required String user,
    required String tanggalPlan,
    required String note,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final payload = <String, dynamic>{
        'cus_kode': cusKode,
        'user': user,
        'tanggal_plan': tanggalPlan,
        'note': note,
      };
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final response = await _api.dio.post(ApiConfig.visitPlan, data: payload);
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateVisitPlan({
    required int id,
    required String tanggalPlan,
    required String note,
    String? catatan,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final payload = <String, dynamic>{
        'tanggal_plan': tanggalPlan,
        'note': note,
      };
      if (catatan != null) payload['catatan'] = catatan;
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final response = await _api.dio.put('${ApiConfig.visitPlan}/$id', data: payload);
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getRekapVisitPlanWA({
    required String user,
    required String cabang,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.dio.get(
        '/rekap-visit-plan/wa',
        queryParameters: {
          'user': user,
          'cabang': cabang,
          'tanggal_awal': startDate,
          'tanggal_akhir': endDate,
        },
      );
      return response.data?['wa_text']?.toString() ??
          response.data?['data']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRekapVisitWA({
    required String user,
    required String cabang,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _api.dio.get(
        '/rekap-visit/wa',
        queryParameters: {
          'user': user,
          'cabang': cabang,
          'tanggal_awal': startDate,
          'tanggal_akhir': endDate,
        },
      );
      return response.data?['wa_text']?.toString() ??
          response.data?['data']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getSalesByCabang(String cabang) async {
    try {
      final response = await _api.dio.get(
        '/karyawan',
        queryParameters: {'cabang': cabang},
      );
      final raw = response.data?['data'] ?? response.data;
      if (raw is List) {
        final names = raw
            .where((x) =>
                x['kar_jabatan']?.toString().toUpperCase() == 'SALES')
            .map((x) => x['kar_nama']?.toString().trim() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        return names;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRekapVisitPlanDetail(int id) async {
    try {
      final response = await _api.dio.get('/rekap-visit-plan/$id');
      if (response.data != null && response.data['data'] != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateRekapVisitPlanNote(int id, String note) async {
    try {
      final response = await _api.dio.put(
        '/rekap-visit-plan/$id/note',
        data: {'note': note},
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}

