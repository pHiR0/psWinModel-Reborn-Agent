# build.ps1 - Script de compilación para pswm.exe
param(
    [switch]$Release,
    [switch]$Debug,
    [switch]$SkipTest
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "+---------------------------------------------------+" -ForegroundColor Cyan
Write-Host "|   psWinModel Reborn Agent - Build Script          |" -ForegroundColor Cyan
Write-Host "+---------------------------------------------------+" -ForegroundColor Cyan
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

# Leer URL de servidor desde build-config.json si existe en el mismo directorio
$buildConfigPath = Join-Path $PSScriptRoot "build-config.json"
$buildDefaultServerUrl = $null
if (Test-Path $buildConfigPath) {
    try {
        $buildConfig = Get-Content $buildConfigPath -Raw | ConvertFrom-Json
        if ($buildConfig.PSObject.Properties['serverUrl'] -and $buildConfig.serverUrl) {
            $buildDefaultServerUrl = $buildConfig.serverUrl
            Write-Host "      build-config.json encontrado, URL del servidor: $buildDefaultServerUrl" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "      [WARN] Error leyendo build-config.json: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "      No se encontro build-config.json, se usara la URL por defecto (http://localhost:3000)." -ForegroundColor DarkGray
}

# Si hay URL personalizada, generar una copia temporal de pswm.ps1 con la URL hardcodeada
$sourceScript = ".\agent-core\pswm.ps1"
$tempScript   = $null
if ($buildDefaultServerUrl) {
    $tempScript   = ".\agent-core\_pswm_build_temp.ps1"
    $content = Get-Content $sourceScript -Raw -Encoding utf8
    # Reemplaza la linea "  return "http://localhost:3000"" dentro de Get-ServerUrl
    $oldLine = '  return "http://localhost:3000"'
    $newLine = "  return `"$buildDefaultServerUrl`""
    if ($content.Contains($oldLine)) {
        $content = $content.Replace($oldLine, $newLine)
        [System.IO.File]::WriteAllText((Resolve-Path ".\agent-core").Path + "\_pswm_build_temp.ps1", $content, [System.Text.Encoding]::UTF8)
        Write-Host "      URL hardcodeada en script temporal: $buildDefaultServerUrl" -ForegroundColor Green
        $sourceScript = $tempScript
    } else {
        Write-Host "      [WARN] No se encontro la linea de URL por defecto en pswm.ps1, se usara la URL original." -ForegroundColor Yellow
        $tempScript = $null
    }
}

$params = @{
    inputFile = $sourceScript
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

# Use icon if available
$icoPath = Join-Path $PSScriptRoot "build\pswm.ico"
if (Test-Path $icoPath) {
    $params['iconFile'] = $icoPath
    Write-Host "      Usando icono: $icoPath" -ForegroundColor Cyan
} else {
    Write-Host "      [INFO] No se encontro build\pswm.ico, compilando sin icono." -ForegroundColor DarkGray
}

# Compilar
Write-Host "[2/4] Compilando $sourceScript -> build\pswm.exe  (version $buildVersion)..." -ForegroundColor Yellow
Invoke-ps2exe @params

# Eliminar script temporal si se creó
if ($tempScript -and (Test-Path $tempScript)) {
    Remove-Item $tempScript -Force
    Write-Host "      Script temporal eliminado." -ForegroundColor DarkGray
}

if (-not (Test-Path .\build\pswm.exe)) {
    Write-Host ""
    Write-Host "  [ERROR] El archivo build\pswm.exe no fue generado." -ForegroundColor Red
    exit 1
}

Write-Host "      Compilacion completada." -ForegroundColor DarkGray

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
Write-Host "+---------------------------------------------------+" -ForegroundColor Green
Write-Host "|   [OK] Build completado correctamente             |" -ForegroundColor Green
Write-Host "+---------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  Ruta    : $exePath" -ForegroundColor White
Write-Host "  Tamano  : $exeMB MB  ($exeBytes bytes)" -ForegroundColor White
Write-Host "  SHA256  : $sha256" -ForegroundColor DarkGray
Write-Host "  MD5     : $md5" -ForegroundColor DarkGray
Write-Host ""
