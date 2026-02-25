$ErrorActionPreference = "Stop"

$rootDir = (Get-Item ..).FullName

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Random_FloatingTool (FT)     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Set-Location "$rootDir\Random_FloatingTool\Random_FloatingTool"
dotnet publish -c Release
if ($LASTEXITCODE -ne 0) {
    Write-Host "FT Build Failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building random-desktop               " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Set-Location "$rootDir\random-desktop"
flutter build windows
if ($LASTEXITCODE -ne 0) {
    Write-Host "Desktop Build Failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Installer with Inno Setup    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Set-Location "$rootDir\random-suite"

$isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-Not (Test-Path $isccPath)) {
    Write-Host "ISCC.exe not found. Please ensure Inno Setup 6 is installed." -ForegroundColor Red
    exit 1
}

& $isccPath "installer.iss"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installer Build Failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "  All tasks completed successfully!     " -ForegroundColor Green
Write-Host "  Installer is located in Output dir.   " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
