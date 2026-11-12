const db = require("../config/dbPenawaran");

const INKASO_TOL = 1000;

const bucketOf = (hari) => {
    if (hari >= 1 && hari <= 30) return "1_30";
    if (hari >= 31 && hari <= 60) return "31_60";
    if (hari >= 61 && hari <= 90) return "61_90";
    if (hari > 90) return "gt_90";
    return null;
};

const statusPriorityOf = (status) => {
    const s = String(status || "").trim().toLowerCase();
    if (s === "proforma") return 1;
    if (s === "tidak normal") return 2;
    return 3;
};

/**
 * Resolusi hierarki status & nota per baris:
 * Urutan kasta: Proforma (1) -> Tidak Normal (2) -> Normal (3)
 * - Proforma menang jika: inv_sts_pro = 1 ATAU punya turunan/referensi Proforma
 * - Tidak Normal menang jika: inv_sts_pro = 2 ATAU punya turunan/referensi Tidak Normal (tanpa Proforma)
 * - Normal: murni tanpa turunan Proforma maupun Tidak Normal
 */
const resolveRowHierarchy = (r) => {
    const explicitStatus = String(r.Status || "").trim();
    if (explicitStatus) {
        return {
            status: explicitStatus,
            status_urut: Number(r.StatusUrut) || statusPriorityOf(explicitStatus),
            nota: r.Nota || r.NotaTampil || "",
            nota_tampil: r.NotaTampil || r.Nota || "",
        };
    }

    const invStsPro = Number(r.InvStsPro ?? 0);
    const notaProforma = String(r.NotaProforma || "").trim();
    const notaTakNormal = String(r.NotaTakNormal || "").trim();

    if (invStsPro === 1 || notaProforma) {
        const resolvedNota = notaProforma || r.Nota || "";
        return {
            status: "Proforma",
            status_urut: 1,
            nota: resolvedNota,
            nota_tampil: resolvedNota,
        };
    }

    if (invStsPro === 2 || notaTakNormal) {
        const resolvedNota = notaTakNormal || r.Nota || "";
        return {
            status: "Tidak Normal",
            status_urut: 2,
            nota: resolvedNota,
            nota_tampil: resolvedNota,
        };
    }

    const normalNota = r.Nota || r.NotaTampil || "";
    return {
        status: "Normal",
        status_urut: 3,
        nota: normalNota,
        nota_tampil: normalNota,
    };
};

