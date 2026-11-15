import { describe, it, expect } from "vitest";
const {
    normalizeCustomerName,
    checkNameSimilarity,
} = require("../utils/customerNameHelper");

describe("customerNameHelper", () => {
    describe("normalizeCustomerName", () => {
        it("mengabaikan sapaan seperti Pak, Bpk, Bapak, Ibu, dll", () => {
            expect(normalizeCustomerName("Pak Mulyono")).toBe("mulyono");
            expect(normalizeCustomerName("Bpk. Mulyono")).toBe("mulyono");
            expect(normalizeCustomerName("BAPAK MULYONO")).toBe("mulyono");
            expect(normalizeCustomerName("Ibu Dewi")).toBe("dewi");
            expect(normalizeCustomerName("Bu Dewi")).toBe("dewi");
            expect(normalizeCustomerName("Sdr. Hendra")).toBe("hendra");
            expect(normalizeCustomerName("Mas Agus")).toBe("agus");
            expect(normalizeCustomerName("Mbak Siti")).toBe("siti");
            expect(normalizeCustomerName("Haji Joko")).toBe("joko");
        });

        it("mengabaikan awalan badan usaha seperti PT, CV, UD, Toko", () => {
            expect(normalizeCustomerName("PT. Jaya Abadi")).toBe("jaya abadi");
            expect(normalizeCustomerName("CV Jaya Abadi")).toBe("jaya abadi");
            expect(normalizeCustomerName("UD. Makmur")).toBe("makmur");
            expect(normalizeCustomerName("Toko Sumber Rejeki")).toBe(
                "sumber rejeki",
            );
            expect(normalizeCustomerName("TB. Subur")).toBe("subur");
            expect(normalizeCustomerName("Bengkel Maju")).toBe("maju");
        });

        it("mengabaikan kombinasi sapaan dan gelar di awal / akhir", () => {
            expect(normalizeCustomerName("Bpk. H. Mulyono")).toBe("mulyono");
            expect(normalizeCustomerName("Pak Mulyono, S.E.")).toBe("mulyono");
            expect(normalizeCustomerName("Ibu Dewi, S.H., M.H.")).toBe("dewi");
            expect(normalizeCustomerName("PT. Sumber Berkah (Solo)")).toBe(
                "sumber berkah",
            );
        });

        it("tidak menghapus kata jika nama hanya terdiri dari 1 kata tersebut", () => {
            expect(normalizeCustomerName("Pak")).toBe("pak");
            expect(normalizeCustomerName("Haji")).toBe("haji");
            expect(normalizeCustomerName("Dewi")).toBe("dewi");
        });
    });

    describe("checkNameSimilarity", () => {
        it("mendeteksi exact match setelah normalisasi", () => {
            const res1 = checkNameSimilarity("Pak Mulyono", "Bpk. MULYONO");
            expect(res1.isMatch).toBe(true);
            expect(res1.isExact).toBe(true);

            const res2 = checkNameSimilarity("Ibu Dewi", "Dewi");
            expect(res2.isMatch).toBe(true);
            expect(res2.isExact).toBe(true);

            const res3 = checkNameSimilarity(
                "PT. Jaya Abadi",
                "CV. JAYA ABADI",
            );
            expect(res3.isMatch).toBe(true);
            expect(res3.isExact).toBe(true);
        });

        it("mendeteksi similar match untuk pelonggaran kata inti", () => {
            // "Mulyono" serupa dengan "Mulyono Santoso"
            const res1 = checkNameSimilarity("Pak Mulyono", "Mulyono Santoso");
            expect(res1.isMatch).toBe(true);
            expect(res1.isExact).toBe(false);

            // "Dewi" serupa dengan "Dewi Sartika"
            const res2 = checkNameSimilarity("Ibu Dewi", "Dewi Sartika");
            expect(res2.isMatch).toBe(true);
            expect(res2.isExact).toBe(false);
        });

        it("tidak mencocokkan nama yang berbeda meskipun mirip hurufnya", () => {
            const res1 = checkNameSimilarity("Ana", "Anang");
            expect(res1.isMatch).toBe(false);

            const res2 = checkNameSimilarity("Dewi", "Deni");
            expect(res2.isMatch).toBe(false);

            const res3 = checkNameSimilarity("Mulyono", "Mulyadi");
            expect(res3.isMatch).toBe(false);
        });
    });
});
