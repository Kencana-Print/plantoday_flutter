const inkasoService = require("../services/inkasoService");

const isManagerUser = (user) => {
    const role = String(user?.jabatan || "").trim().toUpperCase();
    return ["MANAGER", "DIREKSI", "OWNER", "EDP", "ADMIN", "SUPERVISOR", "FINANCE"].includes(role);
};

const getInvoiceJatuhTempo = async (req, res) => {
    try {
        const isManager = isManagerUser(req.user);
        const authSalesKode = String(req.user?.sales_kode || req.user?.kode || "").trim();

        // Non-manager wajib terikat ke sales miliknya
        let targetSales = req.query.sales ? String(req.query.sales).trim() : null;
        if (!isManager) {
            if (!authSalesKode) {
                return res.status(403).json({
                    success: false,
                    message: "Akses ditolak: sales_kode tidak terdaftar untuk akun ini.",
                });
            }
            targetSales = authSalesKode;
        }

        const data = await inkasoService.getInvoiceJatuhTempo({
            salesKode: targetSales,
            search: String(req.query.search || "").trim(),
            page: req.query.page || 1,
            limit: req.query.limit || 50,
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
