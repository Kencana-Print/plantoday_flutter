const inkasoService = require("../services/inkasoService");

const isManagerUser = (user) => {
    const role = String(user?.jabatan || "").trim().toUpperCase();
    const keywords = [
        "MANAGER",
        "DIREKSI",
        "OWNER",
        "EDP",
        "ADMIN",
        "SUPERVISOR",
        "FINANCE",
        "MARKETING",
        "AUDIT",
        "IT",
        "KEPALA",
    ];
    return keywords.some((k) => role.includes(k));
};

const isSpecialAll = (val) => {
    if (!val) return true;
    const s = String(val).trim().toUpperCase();
    return (
        s === "" ||
        s === "ALL" ||
        s === "SEMUA" ||
        s === "ALL SALES" ||
        s === "SEMUA SALES" ||
        s === "NULL" ||
        s === "UNDEFINED" ||
        s === "SEMUA USER"
    );
};

const getInvoiceJatuhTempo = async (req, res) => {
    try {
        const isManager = isManagerUser(req.user);
        const authSalesKode = String(req.user?.sales_kode || req.user?.kode || "").trim();
        const authSalesNama = String(req.user?.sales_nama || req.user?.nama || "").trim();

        let targetSales = req.query.sales && !isSpecialAll(req.query.sales)
            ? String(req.query.sales).trim()
            : null;
        if (!isManager) {
            // Untuk sales biasa: kunci ke sales miliknya (utamakan kode, fallback ke nama sales/karyawan)
            targetSales = authSalesKode || authSalesNama || null;
            if (!targetSales) {
                return res.status(200).json({
                    success: true,
                    data: {
                        summary: {
                            total_invoice: 0,
                            total_overdue: 0,
                            aging: {
                                "1_30": { count: 0, nominal: 0 },
                                "31_60": { count: 0, nominal: 0 },
                                "61_90": { count: 0, nominal: 0 },
                                "gt_90": { count: 0, nominal: 0 },
                            },
                            by_sales: [],
                        },
                        items: [],
                        pagination: {
                            page: 1,
                            limit: Number(req.query.limit || 5000),
                            total_items: 0,
                            total_pages: 1,
                        },
                    },
                });
            }
        }

        const data = await inkasoService.getInvoiceJatuhTempo({
            salesKode: targetSales,
            search: String(req.query.search || "").trim(),
            page: req.query.page || 1,
            limit: req.query.limit || 5000,
        });

        return res.status(200).json({
            success: true,
            data,
        });
    } catch (err) {
        console.error("GET INVOICE JATUH TEMPO ERROR:", err);
        return res.status(500).json({
            success: false,
            message: err.sqlMessage || err.message || "Gagal mengambil data invoice jatuh tempo",
        });
    }
};

module.exports = {
    getInvoiceJatuhTempo,
};
