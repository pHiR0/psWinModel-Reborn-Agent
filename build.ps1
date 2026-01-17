# build.ps1 - Script de compilación para pswm.exe
param(
    [switch]$Release,
    [switch]$Debug,
    [switch]$SkipTest
)

$ErrorActionPreference = 'Stop'

Write-Host "`n=== psWinModel Reborn Agent - Build Script ===" -ForegroundColor Cyan
Write-Host "Compilando pswm.ps1 a pswm.exe...`n" -ForegroundColor Cyan

# Verificar que ps2exe está instalado
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "ps2exe no está instalado. Instalando..." -ForegroundColor Yellow
    Install-Module -Name ps2exe -Scope CurrentUser -Force
    Write-Host "ps2exe instalado correctamente" -ForegroundColor Green
}

# Crear directorio build si no existe
if (-not (Test-Path .\build)) {
    New-Item -ItemType Directory -Path .\build | Out-Null
    Write-Host "Directorio .\build creado" -ForegroundColor Gray
}

# Parámetros de compilación
$params = @{
    inputFile = ".\agent-core\pswm.ps1"
    outputFile = ".\build\pswm.exe"
    title = "psWinModel Reborn Agent"
    version = "0.1.0.0"
    company = "psWinModel"
    product = "psWinModel Reborn Agent"
    copyright = "(c) 2026"
    noConsole = $false
    requireAdmin = $false
    verbose = $true
}

# Compilar
Write-Host "Compilando con ps2exe..." -ForegroundColor Yellow
Invoke-ps2exe @params

if (Test-Path .\build\pswm.exe) {
    $size = (Get-Item .\build\pswm.exe).Length / 1MB
    Write-Host "`n✓ Compilación exitosa: .\build\pswm.exe" -ForegroundColor Green
    Write-Host "  Tamaño: $([math]::Round($size, 2)) MB" -ForegroundColor Gray
} else {
    Write-Host "`n✗ Error: El archivo pswm.exe no fue generado" -ForegroundColor Red
    exit 1
}

# Pruebas post-compilación
if (-not $SkipTest) {
    Write-Host "`n=== Ejecutando pruebas básicas ===" -ForegroundColor Cyan
    
    Write-Host "`n1. Probando 'pswm.exe version':" -ForegroundColor Yellow
    & .\build\pswm.exe version
    
    Write-Host "`n2. Probando 'pswm.exe help':" -ForegroundColor Yellow
    & .\build\pswm.exe help
    
    Write-Host "`n✓ Pruebas básicas completadas" -ForegroundColor Green
}

Write-Host "`n=== Build completado ===" -ForegroundColor Cyan
Write-Host @"

Ejecutable generado: .\build\pswm.exe

Comandos disponibles:
  .\build\pswm.exe version          - Mostrar versión
  .\build\pswm.exe help             - Mostrar ayuda
  .\build\pswm.exe check_status     - Verificar estado
  .\build\pswm.exe view_config      - Ver configuración
  .\build\pswm.exe gencert          - Generar certificados
  .\build\pswm.exe reg_init_check   - Registrar agente

Para más información, consulta: .\docs\compilar_pswm.md

"@ -ForegroundColor White
