class TrackingPenawaranListItem {
  final String noPenawaran;
  final String tanggalPenawaran;
  final String customer;
  final String sales;
  final int totalItem;
  final int totalItemMap;
  final String noMap;
  final String mapStatus;
  final String mapDeadline;
  final String mapWorkshop;
  final String mapKeterangan;
  final String mapKendala;
  final String statusTracking; // 'OPEN' | 'PARSIAL' | 'CLOSE'

  const TrackingPenawaranListItem({
    required this.noPenawaran,
    required this.tanggalPenawaran,
    this.customer = '',
    this.sales = '',
    this.totalItem = 0,
    this.totalItemMap = 0,
    this.noMap = '',
    this.mapStatus = '',
    this.mapDeadline = '',
    this.mapWorkshop = '',
    this.mapKeterangan = '',
    this.mapKendala = '',
    this.statusTracking = 'OPEN',
  });

  factory TrackingPenawaranListItem.fromJson(Map<String, dynamic> json) {
    return TrackingPenawaranListItem(
      noPenawaran: json['no_penawaran']?.toString() ?? '',
      tanggalPenawaran: json['tanggal_penawaran']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
      totalItem: (json['total_item'] as num?)?.toInt() ?? 0,
      totalItemMap: (json['total_item_map'] as num?)?.toInt() ?? 0,
      noMap: json['no_map']?.toString() ?? '',
      mapStatus: json['map_status']?.toString() ?? '',
      mapDeadline: json['map_deadline']?.toString() ?? '',
      mapWorkshop: json['map_workshop']?.toString() ?? '',
      mapKeterangan: json['map_keterangan']?.toString() ?? '',
      mapKendala: json['map_kendala']?.toString() ?? '',
      statusTracking: json['status_tracking']?.toString() ?? 'OPEN',
    );
  }
}

class TrackingMapDetailItem {
  final String penId;
  final String noMap;
  final String mapNama;
  final String tanggalMap;
  final String mapDeadline;
  final int mapDivisi;
  final String mapWorkshop;
  final String mapStatus;
  final String mapKeterangan;
  final String mapKendala;
  final String mapClose;

  const TrackingMapDetailItem({
    this.penId = '',
    required this.noMap,
    this.mapNama = '',
    this.tanggalMap = '',
    this.mapDeadline = '',
    this.mapDivisi = 1,
    this.mapWorkshop = '',
    this.mapStatus = '',
    this.mapKeterangan = '',
    this.mapKendala = '',
    this.mapClose = '',
  });

  factory TrackingMapDetailItem.fromJson(Map<String, dynamic> json) {
    return TrackingMapDetailItem(
      penId: json['pen_id']?.toString() ?? '',
      noMap: json['no_map']?.toString() ?? '',
      mapNama: json['map_nama']?.toString() ?? json['nama']?.toString() ?? '',
      tanggalMap: json['tanggal_map']?.toString() ?? '',
      mapDeadline: json['map_deadline']?.toString() ?? '',
      mapDivisi: (json['map_divisi'] as num?)?.toInt() ?? 1,
      mapWorkshop: json['map_workshop']?.toString() ?? '',
      mapStatus: json['map_status']?.toString() ?? '',
      mapKeterangan: json['map_keterangan']?.toString() ?? '',
      mapKendala: json['map_kendala']?.toString() ?? '',
      mapClose: json['map_close']?.toString() ?? '',
    );
  }
}

class TrackingMapListItem {
  final String noMap;
  final String customer;
  final String alamat;
  final String tanggalMap;
  final String tanggalBast;
  final String tanggalSjMap;
  final String nomorSj;
  final String mspkNama;
  final String mspkUkuran;
  final String mspkKain;
  final String mspkFinishing;
  final String mspkKeterangan;
  final String sales;

  const TrackingMapListItem({
    required this.noMap,
    this.customer = '',
    this.alamat = '',
    this.tanggalMap = '',
    this.tanggalBast = '',
    this.tanggalSjMap = '',
    this.nomorSj = '',
    this.mspkNama = '',
    this.mspkUkuran = '',
    this.mspkKain = '',
    this.mspkFinishing = '',
    this.mspkKeterangan = '',
    this.sales = '',
  });

