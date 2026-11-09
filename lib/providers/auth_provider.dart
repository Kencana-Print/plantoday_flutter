import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/user_model.dart';

/// True jika JWT sudah lewat `exp`. Token yang tidak bisa dibaca dianggap kadaluarsa.
bool isJwtExpired(String token, {DateTime? now}) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is! num) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    return !(now ?? DateTime.now()).isBefore(expiry);
  } catch (_) {
    return true;
  }
}

// Service Provider
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(storage: storage);
});

// Auth State Class
class AuthState {
  final UserModel? user;
  final String? token;
  final bool isLoading;
  final String? errorMessage;
  final bool sessionExpired;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.errorMessage,
    this.sessionExpired = false,
  });

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    UserModel? user,
    String? token,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearToken = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// Auth Notifier
class AuthNotifier extends Notifier<AuthState> {
  late final TokenStorage _storage;
  late final ApiClient _api;

  @override
  AuthState build() {
    _storage = ref.read(tokenStorageProvider);
    _api = ref.read(apiClientProvider);
    _api.onUnauthorized = _expireSession;
    _restoreSession();
    return const AuthState(isLoading: true);
  }

  Future<void> _restoreSession() async {
    final token = await _storage.getToken();
    final user = await _storage.getUser();

    if (token != null && user != null) {
      if (isJwtExpired(token)) {
        await _storage.clearSession();
        state = const AuthState(isLoading: false, sessionExpired: true);
        return;
      }
      state = AuthState(user: user, token: token, isLoading: false);
    } else {
      state = const AuthState(isLoading: false);
    }
  }

  Future<void> _expireSession() async {
    if (!state.isAuthenticated) return; // beberapa request 401 paralel → cukup sekali
    state = const AuthState(isLoading: false, sessionExpired: true);
    await _storage.clearSession();
  }

  Future<bool> login(
    String username,
    String password, {
    String? deviceId,
    String? versiApp,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final payload = <String, dynamic>{
        'username': username,
        'password': password,
      };
      if (deviceId != null) payload['deviceId'] = deviceId;
      if (versiApp != null) payload['versiApp'] = versiApp;

      final response = await _api.dio.post(
        '/login',
        data: payload,
      );

      final data = response.data;
      if (data != null && data['token'] != null) {
        final token = data['token'].toString();
        final userData = UserModel.fromJson(data['user'] as Map<String, dynamic>);

        await _storage.saveToken(token);
        await _storage.saveUser(userData);

        state = AuthState(user: userData, token: token, isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: data['message']?.toString() ?? 'Login gagal',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan saat login: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearSession();
    state = const AuthState(isLoading: false);
  }

  void setUser(UserModel? user) {
    if (user != null) {
      _storage.saveUser(user);
    }
    state = state.copyWith(user: user, clearUser: user == null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
