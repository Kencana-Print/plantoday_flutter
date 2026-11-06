import { describe, it, expect } from "vitest";
import router from "../routes/inkasoRoute";
import inkasoController from "../controllers/inkasoController";
import inkasoService from "../services/inkasoService";

const row = (nota, hari, sisa, salKode = "001", salNama = "SALES A") => ({
    Nota: nota,
    NotaTampil: nota,
    Tanggal: "01-01-2026",
    Tempo: "01-01-2026",
    TglTempo: "2026-01-01",
    TerlambatHari: hari,
    CusKode: "C1",
    CusNama: "CUSTOMER",
    SalKode: salKode,
    SalNama: salNama,
    Nominal: sisa,
    Terbayar: 0,
    Sisa: sisa,
});

describe("Inkaso / Invoice Jatuh Tempo (Read-Only)", () => {
    it("should export getInvoiceJatuhTempo function in service and controller", () => {
        expect(typeof inkasoService.getInvoiceJatuhTempo).toBe("function");
        expect(typeof inkasoController.getInvoiceJatuhTempo).toBe("function");
    });

    it("should mount /inkaso and /invoice-jatuh-tempo GET routes", () => {
        const routes = router.stack
            .filter((layer) => layer.route)
            .map((layer) => ({
                path: layer.route.path,
                methods: Object.keys(layer.route.methods),
            }));

        expect(routes).toEqual(
            expect.arrayContaining([
                { path: "/inkaso", methods: ["get"] },
                { path: "/invoice-jatuh-tempo", methods: ["get"] },
            ]),
        );
    });

    it("aggregates aging buckets, per-sales summary, and paginates", () => {
        const res = inkasoService.buildResult(
            [
                row("N1", 5, 1000),
                row("N2", 45, 2000),
                row("N3", 100, 3000, "002", "SALES B"),
            ],
            1,
            2,
        );

        expect(res.summary.total_invoice).toBe(3);
        expect(res.summary.total_overdue).toBe(6000);
        expect(res.summary.aging["1_30"]).toEqual({ count: 1, nominal: 1000 });
        expect(res.summary.aging["31_60"]).toEqual({ count: 1, nominal: 2000 });
        expect(res.summary.aging["61_90"]).toEqual({ count: 0, nominal: 0 });
        expect(res.summary.aging.gt_90).toEqual({ count: 1, nominal: 3000 });
        expect(res.summary.by_sales).toEqual([
            { sal_kode: "001", sal_nama: "SALES A", jml_invoice: 2, total_sisa: 3000 },
            { sal_kode: "002", sal_nama: "SALES B", jml_invoice: 1, total_sisa: 3000 },
        ]);
        expect(res.items).toHaveLength(2);
        expect(res.pagination).toEqual({
            page: 1,
            limit: 2,
            total_items: 3,
            total_pages: 2,
        });
    });

    it("ignores invoices with 0 days late in aging but keeps them in totals", () => {
        const res = inkasoService.buildResult([row("N1", 0, 500)], 1, 50);

        expect(res.summary.total_invoice).toBe(1);
        expect(res.summary.total_overdue).toBe(500);
        expect(res.summary.aging["1_30"].count).toBe(0);
    });
});
