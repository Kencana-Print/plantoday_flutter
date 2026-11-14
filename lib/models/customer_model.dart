class CustomerModel {
  final int? id;
  final String kode;
  final String nama;
  final String alamat;
  final String kota;
  final String telp;
  final String cp;
  final String email;
  final String korporasi; // 'Y' | 'N'
  final String jenisUsaha;
  final String npwp;
  final String namaNpwp;
  final String alamatNpwp;
  final String kotaNpwp;

  const CustomerModel({
    this.id,
    required this.kode,
    required this.nama,
    required this.alamat,
    this.kota = '',
    this.telp = '',
    this.cp = '',
    this.email = '',
    this.korporasi = 'N',
    this.jenisUsaha = '',
    this.npwp = '',
    this.namaNpwp = '',
    this.alamatNpwp = '',
    this.kotaNpwp = '',
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      kode: json['cc_kode']?.toString() ?? json['kode']?.toString() ?? json['cus_kode']?.toString() ?? '',
      nama: json['cc_nama']?.toString() ?? json['nama']?.toString() ?? json['cus_nama']?.toString() ?? '',
      alamat: json['cc_alamat']?.toString() ?? json['alamat']?.toString() ?? json['cus_alamat']?.toString() ?? '',
      kota: json['cc_kota']?.toString() ?? json['kota']?.toString() ?? '',
      telp: json['cc_telp']?.toString() ?? json['cus_telp']?.toString() ?? '',
      cp: json['cc_cp']?.toString() ?? json['cus_cp']?.toString() ?? '',
      email: json['cus_email']?.toString() ?? json['email']?.toString() ?? '',
      korporasi: json['cus_korporasi']?.toString() ?? 'N',
      jenisUsaha: json['cus_jenisusaha']?.toString() ?? '',
      npwp: json['cus_npwp']?.toString() ?? '',
      namaNpwp: json['cus_nama_npwp']?.toString() ?? '',
      alamatNpwp: json['cus_alamat_npwp']?.toString() ?? '',
      kotaNpwp: json['cus_kota_npwp']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama': nama,
      'alamat': alamat,
      'kota': kota,
      'cus_telp': telp,
      'cus_cp': cp,
      'cus_email': email,
      'cus_korporasi': korporasi,
      'cus_jenisusaha': jenisUsaha,
      'cus_npwp': npwp,
      'cus_nama_npwp': namaNpwp,
      'cus_alamat_npwp': alamatNpwp,
      'cus_kota_npwp': kotaNpwp,
    };
  }
}
