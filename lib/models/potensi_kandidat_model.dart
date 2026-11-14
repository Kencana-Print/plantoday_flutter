class PotensiKandidatItem {
  final String tipeSumber; // 'PENAWARAN' | 'MAP'
  final String? penNomor;
  final String? mspkNomor;
  final String? itemId;
  final String namaItem;
  final double harga;
  final double? qty;
  final String? satuan;
  final String? tanggal;
  final String? salesKode;
  final String? salesNama;
  final String? customerKode;
  final String? customerNama;

  const PotensiKandidatItem({
    required this.tipeSumber,
    this.penNomor,
    this.mspkNomor,
    this.itemId,
    required this.namaItem,
    required this.harga,
    this.qty,
    this.satuan,
    this.tanggal,
    this.salesKode,
    this.salesNama,
    this.customerKode,
    this.customerNama,
  });

  String get itemKey =>
      '${tipeSumber}_${penNomor ?? ""}_${mspkNomor ?? ""}_${itemId ?? ""}_$namaItem';

  factory PotensiKandidatItem.fromJson(Map<String, dynamic> json) {
    return PotensiKandidatItem(
      tipeSumber: json['tipe_sumber']?.toString() ?? 'PENAWARAN',
      penNomor: json['pen_nomor']?.toString(),
      mspkNomor: json['mspk_nomor']?.toString(),
      itemId: json['item_id']?.toString(),
      namaItem: json['nama_item']?.toString() ?? '',
      harga: (json['harga'] as num?)?.toDouble() ?? 0.0,
      qty: (json['qty'] as num?)?.toDouble(),
      satuan: json['satuan']?.toString(),
      tanggal: json['tanggal']?.toString(),
      salesKode: json['sales_kode']?.toString(),
      salesNama: json['sales_nama']?.toString(),
      customerKode: json['customer_kode']?.toString(),
      customerNama: json['customer_nama']?.toString(),
    );
  }

  Map<String, dynamic> toBatchPayload() {
    return {
      'tipe_sumber': tipeSumber,
      'pen_nomor': penNomor,
      'mspk_nomor': mspkNomor,
      'item_id': itemId,
      'pend_id': itemId,
      'pot_pend_id': itemId,
      'nama_item': namaItem,
      'harga': harga,
      'qty': qty,
      'satuan': satuan,
      'tanggal': tanggal,
      'sales_kode': salesKode,
      'sales_nama': salesNama,
      'customer_kode': customerKode,
      'customer_nama': customerNama,
    };
  }
}
