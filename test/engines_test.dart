import 'package:flutter_test/flutter_test.dart';
import 'package:plantoday_flutter/engines/kalkulasi_engine.dart';
import 'package:plantoday_flutter/engines/ongkir_engine.dart';
import 'package:plantoday_flutter/models/kalkulasi_models.dart';

void main() {
  group('KalkulasiEngine Tests', () {
    test('calculatePrice calculates basic components and minimum thresholds', () {
      final state = KalkulasiState(
        rencanaOrder: 100,
        rpPotong: 1000,
        rpJahit: 3000,
        rpFinishing: 500,
        gridKomponen: [
          const KomponenKainItem(
            komponen: 'Badan',
            kg: true,
            harga: 80000,
            babaran: 3.0,
          ),
        ],
        bordir: const Dimension8Slots(
          cm: 50,
          p1: 5,
          l1: 5, // Luas = 25 cm2 -> 50 * 25 = 1250 (< 2500, minimum applies)
        ),
        dtf: const Dimension8Slots(
          cm: 10,
          p1: 10,
          l1: 10, // Luas = 100 cm2 -> 10 * 100 = 1000 (< 3000, minimum applies)
        ),
        persenAllowance: 5,
        persenLaba: 10,
        persenPpn: 11,
      );

      final result = KalkulasiEngine.calculatePrice(state, 100);

      // Verify minimum bordir threshold (Rp 2.500)
      expect(result.rpBordirTotal, equals(2500));
      // Verify minimum DTF threshold (Rp 3.000)
      expect(result.rpDtfTotal, equals(3000));
      // Verify bahan: 80000 / 3 = 26666.67
      expect(result.totBahan, closeTo(26666.67, 0.1));
      expect(result.totalHPP, greaterThan(0));
      expect(result.hargaSesuai, greaterThan(result.totalHPP));
      expect(result.hargaSesuaiPpn, greaterThan(result.hargaSesuai));
    });
  });

  group('OngkirEngine Tests', () {
    test('detectAlokasiFromText detects known cities', () {
      final detected = OngkirEngine.detectAlokasiFromText('Kirim ke Medan');
      expect(detected, isNotNull);
      expect(detected?.alokasi, equals('Sumatra'));

      final detectedBandung = OngkirEngine.detectAlokasiFromText('Cimahi');
      expect(detectedBandung?.alokasi, equals('Bandung'));
    });

    test(
      'hitungOngkirOtomatis calculates Spanduk free shipping above threshold',
      () {
        final result = OngkirEngine.hitungOngkirOtomatis(
          alokasi: 'Jakarta',
          divisi: '1',
          panjang: 2.0,
          qty: 600, // 2 * 600 = 1200 meter >= free threshold 1000
        );

        expect(result.isFreeCharge, isTrue);
        expect(result.totalOngkir, equals(0));
      },
    );

    test('hitungOngkirOtomatis applies minimum weight constraint', () {
      final result = OngkirEngine.hitungOngkirOtomatis(
        alokasi: 'Jakarta',
        divisi: '1',
        panjang: 1.0,
        qty: 50, // 50 meter / 10 = 5 kg (< min 20 kg)
      );

      expect(result.isFreeCharge, isFalse);
      expect(result.beratDihitungKg, equals(20.0));
      expect(result.totalOngkir, equals(40000)); // 20 * 2000
    });
  });
}
