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

/**
 * Mengambil daftar invoice yang sudah jatuh tempo beserta ringkasan KPI dan aging bucket
 * Replikasi 100% logic dari ERP Manksi
 */
const getInvoiceJatuhTempo = async ({
    salesKode = null,
    search = "",
    page = 1,
    limit = 50,
}) => {
    const pageNum = Math.max(1, Number(page) || 1);
    const limitNum = Math.max(1, Number(limit) || 50);
    const offset = (pageNum - 1) * limitNum;

    const params = [];
    let salesFilterSql = "";
    if (salesKode) {
        salesFilterSql = " AND (src.SalKode = ? OR src.SalNama LIKE ?) ";
        params.push(salesKode, `%${salesKode}%`);
    }

    let searchSql = "";
    if (search) {
        searchSql = " AND (src.Nota LIKE ? OR src.CusNama LIKE ? OR src.CusKode LIKE ?) ";
        const s = `%${search}%`;
        params.push(s, s, s);
    }

    const baseSql = `
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
    `;

    const filteredQuery = `
      SELECT src.*, IFNULL(s.sal_nama, '(Tanpa Sales)') AS SalNama
      FROM (${baseSql}) src
      LEFT JOIN tsales s ON s.sal_kode = src.SalKode
      WHERE 1=1 ${salesFilterSql} ${searchSql}
    `;

    // 1. Ambil summary & aging agregat (seluruh data yang cocok dengan filter)
    const summarySql = `
      SELECT
        COUNT(*) AS total_invoice,
        IFNULL(SUM(x.Sisa), 0) AS total_overdue,
        IFNULL(SUM(CASE WHEN x.TerlambatHari BETWEEN 1 AND 30 THEN 1 ELSE 0 END), 0) AS count_1_30,
        IFNULL(SUM(CASE WHEN x.TerlambatHari BETWEEN 1 AND 30 THEN x.Sisa ELSE 0 END), 0) AS nominal_1_30,
        IFNULL(SUM(CASE WHEN x.TerlambatHari BETWEEN 31 AND 60 THEN 1 ELSE 0 END), 0) AS count_31_60,
        IFNULL(SUM(CASE WHEN x.TerlambatHari BETWEEN 31 AND 60 THEN x.Sisa ELSE 0 END), 0) AS nominal_31_60,
        IFNULL(SUM(CASE WHEN x.TerlambatHari BETWEEN 61 AND 90 THEN 1 ELSE 0 END), 0) AS count_61_90,
        IFNULL(SUM(CASE WHEN x.TerlambatHari BETWEEN 61 AND 90 THEN x.Sisa ELSE 0 END), 0) AS nominal_61_90,
        IFNULL(SUM(CASE WHEN x.TerlambatHari > 90 THEN 1 ELSE 0 END), 0) AS count_gt_90,
        IFNULL(SUM(CASE WHEN x.TerlambatHari > 90 THEN x.Sisa ELSE 0 END), 0) AS nominal_gt_90
      FROM (${filteredQuery}) x
    `;

    // 2. Ambil ringkasan per sales
    const salesSummarySql = `
      SELECT
        x.SalKode,
        x.SalNama,
        COUNT(*) AS jml_invoice,
        IFNULL(SUM(x.Sisa), 0) AS total_sisa
      FROM (${filteredQuery}) x
      GROUP BY x.SalKode, x.SalNama
      ORDER BY total_sisa DESC
    `;

    // 3. Ambil data list dengan pagination (paling telat dulu)
    const listSql = `
      ${filteredQuery}
      ORDER BY src.TerlambatHari DESC, src.Nota ASC
      LIMIT ? OFFSET ?
    `;

    const [[sumRows], [salesRows], [items]] = await Promise.all([
        db.query(summarySql, params),
        db.query(salesSummarySql, params),
        db.query(listSql, [...params, limitNum, offset]),
    ]);

    const s = sumRows[0] || {};
    const totalCount = Number(s.total_invoice) || 0;

    return {
        summary: {
            total_invoice: totalCount,
            total_overdue: Number(s.total_overdue) || 0,
            aging: {
                "1_30": { count: Number(s.count_1_30) || 0, nominal: Number(s.nominal_1_30) || 0 },
                "31_60": { count: Number(s.count_31_60) || 0, nominal: Number(s.nominal_31_60) || 0 },
                "61_90": { count: Number(s.count_61_90) || 0, nominal: Number(s.nominal_61_90) || 0 },
                "gt_90": { count: Number(s.count_gt_90) || 0, nominal: Number(s.nominal_gt_90) || 0 },
            },
            by_sales: salesRows.map((r) => ({
                sal_kode: r.SalKode,
                sal_nama: r.SalNama,
                jml_invoice: Number(r.jml_invoice) || 0,
                total_sisa: Number(r.total_sisa) || 0,
            })),
        },
        items: items.map((r) => ({
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
        })),
        pagination: {
            page: pageNum,
            limit: limitNum,
            total_items: totalCount,
            total_pages: Math.ceil(totalCount / limitNum) || 1,
        },
    };
};

module.exports = {
    getInvoiceJatuhTempo,
};
