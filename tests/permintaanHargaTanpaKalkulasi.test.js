import { describe, it, expect, vi, beforeEach } from "vitest";
import db from "../config/dbPenawaran";
import permintaanHargaService from "../services/permintaanHargaService";

const dbProto = Object.getPrototypeOf(db);

describe("Permintaan Harga Tanpa Kalkulasi & Budget Field", () => {
    beforeEach(() => {
        vi.restoreAllMocks();
    });

    describe("1. createPermintaanHarga with Tanpa Kalkulasi & Budget", () => {
        it("should preserve free-text kain and save mh_budget when tanpa_kalkulasi is true", async () => {
            const queries = [];
            const mockConnection = {
                query: vi.fn(async (sql, params) => {
                    queries.push({ sql, params });
                    if (sql.includes("SELECT IFNULL(MAX(CAST(RIGHT(mh_nomor, 4) AS UNSIGNED)), 0)")) {
                        return [[{ max_val: 12 }]];
                    }
                    if (sql.includes("SELECT mh_nomor FROM tmintaharga WHERE mh_nomor = ?")) {
                        return [[]]; // not exists
                    }
                    if (sql.includes("SHOW COLUMNS FROM tmintaharga LIKE 'mh_workshop'")) {
                        return [[{ Field: "mh_workshop" }]];
                    }
                    if (sql.includes("SHOW COLUMNS FROM tmintaharga LIKE 'user_kalkulasi'")) {
                        return [[{ Field: "user_kalkulasi" }]];
                    }
                    if (sql.includes("INSERT INTO tmintaharga")) {
                        return [{ affectedRows: 1 }];
                    }
                    return [[]];
                }),
                beginTransaction: vi.fn(async () => {}),
                commit: vi.fn(async () => {}),
                rollback: vi.fn(async () => {}),
                release: vi.fn(async () => {}),
            };

            vi.spyOn(dbProto, "getConnection").mockResolvedValue(mockConnection);

            const body = {
                mh_tanggal: "2026-11-12",
                mh_divisi: 4, // Garmen
                mh_cus_kode: "CUS-001",
                mh_cus_nama: "Customer Custom",
                mh_nama: "Kaos Custom Bambu",
                mh_jmlorder: 100,
                mh_kain: "Cotton Bamboo 30s Custom Free Text",
                mh_budget: 75000,
                mh_harga_kalkulasi: 0,
                tanpa_kalkulasi: true,
                sales_kode: "SALES-01",
            };

            const result = await permintaanHargaService.createPermintaanHarga({
                body,
                user: { username: "user_test", sales_kode: "SALES-01" },
            });

            expect(result.status).toBe(201);
            expect(result.body.data).toHaveProperty("nomor");

            // Periksa query INSERT INTO tmintaharga
            const insertMh = queries.find((q) => q.sql.includes("INSERT INTO tmintaharga"));
            expect(insertMh).toBeDefined();

            // Field mh_budget (index 9) dan mh_kain (index 11)
            expect(insertMh.params[9]).toBe(75000); // mh_budget
            expect(insertMh.params[11]).toBe("Cotton Bamboo 30s Custom Free Text"); // mh_kain preserved!
        });

        it("should preserve free-text kain for MMT without falling back to master when is_tanpa_kalkulasi is set", async () => {
            const queries = [];
            const mockConnection = {
                query: vi.fn(async (sql, params) => {
                    queries.push({ sql, params });
                    if (sql.includes("SELECT IFNULL(MAX(CAST(RIGHT(mh_nomor, 4) AS UNSIGNED)), 0)")) {
                        return [[{ max_val: 20 }]];
                    }
                    if (sql.includes("SELECT mh_nomor FROM tmintaharga WHERE mh_nomor = ?")) {
                        return [[]]; // not exists
                    }
                    if (sql.includes("SHOW COLUMNS FROM tmintaharga LIKE 'mh_workshop'")) {
                        return [[{ Field: "mh_workshop" }]];
                    }
                    if (sql.includes("SHOW COLUMNS FROM tmintaharga LIKE 'user_kalkulasi'")) {
                        return [[{ Field: "user_kalkulasi" }]];
                    }
                    if (sql.includes("INSERT INTO tmintaharga")) {
                        return [{ affectedRows: 1 }];
                    }
                    return [[]];
                }),
                beginTransaction: vi.fn(async () => {}),
                commit: vi.fn(async () => {}),
                rollback: vi.fn(async () => {}),
                release: vi.fn(async () => {}),
            };

            vi.spyOn(dbProto, "getConnection").mockResolvedValue(mockConnection);

            const body = {
                mh_tanggal: "2026-11-12",
                mh_divisi: 5, // MMT
                mh_cus_kode: "CUS-002",
                mh_cus_nama: "Customer Banner",
                mh_nama: "Spanduk MMT Custom",
                mh_jmlorder: 50,
                mh_kain: "Flexi Korea 510gsm High Gloss Custom",
                budget: 35000,
                mh_harga_kalkulasi: 0,
                is_tanpa_kalkulasi: true,
                sales_kode: "SALES-02",
            };

            const result = await permintaanHargaService.createPermintaanHarga({
                body,
                user: { username: "user_test", sales_kode: "SALES-02" },
            });

            expect(result.status).toBe(201);
            const insertMh = queries.find((q) => q.sql.includes("INSERT INTO tmintaharga"));
            expect(insertMh).toBeDefined();
            expect(insertMh.params[9]).toBe(35000); // budget
            expect(insertMh.params[11]).toBe("Flexi Korea 510gsm High Gloss Custom");
        });
    });

    describe("2. updatePermintaanHarga with Tanpa Kalkulasi & Budget", () => {
        it("should update mh_kain free-text and mh_budget correctly", async () => {
            const queries = [];
            vi.spyOn(dbProto, "query").mockImplementation(async (sql, params) => {
                queries.push({ sql, params });
                if (sql.includes("FROM tmintaharga WHERE mh_nomor = ? LIMIT 1")) {
                    return [
                        [
                            {
                                mh_nomor: "MH.2026.0001",
                                mh_status: "BELUM",
                                mh_sal_kode: "SALES-01",
                                user_create: "SALES-01",
                                mh_nomor_kalkulasi: "",
                                mh_budget: 50000,
                                mh_jmlorder: 100,
                            },
                        ],
                    ];
                }
                if (sql.includes("SELECT pend_pen_nomor FROM tpenawarandtl")) {
                    return [[]]; // not used in penawaran
                }
                if (sql.includes("SHOW COLUMNS FROM tmintaharga LIKE 'mh_workshop'")) {
                    return [[{ Field: "mh_workshop" }]];
                }
                if (sql.includes("UPDATE tmintaharga")) {
                    return [{ affectedRows: 1 }];
                }
                return [[]];
            });

            const body = {
                mh_divisi: 1, // Spanduk
                mh_nama: "Spanduk Bahan Khusus",
                mh_jmlorder: 200,
                mh_kain: "Kain TC 80/20 Custom Import",
                mh_budget: 25000,
                mh_harga_kalkulasi: 0,
                tanpa_kalkulasi: true,
            };

            const result = await permintaanHargaService.updatePermintaanHarga({
                nomor: "MH.2026.0001",
                body,
                user: { username: "user_edit", role: "SALES", sales_kode: "SALES-01" },
            });

            expect(result.status).toBe(200);
            const updateSql = queries.find((q) => q.sql.includes("UPDATE tmintaharga"));
            expect(updateSql).toBeDefined();

            // mh_budget (index 8) and mh_kain (index 10) in UPDATE tmintaharga SET
            expect(updateSql.params[8]).toBe(25000);
            expect(updateSql.params[10]).toBe("Kain TC 80/20 Custom Import");
        });
    });

    describe("3. getPermintaanHargaDetail & getPermintaanHargaList", () => {
        it("should return mh_budget and budget in detail", async () => {
            vi.spyOn(dbProto, "query").mockImplementation(async (sql) => {
                if (sql.includes("SHOW COLUMNS FROM tmintaharga LIKE 'mh_workshop'")) {
                    return [[{ Field: "mh_workshop" }]];
                }
                if (sql.includes("FROM tmintaharga h")) {
                    return [
                        [
                            {
                                mh_nomor: "MH.2026.0001",
                                mh_divisi: 4,
                                mh_nama: "Kaos Polos",
                                mh_jmlorder: 100,
                                mh_harga: 0,
                                mh_budget: 60000,
                                mh_kain: "Cotton 24s Custom",
                                mh_status: "BELUM",
                                mh_nomor_kalkulasi: "",
                            },
                        ],
                    ];
                }
                return [[]];
            });

            const detail = await permintaanHargaService.getPermintaanHargaDetail({
                nomor: "MH.2026.0001",
                managerRole: true,
            });

            expect(detail).toBeDefined();
            expect(detail.mh_budget).toBe(60000);
            expect(detail.budget).toBe(60000);
            expect(detail.mh_kain).toBe("Cotton 24s Custom");
        });
    });
});
