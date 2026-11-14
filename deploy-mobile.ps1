<#
=============================================================================
  Script Otomasi Build & Deploy Mobile (PlanToday_flutter)
  Autentikasi: SSH Key id_ed25519_IT-Yahya_VPS1
  Target Host : kencana@103.94.238.252
  Target Path : /var/www/PlanToday_flutter/build/apk
  Base URL    : http://103.94.238.252:8182/releases
=============================================================================
#>

param(
    [switch]$Force,
    [switch]$Mandatory
)

$ErrorActionPreference = "Stop"

# ── 1. Konfigurasi SSH & VPS ────────────────────────────────────────────────
$SSH_KEY         = "$env:USERPROFILE\.ssh\id_ed25519_IT-Yahya_VPS1"
$VPS_USER        = "kencana"
$VPS_HOST        = "103.94.238.252"
$VPS_PORT        = 22
$VPS_PATH        = "/var/www/PlanToday_flutter/build/apk"
$BASE_URL        = "http://103.94.238.252:8182/releases"
$APK_BASENAME    = "PlanToday"

# Validasi file SSH Key
if (-not (Test-Path $SSH_KEY)) {
    Write-Error "File SSH Key tidak ditemukan di: $SSH_KEY"
    exit 1
}

# ── 2. Validasi Release Keystore ────────────────────────────────────────────
# Menolak build jika keystore rilis tidak lengkap untuk mencegah signature mismatch di HP user
$KEY_PROPS_PATH = "android\key.properties"
if (-not (Test-Path $KEY_PROPS_PATH)) {
    Write-Error @"
[FATAL] File $KEY_PROPS_PATH tidak ditemukan!
Build dibatalkan agar APK tidak ter-sign dengan Debug Key yang dapat merusak auto-update di HP pengguna.
Pastikan file android\key.properties tersedia sebelum melakukan deploy release.
"@
    exit 1
}

# Cari file keystore yang dikonfigurasi di key.properties
$props = ConvertFrom-StringData (Get-Content $KEY_PROPS_PATH -Raw)
$storeFile = $props.storeFile
if (-not $storeFile) { $storeFile = "plantoday.jks" }

$resolvedKeystore = $null
if (Test-Path "android\app\$storeFile") {
    $resolvedKeystore = "android\app\$storeFile"
} elseif (Test-Path "android\$storeFile") {
    $resolvedKeystore = "android\$storeFile"
} elseif (Test-Path $storeFile) {
    $resolvedKeystore = $storeFile
}

if (-not $resolvedKeystore) {
    Write-Error @"
[FATAL] File keystore ($storeFile) tidak ditemukan di android/app/ atau android/!
Build dibatalkan untuk menghindari signature mismatch.
"@
    exit 1
}

Write-Host ">>> [OK] Keystore terverifikasi: $resolvedKeystore" -ForegroundColor Green

# ── 3. Baca Versi dari pubspec.yaml & Cek Version Bump ──────────────────────
Write-Host "`n>>> [1/5] Membaca & Memvalidasi Versi Aplikasi..." -ForegroundColor Cyan
$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -match "version:\s*([0-9\.]+)\+([0-9]+)") {
    $VERSION_NAME = $matches[1]
    $BUILD_NUMBER = [int]$matches[2]
} else {
    Write-Error "Gagal membaca format versi di pubspec.yaml!"
    exit 1
}

Write-Host "    Versi Lokal : v$VERSION_NAME (Build $BUILD_NUMBER)" -ForegroundColor Yellow

# Validasi versionCode terhadap remote server
$REMOTE_LATEST_URL = "$BASE_URL/latest.json"
try {
    $remoteJsonRaw = (Invoke-WebRequest -Uri "$REMOTE_LATEST_URL?t=$((Get-Date).Ticks)" -UseBasicParsing -TimeoutSec 10).Content
    $remoteObj = $remoteJsonRaw | ConvertFrom-Json
    $REMOTE_VERSION_CODE = [int]($remoteObj.versionCode)
    Write-Host "    Versi Server: v$($remoteObj.versionName) (Build $REMOTE_VERSION_CODE)" -ForegroundColor Yellow

    if ($REMOTE_VERSION_CODE -gt 0 -and $BUILD_NUMBER -le $REMOTE_VERSION_CODE) {
        if ($Force) {
            Write-Host "`n[PERINGATAN] Build number lokal ($BUILD_NUMBER) <= server ($REMOTE_VERSION_CODE), dilanjutkan karena parameter -Force aktif." -ForegroundColor Yellow
        } else {
            Write-Error @"
[GAGAL] Build number di pubspec.yaml ($BUILD_NUMBER) harus lebih besar dari server ($REMOTE_VERSION_CODE)!
Naikkan version di pubspec.yaml (misal: +$($REMOTE_VERSION_CODE + 1)) atau jalankan dengan parameter -Force jika sengaja menimpa.
"@
            exit 1
        }
    }
} catch {
    Write-Host "    (Info: Tidak dapat memeriksa latest.json remote: $($_.Exception.Message))" -ForegroundColor Gray
}

