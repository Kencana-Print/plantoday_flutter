import { describe, it, expect, vi, beforeEach } from "vitest";
import path from "path";
import fs from "fs";
import sharp from "sharp";
import db from "../config/dbPenawaran";
import permintaanHargaService from "../services/permintaanHargaService";
import { uploadPermintaanHarga, UPLOAD_DIR } from "../middleware/uploadPermintaanHarga";

const dbProto = Object.getPrototypeOf(db);

describe("Audit & Fix Permintaan Harga Image Upload", () => {
    beforeEach(() => {
        vi.restoreAllMocks();
    });

    describe("1. File Name Sanitization & Delete Consistency", () => {
        it("should sanitize '/' in nomor when deleting image", async () => {
            vi.spyOn(dbProto, "query").mockImplementation(async function (sql) {
                if (sql.includes("FROM tmintaharga WHERE mh_nomor")) {
                    return [
                        [
                            {
                                mh_nomor: "001/MH/2026",
                                mh_status: "BELUM",
                                mh_sal_kode: "SALES1",
                                user_create: "SALES1",
                            },
                        ],
                    ];
                }
                return [[]];
            });

            const existsSyncSpy = vi.spyOn(fs, "existsSync").mockReturnValue(true);
            vi.spyOn(fs.promises, "unlink").mockResolvedValue(undefined);

            const result = await permintaanHargaService.deletePermintaanHargaImage({
                nomor: "001/MH/2026",
                slot: "1",
                user: { salesKode: "SALES1" },
            });

            expect(result.status).toBe(200);
            expect(existsSyncSpy).toHaveBeenCalled();
            // Path should use sanitized filename: "001_MH_2026.jpg", NOT containing "/"
            const checkedPath = existsSyncSpy.mock.calls[0][0];
            expect(checkedPath).toBe(path.join(UPLOAD_DIR, "001_MH_2026.jpg"));
            expect(checkedPath).not.toContain("001/MH/2026");
        });

        it("should sanitize '/' in nomor in multer filename generator", () => {
            const req = { params: { nomor: "001/MH/2026", slot: "1" } };
            let generatedFilename = "";
            uploadPermintaanHarga.storage.getFilename(req, null, (err, filename) => {
                generatedFilename = filename;
            });
            expect(generatedFilename).toBe("001_MH_2026.jpg");
            expect(generatedFilename).not.toContain("/");
        });
    });

    describe("2. Copy Image uses UPLOAD_DIR (not uploads/mintaharga)", () => {
        it("should clone image files from UPLOAD_DIR when copying permintaan harga", async () => {
            vi.spyOn(dbProto, "query").mockImplementation(async function (sql) {
                if (sql.includes("SELECT * FROM tmintaharga WHERE mh_nomor = ?")) {
                    return [
                        [
                            {
                                mh_nomor: "MH.2026.0001",
                                mh_tanggal: "2026-05-18",
                                mh_sal_kode: "SALES1",
                                mh_status: "BELUM",
                            },
                        ],
                    ];
                }
                return [[]];
            });

            const mockConn = {
                query: vi.fn().mockImplementation((sql) => {
                    if (sql.includes("SELECT IFNULL(MAX(RIGHT(mh_nomor,4)),0) AS jumlah")) {
                        return [[{ jumlah: 1 }]];
                    }
                    if (sql.includes("SELECT mh_nomor FROM tmintaharga WHERE mh_nomor = ?")) {
                        return [[]];
                    }
                    if (sql.includes("INSERT INTO tmintaharga")) {
                        return [{ affectedRows: 1 }];
                    }
                    return [[]];
                }),
                beginTransaction: vi.fn().mockResolvedValue(undefined),
                commit: vi.fn().mockResolvedValue(undefined),
                rollback: vi.fn().mockResolvedValue(undefined),
                release: vi.fn().mockResolvedValue(undefined),
            };
            vi.spyOn(dbProto, "getConnection").mockResolvedValue(mockConn);

            const accessSpy = vi.spyOn(fs.promises, "access").mockResolvedValue(undefined);
            const copyFileSpy = vi.spyOn(fs.promises, "copyFile").mockResolvedValue(undefined);

            const result = await permintaanHargaService.copyPermintaanHarga({
                nomor: "MH.2026.0001",
                user: { salesKode: "SALES1" },
            });

            expect(result.status).toBe(201);
            expect(accessSpy).toHaveBeenCalled();
            // Source and destination should be inside UPLOAD_DIR, not "uploads/mintaharga"
            const src1 = accessSpy.mock.calls[0][0];
            expect(src1).toBe(path.join(UPLOAD_DIR, "MH.2026.0001.jpg"));
            expect(src1).not.toContain(path.join("uploads", "mintaharga"));
        });
    });

    describe("3. Base64 Upload sanitizes '/' and uses .rotate()", () => {
        it("should sanitize '/' in nomor and save file in UPLOAD_DIR", async () => {
            vi.spyOn(dbProto, "query").mockImplementation(async function (sql) {
                if (sql.includes("FROM tmintaharga WHERE mh_nomor")) {
                    return [
                        [
                            {
                                mh_nomor: "001/MH/2026",
                                mh_status: "BELUM",
                                mh_sal_kode: "SALES1",
                                user_create: "SALES1",
                            },
                        ],
                    ];
                }
                return [[]];
            });

            const writeFileSpy = vi.spyOn(fs.promises, "writeFile").mockResolvedValue(undefined);

            const testBuffer = await sharp({
                create: {
                    width: 1,
                    height: 1,
                    channels: 3,
                    background: { r: 255, g: 0, b: 0 },
                },
            })
                .jpeg()
                .toBuffer();
            const validBase64 = `data:image/jpeg;base64,${testBuffer.toString("base64")}`;

            const result = await permintaanHargaService.uploadPermintaanHargaImageBase64({
                nomor: "001/MH/2026",
                slot: "1",
                dataUrl: validBase64,
                user: { salesKode: "SALES1" },
            });

            expect(result.status).toBe(200);
            expect(writeFileSpy).toHaveBeenCalled();
            const savedPath = writeFileSpy.mock.calls[0][0];
            expect(savedPath).toBe(path.join(UPLOAD_DIR, "001_MH_2026.jpg"));
            expect(savedPath).not.toContain("001/MH/2026");
        });
    });
});
