class KomponenKainItem {
  final String komponen;
  final bool kg;
  final bool pabrik;
  final String jenisKain;
  final String lengan;
  final String warna;
  final double harga;
  final double babaran;
  final double kebutuhan;
  final double bruto;
  final double pcs;

  const KomponenKainItem({
    required this.komponen,
    this.kg = false,
    this.pabrik = false,
    this.jenisKain = '',
    this.lengan = '',
    this.warna = '',
    this.harga = 0.0,
    this.babaran = 0.0,
    this.kebutuhan = 0.0,
    this.bruto = 0.0,
    this.pcs = 0.0,
  });

  KomponenKainItem copyWith({
    String? komponen,
    bool? kg,
    bool? pabrik,
    String? jenisKain,
    String? lengan,
    String? warna,
    double? harga,
    double? babaran,
    double? kebutuhan,
    double? bruto,
    double? pcs,
  }) {
    return KomponenKainItem(
      komponen: komponen ?? this.komponen,
      kg: kg ?? this.kg,
      pabrik: pabrik ?? this.pabrik,
      jenisKain: jenisKain ?? this.jenisKain,
      lengan: lengan ?? this.lengan,
      warna: warna ?? this.warna,
      harga: harga ?? this.harga,
      babaran: babaran ?? this.babaran,
      kebutuhan: kebutuhan ?? this.kebutuhan,
      bruto: bruto ?? this.bruto,
      pcs: pcs ?? this.pcs,
    );
  }

