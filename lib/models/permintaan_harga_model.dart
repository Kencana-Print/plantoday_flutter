class PermintaanHargaItem {
  final String nomor;
  final String tanggal;
  final String nama;
  final String customer;
  final String divisi;
  final double jmlOrder;
  final double harga;
  final double hargaKalkulasi;
  final String status;
  final String ketKalkulasi;
  final String userCreate;

  const PermintaanHargaItem({
    required this.nomor,
    required this.tanggal,
    this.nama = '',
    this.customer = '',
    this.divisi = '',
    this.jmlOrder = 0.0,
    this.harga = 0.0,
    this.hargaKalkulasi = 0.0,
    this.status = '',
    this.ketKalkulasi = '',
    this.userCreate = '',
  });

  factory PermintaanHargaItem.fromJson(Map<String, dynamic> json) {
    return PermintaanHargaItem(
      nomor: json['nomor']?.toString() ?? json['mh_nomor']?.toString() ?? '',
      tanggal:
          json['tanggal']?.toString() ??
          json['created_at_fmt']?.toString() ??
          json['mh_tanggal']?.toString() ??
          '',
      nama: json['nama']?.toString() ?? json['mh_nama']?.toString() ?? '',
      customer:
          json['customer']?.toString() ?? json['mh_cus_nama']?.toString() ?? '',
      divisi: json['divisi']?.toString() ?? json['mh_divisi']?.toString() ?? '',
      jmlOrder:
          (json['jml_order'] as num?)?.toDouble() ??
          (json['mh_jmlorder'] as num?)?.toDouble() ??
          0.0,
      harga:
          (json['harga'] as num?)?.toDouble() ??
          (json['mh_harga'] as num?)?.toDouble() ??
          0.0,
      hargaKalkulasi:
          (json['harga_kalkulasi'] as num?)?.toDouble() ??
          (json['mh_harga_kalkulasi'] as num?)?.toDouble() ??
          0.0,
      status: json['status']?.toString() ?? json['mh_status']?.toString() ?? '',
      ketKalkulasi:
          json['ket_kalkulasi']?.toString() ??
          json['mh_ket_kalkulasi']?.toString() ??
          '',
      userCreate: json['user_create']?.toString() ?? '',
    );
  }
}

class PermintaanHargaDetail {
  final String nomor;
  final String tanggal;
  final String divisi;
  final String divisiNama;
  final String cusKode;
  final String cusNama;
  final String nama;
  final double jmlOrder;
  final double harga;
  final double budget;
  final double hargaKalkulasi;
  final double ongkir;
  final String kain;
  final double panjang;
  final double lebar;
  final String ukuran;
  final String gramasi;
  final String finishing;
  final String sublim;
  final String warna;
  final String proNomor;
  final String gambarUrl;
  final String gambar1Url;
  final String gambar2Url;
  final String workshop;
  final String dateOrder;
  final String createdAtFmt;
  final String keterangan;
  final String userCreate;
  final String nomorCreate;
  final String salesNama;
  final String status;
  final String nomorKalkulasi;
  final String dateKalkulasi;
  final String ketKalkulasi;
  final String userKalkulasi;
  final double kalRpSales;
  final double kalRpSistem;
  final double kalPpn;
  final Map<String, dynamic>? kalkulasiDetail;
  final Map<String, dynamic>? rawJson;

  const PermintaanHargaDetail({
    required this.nomor,
    required this.tanggal,
    this.divisi = '',
    this.divisiNama = '',
    this.cusKode = '',
    this.cusNama = '',
    this.nama = '',
    this.jmlOrder = 0.0,
    this.harga = 0.0,
    this.budget = 0.0,
    this.hargaKalkulasi = 0.0,
    this.ongkir = 0.0,
    this.kain = '',
    this.panjang = 0.0,
    this.lebar = 0.0,
    this.ukuran = '',
    this.gramasi = '',
    this.finishing = '',
    this.sublim = '',
    this.warna = '',
    this.proNomor = '',
    this.gambarUrl = '',
    this.gambar1Url = '',
    this.gambar2Url = '',
    this.workshop = '',
    this.dateOrder = '',
    this.createdAtFmt = '',
    this.keterangan = '',
    this.userCreate = '',
    this.nomorCreate = '',
    this.salesNama = '',
    this.status = '',
    this.nomorKalkulasi = '',
    this.dateKalkulasi = '',
    this.ketKalkulasi = '',
    this.userKalkulasi = '',
    this.kalRpSales = 0.0,
    this.kalRpSistem = 0.0,
    this.kalPpn = 0.0,
    this.kalkulasiDetail,
    this.rawJson,
  });