$SHORT_SHA = (git rev-parse --short HEAD).Trim()
$APK_FILE        = "${APK_BASENAME}-v${VERSION_NAME}+${BUILD_NUMBER}-${SHORT_SHA}.apk"
$LATEST_APK_FILE = "${APK_BASENAME}-latest.apk"

# ── 4. Build APK Release ────────────────────────────────────────────────────
Write-Host "`n>>> [2/5] Mem-build APK Release (arm64-v8a)..." -ForegroundColor Cyan
flutter build apk --target-platform android-arm64 --release --dart-define-from-file=.env
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build APK gagal!"
    exit 1
}

$LOCAL_APK = "build/app/outputs/flutter-apk/app-release.apk"
if (-not (Test-Path $LOCAL_APK)) {
    $LOCAL_APK = "build/app/outputs/apk/release/app-release.apk"
}

if (-not (Test-Path $LOCAL_APK)) {
    Write-Error "File APK hasil build tidak ditemukan di build/app/outputs!"
    exit 1
}

# ── 5. Siapkan Artifact & latest.json ───────────────────────────────────────
Write-Host "`n>>> [3/5] Menghitung SHA256 & Menyiapkan manifest rilis..." -ForegroundColor Cyan
$SHA256   = (Get-FileHash -Path $LOCAL_APK -Algorithm SHA256).Hash.ToLower()
$PUB_DATE = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$MANDATORY_VAL = if ($Mandatory) { "true" } else { "false" }

$DEPLOY_DIR = "deploy/out"
New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null

Copy-Item $LOCAL_APK -Destination "$DEPLOY_DIR/$APK_FILE" -Force
Copy-Item $LOCAL_APK -Destination "$DEPLOY_DIR/$LATEST_APK_FILE" -Force

$LATEST_JSON = @"
{
  "versionCode": $BUILD_NUMBER,
  "versionName": "$VERSION_NAME",
  "mandatory": $MANDATORY_VAL,
  "apkUrl": "$BASE_URL/$LATEST_APK_FILE",
  "sha256": "$SHA256",
  "releaseDate": "$PUB_DATE",
  "notes": "PlanToday Flutter Build $SHORT_SHA"
}
"@

# Simpan latest.json sebagai UTF-8 tanpa BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $PWD "$DEPLOY_DIR/latest.json"), $LATEST_JSON, $utf8NoBom)

# ── 6. Upload ke VPS via SCP ────────────────────────────────────────────────
Write-Host "`n>>> [4/5] Mengunggah artifact ke VPS ($VPS_PATH)..." -ForegroundColor Cyan
$sshOptions = @("-i", $SSH_KEY, "-p", "$VPS_PORT", "-o", "IdentitiesOnly=yes")
$scpOptions = @("-i", $SSH_KEY, "-P", "$VPS_PORT", "-o", "IdentitiesOnly=yes")

ssh @sshOptions "${VPS_USER}@${VPS_HOST}" "mkdir -p $VPS_PATH/incoming"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal membuat folder incoming di VPS! Cek hak akses folder $VPS_PATH di VPS."
    exit 1
}

scp @scpOptions "$DEPLOY_DIR/*" "${VPS_USER}@${VPS_HOST}:${VPS_PATH}/incoming/"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal mengunggah file APK / latest.json via SCP!"
    exit 1
}

# ── 7. Normalisasi & Bersihkan Versi Lama di VPS ────────────────────────────
Write-Host "`n>>> [5/5] Menormalkan file & membersihkan APK versi lama di VPS..." -ForegroundColor Cyan

$remoteScript = @"
set -e
TARGET_DIR="$VPS_PATH"
cd "`$TARGET_DIR"

if [ -d "incoming" ]; then
  find incoming -type f \( -name "PlanToday-v*.apk" -o -name "PlanToday-latest.apk" -o -name "latest.json" \) -exec mv -f {} . \;
  rm -rf incoming
fi

chmod 644 PlanToday*.apk latest.json || true

# Sisakan 2 versi APK bertanggal terbaru
ls -1t PlanToday-v*.apk 2>/dev/null | tail -n +3 | xargs -r rm -f
"@

ssh @sshOptions "${VPS_USER}@${VPS_HOST}" $remoteScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal menormalkan file APK di server!"
    exit 1
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " [OK] DEPLOY MOBILE SELESAI!" -ForegroundColor Green
Write-Host " Versi Rilis  : v$VERSION_NAME+$BUILD_NUMBER ($SHORT_SHA)" -ForegroundColor Green
Write-Host " Lokasi VPS   : $VPS_PATH" -ForegroundColor Green
Write-Host " URL Download : $BASE_URL/$LATEST_APK_FILE" -ForegroundColor Green
Write-Host " Auto-Update  : $BASE_URL/latest.json" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
