import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantoday_flutter/providers/auth_provider.dart';

String _jwt(Map<String, dynamic> payload) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc(payload)}.sig';
}

void main() {
  final now = DateTime(2026, 11, 9, 12);
  final nowSec = now.millisecondsSinceEpoch ~/ 1000;

  test('token yang masih berlaku tidak dianggap kadaluarsa', () {
    expect(isJwtExpired(_jwt({'id': 1, 'exp': nowSec + 3600}), now: now), isFalse);
  });

  test('token yang lewat exp dianggap kadaluarsa', () {
    expect(isJwtExpired(_jwt({'id': 1, 'exp': nowSec - 1}), now: now), isTrue);
  });

  test('token rusak dianggap kadaluarsa', () {
    expect(isJwtExpired('bukan-jwt', now: now), isTrue);
  });

  test('token tanpa exp dianggap berlaku', () {
    expect(isJwtExpired(_jwt({'id': 1}), now: now), isFalse);
  });
}
