---
design-system:
  name: PlanToday Mobile Design System
  version: 1.0.0
  description: Panduan gaya visual, token desain, dan pedoman komponen untuk aplikasi PlanToday Mobile (Flutter Edition).
  tokens:
    colors:
      brand:
        primary: "#4F46E5" # Indigo (Tombol utama, highlight penting, tab aktif)
        accent: "#06B6D4"  # Cyan (Aksen modern, gradien sekunder)
      feedback:
        success: "#16A34A" # Hijau sukses (Status selesai, berhasil)
        danger: "#EF4444"  # Merah bahaya (Error, gagal, batalkan)
        info: "#0369A1"    # Biru info (Notifikasi, pemberitahuan sistem)
        warning: "#F59E0B" # Kuning peringatan
        warningBg: "#FEF3C7"
        warningBorder: "#FCD34D"
        warningText: "#92400E"
        wa: "#22C55E"      # Hijau WhatsApp
      transaction_status:
        wait: "#D97706"    # Menunggu persetujuan
        acc: "#16A34A"     # Disetujui
        tolak: "#DC2626"   # Ditolak
      company_status:
        belum_diverifikasi:
          base: "#E65100"    # Oranye pekat (Permintaan harga belum diverifikasi / menunggu ACC standar)
          text: "#BF360C"
          unselected_bg: "#FFF3E0"
          unselected_border: "#FFE0B2"
        belum:
          base: "#6B7280"
          text: "#374151"
        minta:
          base: "#DC2626"
          text: "#991B1B"
        wait:
          base: "#16A34A"
          text: "#15803D"
        nego:
          base: "#6B21A8"
          text: "#4A044E"
        done:
          base: "#18181B"
          text: "#09090B"
        cancel:
          base: "#2563EB"
          text: "#1D4ED8"
        default:
          base: "#6366F1"
          text: "#4F46E5"
      neutral:
        ink: "#0F172A"     # Slate gelap (Teks utama, judul)
        muted: "#64748B"   # Slate abu-abu (Teks sekunder, deskripsi, label)
        card: "#FFFFFF"    # Putih bersih (Latar belakang kartu komponen, modal)
        soft: "#F1F5F9"    # Abu-abu sangat lembut (Input non-aktif, chip filter)
        border: "rgba(15,23,42,0.08)" # Abu-abu transparan (Garis pembatas kartu & form)
        overlay: "rgba(15,23,42,0.45)" # Gelap transparan (Overlay modal & bottomsheet)
        bg-top: "#F7F9FF"  # Gradien latar belakang atas layar
        bg-bottom: "#FFFFFF" # Gradien latar belakang bawah layar
    typography:
      families:
        primary: "DM Sans"  # Font utama aplikasi PlanToday (Modern, bersih, legibility tinggi untuk data & nominal rupiah)
      sizes:
        xs: 10
        sm: 12
        md: 14
        lg: 16
        xl: 18
        xxl: 22
      weights:
        regular: "400"
        medium: "500"
        semibold: "700"
        bold: "800"
        heavy: "900"
    spacing:
      base: 4
      scale: [4, 6, 8, 10, 12, 14, 16, 20, 24, 32]
    borders:
      radius:
        small: 8
        medium: 12
        large: 16
        card: 24
    shadows:
      card:
        color: "rgba(0, 0, 0, 0.06)"
        blur: 18
        offset: [0, 10]
        elevation: 3
      softCard:
        color: "rgba(0, 0, 0, 0.05)"
        blur: 14
        offset: [0, 8]
        elevation: 2
    breakpoints:
      mobile:
        max: 599
      tablet:
        min: 600
        max: 1023
      desktop:
        min: 1024
---

# PlanToday Mobile Design System

Berkas ini mendefinisikan bahasa visual dan pedoman tata letak antarmuka pengguna untuk proyek **PlanToday Mobile (Flutter)**, diadopsi langsung dari standar arsitektur visual proyek React Native.

Developer dan asisten AI wajib menggunakan panduan ini sebagai satu-satunya sumber acuan visual (*single source of truth*) dalam merancang, menambahkan, atau memodifikasi komponen UI.

---

## 1. Prinsip Desain
1. **Kejelasan dan Kontras Tinggi**: Seluruh teks harus memiliki tingkat keterbacaan tinggi dengan memanfaatkan warna `neutral.ink` (`#0F172A`) untuk teks utama dan kontras yang cukup dengan latar belakang.
2. **Desain Modern dengan Sudut Melengkung (Rounded)**: Komponen seperti tombol, kartu, input, dan modal menggunakan sudut melengkung sedang (`borders.radius.medium: 12`) atau kartu besar (`borders.radius.card: 24`) untuk tampilan modern yang premium dan ramah pengguna.
3. **Bahasa Warna yang Konsisten**: Warna `brand.primary` (`#4F46E5`) digunakan untuk elemen interaktif utama, sedangkan warna umpan balik (`feedback.success`, `feedback.danger`, `feedback.warning`) hanya digunakan untuk menyampaikan status atau notifikasi secara spesifik.

