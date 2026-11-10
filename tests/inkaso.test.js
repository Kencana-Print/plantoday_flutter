import { describe, it, expect, vi } from "vitest";
import router from "../routes/inkasoRoute";
import inkasoController from "../controllers/inkasoController";
const inkasoService = require("../services/inkasoService");

const row = (
    nota,
    hari,
    sisa,
    salKode = "001",
    salNama = "SALES A",
    nominal = sisa,
    extra = {},
) => ({
    Nomor: `INK_${nota}`,
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
    NominalAwal: nominal,
    Sisa: sisa,
    ...extra,
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

    it("resolves hierarchy: Proforma (1) -> Tidak Normal (2) -> Normal (3)", () => {
        // Murni Normal
        const resNormal = inkasoService.resolveRowHierarchy({
            Nota: "ING/001",
            InvStsPro: 0,
        });
        expect(resNormal.status).toBe("Normal");
        expect(resNormal.status_urut).toBe(3);
        expect(resNormal.nota).toBe("ING/001");

        // Normal dengan turunan Tidak Normal
        const resTN = inkasoService.resolveRowHierarchy({
            Nota: "ING/002",
            InvStsPro: 0,
            NotaTakNormal: "INT/002",
        });
        expect(resTN.status).toBe("Tidak Normal");
        expect(resTN.status_urut).toBe(2);
        expect(resTN.nota).toBe("INT/002");

        // Normal dengan turunan Proforma
        const resPro = inkasoService.resolveRowHierarchy({
            Nota: "ING/003",
            InvStsPro: 0,
            NotaProforma: "ING/PRO/003",
        });
        expect(resPro.status).toBe("Proforma");
        expect(resPro.status_urut).toBe(1);
        expect(resPro.nota).toBe("ING/PRO/003");

        // Jika ada Tidak Normal DAN Proforma -> Proforma kasta tertinggi menang
        const resBoth = inkasoService.resolveRowHierarchy({
            Nota: "ING/004",
            InvStsPro: 0,
            NotaTakNormal: "INT/004",
            NotaProforma: "ING/PRO/004",
        });
        expect(resBoth.status).toBe("Proforma");
        expect(resBoth.status_urut).toBe(1);
        expect(resBoth.nota).toBe("ING/PRO/004");
    });

    it("sorts by status priority (Proforma -> Tidak Normal -> Normal), then terlambat_hari DESC", () => {
        const res = inkasoService.buildResult(
            [
                row("N_NORM", 100, 10000, "001", "SALES A", 10000, {
                    Status: "Normal",
                    StatusUrut: 3,
                }),
                row("N_PRO", 10, 20000, "001", "SALES A", 20000, {
                    Status: "Proforma",
                    StatusUrut: 1,
                }),
                row("N_TN_LAMA", 80, 15000, "001", "SALES A", 15000, {
                    Status: "Tidak Normal",
                    StatusUrut: 2,
                }),
                row("N_TN_BARU", 20, 12000, "001", "SALES A", 12000, {
                    Status: "Tidak Normal",
                    StatusUrut: 2,
                }),
            ],
            1,
            10,
        );

        expect(res.items.map((x) => x.nota)).toEqual([
            "N_PRO",
            "N_TN_LAMA",
            "N_TN_BARU",
            "N_NORM",
        ]);
        expect(res.summary.by_status.proforma).toEqual({ count: 1, nominal: 20000 });
        expect(res.summary.by_status.tidak_normal).toEqual({ count: 2, nominal: 27000 });
        expect(res.summary.by_status.normal).toEqual({ count: 1, nominal: 10000 });
    });

    it("aggregates aging buckets, per-sales summary, realisasi, and paginates", () => {
        const res = inkasoService.buildResult(
            [
                row("N1", 5, 10000, "001", "SALES A", 15000),
                row("N2", 45, 20000, "001", "SALES A", 20000),
                row("N3", 100, 30000, "002", "SALES B", 30000),
                // Sudah lunas (sisa <= 1000): masuk total_realisasi, keluar dari daftar aktif
                row("N4", 20, 0, "002", "SALES B", 10000),
            ],
            1,
            2,
            5000,
        );

        expect(res.summary.total_invoice).toBe(3);
        expect(res.summary.total_overdue).toBe(60000);
        expect(res.summary.total_realisasi).toBe(15000);
        expect(res.summary.total_batal).toBe(5000);
        expect(res.summary.aging["1_30"]).toEqual({ count: 1, nominal: 10000 });
        expect(res.summary.aging["31_60"]).toEqual({ count: 1, nominal: 20000 });
        expect(res.summary.aging["61_90"]).toEqual({ count: 0, nominal: 0 });
        expect(res.summary.aging.gt_90).toEqual({ count: 1, nominal: 30000 });
        expect(res.summary.by_sales).toEqual([
            {
                sal_kode: "001",
                sal_nama: "SALES A",
                jml_invoice: 2,
                total_sisa: 30000,
                total_terealisasi: 5000,
            },
            {
                sal_kode: "002",
                sal_nama: "SALES B",
                jml_invoice: 1,
                total_sisa: 30000,
                total_terealisasi: 10000,
            },
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
        const res = inkasoService.buildResult([row("N1", 0, 5000)], 1, 50);

        expect(res.summary.total_invoice).toBe(1);
        expect(res.summary.total_overdue).toBe(5000);
        expect(res.summary.aging["1_30"].count).toBe(0);
    });

    it("enforces sales filter for non-manager users in controller", async () => {
        const spy = vi
            .spyOn(inkasoService, "getInvoiceJatuhTempo")
            .mockResolvedValueOnce({
                summary: {},
                items: [],
                pagination: {},
            });

        const req = {
            user: { jabatan: "SALES", sales_kode: "004" },
            query: { sales: "002" }, // Sales biasa mencoba mengintip sales 002
        };
        const res = {
            status: vi.fn().mockReturnThis(),
            json: vi.fn(),
        };

        await inkasoController.getInvoiceJatuhTempo(req, res);

        // Harus dipaksa menggunakan sales_kode milik user login (004), bukan 002
        expect(spy).toHaveBeenCalledWith(
            expect.objectContaining({
                salesKode: "004",
            }),
        );

        spy.mockRestore();
    });

    it("allows manager users to view all sales or filter by requested sales", async () => {
        const spy = vi
            .spyOn(inkasoService, "getInvoiceJatuhTempo")
            .mockResolvedValueOnce({
                summary: {},
                items: [],
                pagination: {},
            });

        const req = {
            user: { jabatan: "MARKETING MANAGER" },
            query: { sales: "002" },
        };
        const res = {
            status: vi.fn().mockReturnThis(),
            json: vi.fn(),
        };

        await inkasoController.getInvoiceJatuhTempo(req, res);

        expect(spy).toHaveBeenCalledWith(
            expect.objectContaining({
                salesKode: "002",
            }),
        );

        spy.mockRestore();
    });
});
