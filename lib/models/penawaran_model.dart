class PenawaranListItem {
  final String nomor;
  final String tanggal;
  final String divisi;
  final String tipe;
  final String perusahaan;
  final String customer;
  final String sales;
  final String keterangan;
  final double nominal;
  final int detailCount;
  final String approvalState; // '' | 'WAIT' | 'ACC' | 'TOLAK'
  final bool isApproved;

  const PenawaranListItem({
    required this.nomor,
    required this.tanggal,
    this.divisi = '',
    this.tipe = '',
    this.perusahaan = '',
    this.customer = '',
    this.sales = '',
    this.keterangan = '',
    this.nominal = 0.0,
    this.detailCount = 0,
    this.approvalState = '',
    this.isApproved = false,
  });

  factory PenawaranListItem.fromJson(Map<String, dynamic> json) {
    return PenawaranListItem(
      nomor: json['nomor']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      divisi: json['divisi']?.toString() ?? '',
      tipe: json['tipe']?.toString() ?? '',
      perusahaan: json['perusahaan']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      nominal: (json['nominal'] as num?)?.toDouble() ?? 0.0,
      detailCount: (json['detail_count'] as num?)?.toInt() ?? 0,
      approvalState: json['approval_state']?.toString() ?? '',
      isApproved: json['is_approved'] == 1 || json['is_approved'] == true,
    );
  }
}

class PenawaranHeader {
  final String nomor;
  final String tanggal;
  final String divisi;
  final String tipe;
  final String perusahaanKode;
  final String perusahaan;
  final String customerKode;
  final String customer;
  final String customerAlamat;
  final String customerKota;
  final String up;
  final String ttd;
  final String ttdJabatan;
  final int statusHarga;
  final String digitalSign;
  final String digitalSignDate;
  final String salesKode;
  final String sales;
  final String keterangan;
  final String note;
  final double nominal;
  final String approvalState;
  final String rekening;
  final double dpPer;
  final String bank;
  final String bankAtasnama;
  final String bankCabang;
  final String perushEmail;
  final String perushTelp;
  final String perushFax;
  final String perushAlamatnpwp;
  final String tambahan;
  final String sample;
  final int cetakTotal;
  final String marketing;
  final String marketingTelp;
  final String mx;
  final double panjang;
  final double lebar;

  const PenawaranHeader({
    required this.nomor,
    required this.tanggal,
    this.divisi = '',
    this.tipe = '',
    this.perusahaanKode = '',
    this.perusahaan = '',
    this.customerKode = '',
    this.customer = '',
    this.customerAlamat = '',
    this.customerKota = '',
    this.up = '',
    this.ttd = '',
    this.ttdJabatan = '',
    this.statusHarga = 0,
    this.digitalSign = '',
    this.digitalSignDate = '',
    this.salesKode = '',
    this.sales = '',
    this.keterangan = '',
    this.note = '',
    this.nominal = 0.0,
    this.approvalState = '',
    this.rekening = '',
    this.dpPer = 0.0,
    this.bank = '',
    this.bankAtasnama = '',
    this.bankCabang = '',
    this.perushEmail = '',
    this.perushTelp = '',
    this.perushFax = '',
    this.perushAlamatnpwp = '',
    this.tambahan = '',
    this.sample = '',
    this.cetakTotal = 1,
    this.marketing = '',
    this.marketingTelp = '',
    this.mx = '',
    this.panjang = 0.0,
    this.lebar = 0.0,
  });

  bool get isApproved =>
      approvalState.toUpperCase() == 'ACC' ||
      digitalSign.toUpperCase() == 'Y';

