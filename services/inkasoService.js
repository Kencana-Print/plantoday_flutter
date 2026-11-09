const db = require("../config/dbPenawaran");

const INKASO_TOL = 1000;

// Sisa tagihan per baris piutang_debet `p` — replikasi 100% dari Manksi (INKASO_SISA_CORR)
const INKASO_SISA_CORR = `
  (IFNULL((
      SELECT pd2.debet
      FROM piutang_debet pd2
      WHERE pd2.nota = (SELECT tf.invf_taknormal FROM tinv_flag tf WHERE tf.invf_normal = p.nota LIMIT 1)
        AND pd2.is_writeoff = 0
      LIMIT 1
    ), p.debet) - IFNULL((
    SELECT SUM(kd.kredit)
    FROM piutang_kredit_detail kd
    INNER JOIN piutang_kredit_header kh ON kh.nomor = kd.nomor
    WHERE kd.nota = IFNULL(
      (SELECT tf.invf_taknormal FROM tinv_flag tf WHERE tf.invf_normal = p.nota LIMIT 1),
      p.nota
    )
  ), 0))
`;

const INKASO_VALID_FILTER = `
  AND p.is_writeoff = 0
  AND (p.flag = 0 OR EXISTS (SELECT 1 FROM tinv_flag tf WHERE tf.invf_normal = p.nota))
  AND NOT EXISTS (
    SELECT 1 FROM tinv_flag tf2 WHERE tf2.invf_taknormal = p.nota
  )
`;

const bucketOf = (hari) => {
    if (hari >= 1 && hari <= 30) return "1_30";
    if (hari >= 31 && hari <= 60) return "31_60";
    if (hari >= 61 && hari <= 90) return "61_90";
    if (hari > 90) return "gt_90";
    return null;
};

const buildResult = (rows, pageNum, limitNum, totalBatal = 0) => {
    const aging = {
        "1_30": { count: 0, nominal: 0 },
        "31_60": { count: 0, nominal: 0 },
        "61_90": { count: 0, nominal: 0 },
        gt_90: { count: 0, nominal: 0 },
    };
    const salesMap = new Map();
    const realisasiPerSales = new Map();
    const activeItems = [];
    let totalOverdue = 0;
    let totalRealisasi = 0;

    for (const r of rows) {
        const nominal = Number(r.NominalAwal ?? r.Nominal) || 0;
        const sisa = Number(r.Sisa) || 0;
        const terealisasi =
            r.Terbayar !== undefined
                ? Number(r.Terbayar) || 0
                : Math.min(nominal, Math.max(nominal - sisa, 0));

        // Persis Manksi getInkasoDashboard: totalRealisasi dihitung sebelum filter sisa <= INKASO_TOL
        totalRealisasi += terealisasi;

        const salKode = r.SalKode || "";
        const salNama = r.SalNama || "(Tanpa Sales)";
        const salesKey = `${salKode}|${salNama}`;
        realisasiPerSales.set(
            salesKey,
            (realisasiPerSales.get(salesKey) || 0) + terealisasi,
        );

        // Sudah lunas (sisa <= 1000) -> keluar dari daftar invoice aktif
        if (sisa <= INKASO_TOL) continue;

        const terlambatHari = Number(r.TerlambatHari) || 0;
        totalOverdue += sisa;

        const key = bucketOf(terlambatHari);
        if (key) {
            aging[key].count += 1;
            aging[key].nominal += sisa;
        }

        const agg = salesMap.get(salesKey) || {
            sal_kode: salKode,
            sal_nama: salNama,
            jml_invoice: 0,
            total_sisa: 0,
            total_terealisasi: 0,
        };
        agg.jml_invoice += 1;
        agg.total_sisa += sisa;
        agg.total_terealisasi += terealisasi;
        salesMap.set(salesKey, agg);

        activeItems.push({
            nomor: r.Nomor || "",
            nota: r.Nota || "",
            nota_tampil: r.NotaTampil || r.Nota || "",
            tanggal: r.Tanggal || "",
            tempo: r.Tempo || "",
            terlambat_hari: terlambatHari,
            cus_kode: r.CusKode || "",
            cus_nama: r.CusNama || "",
            sal_kode: salKode,
            sal_nama: salNama,
            nominal,
            terbayar: terealisasi,
            sisa,
            tgl_target: r.TglTarget || "",
            catatan: r.Catatan || "",
            user_create: r.UserCreate || "",
            date_create: r.DateCreate || "",
        });
    }

    // Sinkronkan total_terealisasi per sales (termasuk invoice yang sudah lunas di sales tsb)
    for (const [salesKey, agg] of salesMap.entries()) {
        agg.total_terealisasi =
            realisasiPerSales.get(salesKey) ?? agg.total_terealisasi;
    }

    activeItems.sort(
        (a, b) =>
            b.terlambat_hari - a.terlambat_hari ||
            String(a.nota).localeCompare(String(b.nota)),
    );

    const bySales = Array.from(salesMap.values()).sort(
        (a, b) => b.total_sisa - a.total_sisa,
    );

    const offset = (pageNum - 1) * limitNum;

    return {
        summary: {
            total_invoice: activeItems.length,
            total_overdue: totalOverdue,
            total_realisasi: totalRealisasi,
            total_batal: Number(totalBatal) || 0,
            aging,
            by_sales: bySales,
        },
        items: activeItems.slice(offset, offset + limitNum),
        pagination: {
            page: pageNum,
            limit: limitNum,
            total_items: activeItems.length,
            total_pages: Math.ceil(activeItems.length / limitNum) || 1,
        },
    };
};

