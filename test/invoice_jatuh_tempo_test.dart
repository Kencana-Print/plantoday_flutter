import 'package:flutter_test/flutter_test.dart';
import 'package:plantoday_flutter/models/invoice_jatuh_tempo_model.dart';

void main() {
  group('InvoiceJatuhTempoModel Tests', () {
    test('parses summary with aging buckets correctly', () {
      final json = {
        'total_invoice': 15,
        'total_overdue': 25000000.0,
        'aging': {
          '1_30': {'count': 6, 'nominal': 5000000.0},
          '31_60': {'count': 4, 'nominal': 8000000.0},
          '61_90': {'count': 3, 'nominal': 7000000.0},
          'gt_90': {'count': 2, 'nominal': 5000000.0},
        },
        'by_sales': [
          {
            'sal_kode': 'S01',
            'sal_nama': 'Budi',
            'jml_invoice': 5,
            'total_sisa': 10000000.0,
          }
        ],
      };

      final summary = InvoiceJatuhTempoSummary.fromJson(json);

      expect(summary.totalInvoice, 15);
      expect(summary.totalOverdue, 25000000.0);
      expect(summary.aging.d1To30.count, 6);
      expect(summary.aging.d1To30.nominal, 5000000.0);
      expect(summary.aging.d31To60.count, 4);
      expect(summary.aging.d61To90.count, 3);
      expect(summary.aging.dGt90.count, 2);
      expect(summary.aging.dGt90.nominal, 5000000.0);
      expect(summary.bySales.length, 1);
      expect(summary.bySales.first.salNama, 'Budi');
      expect(summary.bySales.first.totalSisa, 10000000.0);
    });

    test('parses invoice item fields correctly', () {
      final json = {
        'nota': 'INV/2024/001',
        'nota_tampil': 'INV-001',
        'tanggal': '01-10-2024',
        'tempo': '15-10-2024',
        'terlambat_hari': 45,
        'cus_kode': 'CUS01',
        'cus_nama': 'PT Maju Jaya',
        'sal_kode': 'S01',
        'sal_nama': 'Budi Santoso',
        'nominal': 10000000,
        'terbayar': 4000000,
        'sisa': 6000000,
      };

      final item = InvoiceJatuhTempoItem.fromJson(json);

      expect(item.nota, 'INV/2024/001');
      expect(item.notaTampil, 'INV-001');
      expect(item.tanggal, '01-10-2024');
      expect(item.tempo, '15-10-2024');
      expect(item.terlambatHari, 45);
      expect(item.cusNama, 'PT Maju Jaya');
      expect(item.salNama, 'Budi Santoso');
      expect(item.nominal, 10000000.0);
      expect(item.terbayar, 4000000.0);
      expect(item.sisa, 6000000.0);
    });

    test('groups items per sales sorted by totalSisa descending', () {
      final items = [
        InvoiceJatuhTempoItem.fromJson({
          'nota': 'N1',
          'sal_kode': '01',
          'sal_nama': 'Sales A',
          'terlambat_hari': 10,
          'nominal': 5000000,
          'terbayar': 1000000,
          'sisa': 4000000,
        }),
        InvoiceJatuhTempoItem.fromJson({
          'nota': 'N2',
          'sal_kode': '02',
          'sal_nama': 'Sales B',
          'terlambat_hari': 30,
          'nominal': 12000000,
          'terbayar': 2000000,
          'sisa': 10000000,
        }),
      ];

      final groups = InkasoSalesGroup.groupItems(items);
      expect(groups.length, 2);
      expect(groups.first.salNama, 'Sales B');
      expect(groups.first.totalSisa, 10000000.0);
      expect(groups.first.totalTerealisasi, 2000000.0);
      expect(groups.last.salNama, 'Sales A');
    });
  });
}
