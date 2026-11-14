class KurirRencanaItem {
  final int id;
  final String kodePengiriman;
  final String sender;
  final String receiver;
  final String note;
  final String catatan;
  final String tanggalPlan;
  final String jamPlan;
  final String status;
  final String? realisasi;

  const KurirRencanaItem({
    required this.id,
    required this.kodePengiriman,
    this.sender = '',
    this.receiver = '',
    this.note = '',
    this.catatan = '',
    this.tanggalPlan = '',
    this.jamPlan = '',
    this.status = '',
    this.realisasi,
  });

  factory KurirRencanaItem.fromJson(Map<String, dynamic> json) {
    return KurirRencanaItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      kodePengiriman: json['kode_pengiriman']?.toString() ??
          (json['id'] != null ? 'KRM-${json['id'].toString().padLeft(6, '0')}' : ''),
      sender: json['sender']?.toString() ?? '',
      receiver: json['receiver']?.toString() ?? json['tujuan']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      catatan: json['catatan']?.toString() ?? json['alamat_tujuan']?.toString() ?? '',
      tanggalPlan: json['tanggal_plan']?.toString() ??
          json['tanggal_kirim']?.toString() ??
          json['tanggal']?.toString() ??
          '',
      jamPlan: json['jam_plan']?.toString() ?? json['jam']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      realisasi: json['realisasi']?.toString(),
    );
  }
}
