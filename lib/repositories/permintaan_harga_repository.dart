import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/mutation_result.dart';
import '../models/permintaan_harga_model.dart';
import '../providers/auth_provider.dart';

final permintaanHargaRepositoryProvider =
    Provider<PermintaanHargaRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return PermintaanHargaRepository(api);
});

class PermintaanHargaRepository {
  final ApiClient _api;

  PermintaanHargaRepository(this._api);

  Future<List<PermintaanHargaItem>> getList({
    String? startDate,
    String? endDate,
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _api.dio.get(
        '/permintaan-harga',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data != null && data['data'] is List) {
        return (data['data'] as List)
            .map((item) =>
                PermintaanHargaItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> createPermintaanHargaCustomer(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga/customer',
        data: payload,
      );
      if (response.data != null && response.data['success'] == true) {
        return (response.data['data'] as Map<String, dynamic>?) ?? payload;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<PermintaanHargaDetail?> getDetail(String nomor) async {
    try {
      final response = await _api.dio.get('/permintaan-harga/$nomor');
      final data = response.data;
      if (data != null && data['data'] is Map<String, dynamic>) {
        return PermintaanHargaDetail.fromJson(
            data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, int>> getStatusCounts({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      final response = await _api.dio.get(
        '/permintaan-harga/status-counts',
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

  Future<Map<String, dynamic>?> createPermintaanHarga(
      Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga',
        data: payload,
      );
      if (response.data != null && response.data['success'] == true) {
        return (response.data['data'] as Map<String, dynamic>?) ?? payload;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<MutationResult> updatePermintaanHarga(
      String nomor, Map<String, dynamic> payload) async {
    try {
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.put(
        '/permintaan-harga/$encodedNomor',
        data: payload,
      );
      final body = response.data;
      if (body != null && body['success'] == true) {
        return MutationResult.success(
          message: body['message']?.toString() ?? 'Permintaan harga berhasil diperbarui',
          nomor: nomor,
        );
      }
      return MutationResult.failure(
        message: body?['message']?.toString() ?? 'Gagal memperbarui permintaan harga',
        nomor: nomor,
      );
    } on DioException catch (e) {
      final errorData = e.response?.data;
      String message = 'Gagal memperbarui permintaan harga';
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

  Future<bool> deletePermintaanHarga(String nomor) async {
    try {
      final response = await _api.dio.delete('/permintaan-harga/$nomor');
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> copyPermintaanHarga(
      String nomor, Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga/$nomor/copy',
        data: payload,
      );
      if (response.data != null && response.data['success'] == true) {
        return (response.data['data'] as Map<String, dynamic>?);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadImage(
    String nomor,
    File? file, {
    int slot = 1,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final encodedNomor = Uri.encodeComponent(nomor);
    final String resolvedFilename =
        (fileName != null && fileName.trim().isNotEmpty)
            ? fileName.trim()
            : (file != null
                ? file.path.split(RegExp(r'[/\\]')).last
                : 'mh_${nomor}_$slot.jpg');
    final String ext = resolvedFilename.contains('.')
        ? resolvedFilename.split('.').last.toLowerCase()
        : 'jpg';
    final String subType = (ext == 'png') ? 'png' : 'jpeg';

    final Uint8List bytes;
    if (fileBytes != null) {
      bytes = fileBytes;
    } else if (file != null) {
      bytes = await file.readAsBytes();
    } else {
      return null;
    }

    try {
      final String base64Data =
          'data:image/$subType;base64,${base64Encode(bytes)}';

      final response = await _api.dio.post(
        '/permintaan-harga/$encodedNomor/gambar-base64/$slot',
        data: {
          'file_base64': base64Data,
          'file_name': resolvedFilename,
          'file_type': 'image/$subType',
        },
        options: Options(extra: {'skipDedupe': true}),
      );
      final url = response.data?['data']?['url']?.toString() ??
          response.data?['data']?.toString();
      if (url != null && url.isNotEmpty) return url;
    } catch (e) {
      // ignore: avoid_print
      print('Gagal upload base64 permintaan harga $nomor slot $slot: $e');
    }

    // Fallback ke endpoint internal multipart (bypass blokir status DONE 409 di server lama)
    try {
      final multipartFile = MultipartFile.fromBytes(
        bytes,
        filename: resolvedFilename,
        contentType: DioMediaType('image', subType),
      );
      final formData = FormData.fromMap({'file': multipartFile});
      final response = await _api.dio.post(
        '/permintaan-harga-internal/$encodedNomor/gambar/$slot',
        data: formData,
        options: Options(extra: {'skipDedupe': true}),
      );
      return response.data?['data']?['url']?.toString() ??
          response.data?['data']?.toString();
    } catch (e) {
      // ignore: avoid_print
      print('Gagal upload gambar permintaan harga $nomor slot $slot: $e');
      return null;
    }
  }

  Future<bool> deleteImage(String nomor, {int slot = 1}) async {
    try {
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.delete(
        '/permintaan-harga/$encodedNomor/gambar/$slot',
      );
      return response.data != null && response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPraOrderList(String keyword) async {
    try {
      final response = await _api.dio.get(
        '/permintaan-harga/pra-order',
        queryParameters: {
          if (keyword.trim().isNotEmpty) 'q': keyword.trim(),
          'limit': 30,
        },
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

  Future<Map<String, dynamic>?> getPraOrderDetail(String nomor) async {
    try {
      final encodedNomor = Uri.encodeComponent(nomor);
      final response = await _api.dio.get(
        '/permintaan-harga/pra-order/$encodedNomor',
      );
      if (response.data != null && response.data['data'] is Map) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerSoHistory(String cusKode) async {
    try {
      final response = await _api.dio.get(
        '/penjualan/minta-harga-form/katalog/customer/$cusKode',
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

  Future<Map<String, dynamic>?> getKalkulasiOptions() async {
    try {
      final response = await _api.dio.get('/permintaan-harga/kalkulasi/options');
      if (response.data != null && response.data['data'] is Map) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> calculateSpanduk(
      Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga/kalkulasi/spanduk/calculate',
        data: payload,
      );
      if (response.data != null && response.data['data'] is Map) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> calculateMmt(
      Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga/kalkulasi/mmt/calculate',
        data: payload,
      );
      if (response.data != null && response.data['data'] is Map) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> calculateGarmen(
      Map<String, dynamic> payload) async {
    try {
      final response = await _api.dio.post(
        '/permintaan-harga/kalkulasi/garmen/calculate',
        data: payload,
      );
      if (response.data != null && response.data['data'] is Map) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getJenisKainLookup(
      [String kodeModel = 'KH-0001']) async {
    try {
      final response = await _api.dio.get(
        '/lookups/jenis-kain-minta-harga',
        queryParameters: {'kode': kodeModel},
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

  Future<List<Map<String, dynamic>>> getTambahanLookup(
      [Map<String, dynamic>? params]) async {
    try {
      final response = await _api.dio.get(
        '/lookups/tambahan',
        queryParameters: params,
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

  Future<List<Map<String, dynamic>>> getCetakLookup(
      [Map<String, dynamic>? params]) async {
    try {
      final response = await _api.dio.get(
        '/lookups/cetak',
        queryParameters: params,
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

  Future<List<Map<String, dynamic>>> getOngkirOptions() async {
    try {
      final response =
          await _api.dio.get('/permintaan-harga/kalkulasi/ongkir/options');
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
