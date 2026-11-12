import { describe, it, expect, vi, beforeEach } from "vitest";
import db from "../config/dbPenawaran";
import penawaranRoute from "../routes/penawaranRoute";
import permintaanHargaRoute from "../routes/permintaanHargaRoute";
import penawaranController from "../controllers/penawaranController";
import permintaanHargaController from "../controllers/permintaanHargaController";
import penawaranService from "../services/penawaranService";
import permintaanHargaService from "../services/permintaanHargaService";

const dbProto = Object.getPrototypeOf(db);

describe("Fitur Edit Permintaan Harga dan Edit Penawaran", () => {
    beforeEach(() => {
        vi.restoreAllMocks();
    });

    describe("1. Route and Controller Exports", () => {
        it("should have PUT /penawaran/:nomor mounted in penawaranRoute", () => {
            const routes = penawaranRoute.stack
                .filter((layer) => layer.route)
                .map((layer) => ({
                    path: layer.route.path,
                    methods: Object.keys(layer.route.methods),
                }));

            const putPenawaran = routes.find(
                (r) => r.path === "/penawaran/:nomor" && r.methods.includes("put"),
            );
            expect(putPenawaran).toBeDefined();
        });

        it("should have PUT /permintaan-harga/:nomor mounted in permintaanHargaRoute", () => {
            const routes = permintaanHargaRoute.stack
                .filter((layer) => layer.route)
                .map((layer) => ({
                    path: layer.route.path,
                    methods: Object.keys(layer.route.methods),
                }));

            const putMh = routes.find(
                (r) =>
                    r.path === "/permintaan-harga/:nomor" &&
                    r.methods.includes("put"),
            );
            expect(putMh).toBeDefined();
        });

        it("should export updatePenawaran in penawaranController and penawaranService", () => {
            expect(typeof penawaranController.updatePenawaran).toBe("function");
            expect(typeof penawaranService.updatePenawaran).toBe("function");
        });

        it("should export updatePermintaanHarga in permintaanHargaController and permintaanHargaService", () => {
            expect(typeof permintaanHargaController.updatePermintaanHarga).toBe(
                "function",
            );
            expect(typeof permintaanHargaService.updatePermintaanHarga).toBe(
                "function",
            );
        });
    });

    describe("2. Penawaran to MAP / SPK check logic", () => {
        it("should detect when Penawaran already has active Memo SPK (MAP)", async () => {
            const mockConn = {
                query: vi.fn().mockImplementation((sql) => {
                    if (sql.includes("tmemospk")) {
                        return [[{ mspk_nomor: "MAP/001/2026" }]];
                    }
                    return [[]];
                }),
            };

            const result = await penawaranService.checkPenawaranHasMapOrSpk(
                mockConn,
                "00001/KP/2026",
            );
            expect(result.hasMap).toBe(true);
            expect(result.type).toBe("MAP");
            expect(result.refNumber).toBe("MAP/001/2026");
        });

        it("should detect when Penawaran already has direct SPK", async () => {
            const mockConn = {
                query: vi.fn().mockImplementation((sql) => {
                    if (sql.includes("tmemospk")) {
                        return [[]];
                    }
                    if (sql.includes("tspk")) {
                        return [[{ spk_nomor: "SPK/001/2026" }]];
                    }
                    return [[]];
                }),
            };

            const result = await penawaranService.checkPenawaranHasMapOrSpk(
                mockConn,
                "00001/KP/2026",
            );
            expect(result.hasMap).toBe(true);
            expect(result.type).toBe("SPK");
            expect(result.refNumber).toBe("SPK/001/2026");
        });

        it("should return hasMap: false when Penawaran has neither MAP nor SPK", async () => {
            const mockConn = {
                query: vi.fn().mockResolvedValue([[]]),
            };

            const result = await penawaranService.checkPenawaranHasMapOrSpk(
                mockConn,
                "00001/KP/2026",
            );
            expect(result.hasMap).toBe(false);
        });
    });

    describe("3. Permintaan Usage Map exclusion logic", () => {
        it("should exclude current penawaran number so it does not conflict with its own items", async () => {
            let capturedSql = "";
            let capturedParams = [];

            const mockConn = {
                query: vi.fn().mockImplementation((sql, params) => {
                    capturedSql = sql;
                    capturedParams = params;
                    return [[{ nomor: "MH.2026.0001", used_count: 0 }]];
                }),
            };

            const usageMap = await penawaranService.getPermintaanUsageMap(
                mockConn,
                ["MH.2026.0001"],
                { excludePenawaranNomor: "00001/KP/2026" },
            );

            expect(capturedSql).toContain("AND d.pend_pen_nomor <> ?");
            expect(capturedParams).toContain("00001/KP/2026");
            expect(usageMap.get("MH.2026.0001")).toBe(0);
        });
    });

    describe("4. Permintaan Harga Edit Validation", () => {
        it("should reject edit if Permintaan Harga is already used in a Penawaran", async () => {
            vi.spyOn(dbProto, "query").mockImplementation(async function (sql) {
                if (sql.includes("FROM tmintaharga WHERE mh_nomor")) {
                    return [
                        [
                            {
                                mh_nomor: "MH.2026.0001",
                                mh_sal_kode: "S01",
                                mh_status: "DONE",
                            },
                        ],
                    ];
                }
                if (sql.includes("FROM tpenawaran_dtl WHERE pend_minta")) {
                    return [[{ pend_pen_nomor: "00005/KP/2026" }]];
                }
                return [[]];
            });

            const result = await permintaanHargaService.updatePermintaanHarga({
                nomor: "MH.2026.0001",
                user: { sales_kode: "S01", role: "SALES" },
                body: { mh_divisi: 1, mh_nama: "Spanduk Baru" },
            });

            expect(result.status).toBe(409);
            expect(result.body.success).toBe(false);
            expect(result.body.message).toContain("sudah digunakan dalam penawaran");
            expect(result.body.message).toContain("00005/KP/2026");
        });

        it("should reject edit if status is non-editable (e.g. CANCEL)", async () => {
            vi.spyOn(dbProto, "query").mockImplementation(async function (sql) {
                if (sql.includes("FROM tmintaharga WHERE mh_nomor")) {
                    return [
                        [
                            {
                                mh_nomor: "MH.2026.0001",
                                mh_sal_kode: "S01",
                                mh_status: "CANCEL",
                            },
                        ],
                    ];
                }
                return [[]];
            });

            const result = await permintaanHargaService.updatePermintaanHarga({
                nomor: "MH.2026.0001",
                user: { sales_kode: "S01", role: "SALES" },
                body: { mh_divisi: 1, mh_nama: "Spanduk Baru" },
            });

            expect(result.status).toBe(409);
            expect(result.body.success).toBe(false);
            expect(result.body.message).toContain("CANCEL tidak dapat diubah");
        });
    });

    describe("5. Penawaran Edit Validation & Execution", () => {
        it("should reject update if Penawaran has already become MAP", async () => {
            const mockConn = {
                query: vi.fn().mockImplementation(async (sql, params) => {
                    if (sql.includes("FROM tpenawaran_hdr")) {
                        return [
                            [
                                {
                                    pen_nomor: "00001/KP/2026",
                                    pen_tanggal: "2026-03-01",
                                    pen_sal_kode: "S01",
                                    owner_sales_kode: "S01",
                                    pen_status: "",
                                },
                            ],
                        ];
                    }
                    if (sql.includes("FROM tmemospk")) {
                        return [[{ mspk_nomor: "MAP.2026.0099" }]];
                    }
                    return [[]];
                }),
                beginTransaction: vi.fn().mockResolvedValue(),
                rollback: vi.fn().mockResolvedValue(),
                commit: vi.fn().mockResolvedValue(),
                release: vi.fn().mockResolvedValue(),
            };

            vi.spyOn(dbProto, "getConnection").mockResolvedValue(mockConn);
            vi.spyOn(dbProto, "query").mockImplementation(async function (sql, params) {
                if (sql.includes("tpenawaran_hdr") && sql.includes("pen_nomor")) {
                    return [
                        [
                            {
                                pen_nomor: "00001/KP/2026",
                                pen_sal_kode: "S01",
                                owner_sales_kode: "S01",
                                pen_status: "",
                            },
                        ],
                    ];
                }
                return [[]];
            });

            const result = await penawaranService.updatePenawaran({
                nomor: "00001/KP/2026",
                traceId: "test-trace",
                body: {
                    tanggal: "2026-03-30",
                    perusahaan_kode: "KP",
                    customer_kode: "CUS01",
                    details: [{ nama_barang: "Barang A", qty: 10, harga: 50000 }],
                },
                loginUser: { sales_kode: "S01", role: "SALES" },
            });

            expect(result.status).toBe(409);
            expect(result.body.success).toBe(false);
            expect(result.body.message).toContain("sudah diproses menjadi MAP");
            expect(mockConn.rollback).toHaveBeenCalled();
        });

        it("should reject update if Penawaran has already been approved (pen_digitalsign = 'Y')", async () => {
            const mockConn = {
                query: vi.fn().mockImplementation(async (sql, params) => {
                    if (sql.includes("FROM tpenawaran_hdr")) {
                        return [
                            [
                                {
                                    pen_nomor: "00001/KP/2026",
                                    pen_tanggal: "2026-03-01",
                                    pen_sal_kode: "S01",
                                    owner_sales_kode: "S01",
                                    pen_status: "",
                                    pen_digitalsign: "Y",
                                },
                            ],
                        ];
                    }
                    if (sql.includes("FROM tmemospk") || sql.includes("FROM tspk")) {
                        return [[]];
                    }
                    return [[]];
                }),
                beginTransaction: vi.fn().mockResolvedValue(),
                rollback: vi.fn().mockResolvedValue(),
                commit: vi.fn().mockResolvedValue(),
                release: vi.fn().mockResolvedValue(),
            };

            vi.spyOn(dbProto, "getConnection").mockResolvedValue(mockConn);
            vi.spyOn(dbProto, "query").mockImplementation(async function (sql, params) {
                if (sql.includes("tpenawaran_hdr") && sql.includes("pen_nomor")) {
                    return [
                        [
                            {
                                pen_nomor: "00001/KP/2026",
                                pen_sal_kode: "S01",
                                owner_sales_kode: "S01",
                                pen_status: "",
                            },
                        ],
                    ];
                }
                return [[]];
            });

            const result = await penawaranService.updatePenawaran({
                nomor: "00001/KP/2026",
                traceId: "test-trace",
                body: {
                    tanggal: "2026-03-30",
                    perusahaan_kode: "KP",
                    customer_kode: "CUS01",
                    details: [{ nama_barang: "Barang A", qty: 10, harga: 50000 }],
                },
                loginUser: { sales_kode: "S01", role: "SALES" },
            });

            expect(result.status).toBe(409);
            expect(result.body.success).toBe(false);
            expect(result.body.message).toContain("sudah disetujui (approve)");
            expect(mockConn.rollback).toHaveBeenCalled();
        });

        it("should successfully update Penawaran in place (timpa nomor) when valid", async () => {
            const executedQueries = [];
            const mockConn = {
                query: vi.fn().mockImplementation(async (sql, params) => {
                    executedQueries.push({ sql, params });
                    if (sql.includes("FROM tpenawaran_hdr WHERE pen_nomor = ? FOR UPDATE")) {
                        return [
                            [
                                {
                                    pen_nomor: "00001/KP/2026",
                                    pen_tanggal: "2026-03-01",
                                    pen_divisi: "1",
                                    pen_tipe: "Medium",
                                    pen_perush_kode: "KP",
                                    pen_cus_kode: "CUS01",
                                    pen_sal_kode: "S01",
                                    owner_sales_kode: "S01",
                                    pen_ttd: "Direktur",
                                    pen_ttd_jabatan: "Direktur Utama",
                                    pen_digitalsign: "N",
                                },
                            ],
                        ];
                    }
                    if (sql.includes("FROM tmemospk") || sql.includes("FROM tspk")) {
                        return [[]];
                    }
                    if (sql.includes("tspk_pin5")) {
                        return [[]];
                    }
                    if (sql.includes("INFORMATION_SCHEMA.COLUMNS")) {
                        return [[{ COLUMN_NAME: "pin_ket" }]];
                    }
                    return [[]];
                }),
                beginTransaction: vi.fn().mockResolvedValue(),
                rollback: vi.fn().mockResolvedValue(),
                commit: vi.fn().mockResolvedValue(),
                release: vi.fn().mockResolvedValue(),
            };

            vi.spyOn(dbProto, "getConnection").mockResolvedValue(mockConn);
            vi.spyOn(dbProto, "query").mockImplementation(async function (sql, params) {
                if (sql.includes("tpenawaran_hdr") && sql.includes("pen_nomor")) {
                    return [
                        [
                            {
                                pen_nomor: "00001/KP/2026",
                                pen_sal_kode: "S01",
                                owner_sales_kode: "S01",
                                pen_status: "",
                            },
                        ],
                    ];
                }
                return [[]];
            });

            const result = await penawaranService.updatePenawaran({
                nomor: "00001/KP/2026",
                traceId: "test-trace",
                body: {
                    tanggal: "2026-03-30",
                    perusahaan_kode: "KP",
                    customer_kode: "CUS01",
                    keterangan: "Penawaran edisi revisi",
                    details: [
                        { nama_barang: "Baju Sablon", qty: 25, harga: 75000 },
                    ],
                },
                loginUser: { sales_kode: "S01", role: "SALES", nama: "Budi Sales" },
            });

            expect(result.status).toBe(200);
            expect(result.body.success).toBe(true);
            expect(result.body.data.nomor).toBe("00001/KP/2026");

            // Pastikan UPDATE tpenawaran_hdr me-reset pen_digitalsign = 'N' dan menggunakan pen_nomor yang sama
            const updateHdrCall = executedQueries.find((q) =>
                q.sql.includes("UPDATE tpenawaran_hdr"),
            );
            expect(updateHdrCall).toBeDefined();
            expect(updateHdrCall.sql).toContain("pen_digitalsign = 'N'");
            expect(updateHdrCall.params).toContain("00001/KP/2026");

            // Pastikan delete detail lama dan insert detail baru menggunakan pen_nomor yang sama
            const deleteDtlCall = executedQueries.find((q) =>
                q.sql.includes("DELETE FROM tpenawaran_dtl"),
            );
            expect(deleteDtlCall).toBeDefined();
            expect(deleteDtlCall.params).toEqual(["00001/KP/2026"]);

            const insertDtlCall = executedQueries.find((q) =>
                q.sql.includes("INSERT INTO tpenawaran_dtl"),
            );
            expect(insertDtlCall).toBeDefined();
            expect(insertDtlCall.params[1]).toBe("00001/KP/2026");
            expect(insertDtlCall.params[3]).toBe("Baju Sablon");

            // Pastikan audit trail tspk_pin5 dicatat
            const insertAuditCall = executedQueries.find(
                (q) =>
                    q.sql.includes("INSERT INTO tspk_pin5") &&
                    q.params.includes("PENAWARAN_EDIT"),
            );
            expect(insertAuditCall).toBeDefined();

            expect(mockConn.commit).toHaveBeenCalled();
        });
    });
});