const buildResult = (rows, pageNum, limitNum, totalBatal = 0) => {
    const aging = {
        "1_30": { count: 0, nominal: 0 },
        "31_60": { count: 0, nominal: 0 },
        "61_90": { count: 0, nominal: 0 },
        gt_90: { count: 0, nominal: 0 },
    };
    const byStatus = {
        proforma: { count: 0, nominal: 0 },
        tidak_normal: { count: 0, nominal: 0 },
        normal: { count: 0, nominal: 0 },
    };
    const salesMap = new Map();
    const realisasiPerSales = new Map();
    const dedupByResolvedNota = new Map();

    // 1. Resolusi hierarki & eliminasi duplikat nota (utamakan kasta tertinggi: Proforma -> Tidak Normal -> Normal)
    for (const r of rows) {
        const resolved = resolveRowHierarchy(r);
        const key = resolved.nota || r.Nomor || Math.random().toString();
        const existing = dedupByResolvedNota.get(key);
        if (!existing || resolved.status_urut < existing.resolved.status_urut) {
            dedupByResolvedNota.set(key, { raw: r, resolved });
        }
    }

    const activeItems = [];
    let totalOverdue = 0;
    let totalRealisasi = 0;

    for (const { raw: r, resolved } of dedupByResolvedNota.values()) {
        const nominal = Number(r.NominalAwal ?? r.Nominal) || 0;
        const sisa = Number(r.Sisa) || 0;
        const terealisasi =
            r.Terbayar !== undefined
                ? Number(r.Terbayar) || 0
                : Math.min(nominal, Math.max(nominal - sisa, 0));

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

        if (resolved.status === "Proforma") {
            byStatus.proforma.count += 1;
            byStatus.proforma.nominal += sisa;
        } else if (resolved.status === "Tidak Normal") {
            byStatus.tidak_normal.count += 1;
            byStatus.tidak_normal.nominal += sisa;
        } else {
            byStatus.normal.count += 1;
            byStatus.normal.nominal += sisa;
        }

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
            nota: resolved.nota,
            nota_tampil: resolved.nota_tampil,
            nota_normal: r.NotaAsli || r.Nota || "",
            status: resolved.status,
            status_urut: resolved.status_urut,
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

    // Urutkan: Proforma (1) -> Tidak Normal (2) -> Normal (3), lalu TerlambatHari DESC, lalu Nota ASC
    activeItems.sort(
        (a, b) =>
            a.status_urut - b.status_urut ||
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
            by_status: byStatus,
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
 * Mengambil data Proyeksi Inkaso / Invoice Jatuh Tempo dengan hierarki status:
 * Proforma (1) -> Tidak Normal (2) -> Normal (3)
 * Mendeteksi relasi formal (tinv_flag, inv_invpro) dan relasi keterangan (inv_keterangan regex)
 */
const getInvoiceJatuhTempo = async ({
    salesKode = null,
    search = "",
    status = "",
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

    // Resolusi Nota & Status: Proforma -> Tidak Normal -> Normal
    const resolvedNotaExpr = `
      CASE
        WHEN h.inv_sts_pro = 1 THEN k.pik_nota
        WHEN TRIM(IFNULL(h.inv_invpro, '')) <> '' THEN TRIM(h.inv_invpro)
        WHEN h_ref.inv_sts_pro = 1 THEN h_ref.inv_nomor
        WHEN h.inv_sts_pro = 2 THEN k.pik_nota
        WHEN tfm.taknormal IS NOT NULL THEN tfm.taknormal
        WHEN h_ref.inv_sts_pro = 2 OR h_ref.inv_nomor LIKE 'INT/%' THEN h_ref.inv_nomor
        ELSE k.pik_nota
      END
    `;

    const resolvedStatusExpr = `
      CASE
        WHEN h.inv_sts_pro = 1 OR TRIM(IFNULL(h.inv_invpro, '')) <> '' OR h_ref.inv_sts_pro = 1 THEN 'Proforma'
        WHEN h.inv_sts_pro = 2 OR tfm.taknormal IS NOT NULL OR h_ref.inv_sts_pro = 2 OR h_ref.inv_nomor LIKE 'INT/%' THEN 'Tidak Normal'
        ELSE 'Normal'
      END
    `;

    const resolvedStatusUrutExpr = `
      CASE
        WHEN h.inv_sts_pro = 1 OR TRIM(IFNULL(h.inv_invpro, '')) <> '' OR h_ref.inv_sts_pro = 1 THEN 1
        WHEN h.inv_sts_pro = 2 OR tfm.taknormal IS NOT NULL OR h_ref.inv_sts_pro = 2 OR h_ref.inv_nomor LIKE 'INT/%' THEN 2
        ELSE 3
      END
    `;

    const resolvedDebetExpr = `COALESCE(p_res.debet, p.debet)`;
    const resolvedTanggalExpr = `COALESCE(p_res.tanggal, p.tanggal)`;
    const resolvedTempoExpr = `COALESCE(p_res.tanggal_tempo, p.tanggal_tempo)`;

    // Total kredit memperhitungkan pembayaran pada nota hasil resolusi maupun nota normal induknya
    const resolvedKreditExpr = `
      IFNULL((
        SELECT SUM(kd.kredit)
        FROM piutang_kredit_detail kd
        INNER JOIN piutang_kredit_header kh ON kh.nomor = kd.nomor
        WHERE kd.nota IN (k.pik_nota, ${resolvedNotaExpr})
      ), 0)
    `;

    if (search) {
        filterSql += `
          AND (
            k.pik_nota LIKE ?
            OR (${resolvedNotaExpr}) LIKE ?
            OR c.cus_nama LIKE ?
            OR k.pik_cus_kode LIKE ?
            OR s.sal_nama LIKE ?
            OR k.pik_catatan LIKE ?
          )
        `;
        const s = `%${search}%`;
        params.push(s, s, s, s, s, s);
    }

    if (status) {
        const st = String(status).trim().toLowerCase();
        if (st === "proforma") {
            filterSql += ` AND (${resolvedStatusUrutExpr} = 1) `;
        } else if (st === "tidak normal" || st === "tidak_normal") {
            filterSql += ` AND (${resolvedStatusUrutExpr} = 2) `;
        } else if (st === "normal") {
            filterSql += ` AND (${resolvedStatusUrutExpr} = 3) `;
        }
    }

    const sql = `
      SELECT
        k.pik_nomor AS Nomor,
        k.pik_nota AS NotaAsli,
        ${resolvedNotaExpr} AS Nota,
        ${resolvedNotaExpr} AS NotaTampil,
        IFNULL(h.inv_sts_pro, 0) AS InvStsPro,
        TRIM(IFNULL(h.inv_invpro, '')) AS NotaProforma,
        IFNULL(tfm.taknormal, '') AS NotaTakNormal,
        ${resolvedStatusExpr} AS Status,
        ${resolvedStatusUrutExpr} AS StatusUrut,
        k.pik_sal_kode AS SalKode,
        IFNULL(s.sal_nama, '(Tanpa Sales)') AS SalNama,
        k.pik_cus_kode AS CusKode,
        c.cus_nama AS CusNama,
        k.pik_nominal AS NominalAwal,
        DATE_FORMAT(${resolvedTanggalExpr}, '%d-%m-%Y') AS Tanggal,
        DATE_FORMAT(${resolvedTempoExpr}, '%d-%m-%Y') AS Tempo,
        DATEDIFF(CURDATE(), ${resolvedTempoExpr}) AS TerlambatHari,
        DATE_FORMAT(k.pik_tgl_target, '%Y-%m-%d') AS TglTarget,
        k.pik_catatan AS Catatan,
        k.user_create AS UserCreate,
        DATE_FORMAT(k.date_create, '%Y-%m-%d %H:%i:%s') AS DateCreate,
        (${resolvedDebetExpr} - ${resolvedKreditExpr}) AS Sisa,
        ${resolvedKreditExpr} AS Terbayar
      FROM tproyeksi_inkaso k
      INNER JOIN piutang_debet p ON p.nota = k.pik_nota AND p.is_writeoff = 0
      LEFT JOIN tinv_hdr h ON h.inv_nomor = k.pik_nota
      LEFT JOIN (
        SELECT invf_normal, MIN(invf_taknormal) AS taknormal
        FROM tinv_flag
        GROUP BY invf_normal
      ) tfm ON tfm.invf_normal = k.pik_nota
      LEFT JOIN tinv_hdr h_ref
        ON h_ref.inv_nomor = REGEXP_SUBSTR(h.inv_keterangan, 'IN[GT]/[A-Za-z0-9]+/[0-9]+/[0-9]{4}')
      LEFT JOIN piutang_debet p_res
        ON p_res.nota = (${resolvedNotaExpr})
        AND p_res.is_writeoff = 0
      LEFT JOIN tcustomer c ON c.cus_kode = k.pik_cus_kode
      LEFT JOIN tsales s ON s.sal_kode = k.pik_sal_kode
      WHERE k.pik_status <> 'BATAL'
        AND (
          p.flag = 0
          OR h.inv_sts_pro IN (1, 2)
          OR TRIM(IFNULL(h.inv_invpro, '')) <> ''
          OR tfm.taknormal IS NOT NULL
          OR h_ref.inv_sts_pro IN (1, 2)
          OR h_ref.inv_nomor LIKE 'INT/%'
        )
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
    resolveRowHierarchy,
};
