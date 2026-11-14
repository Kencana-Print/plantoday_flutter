class AchievementUserRow {
  final String kode;
  final String nama;
  final String jabatan;
  final double target;
  final double realisasi;
  final double ach; // persentase achievement

  const AchievementUserRow({
    required this.kode,
    required this.nama,
    this.jabatan = '',
    this.target = 0.0,
    this.realisasi = 0.0,
    this.ach = 0.0,
  });

  factory AchievementUserRow.fromJson(Map<String, dynamic> json) {
    return AchievementUserRow(
      kode: json['kode']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '-',
      jabatan: json['jabatan']?.toString() ?? '-',
      target: (json['target'] as num?)?.toDouble() ?? 0.0,
      realisasi: (json['realisasi'] as num?)?.toDouble() ?? 0.0,
      ach: (json['ach'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AchievementMonthlyItem {
  final String bulan;
  final int bulanNum;
  final int tahun;
  final double target;
  final double realisasi;
  final double ach;
  final List<AchievementDetailSpk> detailSpk;

  const AchievementMonthlyItem({
    required this.bulan,
    this.bulanNum = 0,
    this.tahun = 0,
    this.target = 0.0,
    this.realisasi = 0.0,
    this.ach = 0.0,
    this.detailSpk = const [],
  });

  factory AchievementMonthlyItem.fromJson(Map<String, dynamic> json) {
    var spkList = <AchievementDetailSpk>[];
    if (json['detail_spk'] is List) {
      spkList = (json['detail_spk'] as List)
          .map((item) =>
              AchievementDetailSpk.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return AchievementMonthlyItem(
      bulan: json['bulan']?.toString() ?? json['month_label']?.toString() ?? '',
      bulanNum: (json['bulan_num'] as num?)?.toInt() ??
          (json['month'] as num?)?.toInt() ??
          0,
      tahun: (json['tahun'] as num?)?.toInt() ??
          (json['year'] as num?)?.toInt() ??
          0,
      target: (json['target'] as num?)?.toDouble() ?? 0.0,
      realisasi: (json['realisasi'] as num?)?.toDouble() ?? 0.0,
      ach: (json['ach'] as num?)?.toDouble() ?? 0.0,
      detailSpk: spkList,
    );
  }
}

class AchievementDetailSpk {
  final String spkNomor;
  final String spkTanggal;
  final String spkCusKode;
  final String customerNama;
  final int spkDivisi;
  final String spkTipe;
  final String spkNama;
  final int spkJumlah;
  final double spkHarga;
  final double nilai;
  final bool spkClose;

  const AchievementDetailSpk({
    required this.spkNomor,
    this.spkTanggal = '',
    this.spkCusKode = '',
    this.customerNama = '',
    this.spkDivisi = 0,
    this.spkTipe = '',
    this.spkNama = '',
    this.spkJumlah = 0,
    this.spkHarga = 0.0,
    this.nilai = 0.0,
    this.spkClose = false,
  });

  factory AchievementDetailSpk.fromJson(Map<String, dynamic> json) {
    final closeVal = json['spk_close'];
    final isClose = closeVal == true || closeVal == 1 || closeVal == '1';

    return AchievementDetailSpk(
      spkNomor: json['spk_nomor']?.toString() ?? '',
      spkTanggal: json['spk_tanggal']?.toString() ?? '',
      spkCusKode: json['spk_cus_kode']?.toString() ?? '',
      customerNama: json['customer_nama']?.toString() ??
          json['customer']?.toString() ??
          json['cus_nama']?.toString() ??
          '-',
      spkDivisi: (json['spk_divisi'] as num?)?.toInt() ?? 0,
      spkTipe: json['spk_tipe']?.toString() ?? '',
      spkNama: json['spk_nama']?.toString() ?? '',
      spkJumlah: (json['spk_jumlah'] as num?)?.toInt() ?? 0,
      spkHarga: (json['spk_harga'] as num?)?.toDouble() ?? 0.0,
      nilai: (json['nilai'] as num?)?.toDouble() ?? 0.0,
      spkClose: isClose,
    );
  }
}