---

## 2. Panduan Penerapan Komponen di Flutter

### A. Latar Belakang Layar (Screen Background)
Setiap layar utama menggunakan gradien vertikal lembut:
```dart
Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.bgTop, AppColors.bgBottom],
    ),
  ),
  child: ...,
)
```

### B. Kartu & Kontainer (Cards & Containers)
* **Warna Latar**: Menggunakan `AppColors.card` (`#FFFFFF`).
* **Sudut**: Menggunakan `AppRadius.card` (`24.0`) atau `AppRadius.large` (`16.0`).
* **Pembatas**: Garis pinggir tipis (`border: Border.all(color: AppColors.border)`).
* **Bayangan (Elevation / Shadow)**:
```dart
boxShadow: [
  BoxShadow(
    color: Color(0x0F000000), // rgba(0, 0, 0, 0.06)
    blurRadius: 18,
    offset: Offset(0, 10),
  ),
]
```

### C. Tombol Utama (Primary Buttons)
* **Gradien Tombol**: Menggunakan `[AppColors.primary, AppColors.accent]` (`[#4F46E5, #06B6D4]`).
* **Teks**: Berwarna putih (`#FFFFFF`) dengan ketebalan `FontWeight.w800` atau `FontWeight.w900`.
* **Tinggi Minimal**: `48.0` unit (area sentuh mobile nyaman).
* **Radius**: `AppRadius.medium` (`12.0`).

### D. Input Formulir (Form Fields)
* **Tinggi Padding**: `EdgeInsets.symmetric(horizontal: 16, vertical: 12)`.
* **Border**: `OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border))`.
* **Warna Latar**: `AppColors.card` (`#FFFFFF`).
* **Placeholder**: Warna `AppColors.muted` (`#64748B`).

### E. Skala Spasi (Spacing Scale)
Semua tata letak, termasuk *margin*, *padding*, dan jarak antar komponen (*gap*), harus merujuk pada skala dasar kelipatan `4`:
* Jarak mikro (antar teks dan subteks): `6` atau `8` unit.
* Jarak sedang (padding di dalam kartu): `14` atau `16` unit.
* Jarak besar (padding luar layar): `20` atau `24` unit.

### F. Dialog Konfirmasi Formulir (`FormConfirmDialog`)
Setiap pengiriman formulir baru atau penyimpanan perubahan data wajib menampilkan modal konfirmasi terlebih dahulu:
* **Fungsi**: `showFormConfirmDialog(context, title, subtitle, icon, summaryItems, confirmText)`
* **Layout Kartu**: `maxWidth: 400`, `borderRadius: 24`, border tipis `neutral.border`.
* **Indikator Atas**: Kapsul abu-abu selebar `36px` dan tinggi `4px` (`#CBD5E1`) di bagian atas dialog.
* **Kotak Ringkasan**: Latar belakang `#F8FAFC`, border `#E2E8F0`, menampilkan pasangan kunci-nilai data penting (*summary items*).
* **Aksi Bawah**: Dua tombol seimbang — Batal (abu-abu netral) dan Konfirmasi Utama (Primary Indigo / Warning).

### G. Dialog Konfirmasi Keluar Akun (Logout Dialog)
* **Visual**: Kartu terpusat dengan indikator atas kapsul (`#CBD5E1`), judul "Keluar Akun", deskripsi konfirmasi, dan kotak info akun pengguna (`#F1F5F9`) dengan avatar inisial berwarna oranye/amber.
* **Tombol Aksi**: Tombol Batal (`#F1F5F9`) dan Tombol Keluar berwarna merah (`#EF4444`) dengan radius `12.0`.

### H. Banner Notifikasi Pembaruan Web & PWA (`WebUpdateBanner`)
* **Tata Letak**: Melayang di bagian atas layar pada platform Web saat terdeteksi versi baru.
* **Responsif**:
  - Desktop: Satu baris memanjang dengan teks rincian versi di kiri dan tombol aksi di kanan.
  - Mobile: Layout bertumpuk vertikal dengan teks ringkas dan tombol "Perbarui Sekarang" yang memenuhi lebar.
* **Hard Reload**: Tombol memicu unregister Service Worker, pembersihan cache storage, dan pemuatan ulang paksa (*cache-busting query parameter*).

### I. Modal Panduan Shortcut Keyboard (`WebShortcutGuideModal`)
* **Trigger**: Tombol shortcut di header web atau menekan tombol keyboard `?` / `F1`.
* **Visual**: Grid kartu shortcut per kategori (Navigasi, Aksi Cepat, Form) dengan badge tombol keyboard bergaya fisik (*kbd style*).