  factory KomponenKainItem.fromJson(Map<String, dynamic> json) {
    return KomponenKainItem(
      komponen: json['Komponen']?.toString() ?? '',
      kg: json['Kg'] == true || json['Kg'] == 1,
      pabrik: json['Pabrik'] == true || json['Pabrik'] == 1,
      jenisKain: json['JenisKain']?.toString() ?? '',
      lengan: json['Lengan']?.toString() ?? '',
      warna: json['Warna']?.toString() ?? '',
      harga: (json['Harga'] as num?)?.toDouble() ?? 0.0,
      babaran: (json['Babaran'] as num?)?.toDouble() ?? 0.0,
      kebutuhan: (json['Kebutuhan'] as num?)?.toDouble() ?? 0.0,
      bruto: (json['Bruto'] as num?)?.toDouble() ?? 0.0,
      pcs: (json['Pcs'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Komponen': komponen,
      'Kg': kg,
      'Pabrik': pabrik,
      'JenisKain': jenisKain,
      'Lengan': lengan,
      'Warna': warna,
      'Harga': harga,
      'Babaran': babaran,
      'Kebutuhan': kebutuhan,
      'Bruto': bruto,
      'Pcs': pcs,
    };
  }
}

class GridCetakItem {
  final String keterangan;
  final double harga;

  const GridCetakItem({
    required this.keterangan,
    required this.harga,
  });

  factory GridCetakItem.fromJson(Map<String, dynamic> json) {
    return GridCetakItem(
      keterangan: json['Keterangan']?.toString() ?? '',
      harga: (json['Harga'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'Keterangan': keterangan,
    'Harga': harga,
  };
}

class GridAksesorisItem {
  final String keterangan;
  final double harga;

  const GridAksesorisItem({
    required this.keterangan,
    required this.harga,
  });

  factory GridAksesorisItem.fromJson(Map<String, dynamic> json) {
    return GridAksesorisItem(
      keterangan: json['Keterangan']?.toString() ?? '',
      harga: (json['Harga'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'Keterangan': keterangan,
    'Harga': harga,
  };
}

class Dimension8Slots {
  final double cm;
  final double p1, l1;
  final double p2, l2;
  final double p3, l3;
  final double p4, l4;
  final double p5, l5;
  final double p6, l6;
  final double p7, l7;
  final double p8, l8;

  const Dimension8Slots({
    this.cm = 0.0,
    this.p1 = 0.0, this.l1 = 0.0,
    this.p2 = 0.0, this.l2 = 0.0,
    this.p3 = 0.0, this.l3 = 0.0,
    this.p4 = 0.0, this.l4 = 0.0,
    this.p5 = 0.0, this.l5 = 0.0,
    this.p6 = 0.0, this.l6 = 0.0,
    this.p7 = 0.0, this.l7 = 0.0,
    this.p8 = 0.0, this.l8 = 0.0,
  });

  double get totalLuas =>
      (p1 * l1) + (p2 * l2) + (p3 * l3) + (p4 * l4) +
      (p5 * l5) + (p6 * l6) + (p7 * l7) + (p8 * l8);

  factory Dimension8Slots.fromJson(Map<String, dynamic> json) {
    return Dimension8Slots(
      cm: (json['Cm'] as num?)?.toDouble() ?? 0.0,
      p1: (json['P1'] as num?)?.toDouble() ?? 0.0,
      l1: (json['L1'] as num?)?.toDouble() ?? 0.0,
      p2: (json['P2'] as num?)?.toDouble() ?? 0.0,
      l2: (json['L2'] as num?)?.toDouble() ?? 0.0,
      p3: (json['P3'] as num?)?.toDouble() ?? 0.0,
      l3: (json['L3'] as num?)?.toDouble() ?? 0.0,
      p4: (json['P4'] as num?)?.toDouble() ?? 0.0,
      l4: (json['L4'] as num?)?.toDouble() ?? 0.0,
      p5: (json['P5'] as num?)?.toDouble() ?? 0.0,
      l5: (json['L5'] as num?)?.toDouble() ?? 0.0,
      p6: (json['P6'] as num?)?.toDouble() ?? 0.0,
      l6: (json['L6'] as num?)?.toDouble() ?? 0.0,
      p7: (json['P7'] as num?)?.toDouble() ?? 0.0,
      l7: (json['L7'] as num?)?.toDouble() ?? 0.0,
      p8: (json['P8'] as num?)?.toDouble() ?? 0.0,
      l8: (json['L8'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'Cm': cm,
    'P1': p1, 'L1': l1,
    'P2': p2, 'L2': l2,
    'P3': p3, 'L3': l3,
    'P4': p4, 'L4': l4,
    'P5': p5, 'L5': l5,
    'P6': p6, 'L6': l6,
    'P7': p7, 'L7': l7,
    'P8': p8, 'L8': l8,
  };
}

class KalkulasiState {
  final String nomorKalkulasi;
  final String tanggalKalkulasi;
  final String model;
  final String jenisKain;
  final String warna;
  final String kategoriKain;
  final double rencanaOrder;

  final double rpPotong;
  final double rpJahit;
  final double rpFinishing;
  final double rpKirim;
  final double rpObat;

  final List<KomponenKainItem> gridKomponen;
  final List<GridCetakItem> gridCetak;
  final List<GridAksesorisItem> gridAksesoris;

  final Dimension8Slots bordir;
  final Dimension8Slots dtf;
  final double rpBordirTotal;
  final double rpDtfTotal;
  final double rpCetakTotal;

  final double persenAllowance;
  final double rpAllowance;
  final double persenLaba;
  final double rpLaba;
  final double hargaSesuai;
  final double persenPpn;
  final double hargaSesuaiPpn;
  final bool updateOtomatis;

  const KalkulasiState({
    this.nomorKalkulasi = '',
    this.tanggalKalkulasi = '',
    this.model = 'KH-0001',
    this.jenisKain = '',
    this.warna = 'MUDA',
    this.kategoriKain = 'LACOST',
    this.rencanaOrder = 0.0,
    this.rpPotong = 0.0,
    this.rpJahit = 0.0,
    this.rpFinishing = 0.0,
    this.rpKirim = 0.0,
    this.rpObat = 0.0,
    this.gridKomponen = const [],
    this.gridCetak = const [],
    this.gridAksesoris = const [],
    this.bordir = const Dimension8Slots(),
    this.dtf = const Dimension8Slots(),
    this.rpBordirTotal = 0.0,
    this.rpDtfTotal = 0.0,
    this.rpCetakTotal = 0.0,
    this.persenAllowance = 0.0,
    this.rpAllowance = 0.0,
    this.persenLaba = 0.0,
    this.rpLaba = 0.0,
    this.hargaSesuai = 0.0,
    this.persenPpn = 11.0,
    this.hargaSesuaiPpn = 0.0,
    this.updateOtomatis = true,
  });
}
