# Compilar pswm.exe - Guía Rápida

## Requisitos

- PowerShell 5.1 o superior
- Módulo `ps2exe` (para compilar scripts PowerShell a ejecutables)

## Instalación de ps2exe

```powershell
# Instalar ps2exe desde PowerShell Gallery
Install-Module -Name ps2exe -Scope CurrentUser

# O si ya lo tienes, actualizarlo
Update-Module -Name ps2exe
```

## Compilación Básica

Desde el directorio raíz del repositorio del agente:

```powershell
# Compilar pswm.ps1 a pswm.exe
Invoke-ps2exe -inputFile .\agent-core\pswm.ps1 -outputFile .\build\pswm.exe -noConsole:$false

# Con opciones de versión y metadatos
Invoke-ps2exe -inputFile .\agent-core\pswm.ps1 `
              -outputFile .\build\pswm.exe `
              -title "psWinModel Reborn Agent" `
              -version "0.1.0.0" `
              -company "psWinModel" `
              -product "psWinModel Reborn Agent" `
              -copyright "(c) 2026" `
              -noConsole:$false `
              -requireAdmin:$false
```

## Opciones de Compilación

### Modo de Consola

```powershell
# Con ventana de consola (recomendado para MVP/testing)
-noConsole:$false

# Sin ventana de consola (para servicio background)
-noConsole:$true
```

### Requerir Administrador

```powershell
# Requerir elevación (para instalación de servicio)
-requireAdmin:$true

# No requerir elevación (para comandos de usuario)
-requireAdmin:$false
```

### Icono y Recursos

```powershell
# Agregar icono personalizado
-iconFile .\tray-icon\pswm.ico

# Incluir archivos adicionales
-STA  # Single-threaded apartment (para GUI/COM)
```

## Script de Compilación Completo

Crear archivo `build.ps1` en la raíz del repo:

```powershell
# build.ps1 - Script de compilación para pswm.exe
param(
    [switch]$Release,
    [switch]$Debug
)

$ErrorActionPreference = 'Stop'

# Crear directorio build si no existe
if (-not (Test-Path .\build)) {
    New-Item -ItemType Directory -Path .\build | Out-Null
}

# Parámetros base
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
Write-Host "Compilando pswm.exe..." -ForegroundColor Cyan
Invoke-ps2exe @params

if (Test-Path .\build\pswm.exe) {
    $size = (Get-Item .\build\pswm.exe).Length / 1MB
    Write-Host "✓ Compilación exitosa: .\build\pswm.exe ($([math]::Round($size, 2)) MB)" -ForegroundColor Green
    
    # Mostrar versión
    Write-Host "`nProbando ejecutable..." -ForegroundColor Cyan
    & .\build\pswm.exe version
} else {
    Write-Error "Error: No se generó el ejecutable"
}
```

## Pruebas Post-Compilación

```powershell
# 1. Verificar que el ejecutable se creó
Test-Path .\build\pswm.exe

# 2. Probar comando version
.\build\pswm.exe version

# 3. Probar comando help
.\build\pswm.exe help

# 4. Probar view_config (mostrará error si no hay config aún)
.\build\pswm.exe view_config

# 5. Probar check_status
.\build\pswm.exe check_status

# 6. Probar generación de certificados
.\build\pswm.exe gencert

# 7. Probar registro (requiere servidor corriendo)
.\build\pswm.exe reg_init_check -ServerUrl http://localhost:3000
```

## Estructura de Salida

```
build/
  pswm.exe           # Ejecutable compilado
  pswm.pdb           # Símbolos de depuración (opcional)
```

## Datos en Ejecución

El ejecutable creará/usará:

```
C:\ProgramData\pswm-reborn\
  config.json          # Configuración (queue_id, agent_id)
  agent_public.pem     # Clave pública RSA
  agent_private.pem    # Clave privada RSA
```

## Troubleshooting

### Error: "Invoke-ps2exe no reconocido"

```powershell
# Verificar instalación
Get-Module -ListAvailable ps2exe

# Re-instalar
Install-Module ps2exe -Force -Scope CurrentUser
```

### Error: "Script no firmado"

```powershell
# Permitir ejecución temporal
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Ejecutable muy grande

- El tamaño típico es 3-6 MB (incluye runtime de PowerShell)
- Para reducir: usar `-noConfig:$true` si no necesitas config XML
- Considerar UPX para comprimir (opcional, puede causar falsos positivos en antivirus)

## Distribución

Para distribuir el ejecutable:

1. **Sin firma**: Copiar `pswm.exe` directamente
2. **Con firma digital**: Firmar con `signtool.exe` y certificado code signing

```powershell
# Firmar con certificado (requiere certificado válido)
signtool sign /f "mi-cert.pfx" /p "password" /t http://timestamp.digicert.com .\build\pswm.exe
```

## Próximos Pasos (Post-MVP)

- [ ] Agregar icono personalizado
- [ ] Compilar versiones firmadas digitalmente
- [ ] Crear instalador MSI/NSIS
- [ ] Incluir servicio Windows (`pswm install_service`)
- [ ] Build automatizado con CI/CD
