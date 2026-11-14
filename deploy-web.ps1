<#
=============================================================================
  Script Otomasi Build & Deploy Web (PlanToday_flutter)
  Autentikasi: SSH Key id_ed25519_IT-Yahya_VPS1
  Target Host : kencana@103.94.238.252
  Target Path : /var/www/PlanToday_flutter/build/web
=============================================================================
#>

$ErrorActionPreference = "Stop"

# ── 1. Konfigurasi SSH & VPS ────────────────────────────────────────────────
$SSH_KEY      = "$env:USERPROFILE\.ssh\id_ed25519_IT-Yahya_VPS1"
$VPS_USER     = "kencana"
$VPS_HOST     = "103.94.238.252"
$VPS_PORT     = 22
$VPS_PATH     = "/var/www/PlanToday_flutter/build/web"

# Validasi file SSH Key
if (-not (Test-Path $SSH_KEY)) {
    Write-Error "File SSH Key tidak ditemukan di: $SSH_KEY"
    exit 1
}

# ── 2. Build Flutter Web Release ────────────────────────────────────────────
Write-Host ">>> [1/4] Update Dependensi & Mem-build Flutter Web (Release)..." -ForegroundColor Cyan
flutter pub get
flutter build web --release --pwa-strategy=none --base-href "/"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build Flutter Web gagal!"
    exit 1
}

if (-not (Test-Path "build/web/index.html")) {
    Write-Error "Hasil build Flutter Web tidak ditemukan di build/web!"
    exit 1
}

# ── 3. Terapkan Cache-Busting pada flutter_bootstrap.js ──────────────────────
# Sesuai dengan alur di .github/workflows/deploy-web.yml
Write-Host "`n>>> [2/4] Menerapkan cache-buster hash commit ke flutter_bootstrap.js..." -ForegroundColor Cyan
$BUILD_HASH = (git rev-parse --short=8 HEAD).Trim()
$bootstrapPath = "build/web/flutter_bootstrap.js"
if (Test-Path $bootstrapPath) {
    $content = Get-Content $bootstrapPath -Raw
    $content = $content -replace "main\.dart\.js", "main.dart.js?v=$BUILD_HASH"
    [System.IO.File]::WriteAllText((Join-Path $PWD $bootstrapPath), $content, [System.Text.Encoding]::UTF8)
    Write-Host "    [OK] Injeksi cache-buster versi v=$BUILD_HASH berhasil." -ForegroundColor Green
} else {
    Write-Host "    (Info: $bootstrapPath tidak ditemukan, lewati injeksi cache-buster)" -ForegroundColor Gray
}

# ── 4. Kompresi Hasil Build Web (tar.gz) untuk Upload Cepat ─────────────────
Write-Host "`n>>> [3/4] Mengompresi hasil build web..." -ForegroundColor Cyan
$TEMP_DIR = "build/deploy_web_out"
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
$ARCHIVE_FILE = "$TEMP_DIR/web-release.tar.gz"

if (Test-Path $ARCHIVE_FILE) {
    Remove-Item -Path $ARCHIVE_FILE -Force
}

tar -czf $ARCHIVE_FILE -C build/web .
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ARCHIVE_FILE)) {
    Write-Error "Gagal mengompres direktori build/web!"
    exit 1
}

# ── 5. Upload & Ekstrak di VPS via SSH / SCP ────────────────────────────────
Write-Host "`n>>> [4/4] Mengunggah dan mengekstrak di VPS ($VPS_PATH)..." -ForegroundColor Cyan
$sshOptions = @("-i", $SSH_KEY, "-p", "$VPS_PORT", "-o", "IdentitiesOnly=yes")
$scpOptions = @("-i", $SSH_KEY, "-P", "$VPS_PORT", "-o", "IdentitiesOnly=yes")

# Buat folder sementara di VPS
ssh @sshOptions "${VPS_USER}@${VPS_HOST}" "mkdir -p /tmp/plantoday_web_deploy"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal menghubungi VPS atau membuat folder temporary!"
    exit 1
}

# Upload arsip
scp @scpOptions $ARCHIVE_FILE "${VPS_USER}@${VPS_HOST}:/tmp/plantoday_web_deploy/web-release.tar.gz"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal mengunggah file arsip web ke VPS!"
    exit 1
}

# Ekstrak, set permission, reload Nginx
$remoteScript = @"
set -e
sudo mkdir -p "$VPS_PATH"
sudo chown -R ${VPS_USER}:${VPS_USER} "$VPS_PATH"
sudo rm -rf "$VPS_PATH"/*
tar -xzf /tmp/plantoday_web_deploy/web-release.tar.gz -C "$VPS_PATH"
rm -rf /tmp/plantoday_web_deploy
sudo chmod -R 755 "$VPS_PATH" || true
sudo systemctl reload nginx || true
"@

ssh @sshOptions "${VPS_USER}@${VPS_HOST}" $remoteScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal mengekstrak web release atau me-reload Nginx di VPS!"
    exit 1
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " [OK] DEPLOY WEB SELESAI!" -ForegroundColor Green
Write-Host " Commit Hash  : $BUILD_HASH" -ForegroundColor Green
Write-Host " Lokasi VPS   : $VPS_PATH" -ForegroundColor Green
Write-Host " Status Nginx : Reloaded" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
