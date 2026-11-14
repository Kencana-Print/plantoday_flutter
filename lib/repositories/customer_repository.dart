import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/customer_model.dart';
import '../providers/auth_provider.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return CustomerRepository(api);
});

class CustomerRepository {
  final ApiClient _api;

  CustomerRepository(this._api);

  Future<List<CustomerModel>> getRekapCalonCustomer() async {
    try {
      final response = await _api.dio.get(ApiConfig.rekapCalonCustomer);
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => CustomerModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<CustomerModel>> searchCustomer(String keyword) async {
    try {
      final response = await _api.dio.get(
        '/cari-customer',
        queryParameters: {'search': keyword},
      );
      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => CustomerModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> createCalonCustomer(CustomerModel customer, String userName) async {
    final payload = customer.toJson();
    payload['user_create'] = userName;

    try {
      final response = await _api.dio.post(ApiConfig.calonCustomer, data: payload);
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateCalonCustomer(String ccKode, CustomerModel customer) async {
    final payload = customer.toJson();

    try {
      final response = await _api.dio.put('/update-customer/$ccKode', data: payload);
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> cekCustomerNama(
    String nama, {
    String? excludeKode,
  }) async {
    try {
      final response = await _api.dio.get(
        '/customer/cek-nama',
        queryParameters: {
          'nama': nama,
          if (excludeKode != null && excludeKode.isNotEmpty)
            'exclude_kode': excludeKode,
        },
      );
      final data = response.data;
      if (data != null && data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      return {'isDuplicate': false, 'notice': null, 'matches': []};
    } catch (_) {
      return {'isDuplicate': false, 'notice': null, 'matches': []};
    }
  }

  Future<String?> getRekapCalonCustomerWA(String? keyword) async {
    try {
      final response = await _api.dio.get(
        '/rekap-calon-customer/wa',
        queryParameters: {
          if (keyword != null && keyword.trim().isNotEmpty) 'cc_nama': keyword.trim(),
        },
      );
      return response.data?['wa_text']?.toString();
    } catch (_) {
      return null;
    }
  }
}
