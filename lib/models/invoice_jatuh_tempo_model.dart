class AgingBucketItem {
  final int count;
  final double nominal;

  const AgingBucketItem({
    required this.count,
    required this.nominal,
  });

  factory AgingBucketItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AgingBucketItem(count: 0, nominal: 0.0);
    return AgingBucketItem(
      count: (json['count'] as num?)?.toInt() ?? 0,
      nominal: (json['nominal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class InvoiceAgingSummary {
  final AgingBucketItem d1To30;
  final AgingBucketItem d31To60;
  final AgingBucketItem d61To90;
  final AgingBucketItem dGt90;

  const InvoiceAgingSummary({
    required this.d1To30,
    required this.d31To60,
    required this.d61To90,
    required this.dGt90,
  });

  factory InvoiceAgingSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const InvoiceAgingSummary(
        d1To30: AgingBucketItem(count: 0, nominal: 0.0),
        d31To60: AgingBucketItem(count: 0, nominal: 0.0),
        d61To90: AgingBucketItem(count: 0, nominal: 0.0),
        dGt90: AgingBucketItem(count: 0, nominal: 0.0),
      );
    }
    return InvoiceAgingSummary(
      d1To30: AgingBucketItem.fromJson(json['1_30'] as Map<String, dynamic>?),
      d31To60: AgingBucketItem.fromJson(json['31_60'] as Map<String, dynamic>?),
      d61To90: AgingBucketItem.fromJson(json['61_90'] as Map<String, dynamic>?),
      dGt90: AgingBucketItem.fromJson(json['gt_90'] as Map<String, dynamic>?),
    );
  }
}

class InvoiceJatuhTempoSalesSummary {
  final String salKode;
  final String salNama;
  final int jmlInvoice;
  final double totalSisa;
  final double totalTerealisasi;

  const InvoiceJatuhTempoSalesSummary({
    required this.salKode,
    required this.salNama,
    required this.jmlInvoice,
    required this.totalSisa,
    this.totalTerealisasi = 0.0,
  });

  factory InvoiceJatuhTempoSalesSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceJatuhTempoSalesSummary(
      salKode: json['sal_kode']?.toString() ?? '',
      salNama: json['sal_nama']?.toString() ?? '',
      jmlInvoice: (json['jml_invoice'] as num?)?.toInt() ?? 0,
      totalSisa: (json['total_sisa'] as num?)?.toDouble() ?? 0.0,
      totalTerealisasi: (json['total_terealisasi'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class InvoiceJatuhTempoSummary {
  final int totalInvoice;
  final double totalOverdue;
  final double totalRealisasi;
  final double totalBatal;
  final InvoiceAgingSummary aging;
  final List<InvoiceJatuhTempoSalesSummary> bySales;

  const InvoiceJatuhTempoSummary({
    required this.totalInvoice,
    required this.totalOverdue,
    this.totalRealisasi = 0.0,
    this.totalBatal = 0.0,
    required this.aging,
    required this.bySales,
  });

  factory InvoiceJatuhTempoSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return InvoiceJatuhTempoSummary(
        totalInvoice: 0,
        totalOverdue: 0.0,
        aging: InvoiceAgingSummary.fromJson(null),
        bySales: const [],
      );
    }
    final rawBySales = json['by_sales'] as List? ?? [];
    return InvoiceJatuhTempoSummary(
      totalInvoice: (json['total_invoice'] as num?)?.toInt() ?? 0,
      totalOverdue: (json['total_overdue'] as num?)?.toDouble() ?? 0.0,
      totalRealisasi: (json['total_realisasi'] as num?)?.toDouble() ?? 0.0,
      totalBatal: (json['total_batal'] as num?)?.toDouble() ?? 0.0,
      aging: InvoiceAgingSummary.fromJson(json['aging'] as Map<String, dynamic>?),
      bySales: rawBySales
          .map((e) => InvoiceJatuhTempoSalesSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InvoiceJatuhTempoItem {
  final String nomor;
  final String nota;
  final String notaTampil;
  final String tanggal;
  final String tempo;
  final int terlambatHari;
  final String cusKode;
  final String cusNama;
  final String salKode;
  final String salNama;
  final double nominal;
  final double terbayar;
  final double sisa;
  final String tglTarget;
  final String catatan;
  final String userCreate;

  const InvoiceJatuhTempoItem({
    this.nomor = '',
    required this.nota,
    required this.notaTampil,
    required this.tanggal,
    required this.tempo,
    required this.terlambatHari,
    required this.cusKode,
    required this.cusNama,
    required this.salKode,
    required this.salNama,
    required this.nominal,
    required this.terbayar,
    required this.sisa,
    this.tglTarget = '',
    this.catatan = '',
    this.userCreate = '',
  });

  factory InvoiceJatuhTempoItem.fromJson(Map<String, dynamic> json) {
    return InvoiceJatuhTempoItem(
      nomor: json['nomor']?.toString() ?? '',
      nota: json['nota']?.toString() ?? '',
      notaTampil: json['nota_tampil']?.toString() ?? json['nota']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      tempo: json['tempo']?.toString() ?? '',
      terlambatHari: (json['terlambat_hari'] as num?)?.toInt() ?? 0,
      cusKode: json['cus_kode']?.toString() ?? '',
      cusNama: json['cus_nama']?.toString() ?? '',
      salKode: json['sal_kode']?.toString() ?? '',
      salNama: json['sal_nama']?.toString() ?? '',
      nominal: (json['nominal'] as num?)?.toDouble() ?? 0.0,
      terbayar: (json['terbayar'] as num?)?.toDouble() ?? 0.0,
      sisa: (json['sisa'] as num?)?.toDouble() ?? 0.0,
      tglTarget: json['tgl_target']?.toString() ?? '',
      catatan: json['catatan']?.toString() ?? '',
      userCreate: json['user_create']?.toString() ?? '',
    );
  }
}

class InkasoSalesGroup {
  final String salKode;
  final String salNama;
  final int jmlInvoice;
  final double totalNominal;
  final double totalTerealisasi;
  final double totalSisa;
  final List<InvoiceJatuhTempoItem> items;

  const InkasoSalesGroup({
    required this.salKode,
    required this.salNama,
    required this.jmlInvoice,
    required this.totalNominal,
    required this.totalTerealisasi,
    required this.totalSisa,
    required this.items,
  });

  static List<InkasoSalesGroup> groupItems(
    List<InvoiceJatuhTempoItem> list, {
    List<InvoiceJatuhTempoSalesSummary>? summaryBySales,
  }) {
    final map = <String, List<InvoiceJatuhTempoItem>>{};
    for (final it in list) {
      final name = it.salNama.trim().isNotEmpty ? it.salNama.trim() : '(Tanpa Sales)';
      map.putIfAbsent(name, () => []).add(it);
    }
    final groups = map.entries.map((entry) {
      final items = List<InvoiceJatuhTempoItem>.from(entry.value)
        ..sort((a, b) => b.terlambatHari.compareTo(a.terlambatHari));
      double nom = 0, real = 0, sisa = 0;
      String kode = '';
      for (final it in items) {
        nom += it.nominal;
        real += it.terbayar;
        sisa += it.sisa;
        if (kode.isEmpty && it.salKode.isNotEmpty) kode = it.salKode;
      }
      if (summaryBySales != null) {
        for (final s in summaryBySales) {
          if (s.salNama.trim().toLowerCase() == entry.key.toLowerCase() ||
              (kode.isNotEmpty && s.salKode == kode)) {
            if (s.totalTerealisasi > real) {
              real = s.totalTerealisasi;
            }
            break;
          }
        }
      }
      return InkasoSalesGroup(
        salKode: kode,
        salNama: entry.key,
        jmlInvoice: items.length,
        totalNominal: nom,
        totalTerealisasi: real,
        totalSisa: sisa,
        items: items,
      );
    }).toList();

    groups.sort((a, b) => b.totalSisa.compareTo(a.totalSisa));
    return groups;
  }
}

class InvoiceJatuhTempoPagination {
  final int page;
  final int limit;
  final int totalItems;
  final int totalPages;

  const InvoiceJatuhTempoPagination({
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
  });

  factory InvoiceJatuhTempoPagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const InvoiceJatuhTempoPagination(
        page: 1,
        limit: 50,
        totalItems: 0,
        totalPages: 1,
      );
    }
    return InvoiceJatuhTempoPagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

class InvoiceJatuhTempoResult {
  final InvoiceJatuhTempoSummary? summary;
  final List<InvoiceJatuhTempoItem> items;
  final InvoiceJatuhTempoPagination pagination;

  const InvoiceJatuhTempoResult({
    this.summary,
    this.items = const [],
    this.pagination = const InvoiceJatuhTempoPagination(
      page: 1,
      limit: 50,
      totalItems: 0,
      totalPages: 1,
    ),
  });
}