  bool get isSalesKalkulasi {
    final kalNo =
        (nomorKalkulasi.isNotEmpty
                ? nomorKalkulasi
                : (kalkulasiDetail?['hdr']?['kal_nomor']?.toString() ?? ''))
            .toUpperCase();
    if (kalNo.startsWith('KALS')) return true;

    final kalMh = kalkulasiDetail?['hdr']?['kal_mh_nomor']?.toString() ?? '';
    if (kalMh.isNotEmpty && kalMh == nomor) return true;

    return false;
  }

  bool get isFinance {
    final hdr = kalkulasiDetail?['hdr'];
    if (hdr is Map) {
      if (hdr['is_finance'] == true || hdr['source'] == 'tkalkulasi2') {
        return true;
      }
    }
    final kalNo = (nomorKalkulasi.isNotEmpty
            ? nomorKalkulasi
            : (kalkulasiDetail?['hdr']?['kal_nomor']?.toString() ?? ''))
        .toUpperCase();
    if (kalNo.startsWith('KAL-') ||
        (kalNo.startsWith('KAL') && !kalNo.startsWith('KALS'))) {
      return true;
    }
    return false;
  }

  double get kalRpSistemIncPpn {
    if (kalRpSistem <= 0) return 0.0;
    final ppn = kalPpn > 0
        ? kalPpn
        : (kalkulasiDetail?['hdr']?['kal_ppn'] as num?)?.toDouble() ?? 0.0;
    if (ppn > 0) {
      return (kalRpSistem * (1 + ppn / 100)).roundToDouble();
    }
    return kalRpSistem;
  }

  double get kalRpSalesIncPpn {
    if (kalRpSales <= 0) return 0.0;
    final ppn = kalPpn > 0
        ? kalPpn
        : (kalkulasiDetail?['hdr']?['kal_ppn'] as num?)?.toDouble() ?? 0.0;
    if (ppn > 0) {
      return (kalRpSales * (1 + ppn / 100)).roundToDouble();
    }
    return kalRpSales;
  }

