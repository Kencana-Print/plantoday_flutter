import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/mutation_result.dart';
import '../models/penawaran_model.dart';
import '../providers/auth_provider.dart';

final penawaranRepositoryProvider = Provider<PenawaranRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return PenawaranRepository(api);
});

class PenawaranRepository {
  final ApiClient _api;

  PenawaranRepository(this._api);

  Future<List<PenawaranListItem>> getPenawaranList({
    String? startDate,
    String? endDate,
    String? status,
    String? search,
    String? salesKode,
    String? approvalStatus,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (salesKode != null && salesKode.isNotEmpty) queryParams['sales_kode'] = salesKode;
      if (approvalStatus != null && approvalStatus.isNotEmpty) queryParams['approval_status'] = approvalStatus;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _api.dio.get(
        '/penawaran',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => PenawaranListItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<PenawaranDetailData?> getPenawaranDetail(String nomor) async {
    try {
      // Backend route is GET /penawaran/:nomor dengan URL encoded component
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.get('/penawaran/$encodedNomor');
      final data = response.data;
      if (data != null && data['data'] != null) {
        final payload = data['data'];

        PenawaranHeader? header;
        if (payload['header'] != null && payload['header'] is Map<String, dynamic>) {
          header = PenawaranHeader.fromJson(payload['header'] as Map<String, dynamic>);
        }

        final detailsRaw = payload['details'] ?? (payload is List ? payload : []);
        final details = (detailsRaw as List? ?? [])
            .map((item) => PenawaranDetailItem.fromJson(item as Map<String, dynamic>))
            .toList();

        return PenawaranDetailData(header: header, details: details);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<PenawaranActivityLog>> getPenawaranActivityLogs(String nomor) async {
    try {
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.get('/penawaran/$encodedNomor/activity-logs');
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => PenawaranActivityLog.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> approvePenawaran(String nomor, {String note = ''}) async {
    try {
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.post(
        '/penawaran/$encodedNomor/approve',
        data: {'note': note},
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> createPenawaran(Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/penawaran',
        data: payload,
      );
      if (response.data != null && response.data['success'] == true) {
        return response.data['data']?['nomor']?.toString() ??
            response.data['nomor']?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<MutationResult> updatePenawaran(
    String nomor,
    Map<String, dynamic> payload,
  ) async {
    try {
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.put(
        '/penawaran/$encodedNomor',
        data: payload,
      );
      final body = response.data;
      if (body != null && body['success'] == true) {
        return MutationResult.success(
          message: body['message']?.toString() ?? 'Penawaran berhasil diperbarui',
          nomor: body['data']?['nomor']?.toString() ?? nomor,
        );
      }
      return MutationResult.failure(
        message: body?['message']?.toString() ?? 'Gagal memperbarui penawaran',
        nomor: nomor,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data;
      String message = 'Gagal memperbarui penawaran';
      if (errorData is Map && errorData['message'] != null) {
        message = errorData['message'].toString();
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }
      return MutationResult.failure(message: message, nomor: nomor);
    } catch (e) {
      return MutationResult.failure(message: e.toString(), nomor: nomor);
    }
  }

  Future<Map<String, dynamic>> getMasterPermintaanHargaForPenawaran({
    required String salesKode,
    String? customerKode,
    String search = '',
    int limit = 20,
    int page = 1,
    String? nomor,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'sales_kode': salesKode,
        'limit': limit,
        'page': page,
        'status': 'DONE',
      };
      if (customerKode != null && customerKode.trim().isNotEmpty) {
        queryParams['customer_kode'] = customerKode.trim();
      }
      if (search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (nomor != null && nomor.trim().isNotEmpty) {
        queryParams['nomor'] = nomor.trim();
      }
      final response = await _api.dio.get(
        '/penawaran/master/permintaan-harga',
        queryParameters: queryParams,
      );
      final data = response.data;
      if (data != null && data['data'] is Map<String, dynamic>) {
        final innerData = data['data'] as Map<String, dynamic>;
        final rawOptions = innerData['options'] as List<dynamic>? ?? [];
        final options = rawOptions
            .whereType<Map<String, dynamic>>()
            .toList();
        final selected = innerData['selected'] as Map<String, dynamic>?;
        return {
          'options': options,
          'selected': selected,
        };
      }
      return {'options': <Map<String, dynamic>>[], 'selected': null};
    } catch (_) {
      return {'options': <Map<String, dynamic>>[], 'selected': null};
    }
  }

  Future<bool> updatePenawaranStatusDetail(
    String nomor,
    List<Map<String, dynamic>> updates,
  ) async {
    try {
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.put(
        '/penawaran/$encodedNomor/status',
        data: {'updates': updates},
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, String>>> getMasterPenawaranBatal() async {
    try {
      final response = await _api.dio.get('/penawaran/master/batal');
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => {
                  'kode': item['kode']?.toString() ?? '',
                  'nama': item['nama']?.toString() ?? '',
                })
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, String>>> getMasterPenawaranConfirm() async {
    try {
      final response = await _api.dio.get('/penawaran/master/confirm');
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => {
                  'kode': item['kode']?.toString() ?? '',
                  'nama': item['nama']?.toString() ?? '',
                })
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> requestApprovalPerubahan(
    String nomor, {
    required String alasan,
  }) async {
    try {
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.post(
        '/penawaran/$encodedNomor/pengajuan-perubahan',
        data: {'alasan': alasan},
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, String>>> getMasterSales(String search) async {
    try {
      final response = await _api.dio.get(
        '/penawaran/master/sales',
        queryParameters: {'search': search},
      );
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => {
                  'kode': item['kode']?.toString() ?? item['sal_kode']?.toString() ?? '',
                  'nama': item['nama']?.toString() ?? item['sal_nama']?.toString() ?? '',
                })
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, String>>> getMasterPerusahaan() async {
    try {
      final response = await _api.dio.get('/penawaran/master/perusahaan');
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => {
                  'kode': item['kode']?.toString() ?? '',
                  'nama': item['nama']?.toString() ?? '',
                })
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMasterPenawaranNomor(String search) async {
    try {
      final response = await _api.dio.get(
        '/penawaran/master/nomor',
        queryParameters: {'search': search},
      );
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
