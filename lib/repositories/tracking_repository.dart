import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/tracking_model.dart';
import '../providers/auth_provider.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return TrackingRepository(api);
});

class TrackingRepository {
  final ApiClient _api;

  TrackingRepository(this._api);

  Future<List<TrackingPenawaranListItem>> getTrackingPenawaranList({
    String? startDate,
    String? endDate,
    String? search,
    String? sales,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (sales != null && sales.isNotEmpty) queryParams['sales'] = sales;

      final response = await _api.dio.get(
        '/tracking-penawaran',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => TrackingPenawaranListItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<TrackingMapDetailItem>> getTrackingPenawaranDetail(String noPenawaran) async {
    try {
      final encoded = Uri.encodeComponent(noPenawaran);
      final response = await _api.dio.get('/tracking-penawaran/$encoded');
      final data = response.data;
      final rawDetails = data?['data']?['map_details'] ?? data?['map_details'];
      if (rawDetails is List) {
        return rawDetails
            .map((item) => TrackingMapDetailItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<TrackingMapListItem>> getTrackingMapList({
    String? startDate,
    String? endDate,
    String? search,
    String? sales,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (sales != null && sales.isNotEmpty) queryParams['sales'] = sales;

      final response = await _api.dio.get(
        '/tracking-map',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => TrackingMapListItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<TrackingSpkListItem>> getTrackingSpkList({
    String? startDate,
    String? endDate,
    String? search,
    String? sales,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (sales != null && sales.isNotEmpty) queryParams['sales'] = sales;

      final response = await _api.dio.get(
        '/tracking-spk',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => TrackingSpkListItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, int>> getTrackingPenawaranStatusCounts({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _api.dio.get(
        '/tracking-penawaran/status-counts',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is Map) {
        final map = <String, int>{};
        (data['data'] as Map).forEach((k, v) {
          map[k.toString().toUpperCase()] = (v as num?)?.toInt() ?? 0;
        });
        return map;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, int>> getTrackingSpkStatusCounts({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _api.dio.get(
        '/tracking-spk/status-counts',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is Map) {
        final map = <String, int>{};
        (data['data'] as Map).forEach((k, v) {
          map[k.toString().toUpperCase()] = (v as num?)?.toInt() ?? 0;
        });
        return map;
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
