import { describe, it, expect, vi, beforeEach } from "vitest";
import db from "../config/dbPenawaran";
const inkasoService = require("../services/inkasoService");
const inkasoController = require("../controllers/inkasoController");

const dbProto = Object.getPrototypeOf(db);

describe("Invoice Jatuh Tempo Berdasarkan Rekap Piutang Manksi Web", () => {
    beforeEach(() => {
        vi.restoreAllMocks();
    });

    describe("1. Query Construction & Filtering in Service", () => {
        it("should query piutang_debet with Rekap Piutang conditions & overdue filter", async () => {
            const executedQueries = [];

            vi.spyOn(dbProto, "query").mockImplementation(async function (sql, params) {
                executedQueries.push({ sql, params });
                return [[]];
            });

            await inkasoService.getInvoiceJatuhTempo({
                month: 11,
                year: 2026,
                salesKode: "SALES01",
                search: "CUS_ABC",
                status: "normal",
                page: 1,
                limit: 50,
            });

            const mainQuery = executedQueries.find((q) =>
                q.sql.includes("FROM piutang_debet p"),
            );
            expect(mainQuery).toBeDefined();

            // 1. Base table & Rekap Piutang conditions
            expect(mainQuery.sql).toContain("p.flag = 0");
            expect(mainQuery.sql).toContain("p.is_writeoff = 0");
            expect(mainQuery.sql).toContain("INV YG DIKIRIM");

            // 2. Koreksi tak-normal via tinv_flag
            expect(mainQuery.sql).toContain("tinv_flag");

            // 3. Hanya invoice yang sudah jatuh tempo kumulatif s/d cut-off
            expect(mainQuery.sql).toContain("tanggal_tempo");
            expect(mainQuery.sql).toContain("CURDATE()");

            // Cut-off terbit 2 bulan lalu (misal bulan 11 -> cut-off 30 September 2026)
            expect(mainQuery.params).toContain("2026-09-30");

            // 4. Sales filter & Search filter
            expect(mainQuery.sql).toContain("sal_nama");
            expect(mainQuery.params).toContain("SALES01");
            expect(mainQuery.params).toContain("%CUS_ABC%");
        });

        it("should allow querying all sales when salesKode is null or ALL", async () => {
            const executedQueries = [];

            vi.spyOn(dbProto, "query").mockImplementation(async function (sql, params) {
                executedQueries.push({ sql, params });
                return [[]];
            });

            await inkasoService.getInvoiceJatuhTempo({
                salesKode: null,
                month: 11,
                year: 2026,
            });

            const mainQuery = executedQueries.find((q) =>
                q.sql.includes("FROM piutang_debet p"),
            );
            expect(mainQuery).toBeDefined();
            // Tidak boleh ada filter kaku ke 1 sales tertentu
            expect(mainQuery.params).not.toContain("SALES01");
        });
    });

    describe("2. Controller Parameter Extraction", () => {
        it("should pass month and year query params to inkasoService", async () => {
            const spy = vi
                .spyOn(inkasoService, "getInvoiceJatuhTempo")
                .mockResolvedValueOnce({
                    summary: {},
                    items: [],
                    pagination: {},
                });

            const req = {
                user: { jabatan: "MARKETING MANAGER" },
                query: {
                    month: "11",
                    year: "2026",
                    sales: "ALL",
                    search: "Nota123",
                },
            };
            const res = {
                status: vi.fn().mockReturnThis(),
                json: vi.fn(),
            };

            await inkasoController.getInvoiceJatuhTempo(req, res);

            expect(spy).toHaveBeenCalledWith(
                expect.objectContaining({
                    month: 11,
                    year: 2026,
                    salesKode: null,
                    search: "Nota123",
                }),
            );
        });

        it("should default month and year to current date if omitted in query", async () => {
            const spy = vi
                .spyOn(inkasoService, "getInvoiceJatuhTempo")
                .mockResolvedValueOnce({
                    summary: {},
                    items: [],
                    pagination: {},
                });

            const req = {
                user: { jabatan: "MANAGER" },
                query: {},
            };
            const res = {
                status: vi.fn().mockReturnThis(),
                json: vi.fn(),
            };

            await inkasoController.getInvoiceJatuhTempo(req, res);

            const now = new Date();
            expect(spy).toHaveBeenCalledWith(
                expect.objectContaining({
                    month: now.getMonth() + 1,
                    year: now.getFullYear(),
                }),
            );
        });
    });
});
