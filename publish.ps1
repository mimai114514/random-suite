$ErrorActionPreference = "Stop"

$rootDir = (Get-Item ..).FullName
$timestamp = Get-Date -Format "yyMMddHHmm"
$releaseDir = "$rootDir\Release\$timestamp"

if (-Not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building Random_FloatingTool (FT)     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Set-Location "$rootDir\Random_FloatingTool\Random_FloatingTool"
dotnet publish -c Release
if ($LASTEXITCODE -ne 0) {
    Write-Host "FT Build Failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}
$ftPublishDir = "$rootDir\Random_FloatingTool\Random_FloatingTool\bin\Release\net8.0-windows10.0.19041.0\publish"
if (Test-Path $ftPublishDir) {
    Compress-Archive -Path "$ftPublishDir\*" -DestinationPath "$releaseDir\FT.zip" -Force
    Write-Host "FT packaged to $releaseDir\FT.zip" -ForegroundColor Green
} else {
    Write-Host "FT publish directory not found!" -ForegroundColor Yellow
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
$desktopPublishDir = "$rootDir\random-desktop\build\windows\x64\runner\Release"
if (Test-Path $desktopPublishDir) {
    Compress-Archive -Path "$desktopPublishDir\*" -DestinationPath "$releaseDir\desktop.zip" -Force
    Write-Host "Desktop packaged to $releaseDir\desktop.zip" -ForegroundColor Green
} else {
    Write-Host "Desktop publish directory not found!" -ForegroundColor Yellow
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

$installerOutDir = "$rootDir\Output"
if (Test-Path $installerOutDir) {
    Copy-Item -Path "$installerOutDir\*" -Destination $releaseDir -Force
    Write-Host "Installer copied to $releaseDir" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "  All tasks completed successfully!     " -ForegroundColor Green
Write-Host "  All artifacts are located in $releaseDir" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