  factory TrackingMapListItem.fromJson(Map<String, dynamic> json) {
    return TrackingMapListItem(
      noMap: json['no_map']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      alamat: json['alamat']?.toString() ?? '',
      tanggalMap: json['tanggal_map']?.toString() ?? '',
      tanggalBast: json['tanggal_bast']?.toString() ?? '',
      tanggalSjMap: json['tanggal_sj_map']?.toString() ?? '',
      nomorSj: json['nomor_sj']?.toString() ?? '',
      mspkNama: json['mspk_nama']?.toString() ?? '',
      mspkUkuran: json['mspk_ukuran']?.toString() ?? '',
      mspkKain: json['mspk_kain']?.toString() ?? '',
      mspkFinishing: json['mspk_finishing']?.toString() ?? '',
      mspkKeterangan: json['mspk_keterangan']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
    );
  }
}

class TrackingSpkScheduleItem {
  final String tanggal;
  final double jumlah;

  const TrackingSpkScheduleItem({
    this.tanggal = '',
    this.jumlah = 0.0,
  });

  factory TrackingSpkScheduleItem.fromJson(Map<String, dynamic> json) {
    return TrackingSpkScheduleItem(
      tanggal: json['tanggal']?.toString() ?? '',
      jumlah: (json['jumlah'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TrackingSpkListItem {
  final String noSpk;
  final String tanggalSpk;
  final String customer;
  final String sales;
  final String namaBarang;
  final double qty;
  final double realisasiTotal;
  final String status;
  final List<TrackingSpkScheduleItem> estimasiList;
  final double estimasiTotal;
  final List<TrackingSpkScheduleItem> komitmenList;
  final double komitmenTotal;
  final List<TrackingSpkScheduleItem> realisasiList;

  const TrackingSpkListItem({
    required this.noSpk,
    this.tanggalSpk = '',
    this.customer = '',
    this.sales = '',
    this.namaBarang = '',
    this.qty = 0.0,
    this.realisasiTotal = 0.0,
    this.status = '',
    this.estimasiList = const [],
    this.estimasiTotal = 0.0,
    this.komitmenList = const [],
    this.komitmenTotal = 0.0,
    this.realisasiList = const [],
  });

  factory TrackingSpkListItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['spk_jumlah'] as num?)?.toDouble() ??
        (json['qty'] as num?)?.toDouble() ??
        0.0;
    final realisasi = (json['realisasi_total'] as num?)?.toDouble() ?? 0.0;
    String computedStatus = json['status']?.toString() ?? '';
    if (computedStatus.isEmpty) {
      if (qty > 0 && realisasi >= qty - 0.01) {
        computedStatus = 'CLOSE';
      } else if (realisasi > 0) {
        computedStatus = 'PROSES';
      } else {
        computedStatus = 'OPEN';
      }
    }

    final rawEstimasi = json['estimasi_list'] as List?;
    final estimasi = rawEstimasi != null
        ? rawEstimasi
            .map((e) => TrackingSpkScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : const <TrackingSpkScheduleItem>[];

    final rawKomitmen = json['komitmen_list'] as List?;
    final komitmen = rawKomitmen != null
        ? rawKomitmen
            .map((e) => TrackingSpkScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : const <TrackingSpkScheduleItem>[];

    final rawRealisasiList = json['realisasi_list'] as List?;
    final realList = rawRealisasiList != null
        ? rawRealisasiList
            .map((e) => TrackingSpkScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : const <TrackingSpkScheduleItem>[];

    return TrackingSpkListItem(
      noSpk: json['spk_nomor']?.toString() ??
          json['no_spk']?.toString() ??
          json['mspk_nomor']?.toString() ??
          '',
      tanggalSpk: json['spk_tanggal']?.toString() ??
          json['tanggal_spk']?.toString() ??
          '',
      customer: json['customer']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
      namaBarang: json['spk_nama']?.toString() ??
          json['nama_barang']?.toString() ??
          json['mspk_nama']?.toString() ??
          '',
      qty: qty,
      realisasiTotal: realisasi,
      status: computedStatus,
      estimasiList: estimasi,
      estimasiTotal: (json['estimasi_total'] as num?)?.toDouble() ?? 0.0,
      komitmenList: komitmen,
      komitmenTotal: (json['komitmen_total'] as num?)?.toDouble() ?? 0.0,
      realisasiList: realList,
    );
  }
}
