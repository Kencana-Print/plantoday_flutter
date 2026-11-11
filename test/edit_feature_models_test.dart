import 'package:flutter_test/flutter_test.dart';
import 'package:plantoday_flutter/models/mutation_result.dart';
import 'package:plantoday_flutter/models/penawaran_model.dart';

void main() {
  group('MutationResult Tests', () {
    test('MutationResult.success instantiates correctly', () {
      final res = MutationResult.success(
        message: 'Penawaran berhasil diperbarui',
        nomor: 'PNW-001',
      );
      expect(res.success, isTrue);
      expect(res.message, 'Penawaran berhasil diperbarui');
      expect(res.nomor, 'PNW-001');
    });

    test('MutationResult.failure instantiates correctly', () {
      final res = MutationResult.failure(
        message: 'Gagal karena sudah diproses MAP',
      );
      expect(res.success, isFalse);
      expect(res.message, 'Gagal karena sudah diproses MAP');
      expect(res.nomor, isNull);
    });
  });

  group('PenawaranDetailItem Parsing Tests', () {
    test('parses minta and pend_minta fields correctly', () {
      final json1 = {
        'id': '10',
        'urutan': 1,
        'minta': 'PH-2026-001',
        'namaBarang': 'Brosur A4',
        'qty': 500,
        'satuan': 'Rim',
        'harga': 150000,
      };

      final item1 = PenawaranDetailItem.fromJson(json1);
      expect(item1.id, '10');
      expect(item1.urutan, 1);
      expect(item1.minta, 'PH-2026-001');
      expect(item1.namaBarang, 'Brosur A4');

      final json2 = {
        'id': '11',
        'urutan': 2,
        'pend_minta': 'PH-2026-002',
        'namaBarang': 'Kartu Nama',
        'qty': 10,
        'satuan': 'Box',
        'harga': 35000,
      };

      final item2 = PenawaranDetailItem.fromJson(json2);
      expect(item2.minta, 'PH-2026-002');
    });
  });
}
