# build.ps1 - Script de compilación para pswm.exe
param(
    [switch]$Release,
    [switch]$Debug,
    [switch]$SkipTest
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "┌─────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│   psWinModel Reborn Agent — Build Script        │" -ForegroundColor Cyan
Write-Host "└─────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""

# Verificar que ps2exe está instalado
Write-Host "[1/4] Verificando dependencias..." -ForegroundColor Gray
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "      ps2exe no encontrado. Instalando desde PSGallery..." -ForegroundColor Yellow
    Install-Module -Name ps2exe -Scope CurrentUser -Force
    Write-Host "      ps2exe instalado correctamente." -ForegroundColor Green
} else {
    Write-Host "      ps2exe OK." -ForegroundColor DarkGray
}

# Crear directorio build si no existe
if (-not (Test-Path .\build)) {
    New-Item -ItemType Directory -Path .\build | Out-Null
    Write-Host "      Directorio .\build creado." -ForegroundColor DarkGray
}

# Parámetros de compilación
$buildVersion = ((Get-Date -Format 'yyyy.MM.dd.HHmm') + [math]::Floor((Get-Date).Second / 10).ToString())
$params = @{
    inputFile = ".\agent-core\pswm.ps1"
    outputFile = ".\build\pswm.exe"
    title = "psWinModel Reborn Agent"
    version = $buildVersion
    company = "psWinModel"
    product = "psWinModel Reborn Agent"
    copyright = ("(c) " + (Get-Date -Format 'yyyy'))
    noConsole = $false
    requireAdmin = $false
    verbose = $true
}

# Compilar
Write-Host "[2/4] Compilando agent-core\pswm.ps1 → build\pswm.exe  (versión $buildVersion)..." -ForegroundColor Yellow
Invoke-ps2exe @params

if (-not (Test-Path .\build\pswm.exe)) {
    Write-Host ""
    Write-Host "  ✗ Error: el archivo build\pswm.exe no fue generado." -ForegroundColor Red
    exit 1
}

Write-Host "      Compilación completada." -ForegroundColor DarkGray

# Pruebas post-compilación
if (-not $SkipTest) {
    Write-Host "[3/4] Verificando binario generado..." -ForegroundColor Gray
    Write-Host ""
    & .\build\pswm.exe version
    Write-Host ""
}

# Resumen final
Write-Host "[4/4] Calculando hashes y generando resumen..." -ForegroundColor Gray

$exeItem  = Get-Item .\build\pswm.exe
$exePath  = $exeItem.FullName
$exeBytes = $exeItem.Length
$exeMB    = [math]::Round($exeBytes / 1MB, 2)
$sha256   = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLower()
$md5      = (Get-FileHash -LiteralPath $exePath -Algorithm MD5).Hash.ToLower()

Write-Host ""
Write-Host "┌─────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "│   ✓ Build completado correctamente              │" -ForegroundColor Green
Write-Host "└─────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host ""
Write-Host "  Ruta    : $exePath" -ForegroundColor White
Write-Host "  Tamaño  : $exeMB MB  ($exeBytes bytes)" -ForegroundColor White
Write-Host "  SHA256  : $sha256" -ForegroundColor DarkGray
Write-Host "  MD5     : $md5" -ForegroundColor DarkGray
Write-Host ""
