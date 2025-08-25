
# build_installer.ps1
# Usage:
#   1) Extract tauri_native_ocr_project.zip
#   2) Copy this script into the project folder (same level as package.json) — already included.
#   3) Right-click "Run with PowerShell" (or run: powershell -ExecutionPolicy Bypass -File .\build_installer.ps1)

param(
  [switch]$NoInstall # skip installing prerequisites
)

function Ensure-Cmd($cmd) {
  $exists = Get-Command $cmd -ErrorAction SilentlyContinue
  return $null -ne $exists
}

Write-Host "=== Tauri Native OCR – Auto builder ===" -ForegroundColor Cyan

# 0) Move to script directory
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not $NoInstall) {
  # 1) Install prerequisites via winget (Node LTS, Rustup, NSIS)
  if (-not (Ensure-Cmd "winget")) {
    Write-Host "winget not found. Please update to the latest Windows 10/11 or install prerequisites manually." -ForegroundColor Yellow
  } else {
    Write-Host "Installing Node.js LTS..." -ForegroundColor Green
    winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements || Write-Host "Node install skipped/failed." -ForegroundColor Yellow

    Write-Host "Installing Rustup..." -ForegroundColor Green
    winget install -e --id Rustlang.Rustup --accept-package-agreements --accept-source-agreements || Write-Host "Rustup install skipped/failed." -ForegroundColor Yellow

    Write-Host "Installing NSIS..." -ForegroundColor Green
    winget install -e --id NSIS.NSIS --accept-package-agreements --accept-source-agreements || Write-Host "NSIS install skipped/failed." -ForegroundColor Yellow
  }

  # Ensure PATH refreshed for current session
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")

  # 2) Install Tauri CLI
  if (-not (Ensure-Cmd "cargo")) {
    Write-Host "Rust/Cargo not available yet. Please open a NEW PowerShell window and rerun this script after Rustup finishes." -ForegroundColor Red
    exit 1
  }
  if (-not (Ensure-Cmd "tauri")) {
    Write-Host "Installing Tauri CLI..." -ForegroundColor Green
    cargo install tauri-cli || (Write-Host "Failed to install tauri-cli" -ForegroundColor Red; exit 1)
  }
}

# 3) Node dependencies
if (-not (Test-Path "package.json")) {
  Write-Host "package.json not found. Please run this script inside the project folder." -ForegroundColor Red
  exit 1
}

Write-Host "Installing npm dependencies..." -ForegroundColor Green
npm install || (Write-Host "npm install failed." -ForegroundColor Red; exit 1)

# 4) Fetch offline models (eng/vie) + wasm core/worker into resources
Write-Host "Fetching OCR models & core (offline resources)..." -ForegroundColor Green
npm run fetch-models || (Write-Host "fetch-models failed." -ForegroundColor Red; exit 1)

# 5) Build .exe installer
Write-Host "Building NSIS installer..." -ForegroundColor Green
npm run build || (Write-Host "tauri build failed." -ForegroundColor Red; exit 1)

# 6) Locate output
$bundle = Get-ChildItem -Path "src-tauri\target\release\bundle\nsis" -Filter "*setup*.exe" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($bundle) {
  Write-Host ("SUCCESS: " + $bundle.FullName) -ForegroundColor Cyan
} else {
  Write-Host "Build finished, but installer not found. Check src-tauri\target\release\bundle\nsis" -ForegroundColor Yellow
}
