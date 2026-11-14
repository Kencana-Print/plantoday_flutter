import '../models/kalkulasi_models.dart';

class KalkulasiCalculationResult {
  final List<KomponenKainItem> updatedKomponen;
  final double totBahan;
  final double totCetak;
  final double totTambahan;
  final double luasBordir;
  final int rpBordirTotal;
  final double luasDtf;
  final int rpDtfTotal;
  final double hppMurni;
  final int rpAllowance;
  final int totalHPP;
  final int rpLaba;
  final int hargaSesuai;
  final int hargaSesuaiPpn;

  const KalkulasiCalculationResult({
    required this.updatedKomponen,
    required this.totBahan,
    required this.totCetak,
    required this.totTambahan,
    required this.luasBordir,
    required this.rpBordirTotal,
    required this.luasDtf,
    required this.rpDtfTotal,
    required this.hppMurni,
    required this.rpAllowance,
    required this.totalHPP,
    required this.rpLaba,
    required this.hargaSesuai,
    required this.hargaSesuaiPpn,
  });
}

/// Pure calculation engine untuk modul kalkulasi harga PlanToday Mobile.
/// Porting 100% presisi dari kalkulasiEngine.ts (Manksi Web / Delphi).
class KalkulasiEngine {
  static KalkulasiCalculationResult calculatePrice(KalkulasiState state, double qtyOrder) {
    final qty = qtyOrder <= 0 ? 0.0 : qtyOrder;

    // 1. Hitung Baris Komponen Bahan
    final updatedKomponen = state.gridKomponen.map((item) {
      final babaran = item.babaran;
      final harga = item.harga;

      if (babaran == 0 || harga == 0) {
        return item.copyWith(kebutuhan: 0, bruto: 0, pcs: 0);
      }

      final kebutuhan = item.kg ? (qty / babaran) : (qty * babaran);
      final bruto = item.kg ? (harga / babaran) : (harga * babaran);
      final pcs = item.pabrik ? (bruto / 1.11) : bruto;

      return item.copyWith(
        kebutuhan: kebutuhan,
        bruto: bruto,
        pcs: pcs,
      );
    }).toList();

    final totBahan = updatedKomponen.fold<double>(
      0.0,
      (acc, curr) => acc + curr.pcs,
    );

    // 2. Hitung Total Cetak & Aksesoris Tambahan
    final totCetak = state.gridCetak.fold<double>(
      0.0,
      (acc, curr) => acc + curr.harga,
    );

    final totTambahan = state.gridAksesoris.fold<double>(
      0.0,
      (acc, curr) => acc + curr.harga,
    );

    // 3. Hitung Luas & Biaya Bordir (Batas Minimal: Rp 2.500)
    final luasBordir = state.bordir.totalLuas;
    double rpBordir = state.bordir.cm * luasBordir;
    if (rpBordir > 0 && rpBordir < 2500) {
      rpBordir = 2500;
    }
    final rpBordirTotal = rpBordir.round();

    // 4. Hitung Luas & Biaya DTF (Batas Minimal: Rp 3.000)
    final luasDtf = state.dtf.totalLuas;
    double rpDtf = state.dtf.cm * luasDtf;
    if (rpDtf > 0 && rpDtf < 3000) {
      rpDtf = 3000;
    }
    final rpDtfTotal = rpDtf.round();

    // 5. Hitung HPP Murni
    final hppMurni = totBahan +
        totCetak +
        rpBordirTotal +
        rpDtfTotal +
        state.rpPotong +
        state.rpJahit +
        state.rpFinishing +
        state.rpObat +
        state.rpKirim +
        totTambahan;

    // 6. Terapkan Allowance
    final persenAllowance = state.persenAllowance;
    final rpAllowance = ((hppMurni * persenAllowance) / 100).round();
    final totalHPP = (hppMurni + rpAllowance).round();

    // 7. Terapkan Margin Laba
    int rpLaba = state.rpLaba.round();
    final persenLaba = state.persenLaba;
    if (persenLaba > 0) {
      rpLaba = ((totalHPP * persenLaba) / 100).round();
    }
    final hargaSesuai = totalHPP + rpLaba;

    // 8. Terapkan PPN
    final persenPpn = state.persenPpn;
    int hargaSesuaiPpn = state.hargaSesuaiPpn.round();
    if (state.updateOtomatis) {
      hargaSesuaiPpn = (hargaSesuai * (1 + persenPpn / 100)).round();
    }

    return KalkulasiCalculationResult(
      updatedKomponen: updatedKomponen,
      totBahan: totBahan,
      totCetak: totCetak,
      totTambahan: totTambahan,
      luasBordir: luasBordir,
      rpBordirTotal: rpBordirTotal,
      luasDtf: luasDtf,
      rpDtfTotal: rpDtfTotal,
      hppMurni: hppMurni,
      rpAllowance: rpAllowance,
      totalHPP: totalHPP,
      rpLaba: rpLaba,
      hargaSesuai: hargaSesuai,
      hargaSesuaiPpn: hargaSesuaiPpn,
    );
  }

  static double calculateSpanduk({
    required double panjangM,
    required double lebarM,
    required double kainRatePerM2,
    required double finishingRatePerM,
  }) {
    final luasM2 = panjangM * lebarM;
    final kelilingM = 2 * (panjangM + lebarM);
    return (luasM2 * kainRatePerM2) + (kelilingM * finishingRatePerM);
  }

  static double calculateMmt({
    required double panjangM,
    required double lebarM,
    required double bahanRatePerM2,
  }) {
    final luasM2 = panjangM * lebarM;
    return luasM2 * bahanRatePerM2;
  }
}