### J. Standar Tipografi Global (DM Sans)
Seluruh teks antarmuka aplikasi **PlanToday** menggunakan keluarga font **DM Sans**:
* **Karakteristik**: Geometric sans-serif modern dengan legibility tinggi pada layar berukuran kecil (mobile), pembedaan karakter yang tegas (angka `0` vs huruf `O`, `1` vs `l`/`I`), serta proporsi angka finansial yang stabil dan rapi untuk data transaksi & nominal rupiah.
* **Integrasi Teknis**: Diterapkan secara terpusat melalui `GoogleFonts.dmSans` pada `AppTheme.lightTheme` (`ThemeData.fontFamily` dan `ThemeData.textTheme`).
* **Hirarki Bobot (Weights)**:
  - `FontWeight.w400` (`Regular`): Deskripsi panjang, body text, placeholder.
  - `FontWeight.w500` (`Medium`): Label input, teks pendukung.
  - `FontWeight.w600` / `w700` (`SemiBold`): Label tombol sekunder, tanggal, subtitle kartu.
  - `FontWeight.w800` (`Bold`): Judul kartu modul, judul AppBar, badge status.
  - `FontWeight.w900` (`Black/Heavy`): **Seluruh penulisan angka kuantitatif, nominal rupiah (`Rp ...`), nilai target, realisasi, persentase ketercapaian (`%`), quick stats, nama pengguna, dan logo.**

---

## 3. Pedoman Desain Responsif (Mobile, Tablet, Desktop)

Aplikasi **PlanToday** mendukung tata letak adaptif dan responsif multi-platform (Android Phone, Tablet/iPad, Desktop & Web) menggunakan standar Material 3 Adaptive Breakpoints.

### A. Titik Henti Layar (Breakpoints)

| Kategori Perangkat | Lebar Layar (Width) | Tipe Grid Konten | Padding Horizontal Layar |
|---|---|---|---|
| **Mobile (Compact)** | `< 600px` | 1 Kolom (List vertikal) | `16px - 20px` |
| **Tablet (Medium)** | `600px - 1023px` | 2 Kolom (List / Form) | `24px - 32px` |
| **Desktop / Web (Expanded)** | `≥ 1024px` | 3 - 4 Kolom | `32px - 48px` (Max Content Width: `1200px`) |

---

### B. Aturan Adaptasi Tata Letak (Layout Adaptation Rules)

#### 1. Kontainer Maksimal di Layar Lebar (Max-Width Container)
Pada layar Tablet dan Desktop, seluruh konten utama tidak boleh membentang penuh dari ujung ke ujung layar agar keterbacaan tetap terjaga. Bungkus halaman dengan kontainer terpusat:
```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 1200),
    child: child,
  ),
)
```

#### 2. Grid Menu Dashboard (HomeScreen)
* **Mobile**: `crossAxisCount: 3`, rasio kartu `0.9` (3 menu per baris).
* **Tablet**: `crossAxisCount: 4` s/d `6`, rasio kartu `1.0` (4–6 menu per baris).
* **Desktop**: `crossAxisCount: 6`, dengan padding horizontal diperlebar.

#### 3. List Data Transaksi (Penawaran, Visit, Permintaan Harga, Potensi)
* **Mobile**: `ListView.separated` satu kartu penuh per baris.
* **Tablet & Desktop**: Gunakan `GridView.builder` dengan `SliverGridDelegateWithFixedCrossAxisCount`:
  - Tablet: `crossAxisCount: 2`, `childAspectRatio: 1.4` (2 kartu berdampingan).
  - Desktop: `crossAxisCount: 3`, `childAspectRatio: 1.3` (3 kartu per baris).

#### 4. Formulir Input (Forms & Inputs)
* **Mobile**: Input bertumpuk vertikal (*single column*), tombol simpan membentang penuh (`width: double.infinity`).
* **Tablet & Desktop**: Input berpasangan menggunakan `Row` dengan `Expanded` (misal: Tanggal & Customer berdampingan; Biaya Potong & Jahit berdampingan). Tombol aksi berada di sisi kanan bawah (*right-aligned*) dengan lebar tetap (`width: 200px - 240px`).

---

### C. Adaptasi Modal & Dialog

* **Mobile**:
  - Gunakan **`showModalBottomSheet`** dengan sudut melengkung atas (`AppRadius.card`), mendukung geser ke bawah (*swipe-to-dismiss*).
* **Tablet & Desktop**:
  - Hindari bottom sheet yang melebar penuh. Alihkan otomatis menjadi **`showDialog`** di tengah layar dengan batasan lebar:
```dart
Dialog(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: content,
  ),
)
```

---

### D. Pola Navigasi Adaptif

* **Mobile**: App Bar dengan tombol kembali (`AppBar`) dan menu navigasi bawah (*Bottom Navigation Bar*).
* **Tablet**: **`NavigationRail`** ramping vertikal di sebelah kiri layar untuk perpindahan modul cepat.
* **Desktop**: **Sidebar Tetap (Permanent Navigation Drawer)** di sisi kiri selebar `260px` dengan rincian menu dan profil sales permanen.

---

### E. Snippet Helper Widget Flutter (`ResponsiveHelper`)

Gunakan fungsi atau widget pembantu berikut untuk mempermudah percabangan layout di UI:

```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 && width < 1024;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1024 && desktop != null) return desktop!;
    if (width >= 600 && tablet != null) return tablet!;
    return mobile;
  }
}
```

