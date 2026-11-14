import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/achievement_model.dart';
import '../providers/auth_provider.dart';

final achievementRepositoryProvider = Provider<AchievementRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AchievementRepository(api);
});

class AchievementRepository {
  final ApiClient _api;

  AchievementRepository(this._api);

  Future<List<AchievementUserRow>> getOmsetRange({
    required int fromYear,
    required int fromMonth,
    required int toYear,
    required int toMonth,
  }) async {
    try {
      final response = await _api.dio.get(
        '/achievement/omset/range',
        queryParameters: {
          'fromYear': fromYear,
          'fromMonth': fromMonth,
          'toYear': toYear,
          'toMonth': toMonth,
        },
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => AchievementUserRow.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<AchievementMonthlyItem>> getMonthlyOmsetByUser({
    required String kode,
    required String fromYm,
    required String toYm,
  }) async {
    try {
      final response = await _api.dio.get(
        '/achievement/omset/month/$kode',
        queryParameters: {
          'from': fromYm,
          'to': toYm,
        },
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => AchievementMonthlyItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