  factory PenawaranHeader.fromJson(Map<String, dynamic> json) {
    return PenawaranHeader(
      nomor: json['nomor']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      divisi: json['divisi']?.toString() ?? json['divisi_nama']?.toString() ?? '',
      tipe: json['tipe']?.toString() ?? '',
      perusahaanKode: json['perusahaan_kode']?.toString() ?? '',
      perusahaan: json['perusahaan']?.toString() ?? '',
      customerKode: json['customer_kode']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      customerAlamat: json['customer_alamat']?.toString() ?? '',
      customerKota: json['customer_kota']?.toString() ?? '',
      up: json['up']?.toString() ?? '',
      ttd: json['ttd']?.toString() ?? '',
      ttdJabatan: json['ttd_jabatan']?.toString() ?? '',
      statusHarga: int.tryParse(json['status_harga']?.toString() ?? '0') ?? 0,
      digitalSign: json['digital_sign']?.toString() ?? '',
      digitalSignDate: json['digital_sign_date']?.toString() ?? '',
      salesKode: json['sales_kode']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      nominal: (json['nominal'] as num?)?.toDouble() ?? 0.0,
      approvalState: json['approval_state']?.toString() ?? '',
      rekening: json['rekening']?.toString() ?? json['pen_rekening']?.toString() ?? '',
      dpPer: (json['dp_per'] as num?)?.toDouble() ?? (json['pen_dpper'] as num?)?.toDouble() ?? 0.0,
      bank: json['bank']?.toString() ?? json['perushd_bank']?.toString() ?? '',
      bankAtasnama: json['bank_atasnama']?.toString() ?? json['perushd_atasnama']?.toString() ?? '',
      bankCabang: json['bank_cabang']?.toString() ?? json['perushd_cabang']?.toString() ?? '',
      perushEmail: json['perush_email']?.toString() ?? '',
      perushTelp: json['perush_telp']?.toString() ?? '',
      perushFax: json['perush_fax']?.toString() ?? '',
      perushAlamatnpwp: json['perush_alamatnpwp']?.toString() ?? '',
      tambahan: json['tambahan']?.toString() ?? json['pen_tambahan']?.toString() ?? '',
      sample: json['sample']?.toString() ?? json['pen_sample']?.toString() ?? '',
      cetakTotal: int.tryParse(json['cetak_total']?.toString() ?? json['pen_cetaktotal']?.toString() ?? '1') ?? 1,
      marketing: json['marketing']?.toString() ?? json['pen_marketing']?.toString() ?? '',
      marketingTelp: json['marketing_telp']?.toString() ?? json['pen_marketing_telp']?.toString() ?? '',
      mx: json['mx']?.toString() ?? json['pen_mx']?.toString() ?? '',
      panjang: (json['panjang'] as num?)?.toDouble() ?? (json['pen_panjang'] as num?)?.toDouble() ?? 0.0,
      lebar: (json['lebar'] as num?)?.toDouble() ?? (json['pen_lebar'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PenawaranDetailItem {
  final String id;
  final int urutan;
  final String minta;
  final String namaBarang;
  final String bahan;
  final String ukuran;
  final double panjang;
  final double lebar;
  final String satuan;
  final double qty;
  final double harga;
  final double total;
  final String status;
  final String ketBatal;
  final String ketConfirm;

  const PenawaranDetailItem({
    required this.id,
    this.urutan = 0,
    this.minta = '',
    required this.namaBarang,
    this.bahan = '',
    this.ukuran = '',
    this.panjang = 0.0,
    this.lebar = 0.0,
    this.satuan = 'pcs',
    this.qty = 0.0,
    this.harga = 0.0,
    this.total = 0.0,
    this.status = '',
    this.ketBatal = '',
    this.ketConfirm = '',
  });

  factory PenawaranDetailItem.fromJson(Map<String, dynamic> json) {
    return PenawaranDetailItem(
      id: json['id']?.toString() ?? '',
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
      minta: json['minta']?.toString() ?? json['pend_minta']?.toString() ?? '',
      namaBarang: json['namaBarang']?.toString() ??
          json['nama_barang']?.toString() ??
          '',
      bahan: json['bahan']?.toString() ?? '',
      ukuran: json['ukuran']?.toString() ?? '',
      panjang: (json['panjang'] as num?)?.toDouble() ?? 0.0,
      lebar: (json['lebar'] as num?)?.toDouble() ?? 0.0,
      satuan: json['satuan']?.toString() ?? 'pcs',
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      harga: (json['harga'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? '',
      ketBatal: json['ket_batal']?.toString() ?? '',
      ketConfirm: json['ket_confirm']?.toString() ?? '',
    );
  }
}

class PenawaranActivityLog {
  final String type;
  final String approvalState;
  final String note;
  final String user;
  final String createdAt;

  const PenawaranActivityLog({
    this.type = '',
    this.approvalState = '',
    this.note = '',
    this.user = '',
    this.createdAt = '',
  });

  factory PenawaranActivityLog.fromJson(Map<String, dynamic> json) {
    return PenawaranActivityLog(
      type: json['type']?.toString() ?? '',
      approvalState: json['approval_state']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      user: json['user']?.toString() ?? json['username']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class PenawaranDetailData {
  final PenawaranHeader? header;
  final List<PenawaranDetailItem> details;

  const PenawaranDetailData({
    this.header,
    required this.details,
  });
}
