import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../models/user_model.dart';

class TokenStorage {
  static const _tokenKey = StorageKeys.token;
  static const _userKey = StorageKeys.userData;
  static const _rememberMeFlagKey = 'remember_me_flag';
  static const _rememberedUsernameKey = 'remembered_username';
  static const _rememberMeKey = StorageKeys.rememberMe;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Map<String, String> _memoryStorage = {};

  // Simpan Token (Web-safe: gunakan SharedPreferences di Web untuk menghindari crash Web Crypto API di HTTP)
  Future<void> saveToken(String token) async {
    _memoryStorage[_tokenKey] = token;
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
      } catch (_) {}
      return;
    }
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
      } catch (_) {}
    }
  }

  // Ambil Token (Web-safe)
  Future<String?> getToken() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_tokenKey) ?? _memoryStorage[_tokenKey];
      } catch (_) {
        return _memoryStorage[_tokenKey];
      }
    }
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token != null) return token;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey) ?? _memoryStorage[_tokenKey];
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_tokenKey) ?? _memoryStorage[_tokenKey];
      } catch (_) {
        return _memoryStorage[_tokenKey];
      }
    }
  }

  // Simpan Data User
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  // Ambil Data User
  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userKey);
    if (jsonStr == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // Hapus Sesi (Logout)
  Future<void> clearSession() async {
    _memoryStorage.remove(_tokenKey);
    try {
      if (!kIsWeb) {
        await _secureStorage.delete(key: _tokenKey);
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // Remember Me Persistence sesuai React Native rememberMeStorage.tsx
  Future<void> setRememberMeFlag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeFlagKey, value);
  }

  Future<bool> getRememberMeFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeFlagKey) ?? false;
  }

  Future<void> setRememberedUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberedUsernameKey, username);
  }

  Future<String?> getRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedUsernameKey);
  }

  Future<void> clearRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedUsernameKey);
  }

  // Legacy helper
  Future<void> saveRememberMe({required String username, required String password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberMeKey, jsonEncode({'username': username, 'password': password}));
  }

  Future<Map<String, String>?> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_rememberMeKey);
    if (data == null) return null;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return {
        'username': map['username'] as String? ?? '',
        'password': map['password'] as String? ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
  }
}
