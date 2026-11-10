const HONORIFICS = new Set([
    "pak",
    "bpk",
    "bapak",
    "bp",
    "ibu",
    "bu",
    "sdr",
    "sdri",
    "saudara",
    "saudari",
    "tn",
    "tuan",
    "ny",
    "nyonya",
    "nn",
    "nona",
    "mas",
    "mbak",
    "mba",
    "kak",
    "kakak",
    "om",
    "tante",
    "ust",
    "ustadz",
    "ustadzah",
    "kyai",
    "gus",
    "h",
    "hj",
    "haji",
    "hajjah",
    "dr",
    "drg",
    "drs",
    "dra",
    "ir",
    "prof",
]);

const BUSINESS_PREFIXES = new Set([
    "pt",
    "cv",
    "ud",
    "pd",
    "fa",
    "firma",
    "toko",
    "tk",
    "tb",
    "bengkel",
    "katering",
    "catering",
    "lpk",
    "lkp",
    "yayasan",
    "koperasi",
    "ksp",
    "kjks",
    "po",
    "otobus",
    "apotek",
    "apotik",
    "klinik",
    "salon",
    "resto",
    "restoran",
    "rm",
    "warung",
    "wr",
]);

const TITLE_SUFFIXES = new Set([
    "se",
    "sh",
    "st",
    "si",
    "skm",
    "spd",
    "sos",
    "ikom",
    "kom",
    "mm",
    "mag",
    "mh",
    "msi",
    "mba",
    "phd",
]);

/**
 * Normalisasi nama customer:
 * - Huruf kecil
 * - Hapus teks di dalam kurung (misal keterangan/kota seperti "(SOLO)", "(BARU)")
 * - Ganti tanda baca dengan spasi
 * - Hapus kata sapaan/gelar (Pak, Bu, Mas, Haji, dll.) dan badan usaha (PT, CV, UD, Toko, dll.) di awal
 * - Hapus gelar kesarjanaan di akhir
 */
function normalizeCustomerName(raw) {
    if (!raw || typeof raw !== "string") return "";
    let str = raw.trim().toLowerCase();
    if (!str) return "";

    // Buang teks di dalam tanda kurung
    str = str.replace(/\([^)]*\)/g, " ");

    // Gabungkan singkatan bertitik (misal: s.e. -> se, s.h. -> sh, p.t. -> pt, c.v. -> cv)
    str = str.replace(/\b([a-z])\.([a-z])(?:\.([a-z]))?(?:\.([a-z]))?\b/g, "$1$2$3$4");

    // Ganti karakter non-alfanumerik dengan spasi
    str = str.replace(/[^a-z0-9]+/g, " ");

    let tokens = str.split(/\s+/).filter(Boolean);
    if (!tokens.length) return "";

    // Buang awalan sapaan dan badan usaha selama masih ada kata berikutnya
    while (
        tokens.length > 1 &&
        (HONORIFICS.has(tokens[0]) || BUSINESS_PREFIXES.has(tokens[0]))
    ) {
        tokens.shift();
    }

    // Buang akhiran gelar jika ada kata sebelumnya
    while (tokens.length > 1 && TITLE_SUFFIXES.has(tokens[tokens.length - 1])) {
        tokens.pop();
    }

    return tokens.join(" ");
}

/**
 * Cek apakah dua nama customer serupa dengan aturan pelonggaran:
 * - isExact: true jika nama hasil normalisasi persis sama (misal: "Pak Mulyono" == "Bpk. MULYONO" == "Mulyono")
 * - isMatch: true jika exact ATAU ada irisan kata inti (misal: "Dewi" serupa dengan "Dewi Sartika")
 */
function checkNameSimilarity(nameA, nameB) {
    const normA = normalizeCustomerName(nameA);
    const normB = normalizeCustomerName(nameB);

    if (!normA || !normB) {
        return { isMatch: false, isExact: false, normA, normB };
    }

    if (normA === normB) {
        return { isMatch: true, isExact: true, normA, normB };
    }

    const tokensA = normA.split(" ").filter((t) => t.length >= 2);
    const tokensB = normB.split(" ").filter((t) => t.length >= 2);

    if (!tokensA.length || !tokensB.length) {
        return { isMatch: false, isExact: false, normA, normB };
    }

    const setA = new Set(tokensA);
    const setB = new Set(tokensB);

    const isSubset = (small, large) => {
        let matched = 0;
        const validTokens = small.filter((t) => t.length >= 3);
        if (!validTokens.length) return false;
        for (const t of validTokens) {
            if (large.has(t)) matched++;
        }
        return matched === validTokens.length;
    };

    if (isSubset(tokensA, setB) || isSubset(tokensB, setA)) {
        return { isMatch: true, isExact: false, normA, normB };
    }

    return { isMatch: false, isExact: false, normA, normB };
}

/**
 * Mencari customer serupa di database
 */
async function findSimilarCustomers(
    db,
    rawName,
    { excludeKode = "", tableName = "tcustomer" } = {},
) {
    const norm = normalizeCustomerName(rawName);
    if (!norm || norm.length < 2) return [];

    const tokens = norm.split(" ").filter((t) => t.length >= 2);
    if (!tokens.length) return [];

    // Ambil kata terpanjang untuk filter awal via SQL LIKE
    const mainToken = tokens.reduce(
        (a, b) => (b.length > a.length ? b : a),
        tokens[0],
    );
    if (mainToken.length < 2) return [];

    const likePattern = `%${mainToken}%`;
    const cleanExclude = String(excludeKode || "").trim();

    const sql = `
        SELECT
            cus_kode AS kode,
            cus_nama AS nama,
            COALESCE(cus_alamat, '') AS alamat,
            COALESCE(cus_kota, '') AS kota
        FROM ${tableName}
        WHERE cus_nama LIKE ?
        ${cleanExclude ? "AND cus_kode != ?" : ""}
        LIMIT 50
    `;
    const params = cleanExclude ? [likePattern, cleanExclude] : [likePattern];

    const [rows] = await db.query(sql, params);
    if (!rows || !rows.length) return [];

    const matched = [];
    for (const row of rows) {
        const sim = checkNameSimilarity(rawName, row.nama);
        if (sim.isMatch) {
            matched.push({
                kode: String(row.kode || ""),
                nama: String(row.nama || ""),
                alamat: String(row.alamat || ""),
                kota: String(row.kota || ""),
                isExact: sim.isExact,
            });
        }
    }

    matched.sort((a, b) => (b.isExact ? 1 : 0) - (a.isExact ? 1 : 0));
    return matched;
}

module.exports = {
    HONORIFICS,
    BUSINESS_PREFIXES,
    TITLE_SUFFIXES,
    normalizeCustomerName,
    checkNameSimilarity,
    findSimilarCustomers,
};
