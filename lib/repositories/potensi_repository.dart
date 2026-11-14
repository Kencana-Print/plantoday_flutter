import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/potensi_kandidat_model.dart';
import '../models/potensi_model.dart';
import '../providers/auth_provider.dart';

final potensiRepositoryProvider = Provider<PotensiRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return PotensiRepository(api);
});

class PotensiResult {
  final List<PotensiListItem> list;
  final PotensiKpiSummary? kpi;

  const PotensiResult({required this.list, this.kpi});
}

class PotensiRepository {
  final ApiClient _api;

  PotensiRepository(this._api);

  Future<PotensiResult> getPotensiList({
    String? startDate,
    String? endDate,
    String? status,
    String? search,
    String? sales,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (sales != null && sales.isNotEmpty) queryParams['sales'] = sales;

      final response = await _api.dio.get(
        '/potensi',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null) {
        final list = (data['data'] as List? ?? [])
            .map((item) => PotensiListItem.fromJson(item as Map<String, dynamic>))
            .toList();

        PotensiKpiSummary? kpi;
        if (data['meta']?['kpi_summary'] != null) {
          kpi = PotensiKpiSummary.fromJson(
            data['meta']['kpi_summary'] as Map<String, dynamic>,
          );
        } else if (list.isNotEmpty) {
          final totalCount = list.length;
          final closeCount = list.where((x) => x.status == 'CLOSE').length;
          final batalCount = list.where((x) => x.status == 'BATAL').length;
          final openCount = totalCount - closeCount - batalCount;
          final totalNominal = list.fold<double>(0.0, (acc, x) => acc + x.harga);
          final closeNominal = list.where((x) => x.status == 'CLOSE').fold<double>(0.0, (acc, x) => acc + x.harga);
          final openNominal = list.where((x) => x.status == 'POTENSI' || x.status == 'OPEN').fold<double>(0.0, (acc, x) => acc + x.harga);
          final batalNominal = list.where((x) => x.status == 'BATAL').fold<double>(0.0, (acc, x) => acc + x.harga);
          final closingRatePct = totalCount > 0 ? (closeCount / totalCount) * 100 : 0.0;
          kpi = PotensiKpiSummary(
            totalCount: totalCount,
            openCount: openCount,
            closeCount: closeCount,
            batalCount: batalCount,
            totalNominal: totalNominal,
            openNominal: openNominal,
            closeNominal: closeNominal,
            batalNominal: batalNominal,
            closingRatePct: closingRatePct,
          );
        }

        return PotensiResult(list: list, kpi: kpi);
      }
      return const PotensiResult(list: []);
    } catch (_) {
      return const PotensiResult(list: []);
    }
  }

  Future<bool> batalPotensi(String nomor, String alasan) async {
    try {
      // Backend route is POST /potensi/:pot_nomor/batal
      final response = await _api.dio.post(
        '/potensi/$nomor/batal',
        data: {'alasan': alasan},
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<PotensiKandidatItem>> getPotensiKandidatList({
    String? sales,
    String? search,
    String sumber = 'ALL',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'sumber': sumber,
      };
      if (sales != null && sales.isNotEmpty) queryParams['sales'] = sales;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _api.dio.get(
        '/potensi/kandidat',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => PotensiKandidatItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> createPotensiBatch(List<Map<String, dynamic>> items) async {
    try {
      final response = await _api.dio.post(
        '/potensi',
        data: {'items': items},
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
