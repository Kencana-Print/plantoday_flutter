import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/token_storage.dart';

class ApiClient {
  late final Dio dio;
  final TokenStorage tokenStorage;

  // In-flight mutation deduplication set (seperti di React Native api.tsx)
  static final Set<String> _inFlightMutationKeys = <String>{};
  static const Set<String> _mutatingMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

  // Dipanggil saat server membalas 401 (token kadaluarsa / akun nonaktif).
  void Function()? onUnauthorized;

  ApiClient({TokenStorage? storage}) : tokenStorage = storage ?? TokenStorage() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-App-Client': 'PlanToday-Flutter',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 1. Inject Token Auth jika ada
          final token = await tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // 2. Mutation Request Deduplication Guard
          final method = options.method.toUpperCase();
          final skipDedupe = options.extra['skipDedupe'] == true;

          // Hapus Content-Type application/json jika data adalah FormData agar Dio
          // otomatis membuat Content-Type: multipart/form-data beserta boundary yang valid
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
            options.contentType = null;
          }

          if (!_mutatingMethods.contains(method) || skipDedupe) {
            return handler.next(options);
          }

          final requestKey = _buildRequestKey(options);
          if (_inFlightMutationKeys.contains(requestKey)) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Permintaan sedang diproses. Mohon tunggu.',
                type: DioExceptionType.unknown,
              ),
            );
          }

          _inFlightMutationKeys.add(requestKey);
          options.extra['__mutationRequestKey'] = requestKey;
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final key = response.requestOptions.extra['__mutationRequestKey'] as String?;
          if (key != null) {
            _inFlightMutationKeys.remove(key);
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          final key = error.requestOptions.extra['__mutationRequestKey'] as String?;
          if (key != null) {
            _inFlightMutationKeys.remove(key);
          }
          final hadToken =
              error.requestOptions.headers['Authorization'] != null;
          if (error.response?.statusCode == 401 &&
              hadToken &&
              !error.requestOptions.path.contains('/login')) {
            onUnauthorized?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  static String _buildRequestKey(RequestOptions options) {
    final method = options.method.toLowerCase();
    final url = options.path;
    final params = jsonEncode(options.queryParameters);
    String dataStr = '';
    if (options.data != null) {
      if (options.data is FormData) {
        dataStr = 'form_data_${options.data.hashCode}';
      } else {
        try {
          dataStr = jsonEncode(options.data);
        } catch (_) {
          dataStr = options.data.toString();
        }
      }
    }
    return '$method|$url|$params|$dataStr';
  }
}
