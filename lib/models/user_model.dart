class UserModel {
  final int id;
  final String nama;
  final String jabatan;
  final String cabang;
  final String? kode;
  final String? salesKode;
  final String? salKode;
  final String? spkSalKode;
  final String? kodeSales;

  const UserModel({
    required this.id,
    required this.nama,
    required this.jabatan,
    required this.cabang,
    this.kode,
    this.salesKode,
    this.salKode,
    this.spkSalKode,
    this.kodeSales,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nama: json['nama']?.toString() ?? '',
      jabatan: json['jabatan']?.toString() ?? '',
      cabang: json['cabang']?.toString() ?? '',
      kode: json['kode']?.toString(),
      salesKode: json['sales_kode']?.toString(),
      salKode: json['sal_kode']?.toString(),
      spkSalKode: json['spk_sal_kode']?.toString(),
      kodeSales: json['kode_sales']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'jabatan': jabatan,
      'cabang': cabang,
      'kode': kode,
      'sales_kode': salesKode,
      'sal_kode': salKode,
      'spk_sal_kode': spkSalKode,
      'kode_sales': kodeSales,
    };
  }

  UserModel copyWith({
    int? id,
    String? nama,
    String? jabatan,
    String? cabang,
    String? kode,
    String? salesKode,
    String? salKode,
    String? spkSalKode,
    String? kodeSales,
  }) {
    return UserModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      jabatan: jabatan ?? this.jabatan,
      cabang: cabang ?? this.cabang,
      kode: kode ?? this.kode,
      salesKode: salesKode ?? this.salesKode,
      salKode: salKode ?? this.salKode,
      spkSalKode: spkSalKode ?? this.spkSalKode,
      kodeSales: kodeSales ?? this.kodeSales,
    );
  }

  bool get isManager =>
      jabatan.trim().toUpperCase().split(RegExp(r'[\s/_-]+')).contains('MANAGER');
}
