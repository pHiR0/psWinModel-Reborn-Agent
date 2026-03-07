# deploy-admin.ps1 - Ejecutar como Administrador
$logFile = "C:\MyRepos\psWinModel-Reborn-Agent\deploy-admin.log"
"[$(Get-Date)] Iniciando deploy..." | Out-File $logFile

# 1. Detener servicio
Stop-Service pswm-reborn -Force -ErrorAction SilentlyContinue
Start-Sleep 3
"[$(Get-Date)] Servicio detenido" | Out-File $logFile -Append

# 2. Matar procesos pswm restantes
Get-Process -Name pswm,pswm_svc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
"[$(Get-Date)] Procesos terminados" | Out-File $logFile -Append

# 3. Eliminar lock file de tcping
$lockFile = 'C:\ProgramData\chocolatey\lib\4c3ccf29508aa172a66c4e8c7a041dd115462b3e'
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    "[$(Get-Date)] Lock file de tcping eliminado" | Out-File $logFile -Append
} else {
    "[$(Get-Date)] Lock file no encontrado (ya limpio)" | Out-File $logFile -Append
}

# 4. Eliminar build/pswm.exe si existe para desbloquear
$buildExe = "C:\MyRepos\psWinModel-Reborn-Agent\build\pswm.exe"
if (Test-Path $buildExe) {
    Remove-Item $buildExe -Force -ErrorAction SilentlyContinue
    "[$(Get-Date)] build\pswm.exe eliminado" | Out-File $logFile -Append
}

# 5. Build
Set-Location C:\MyRepos\psWinModel-Reborn-Agent
$buildResult = & .\build.ps1 2>&1
$buildResult | Out-File $logFile -Append
"[$(Get-Date)] Build completado, exit: $LASTEXITCODE" | Out-File $logFile -Append

# 6. Deploy a Program Files
if (Test-Path $buildExe) {
    Copy-Item $buildExe 'C:\Program Files\pswm-reborn\pswm.exe' -Force
    Copy-Item $buildExe 'C:\Program Files\pswm-reborn\pswm_svc.exe' -Force
    "[$(Get-Date)] Binarios copiados a Program Files" | Out-File $logFile -Append
} else {
    "[$(Get-Date)] ERROR: build\pswm.exe no generado" | Out-File $logFile -Append
}

# 7. Iniciar servicio
Start-Service pswm-reborn
"[$(Get-Date)] Servicio iniciado: $($(Get-Service pswm-reborn).Status)" | Out-File $logFile -Append
"[$(Get-Date)] DEPLOY COMPLETADO" | Out-File $logFile -Append