/**
 * Mengambil data Proyeksi Inkaso / Invoice Jatuh Tempo yang ditagih per sales.
 * Replikasi 100% dari getInkasoDashboard di Manksi ERP Web (manksi_backend).
 */
const getInvoiceJatuhTempo = async ({
    salesKode = null,
    search = "",
    page = 1,
    limit = 5000,
}) => {
    const pageNum = Math.max(1, Number(page) || 1);
    const limitNum = Math.max(1, Number(limit) || 5000);

    const params = [];
    const batalParams = [];
    let filterSql = "";
    let batalSalesFilterSql = "";

    if (salesKode) {
        filterSql +=
            " AND (k.pik_sal_kode = ? OR s.sal_nama = ? OR s.sal_nama LIKE ?) ";
        params.push(salesKode, salesKode, `%${salesKode}%`);

        batalSalesFilterSql =
            " AND (k.pik_sal_kode = ? OR s.sal_nama = ? OR s.sal_nama LIKE ?) ";
        batalParams.push(salesKode, salesKode, `%${salesKode}%`);
    }

    if (search) {
        filterSql +=
            " AND (k.pik_nota LIKE ? OR c.cus_nama LIKE ? OR k.pik_cus_kode LIKE ? OR s.sal_nama LIKE ? OR k.pik_catatan LIKE ?) ";
        const s = `%${search}%`;
        params.push(s, s, s, s, s);
    }

    const sql = `
      SELECT
        k.pik_nomor AS Nomor,
        k.pik_nota AS Nota,
        k.pik_nota AS NotaTampil,
        k.pik_sal_kode AS SalKode,
        IFNULL(s.sal_nama, '(Tanpa Sales)') AS SalNama,
        k.pik_cus_kode AS CusKode,
        c.cus_nama AS CusNama,
        k.pik_nominal AS NominalAwal,
        DATE_FORMAT(p.tanggal, '%d-%m-%Y') AS Tanggal,
        DATE_FORMAT(p.tanggal_tempo, '%d-%m-%Y') AS Tempo,
        DATEDIFF(CURDATE(), p.tanggal_tempo) AS TerlambatHari,
        DATE_FORMAT(k.pik_tgl_target, '%Y-%m-%d') AS TglTarget,
        k.pik_catatan AS Catatan,
        k.user_create AS UserCreate,
        DATE_FORMAT(k.date_create, '%Y-%m-%d %H:%i:%s') AS DateCreate,
        ${INKASO_SISA_CORR} AS Sisa
      FROM tproyeksi_inkaso k
      INNER JOIN piutang_debet p ON p.nota = k.pik_nota
        ${INKASO_VALID_FILTER}
      LEFT JOIN tcustomer c ON c.cus_kode = k.pik_cus_kode
      LEFT JOIN tsales s ON s.sal_kode = k.pik_sal_kode
      WHERE k.pik_status <> 'BATAL'
        ${filterSql}
    `;

    const batalSql = `
      SELECT IFNULL(SUM(k.pik_nominal), 0) AS TotalBatal
      FROM tproyeksi_inkaso k
      LEFT JOIN tsales s ON s.sal_kode = k.pik_sal_kode
      WHERE k.pik_status = 'BATAL'
        ${batalSalesFilterSql}
    `;

    const [[rows], [[batalRow]]] = await Promise.all([
        db.query(sql, params),
        db.query(batalSql, batalParams),
    ]);

    return buildResult(rows, pageNum, limitNum, batalRow?.TotalBatal || 0);
};

module.exports = {
    getInvoiceJatuhTempo,
    buildResult,
};
