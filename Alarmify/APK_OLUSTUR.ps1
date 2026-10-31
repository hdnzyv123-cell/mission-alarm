# Mission Alarm - Tek Tıkla Yerel APK Üretici Script
$ErrorActionPreference = "Stop"

Write-Host "=====================================================" -ForegroundColor Green
Write-Host "   MISSION ALARM - ANDROID APK DERLEME ARACI         " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Bilgisayarınızda Flutter SDK bulunamadı." -ForegroundColor Yellow
    Write-Host "Lütfen önce Flutter ve Android SDK kurun VEYA klasördeki .github/workflows/build_apk.yml" -ForegroundColor Yellow
    Write-Host "dosyasını kullanarak GitHub üzerinden hiçbir kurulum yapmadan APK dosyanızı indirin." -ForegroundColor Cyan
    exit 1
}

Write-Host "[1/4] Özel Kotlin/Swift/Dart dosyaları yedekleniyor..." -ForegroundColor Cyan
$backupDir = Join-Path $env:TEMP "mission_alarm_backup"
if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item -Path "android", "ios", "lib", "pubspec.yaml" -Destination $backupDir -Recurse -Force

Write-Host "[2/4] Eksik Gradle sarmalayıcı (wrapper) dosyaları tamamlanıyor..." -ForegroundColor Cyan
flutter create . --project-name mission_alarm --org com.opensource

Write-Host "[3/4] Özel Mission Alarm kodları geri yükleniyor ve paketler indiriliyor..." -ForegroundColor Cyan
Copy-Item -Path "$backupDir\*" -Destination "." -Recurse -Force
flutter pub get

Write-Host "[4/4] Android APK derleniyor (Release Modu)..." -ForegroundColor Cyan
flutter build apk --release

$apkPath = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    Copy-Item $apkPath -Destination ".\MissionAlarm-v1.0.apk" -Force
    Write-Host "`n[BAŞARILI!] APK dosyanız hazır:" -ForegroundColor Green
    Write-Host "-> $(Join-Path (Get-Location) 'MissionAlarm-v1.0.apk')" -ForegroundColor White
}
