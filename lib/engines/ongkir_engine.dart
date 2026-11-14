class OngkirMasterItem {
  final int id;
  final String alokasi;
  final double hargaKg;
  final double minKg;
  final double freeSpandukM;
  final double freeMmtM2;
  final double freeGarmenPcs;
  final double spandukMPerKg;
  final double mmtM2PerKg;
  final double garmenMedPcsPerKg;
  final double garmenPremPcsPerKg;
  final String? coverageDesc;
  final List<String> aliasKeywords;

  const OngkirMasterItem({
    required this.id,
    required this.alokasi,
    required this.hargaKg,
    required this.minKg,
    required this.freeSpandukM,
    required this.freeMmtM2,
    required this.freeGarmenPcs,
    required this.spandukMPerKg,
    required this.mmtM2PerKg,
    required this.garmenMedPcsPerKg,
    required this.garmenPremPcsPerKg,
    this.coverageDesc,
    this.aliasKeywords = const [],
  });

  factory OngkirMasterItem.fromJson(Map<String, dynamic> json) {
    return OngkirMasterItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      alokasi: json['alokasi']?.toString() ?? '',
      hargaKg: (json['harga_kg'] as num?)?.toDouble() ?? 0.0,
      minKg: (json['min_kg'] as num?)?.toDouble() ?? 0.0,
      freeSpandukM: (json['free_spanduk_m'] as num?)?.toDouble() ?? 0.0,
      freeMmtM2: (json['free_mmt_m2'] as num?)?.toDouble() ?? 0.0,
      freeGarmenPcs: (json['free_garmen_pcs'] as num?)?.toDouble() ?? 0.0,
      spandukMPerKg: (json['spanduk_m_per_kg'] as num?)?.toDouble() ?? 10.0,
      mmtM2PerKg: (json['mmt_m2_per_kg'] as num?)?.toDouble() ?? 2.0,
      garmenMedPcsPerKg: (json['garmen_med_pcs_per_kg'] as num?)?.toDouble() ?? 5.0,
      garmenPremPcsPerKg: (json['garmen_prem_pcs_per_kg'] as num?)?.toDouble() ?? 3.0,
      coverageDesc: json['coverage_desc']?.toString(),
      aliasKeywords: (json['alias_keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class OngkirCalcResult {
  final String alokasi;
  final bool isCustom;
  final double totalBeratKg;
  final double beratDihitungKg;
  final double minKg;
  final double tarifPerKg;
  final bool isFreeCharge;
  final double freeThreshold;
  final int totalOngkir;
  final int ongkirPerPcs;
  final String ringkasan;
  final String? detectedFrom;

  const OngkirCalcResult({
    required this.alokasi,
    required this.isCustom,
    required this.totalBeratKg,
    required this.beratDihitungKg,
    required this.minKg,
    required this.tarifPerKg,
    required this.isFreeCharge,
    required this.freeThreshold,
    required this.totalOngkir,
    required this.ongkirPerPcs,
    required this.ringkasan,
    this.detectedFrom,
  });
}

const List<OngkirMasterItem> fallbackOngkirOptions = [
  OngkirMasterItem(
    id: 1,
    alokasi: 'Jakarta',
    hargaKg: 2000,
    minKg: 20,
    freeSpandukM: 1000,
    freeMmtM2: 500,
    freeGarmenPcs: 300,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'DKI Jakarta, Bogor, Depok, Tangerang, Bekasi (Jabodetabek)',
    aliasKeywords: [
      'jakarta',
      'dki',
      'jaksel',
      'jakbar',
      'jaktim',
      'jakut',
      'jakpus',
      'bogor',
      'depok',
      'tangerang',
      'tangsel',
      'bekasi',
      'cikarang',
      'jabodetabek',
    ],
  ),
  OngkirMasterItem(
    id: 2,
    alokasi: 'Bandung',
    hargaKg: 2000,
    minKg: 20,
    freeSpandukM: 1000,
    freeMmtM2: 500,
    freeGarmenPcs: 300,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Kota & Kab. Bandung, Cimahi, Bandung Barat',
    aliasKeywords: ['bandung', 'cimahi', 'soreang', 'padalarang', 'lembang'],
  ),
  OngkirMasterItem(
    id: 3,
    alokasi: 'Yogya',
    hargaKg: 2000,
    minKg: 20,
    freeSpandukM: 1000,
    freeMmtM2: 500,
    freeGarmenPcs: 300,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'DIY Yogyakarta, Sleman, Bantul, Kulon Progo, Gunungkidul',
    aliasKeywords: [
      'yogya',
      'yogyakarta',
      'jogja',
      'sleman',
      'bantul',
      'kulon progo',
      'gunungkidul',
      'wates',
      'wonosari',
    ],
  ),
  OngkirMasterItem(
    id: 4,
    alokasi: 'Sidoarjo',
    hargaKg: 2000,
    minKg: 20,
    freeSpandukM: 1000,
    freeMmtM2: 500,
    freeGarmenPcs: 300,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Kabupaten Sidoarjo & sekitarnya',
    aliasKeywords: ['sidoarjo', 'waru', 'krian', 'porong'],
  ),
  OngkirMasterItem(
    id: 5,
    alokasi: 'Surabaya',
    hargaKg: 2000,
    minKg: 20,
    freeSpandukM: 1000,
    freeMmtM2: 500,
    freeGarmenPcs: 300,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Kota Surabaya & sekitarnya',
    aliasKeywords: ['surabaya', 'sby', 'rungkut', 'gubeng', 'wonokromo'],
  ),
  OngkirMasterItem(
    id: 6,
    alokasi: 'Surakarta',
    hargaKg: 2000,
    minKg: 20,
    freeSpandukM: 1000,
    freeMmtM2: 500,
    freeGarmenPcs: 300,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Solo Raya (Solo, Sukoharjo, Karanganyar, Klaten, Boyolali, Sragen, Wonogiri)',
    aliasKeywords: [
      'surakarta',
      'solo',
      'sukoharjo',
      'karanganyar',
      'klaten',
      'boyolali',
      'sragen',
      'wonogiri',
      'kartasura',
      'palur',
    ],
  ),
  OngkirMasterItem(
    id: 7,
    alokasi: 'Jawa Lainnya',
    hargaKg: 5000,
    minKg: 20,
    freeSpandukM: 0,
    freeMmtM2: 0,
    freeGarmenPcs: 0,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Semarang, Malang, Cirebon, Tegal, Purwokerto, Jember, Banyuwangi, dll.',
    aliasKeywords: [
      'jawa',
      'semarang',
      'malang',
      'cirebon',
      'serang',
      'banten',
      'tasikmalaya',
      'sukabumi',
      'purwokerto',
      'banyumas',
      'tegal',
      'pekalongan',
      'kudus',
      'pati',
      'jepara',
      'magelang',
      'salatiga',
      'kediri',
      'madiun',
      'jember',
      'banyuwangi',
      'pasuruan',
      'probolinggo',
      'mojokerto',
      'blitar',
      'tulungagung',
      'nganjuk',
      'ngawi',
      'bojonegoro',
      'tuban',
      'lamongan',
      'gresik',
      'jombang',
      'lumajang',
      'situbondo',
      'bondowoso',
      'cilacap',
      'kebumen',
      'purworejo',
      'wonosobo',
      'temanggung',
      'kendal',
      'demak',
      'grobogan',
      'purwodadi',
      'blora',
      'rembang',
      'brebes',
      'pemalang',
      'batang',
      'kuningan',
      'majalengka',
      'sumedang',
      'garut',
      'ciamis',
      'pangandaran',
      'banjar',
      'purwakarta',
      'subang',
      'karawang',
      'pandeglang',
      'lebak',
      'cilegon',
      'madura',
      'bangkalan',
      'sampang',
      'pamekasan',
      'sumenep',
    ],
  ),
  OngkirMasterItem(
    id: 8,
    alokasi: 'Sumatra',
    hargaKg: 10000,
    minKg: 40,
    freeSpandukM: 0,
    freeMmtM2: 0,
    freeGarmenPcs: 0,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Jambi, Medan, Palembang, Padang, Pekanbaru, Batam, Lampung, Aceh, Bengkulu, Babel',
    aliasKeywords: [
      'sumatra',
      'sumatera',
      'jambi',
      'medan',
      'palembang',
      'padang',
      'pekanbaru',
      'riau',
      'batam',
      'tanjung pinang',
      'kepri',
      'lampung',
      'bandar lampung',
      'aceh',
      'banda aceh',
      'bengkulu',
      'pangkal pinang',
      'bangka',
      'belitung',
      'babel',
      'bukittinggi',
      'dumai',
      'binjai',
      'pematang siantar',
      'lubuklinggau',
      'prabumulih',
      'lahat',
      'baturaja',
      'muaro jambi',
      'bungo',
      'tebo',
      'sarolangun',
      'merangin',
      'kerinci',
      'sungai penuh',
      'tanjab',
      'tanjung jabung',
      'asahan',
      'deli serdang',
      'karo',
      'labuhanbatu',
      'langkat',
      'mandailing',
      'nias',
      'simalungun',
      'tapanuli',
      'toba',
      'agam',
      'dharmasraya',
      'mentawai',
      'lima puluh kota',
      'padang pariaman',
      'pasaman',
      'pesisir selatan',
      'sijunjung',
      'solok',
      'tanah datar',
      'bengkalis',
      'indragiri',
      'kampar',
      'kuantan singingi',
      'pelalawan',
      'rokan',
      'siak',
      'banyuasin',
      'empat lawang',
      'muara enim',
      'musi banyuasin',
      'musi rawas',
      'ogan ilir',
      'ogan komering',
      'penukal abab',
      'mesuji',
      'pesawaran',
      'pringsewu',
      'tanggamus',
      'tulang bawang',
      'way kanan',
      'metro',
    ],
  ),
  OngkirMasterItem(
    id: 9,
    alokasi: 'Sulawesi',
    hargaKg: 10000,
    minKg: 40,
    freeSpandukM: 0,
    freeMmtM2: 0,
    freeGarmenPcs: 0,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Makassar, Manado, Palu, Kendari, Gorontalo, Mamuju & seluruh Sulawesi',
    aliasKeywords: [
      'sulawesi',
      'makassar',
      'manado',
      'palu',
      'kendari',
      'gorontalo',
      'mamuju',
      'sulsel',
      'sulut',
      'sulteng',
      'sultra',
      'sulbar',
      'parepare',
      'palopo',
      'bitung',
      'tomohon',
      'kotamobagu',
      'baubau',
      'gowa',
      'maros',
      'bone',
      'bulukumba',
      'bantaeng',
      'pinrang',
      'sidrap',
      'wajo',
      'soppeng',
      'luwu',
      'toraja',
      'kolaka',
      'konawe',
      'muna',
      'buton',
      'wakatobi',
      'poso',
      'donggala',
      'tolitoli',
      'banggai',
      'morowali',
      'parigi',
      'minahasa',
      'bolmong',
      'sangihe',
      'talaud',
    ],
  ),
  OngkirMasterItem(
    id: 10,
    alokasi: 'Kalimantan',
    hargaKg: 15000,
    minKg: 40,
    freeSpandukM: 0,
    freeMmtM2: 0,
    freeGarmenPcs: 0,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Banjarmasin, Samarinda, Balikpapan, Pontianak, Palangkaraya, Tarakan',
    aliasKeywords: [
      'kalimantan',
      'borneo',
      'banjarmasin',
      'banjarbaru',
      'samarinda',
      'balikpapan',
      'pontianak',
      'palangkaraya',
      'tarakan',
      'tanjung selor',
      'kalsel',
      'kaltim',
      'kalbar',
      'kalteng',
      'kaltara',
      'bontang',
      'singkawang',
      'sambas',
      'ketapang',
      'sintang',
      'kapuas',
      'kotawaringin',
      'sampit',
      'pangkalan bun',
      'katingan',
      'barito',
      'murung raya',
      'tanah laut',
      'kotabaru',
      'banjar',
      'tapin',
      'hulu sungai',
      'tabalong',
      'tanah bumbu',
      'penajam',
      'pasel',
      'kukar',
      'kutai',
      'berau',
      'nunukan',
      'bulungan',
      'malinau',
      'ikn',
      'nusantara',
    ],
  ),
  OngkirMasterItem(
    id: 11,
    alokasi: 'Bali',
    hargaKg: 8000,
    minKg: 40,
    freeSpandukM: 0,
    freeMmtM2: 0,
    freeGarmenPcs: 0,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Denpasar, Badung, Gianyar, Tabanan, Buleleng, Klungkung, dll.',
    aliasKeywords: [
      'bali',
      'denpasar',
      'badung',
      'kuta',
      'seminyak',
      'canggu',
      'jimbaran',
      'nusa dua',
      'gianyar',
      'ubud',
      'tabanan',
      'buleleng',
      'singaraja',
      'klungkung',
      'nusa penida',
      'bangli',
      'karangasem',
      'jembrana',
      'negara',
    ],
  ),
  OngkirMasterItem(
    id: 12,
    alokasi: 'Nusa Tenggara',
    hargaKg: 10000,
    minKg: 40,
    freeSpandukM: 0,
    freeMmtM2: 0,
    freeGarmenPcs: 0,
    spandukMPerKg: 10,
    mmtM2PerKg: 2,
    garmenMedPcsPerKg: 5,
    garmenPremPcsPerKg: 3,
    coverageDesc: 'Mataram, Lombok, Sumbawa, Bima (NTB), Kupang, Labuan Bajo, Flores (NTT)',
    aliasKeywords: [
      'nusa tenggara',
      'ntb',
      'ntt',
      'mataram',
      'lombok',
      'sumbawa',
      'bima',
      'dompu',
      'kupang',
      'labuan bajo',
      'flores',
      'manggari',
      'ende',
      'sikka',
      'maumere',
      'ngada',
      'sumba',
      'waingapu',
      'alor',
      'lembata',
      'rote',
      'sabu',
      'timor',
      'belu',
      'atambua',
      'ttus',
      'tts',
    ],
  ),
];

class OngkirEngine {
  static OngkirMasterItem? detectAlokasiFromText(
    String text, [
    List<OngkirMasterItem> options = fallbackOngkirOptions,
  ]) {
    final q = text.toLowerCase().trim();
    if (q.length < 2) return null;

    final masterList = options.isNotEmpty ? options : fallbackOngkirOptions;

    // 1. Exact match nama alokasi
    for (final item in masterList) {
      if (item.alokasi.toLowerCase() == q) return item;
    }

    // 2. Exact match keyword alias
    for (final item in masterList) {
      if (item.aliasKeywords.any((kw) => kw.toLowerCase() == q)) return item;
    }

    // 3. Query contains keyword
    for (final item in masterList) {
      if (item.aliasKeywords.any((kw) => kw.length >= 3 && q.contains(kw.toLowerCase()))) {
        return item;
      }
    }

    // 4. Starts with / includes query
    if (q.length >= 3) {
      for (final item in masterList) {
        if (item.aliasKeywords.any((kw) => kw.toLowerCase().startsWith(q) || kw.toLowerCase().contains(q))) {
          return item;
        }
      }
    }

    // 5. Query contains alokasi name
    for (final item in masterList) {
      if (q.contains(item.alokasi.toLowerCase())) return item;
    }

    return null;
  }

  static OngkirCalcResult hitungOngkirOtomatis({
    List<OngkirMasterItem> options = const [],
    String alokasi = 'Jakarta',
    String divisi = '1',
    double panjang = 0,
    double lebar = 0,
    double qty = 0,
    String sublim = '',
    int customNominal = 0,
    bool isCustom = false,
  }) {
    final normDivisi = divisi.trim().isEmpty ? '1' : divisi.trim();

    // Mode Tanpa Ongkir
    final alokasiLower = alokasi.toLowerCase().trim();
    if (alokasiLower.isEmpty || alokasiLower == 'tanpa ongkir' || alokasiLower == 'none') {
      return const OngkirCalcResult(
        alokasi: 'Tanpa Ongkir',
        isCustom: false,
        totalBeratKg: 0,
        beratDihitungKg: 0,
        minKg: 0,
        tarifPerKg: 0,
        isFreeCharge: true,
        freeThreshold: 0,
        totalOngkir: 0,
        ongkirPerPcs: 0,
        ringkasan: 'Tanpa Ongkir (Rp 0)',
      );
    }

    // Mode Custom / Manual
    if (isCustom || alokasiLower == 'custom' || alokasiLower == 'manual') {
      final totalOngkir = customNominal;
      final ongkirPerPcs = qty > 0 ? (totalOngkir / qty).round() : totalOngkir;
      return OngkirCalcResult(
        alokasi: 'Custom',
        isCustom: true,
        totalBeratKg: 0,
        beratDihitungKg: 0,
        minKg: 0,
        tarifPerKg: 0,
        isFreeCharge: totalOngkir == 0,
        freeThreshold: 0,
        totalOngkir: totalOngkir,
        ongkirPerPcs: ongkirPerPcs,
        ringkasan: totalOngkir > 0 ? 'Manual: Rp $totalOngkir' : 'Rp 0',
      );
    }

    final masterList = options.isNotEmpty ? options : fallbackOngkirOptions;
    final matched = masterList.firstWhere(
      (o) => o.alokasi.toLowerCase() == alokasiLower,
      orElse: () => detectAlokasiFromText(alokasi, masterList) ?? masterList.first,
    );

    double totalBeratKg = 0;
    bool isFreeCharge = false;
    double freeThreshold = 0;

    if (normDivisi == '1') {
      // Spanduk: 10 meter = 1 kg
      final totalMeter = double.parse((panjang * qty).toStringAsFixed(2));
      final rasio = matched.spandukMPerKg > 0 ? matched.spandukMPerKg : 10.0;
      totalBeratKg = totalMeter / rasio;
      freeThreshold = matched.freeSpandukM;
      if (freeThreshold > 0 && totalMeter >= freeThreshold) {
        isFreeCharge = true;
      }
    } else if (normDivisi == '5') {
      // MMT: 2 m2 = 1 kg
      final luasPerPcs = double.parse((panjang * lebar).toStringAsFixed(2));
      final totalLuas = double.parse((luasPerPcs * qty).toStringAsFixed(2));
      final rasio = matched.mmtM2PerKg > 0 ? matched.mmtM2PerKg : 2.0;
      totalBeratKg = totalLuas / rasio;
      freeThreshold = matched.freeMmtM2;
      if (freeThreshold > 0 && totalLuas >= freeThreshold) {
        isFreeCharge = true;
      }
    } else if (normDivisi == '4') {
      // Garmen: 5 pcs/kg (Medium) atau 3 pcs/kg (Premium)
      final isPremium = sublim.toUpperCase() == 'PREMIUM';
      final rasio = isPremium ? matched.garmenPremPcsPerKg : matched.garmenMedPcsPerKg;
      totalBeratKg = rasio > 0 ? qty / rasio : 0;
      freeThreshold = matched.freeGarmenPcs;
      if (freeThreshold > 0 && qty >= freeThreshold) {
        isFreeCharge = true;
      }
    } else {
      totalBeratKg = qty;
    }

    totalBeratKg = double.parse(totalBeratKg.toStringAsFixed(2));
    final minKg = matched.minKg > 0 ? matched.minKg : 20.0;
    final tarifPerKg = matched.hargaKg;

    int totalOngkir = 0;
    double beratDihitungKg = totalBeratKg;

    if (isFreeCharge) {
      totalOngkir = 0;
      beratDihitungKg = totalBeratKg;
    } else {
      beratDihitungKg = totalBeratKg > minKg ? totalBeratKg : minKg;
      totalOngkir = (beratDihitungKg * tarifPerKg).round();
    }

    final ongkirPerPcs = qty > 0 ? (totalOngkir / qty).round() : totalOngkir;
    final ringkasan = isFreeCharge
        ? 'Gratis Ongkir (Free Charge)'
        : 'Rp $totalOngkir (${beratDihitungKg.toStringAsFixed(1)}kg @ Rp ${tarifPerKg.round()}/kg)';

    return OngkirCalcResult(
      alokasi: matched.alokasi,
      isCustom: false,
      totalBeratKg: totalBeratKg,
      beratDihitungKg: beratDihitungKg,
      minKg: minKg,
      tarifPerKg: tarifPerKg,
      isFreeCharge: isFreeCharge,
      freeThreshold: freeThreshold,
      totalOngkir: totalOngkir,
      ongkirPerPcs: ongkirPerPcs,
      ringkasan: ringkasan,
    );
  }
}
