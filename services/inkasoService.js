const db = require("../config/dbPenawaran");

const INKASO_TOL = 1000;

// Sales attribution: prioritaskan dari SPK/SO di detail invoice, fallback ke customer sales
const INKASO_SAL_CORR = `
  IFNULL((
    SELECT MAX(COALESCE(s.spk_sal_kode, so.so_sal_kode))
    FROM tinv_dtl d
    LEFT JOIN tspk s ON s.spk_nomor = d.invd_spk_nomor
    LEFT JOIN tsalesorder so ON so.so_nomor = d.invd_spk_nomor
    WHERE d.invd_inv_nomor = p.nota
  ), c.cus_sales)
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

const buildResult = (rows, pageNum, limitNum) => {
    const items = rows.map((r) => ({
        nota: r.Nota,
        nota_tampil: r.NotaTampil,
        tanggal: r.Tanggal,
        tempo: r.Tempo,
        terlambat_hari: Number(r.TerlambatHari) || 0,
        cus_kode: r.CusKode,
        cus_nama: r.CusNama,
        sal_kode: r.SalKode,
        sal_nama: r.SalNama,
        nominal: Number(r.Nominal) || 0,
        terbayar: Number(r.Terbayar) || 0,
        sisa: Number(r.Sisa) || 0,
    }));

    const aging = {
        "1_30": { count: 0, nominal: 0 },
        "31_60": { count: 0, nominal: 0 },
        "61_90": { count: 0, nominal: 0 },
        gt_90: { count: 0, nominal: 0 },
    };
    const salesMap = new Map();
    let totalOverdue = 0;

    for (const it of items) {
        totalOverdue += it.sisa;

        const key = bucketOf(it.terlambat_hari);
        if (key) {
            aging[key].count += 1;
            aging[key].nominal += it.sisa;
        }

        const salesKey = `${it.sal_kode || ""}|${it.sal_nama || ""}`;
        const agg = salesMap.get(salesKey) || {
            sal_kode: it.sal_kode || "",
            sal_nama: it.sal_nama || "",
            jml_invoice: 0,
            total_sisa: 0,
        };
        agg.jml_invoice += 1;
        agg.total_sisa += it.sisa;
        salesMap.set(salesKey, agg);
    }

    const bySales = Array.from(salesMap.values()).sort(
        (a, b) => b.total_sisa - a.total_sisa,
    );

    const offset = (pageNum - 1) * limitNum;

    return {
        summary: {
            total_invoice: items.length,
            total_overdue: totalOverdue,
            aging,
            by_sales: bySales,
        },
        items: items.slice(offset, offset + limitNum),
        pagination: {
            page: pageNum,
            limit: limitNum,
            total_items: items.length,
            total_pages: Math.ceil(items.length / limitNum) || 1,
        },
    };
};

/**
 * Mengambil daftar invoice yang sudah jatuh tempo beserta ringkasan KPI dan aging bucket.
 * Replikasi logic ERP Manksi.
 *
 * Catatan performa: query dasar dijalankan SEKALI lalu agregasi (summary/aging/by_sales)
 * dan pagination dilakukan di JS. Sebelumnya query dijalankan 3x dan join `tsales`
 * memakai ekspresi berkorelasi sehingga response bisa >45 detik (timeout client 30 detik).
 */
const getInvoiceJatuhTempo = async ({
    salesKode = null,
    search = "",
    page = 1,
    limit = 50,
}) => {
    const pageNum = Math.max(1, Number(page) || 1);
    const limitNum = Math.max(1, Number(limit) || 50);

    const params = [];
    let filterSql = "";
    if (salesKode) {
        filterSql += " AND (x.SalKode = ? OR x.SalNama = ? OR x.SalNama LIKE ?) ";
        params.push(salesKode, salesKode, `%${salesKode}%`);
    }
    if (search) {
        filterSql += " AND (x.Nota LIKE ? OR x.NotaTampil LIKE ? OR x.CusNama LIKE ? OR x.CusKode LIKE ?) ";
        const s = `%${search}%`;
        params.push(s, s, s, s);
    }

    // Join tsales dilakukan di lapisan luar (set-based), BUKAN pada ekspresi
    // berkorelasi di ON clause — pola lama membuat subquery dieksekusi per kombinasi baris.
    const sql = `
      SELECT x.*
      FROM (
        SELECT
          b.Nota,
          b.NotaTampil,
          b.Tanggal,
          b.Tempo,
          b.TglTempo,
          b.TerlambatHari,
          b.CusKode,
          b.CusNama,
          b.SalKode,
          IFNULL(s.sal_nama, '(Tanpa Sales)') AS SalNama,
          b.Nominal,
          b.Terbayar,
          b.Sisa
        FROM (
          SELECT
            p.nota AS Nota,
            IFNULL(tfm.taknormal, p.nota) AS NotaTampil,
            DATE_FORMAT(p.tanggal, '%d-%m-%Y') AS Tanggal,
            DATE_FORMAT(p.tanggal_tempo, '%d-%m-%Y') AS Tempo,
            p.tanggal_tempo AS TglTempo,
            DATEDIFF(CURDATE(), p.tanggal_tempo) AS TerlambatHari,
            p.customer AS CusKode,
            c.cus_nama AS CusNama,
            ${INKASO_SAL_CORR} AS SalKode,
            p.debet AS Nominal,
            IFNULL(kr.kredit, 0) AS Terbayar,
            (p.debet - IFNULL(kr.kredit, 0)) AS Sisa
          FROM piutang_debet p
          INNER JOIN tcustomer c ON c.cus_kode = p.customer
          LEFT JOIN (
            SELECT invf_normal, MIN(invf_taknormal) AS taknormal
            FROM tinv_flag GROUP BY invf_normal
          ) tfm ON tfm.invf_normal = p.nota
          LEFT JOIN (
            SELECT kd.nota, SUM(kd.kredit) AS kredit
            FROM piutang_kredit_detail kd
            INNER JOIN piutang_kredit_header kh ON kh.nomor = kd.nomor
            GROUP BY kd.nota
          ) kr ON kr.nota = IFNULL(tfm.taknormal, p.nota)
          WHERE p.tanggal_tempo < CURDATE()
            ${INKASO_VALID_FILTER}
            AND (p.debet - IFNULL(kr.kredit, 0)) > ${INKASO_TOL}
        ) b
        LEFT JOIN tsales s ON s.sal_kode = b.SalKode
      ) x
      WHERE 1=1 ${filterSql}
      ORDER BY x.TerlambatHari DESC, x.Nota ASC
    `;

    const [rows] = await db.query(sql, params);
    return buildResult(rows, pageNum, limitNum);
};

module.exports = {
    getInvoiceJatuhTempo,
    buildResult,
};
