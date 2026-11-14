class VisitModel {
  final int? id;
  final String? cusKode;
  final String cusNama;
  final String cusAlamat;
  final String tanggal;
  final String note;
  final String catatan;
  final String? realisasi;
  final double? latitude;
  final double? longitude;
  final String? fotoUrl;
  final String? salesName;

  const VisitModel({
    this.id,
    this.cusKode,
    required this.cusNama,
    this.cusAlamat = '',
    required this.tanggal,
    this.note = '',
    this.catatan = '',
    this.realisasi,
    this.latitude,
    this.longitude,
    this.fotoUrl,
    this.salesName,
  });

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }
    return null;
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }
    return null;
  }

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: _parseInt(json['id']),
      cusKode: json['cus_kode']?.toString(),
      cusNama: json['cus_nama']?.toString() ??
          json['cc_nama']?.toString() ??
          json['customer_text']?.toString() ??
          '',
      cusAlamat: json['cus_alamat']?.toString() ??
          json['cc_alamat']?.toString() ??
          json['cus_alamat_text']?.toString() ??
          '',
      tanggal: json['tanggal']?.toString() ??
          json['tanggal_plan']?.toString() ??
          '',
      note: json['note']?.toString() ?? '',
      catatan: json['catatan']?.toString() ?? '',
      realisasi: json['realisasi']?.toString(),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      fotoUrl: json['foto_url']?.toString() ?? json['foto']?.toString(),
      salesName: json['sales_name']?.toString() ??
          json['sales']?.toString() ??
          json['user']?.toString(),
    );
  }
}