  String get kodeKh {
    final fromHdr = kalkulasiDetail?['hdr']?['kal_kh_kode']?.toString().trim();
    if (fromHdr != null && fromHdr.isNotEmpty) {
      return fromHdr.toUpperCase();
    }

    if (rawJson != null) {
      final fromRaw =
          rawJson!['kal_kh_kode']?.toString().trim() ??
          rawJson!['kh_kode']?.toString().trim() ??
          rawJson!['garmen_model']?.toString().trim() ??
          rawJson!['kode_model']?.toString().trim() ??
          rawJson!['mh_kode_model']?.toString().trim() ??
          '';
      if (fromRaw.isNotEmpty) {
        return fromRaw.toUpperCase();
      }
    }

    if (kalkulasiDetail?['komponen'] is List) {
      final komponenList = (kalkulasiDetail!['komponen'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final hasLengan = komponenList.any(
        (k) =>
            (k['kk_komponen']?.toString().toUpperCase().trim() ?? '') ==
            'LENGAN',
      );
      if (hasLengan) {
        return 'KH-0002';
      }
    }

    final text = '$keterangan $ketKalkulasi $ukuran $nama'.toUpperCase();
    if (text.contains('KH-0002') ||
        text.contains('2 WARNA') ||
        text.contains('2WARNA')) {
      return 'KH-0002';
    } else if (text.contains('KH-0001') ||
        text.contains('1 WARNA') ||
        text.contains('1WARNA')) {
      return 'KH-0001';
    }

    if (divisi == '4') {
      return 'KH-0001';
    }

    return '';
  }

  String? get keteranganWarnaKh {
    final code = kodeKh;
    if (code.isEmpty) return null;

    if (code.contains('KH-0002') ||
        code.contains('0002') ||
        code.contains('2 WARNA')) {
      return '2 Warna (KH-0002)';
    } else if (code.contains('KH-0001') ||
        code.contains('0001') ||
        code.contains('1 WARNA')) {
      return '1 Warna (KH-0001)';
    }

    return code;
  }

  List<Map<String, dynamic>> get garmenTambahanList {
    final List<Map<String, dynamic>> result = [];

    // 1. Dari kalkulasiDetail['aksesories']
    final aksList = kalkulasiDetail?['aksesories'];
    if (aksList is List && aksList.isNotEmpty) {
      for (final a in aksList) {
        if (a is Map) {
          final ket =
              a['ka_aksesories']?.toString() ??
              a['ket']?.toString() ??
              a['nama']?.toString() ??
              '';
          final tarif =
              (a['ka_biaya'] as num?)?.toInt() ??
              (a['tarif'] as num?)?.toInt() ??
              (a['biaya'] as num?)?.toInt() ??
              0;
          if (ket.isNotEmpty) {
            result.add({'ket': ket, 'tarif': tarif});
          }
        }
      }
    }

    // 2. Fallback dari rawJson['garmen_tambahan']
    if (result.isEmpty && rawJson?['garmen_tambahan'] is List) {
      for (final a in rawJson!['garmen_tambahan'] as List) {
        if (a is Map) {
          final ket = a['ket']?.toString() ?? a['nama']?.toString() ?? '';
          final tarif =
              (a['tarif'] as num?)?.toInt() ??
              (a['biaya'] as num?)?.toInt() ??
              0;
          if (ket.isNotEmpty) {
            result.add({'ket': ket, 'tarif': tarif});
          }
        }
      }
    }

    return result;
  }

  List<Map<String, dynamic>> get garmenCetakList {
    final List<Map<String, dynamic>> result = [];

    // 1. Dari kalkulasiDetail['ctk_list']
    final ctkList = kalkulasiDetail?['ctk_list'];
    if (ctkList is List && ctkList.isNotEmpty) {
      for (final c in ctkList) {
        if (c is Map) {
          final ket =
              c['kc_ket']?.toString() ??
              c['ket']?.toString() ??
              c['nama']?.toString() ??
              '';
          final biaya =
              (c['kc_biaya'] as num?)?.toInt() ??
              (c['biaya'] as num?)?.toInt() ??
              0;

          String jenis = c['jenis']?.toString().toUpperCase().trim() ?? '';
          if (jenis.isEmpty) {
            final uKet = ket.toUpperCase();
            if (uKet.startsWith('DTF')) {
              jenis = 'DTF';
            } else if (uKet.startsWith('BORDIR')) {
              jenis = 'BORDIR';
            } else if (uKet.startsWith('SUBLIM')) {
              jenis = 'SUBLIM';
            } else if (uKet.startsWith('POLYFLEX')) {
              jenis = 'POLYFLEX';
            } else {
              jenis = 'SABLON';
            }
          }

          if (ket.isNotEmpty) {
            result.add({'jenis': jenis, 'ket': ket, 'biaya': biaya});
          }
        }
      }
    }

    // 2. Fallback jika ctk_list kosong: dari kalkulasiDetail sub-objek cetak
    if (result.isEmpty && kalkulasiDetail != null) {
      // Bordir
      final bor = kalkulasiDetail!['bordir'];
      if (bor is Map) {
        final rp = (bor['kald_rpbordir'] as num?)?.toInt() ?? 0;
        final cm = (bor['kald_cmbordir'] as num?)?.toDouble() ?? 0.0;
        if (rp > 0) {
          final label = cm > 0 ? 'BORDIR ${cm.toInt()} cm' : 'BORDIR';
          result.add({'jenis': 'BORDIR', 'ket': label, 'biaya': rp});
        }
      }

      // DTF
      final dtf = kalkulasiDetail!['dtf'];
      if (dtf is Map) {
        final rp = (dtf['kald_rpdtf'] as num?)?.toInt() ?? 0;
        final cm = (dtf['kald_cmdtf'] as num?)?.toDouble() ?? 0.0;
        if (rp > 0) {
          final label = cm > 0 ? 'DTF ${cm.toInt()} cm' : 'DTF';
          result.add({'jenis': 'DTF', 'ket': label, 'biaya': rp});
        }
      }

      // Sublim
      final sub = kalkulasiDetail!['sublim'];
      if (sub is Map) {
        final rp = (sub['kald_rpsublim'] as num?)?.toInt() ?? 0;
        if (rp > 0) {
          result.add({'jenis': 'SUBLIM', 'ket': 'SUBLIM', 'biaya': rp});
        }
      }

      // Sablon (tkalkulasi_cetak)
      final ctk = kalkulasiDetail!['cetak'];
      if (ctk is Map) {
        final rp = (ctk['kald_rpcetak'] as num?)?.toInt() ?? 0;
        if (rp > 0) {
          result.add({'jenis': 'SABLON', 'ket': 'SABLON', 'biaya': rp});
        }
      }

      // Polyflex
      final pol = kalkulasiDetail!['polyflex'];
      if (pol is Map) {
        final rp = (pol['kald_rppolyflex'] as num?)?.toInt() ?? 0;
        final cm = (pol['kald_cmpolyflex'] as num?)?.toDouble() ?? 0.0;
        if (rp > 0) {
          final label = cm > 0 ? 'POLYFLEX ${cm.toInt()} cm' : 'POLYFLEX';
          result.add({'jenis': 'POLYFLEX', 'ket': label, 'biaya': rp});
        }
      }
    }

    // 3. Fallback dari rawJson['garmen_cetak']
    if (result.isEmpty && rawJson?['garmen_cetak'] is List) {
      for (final c in rawJson!['garmen_cetak'] as List) {
        if (c is Map) {
          final ket = c['ket']?.toString() ?? c['nama']?.toString() ?? '';
          final biaya = (c['biaya'] as num?)?.toInt() ?? 0;
          final jenis = c['jenis']?.toString().toUpperCase() ?? 'SABLON';
          if (ket.isNotEmpty) {
            result.add({'jenis': jenis, 'ket': ket, 'biaya': biaya});
          }
        }
      }
    }

    return result;
  }

  factory PermintaanHargaDetail.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? kalDetail;
    if (json['kalkulasi_detail'] is Map) {
      kalDetail = Map<String, dynamic>.from(json['kalkulasi_detail'] as Map);
    }

    final rawKetKal = json['mh_ket_kalkulasi']?.toString() ??
        json['ket_kalkulasi']?.toString() ??
        '';
    final ketKalkulasiVal = rawKetKal.isNotEmpty
        ? rawKetKal
        : (kalDetail?['hdr']?['kal_ket']?.toString() ?? '');

    final rawDateKal = json['mh_date_kalkulasi']?.toString() ?? '';
    final dateKalkulasiVal = rawDateKal.isNotEmpty
        ? rawDateKal
        : (kalDetail?['hdr']?['date_modified']?.toString() ??
            kalDetail?['hdr']?['date_create']?.toString() ??
            kalDetail?['hdr']?['kal_tanggal']?.toString() ??
            '');

    final rawUserKal = json['user_kalkulasi']?.toString() ??
        json['mh_apv_usr']?.toString() ??
        '';
    final userKalkulasiVal = rawUserKal.isNotEmpty
        ? rawUserKal
        : (kalDetail?['hdr']?['user_create']?.toString() ??
            kalDetail?['hdr']?['user_modified']?.toString() ??
            '');

    return PermintaanHargaDetail(
      nomor: json['mh_nomor']?.toString() ?? json['nomor']?.toString() ?? '',
      tanggal:
          json['mh_tanggal']?.toString() ?? json['tanggal']?.toString() ?? '',
      divisi: json['mh_divisi']?.toString() ?? json['divisi']?.toString() ?? '',
      divisiNama: json['divisi_nama']?.toString() ?? '',
      cusKode: json['mh_cus_kode']?.toString() ?? '',
      cusNama:
          json['mh_cus_nama']?.toString() ?? json['customer']?.toString() ?? '',
      nama: json['mh_nama']?.toString() ?? json['nama']?.toString() ?? '',
      jmlOrder:
          (json['mh_jmlorder'] as num?)?.toDouble() ??
          (json['jml_order'] as num?)?.toDouble() ??
          0.0,
      harga:
          (json['mh_harga'] as num?)?.toDouble() ??
          (json['harga'] as num?)?.toDouble() ??
          0.0,
      budget: (json['mh_budget'] as num?)?.toDouble() ?? 0.0,
      hargaKalkulasi:
          (json['mh_harga_kalkulasi'] as num?)?.toDouble() ??
          (json['harga_kalkulasi'] as num?)?.toDouble() ??
          (kalDetail?['hdr']?['kal_rpsesuai'] as num?)?.toDouble() ??
          0.0,
      ongkir:
          (json['mh_ongkir'] as num?)?.toDouble() ??
          (json['kald_rpkirim'] as num?)?.toDouble() ??
          (kalDetail?['dtl']?['kald_rpkirim'] as num?)?.toDouble() ??
          0.0,
      kain: json['mh_kain']?.toString() ?? '',
      panjang: (json['mh_panjang'] as num?)?.toDouble() ?? 0.0,
      lebar: (json['mh_lebar'] as num?)?.toDouble() ?? 0.0,
      ukuran: json['mh_ukuran']?.toString() ?? '',
      gramasi: json['mh_gramasi']?.toString() ?? '',
      finishing: json['mh_finishing']?.toString() ?? '',
      sublim: json['mh_sublim']?.toString() ?? '',
      warna: json['mh_warna']?.toString() ?? '',
      proNomor:
          json['mh_pro_nomor']?.toString() ??
          json['pro_nomor']?.toString() ??
          '',
      gambarUrl: json['mh_gambar']?.toString() ?? '',
      gambar1Url:
          json['gambar_1_url']?.toString() ??
          json['gambar1_url']?.toString() ??
          json['img1']?.toString() ??
          json['image1']?.toString() ??
          json['mh_gambar1']?.toString() ??
          json['gambar1']?.toString() ??
          '',
      gambar2Url:
          json['gambar_2_url']?.toString() ??
          json['gambar2_url']?.toString() ??
          json['img2']?.toString() ??
          json['image2']?.toString() ??
          json['mh_gambar2']?.toString() ??
          json['gambar2']?.toString() ??
          '',
      workshop: json['mh_workshop']?.toString() ?? '',
      dateOrder: json['mh_dateorder']?.toString() ?? '',
      createdAtFmt:
          json['created_at_fmt']?.toString() ??
          json['date_create']?.toString() ??
          '',
      keterangan: json['mh_ket']?.toString() ?? '',
      userCreate: json['user_create']?.toString() ?? '',
      nomorCreate: json['nomor_create']?.toString() ?? '',
      salesNama: json['sales_nama']?.toString() ?? '',
      status: json['status']?.toString() ?? json['mh_status']?.toString() ?? '',
      nomorKalkulasi:
          (json['mh_nomor_kalkulasi'] != null &&
              json['mh_nomor_kalkulasi'].toString().isNotEmpty)
          ? json['mh_nomor_kalkulasi'].toString()
          : (kalDetail?['hdr']?['kal_nomor']?.toString() ??
                json['nomor_kalkulasi']?.toString() ??
                ''),
      dateKalkulasi: dateKalkulasiVal,
      ketKalkulasi: ketKalkulasiVal,
      userKalkulasi: userKalkulasiVal,
      kalRpSales: (json['kal_rpsales'] as num?)?.toDouble() ??
          (kalDetail?['hdr']?['kal_rpsales'] as num?)?.toDouble() ??
          0.0,
      kalRpSistem: (json['kal_rpsistem'] as num?)?.toDouble() ??
          (kalDetail?['hdr']?['kal_rpsesuai'] as num?)?.toDouble() ??
          (kalDetail?['hdr']?['kal_rpsistem'] as num?)?.toDouble() ??
          0.0,
      kalPpn: (json['kal_ppn'] as num?)?.toDouble() ??
          (kalDetail?['hdr']?['kal_ppn'] as num?)?.toDouble() ??
          0.0,
      kalkulasiDetail: kalDetail,
      rawJson: json,
    );
  }
}
