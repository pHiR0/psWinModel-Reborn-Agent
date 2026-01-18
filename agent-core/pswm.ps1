<#
.SYNOPSIS
  psWinModel Reborn Agent - CLI principal

.DESCRIPTION
  Comandos disponibles:
    reg_init_check  - Registrar agente vía Cola de Aprobación (si no hay agent_id)
    check_status    - Verificar conectividad y estado del agente
    view_config     - Mostrar configuración actual
    gencert         - Generar/regenerar par de claves RSA
    archive_config  - Archivar config y claves en ZIP y eliminar originales (uso: archive_config "NAME")
    restore_config  - Restaurar una configuración archivada (uso: restore_config "NAME")
    version         - Mostrar versión del agente
    help            - Mostrar ayuda

.EXAMPLE
  pswm.exe reg_init_check
  pswm.exe check_status
  pswm.exe view_config
#>

param(
  [Parameter(Position=0)]
  [string]$Command = "help",
  
  [string]$ServerUrl = $null,
  [Parameter(Position=1)]
  [string]$Arg1 = $null,
  [string]$OutDir = "$env:ProgramData\pswm-reborn",
  [int]$KeySize = 2048,
  [int]$PollIntervalSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuración
$script:Version = "0.1.0-mvp"
$script:ConfigPath = Join-Path $OutDir "config.json"
$script:PrivateKeyPath = Join-Path $OutDir "agent_private.pem"
$script:PublicKeyPath = Join-Path $OutDir "agent_public.pem"

# Detectar PowerShell version
$script:UseLegacyRsa = $PSVersionTable.PSVersion.Major -lt 7
#endregion

#region Helper Functions

function Write-Info([string]$msg) {
  Write-Host "[INFO] $msg" -ForegroundColor Cyan
}

function Write-Success([string]$msg) {
  Write-Host "[OK] $msg" -ForegroundColor Green
}

function Write-Err([string]$msg) {
  Write-Host "[ERROR] $msg" -ForegroundColor Red
}

function Get-Config {
  if (-not (Test-Path $script:ConfigPath)) { return $null }
  try {
    return Get-Content -Raw -Path $script:ConfigPath | ConvertFrom-Json
  } catch {
    Write-Err "Error leyendo config.json: $_"
    return $null
  }
}

function Save-Config([hashtable]$cfg) {
  $cfg | ConvertTo-Json -Depth 5 | Out-File -FilePath $script:ConfigPath -Encoding utf8 -Force
}

function Get-ServerUrl {
  if ($ServerUrl) { return $ServerUrl }
  $cfg = Get-Config
  if ($cfg -and $cfg.PSObject.Properties['server_url']) { return $cfg.server_url }
  return "http://localhost:3000"
}

function Test-ServerReachable([string]$url) {
  try {
    $u = [uri]$url
    $h = $u.Host
    $p = if ($u.Port -gt 0) { $u.Port } else { if ($u.Scheme -eq 'https') { 443 } else { 80 } }
    $r = Test-NetConnection -ComputerName $h -Port $p -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    return $r.TcpTestSucceeded
  } catch {
    return $false
  }
}

function Wrap-Base64($s) {
  $out = ""
  for ($i=0; $i -lt $s.Length; $i += 64) {
    $len = [Math]::Min(64, $s.Length - $i)
    $out += $s.Substring($i, $len) + "`n"
  }
  return $out.TrimEnd("`n")
}

#endregion

#region Key Generation

function New-RsaKeyPairPem([int]$bits, [string]$privatePath, [string]$publicPath) {
  if (-not $script:UseLegacyRsa) {
    $rsa = [System.Security.Cryptography.RSA]::Create($bits)
    try {
      $priv = $rsa.ExportRSAPrivateKey()
      $pub = $rsa.ExportSubjectPublicKeyInfo()

      $privB64 = [System.Convert]::ToBase64String($priv)
      $pubB64 = [System.Convert]::ToBase64String($pub)

      $privPem = "-----BEGIN RSA PRIVATE KEY-----`n" + (Wrap-Base64 $privB64) + "`n-----END RSA PRIVATE KEY-----`n"
      $pubPem = "-----BEGIN PUBLIC KEY-----`n" + (Wrap-Base64 $pubB64) + "`n-----END PUBLIC KEY-----`n"

      New-Item -ItemType Directory -Force -Path (Split-Path $privatePath) | Out-Null
      $privPem | Out-File -FilePath $privatePath -Encoding ascii -Force
      $pubPem | Out-File -FilePath $publicPath -Encoding ascii -Force

      return @{ private = $privatePath; public = $publicPath }
    } finally {
      $rsa.Dispose()
    }
  } else {
    # Legacy implementation para PowerShell 5.1
    $csp = New-Object System.Security.Cryptography.RSACryptoServiceProvider($bits)
    try {
      $parameters = $csp.ExportParameters($true)

      function TrimLeadingZero([byte[]]$b) {
        if ($b.Length -gt 1 -and $b[0] -eq 0) {
          $result = New-Object 'byte[]' ($b.Length - 1)
          [Array]::Copy($b, 1, $result, 0, $b.Length - 1)
          return $result
        }
        return $b
      }

      function EncodeLength([int]$len) {
        if ($len -lt 0x80) { $arr = New-Object 'System.Byte[]' 1; $arr[0] = [byte]$len; return $arr }
        $tmp = New-Object 'System.Collections.Generic.List[byte]'
        while ($len -gt 0) { $tmp.Add([byte]($len -band 0xff)); $len = $len -shr 8 }
        [void]$tmp.Reverse()
        $out = New-Object 'System.Collections.Generic.List[byte]'
        $out.Add([byte](0x80 -bor $tmp.Count))
        foreach ($b2 in $tmp) { $out.Add($b2) }
        return $out.ToArray()
      }

      function EncodeInteger([byte[]]$bytes) {
        $b = TrimLeadingZero $bytes
        $list = New-Object 'System.Collections.Generic.List[byte]'
        if (($b[0] -band 0x80) -ne 0) { [void]$list.Add([byte]0) }
        foreach ($bb in $b) { [void]$list.Add($bb) }
        $lenEnc = EncodeLength($list.Count)
        $out = New-Object 'System.Collections.Generic.List[byte]'
        [void]$out.Add([byte]0x02)
        foreach ($b2 in $lenEnc) { [void]$out.Add($b2) }
        foreach ($b2 in $list) { [void]$out.Add($b2) }
        return $out.ToArray()
      }

      function BuildSequence([byte[][]]$parts) {
        $bodyList = New-Object 'System.Collections.Generic.List[byte]'
        foreach ($p in $parts) { foreach ($b2 in $p) { $bodyList.Add($b2) } }
        $body = $bodyList.ToArray()
        $lenEnc = EncodeLength($body.Length)
        $seq = New-Object 'System.Collections.Generic.List[byte]'
        $seq.Add([byte]0x30)
        foreach ($b2 in $lenEnc) { $seq.Add($b2) }
        foreach ($b2 in $body) { $seq.Add($b2) }
        return $seq.ToArray()
      }

      $n = $parameters.Modulus
      $e = $parameters.Exponent
      $pubparts = @((EncodeInteger $n),(EncodeInteger $e))
      $rsapubseq = BuildSequence($pubparts)

      $bitList = New-Object 'System.Collections.Generic.List[byte]'
      $bitList.Add([byte]0x03)
      $lenEnc = EncodeLength($rsapubseq.Length + 1)
      foreach ($b2 in $lenEnc) { $bitList.Add($b2) }
      $bitList.Add([byte]0x00)
      foreach ($b2 in $rsapubseq) { $bitList.Add($b2) }
      $bitstring = $bitList.ToArray()

      $oid = [byte[]](0x06,0x09,0x2A,0x86,0x48,0x86,0xF7,0x0D,0x01,0x01,0x01)
      $algList = New-Object 'System.Collections.Generic.List[byte]'
      $algList.Add([byte]0x30)
      $algBodyLen = $oid.Length + 2
      foreach ($b2 in (EncodeLength $algBodyLen)) { $algList.Add($b2) }
      foreach ($b2 in $oid) { $algList.Add($b2) }
      $algList.Add([byte]0x05)
      $algList.Add([byte]0x00)
      $alg = $algList.ToArray()

      $spki = BuildSequence(@($alg,$bitstring))

      $pubB64 = [System.Convert]::ToBase64String($spki)
      $pubPem = "-----BEGIN PUBLIC KEY-----`n" + (Wrap-Base64 $pubB64) + "`n-----END PUBLIC KEY-----`n"

      $privXml = $csp.ToXmlString($true)

      New-Item -ItemType Directory -Force -Path (Split-Path $privatePath) | Out-Null
      $privXml | Out-File -FilePath $privatePath -Encoding utf8 -Force
      $pubPem | Out-File -FilePath $publicPath -Encoding ascii -Force

      return @{ private = $privatePath; public = $publicPath }
    } finally {
      $csp.Dispose()
    }
  }
}

#endregion

#region API Functions

function Invoke-QueuePost([string]$serverUrl, [string]$hostname, [string]$publicKeyPath) {
  $pub = Get-Content -Raw -Path $publicKeyPath
  $os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
  $facts = @{ os = $os; user = $env:USERNAME; hostname = $hostname }
  $payload = @{ hostname = $hostname; public_key = $pub; facts = $facts } | ConvertTo-Json -Depth 5 -Compress
  $uri = "$serverUrl/api/agents/queue"
  
  try {
    return Invoke-RestMethod -Uri $uri -Method Post -Body $payload -ContentType 'application/json' -ErrorAction Stop
  } catch {
    Write-Err "Error POST queue: $_"
    throw $_
  }
}

function Get-QueueStatus([string]$serverUrl, [int]$id) {
  $uri = "$serverUrl/api/agents/queue/$id/status"
  try {
    return Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
  } catch {
    return $null
  }
}

#endregion

#region Commands

function Invoke-RegInitCheck {
  Write-Info "Ejecutando reg_init_check..."
  
  if (-not (Test-Path $OutDir)) { 
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null 
    Write-Info "Directorio creado: $OutDir"
  }

  $cfg = Get-Config
  if ($cfg -and $cfg.PSObject.Properties['agent_id'] -and $cfg.agent_id) {
    Write-Success "Agente ya registrado con agent_id: $($cfg.agent_id)"
    Write-Host "Ruta config: $script:ConfigPath"
    exit 0
  }

  $srvUrl = Get-ServerUrl
  Write-Info "Server URL: $srvUrl"
  
  if (-not (Test-ServerReachable $srvUrl)) {
    Write-Err "Servidor no accesible: $srvUrl"
    exit 2
  }
  Write-Success "Servidor accesible"

  # Generar claves si no existen
  if (-not (Test-Path $script:PublicKeyPath) -or -not (Test-Path $script:PrivateKeyPath)) {
    Write-Info "Generando par de claves RSA ($KeySize bits)..."
    $kp = New-RsaKeyPairPem -bits $KeySize -privatePath $script:PrivateKeyPath -publicPath $script:PublicKeyPath
    Write-Success "Claves generadas en: $OutDir"
  } else {
    Write-Info "Usando claves existentes"
  }

  # Si ya hay queue_id en config, reutilizarlo
  $qid = $null
  if ($cfg -and $cfg.PSObject.Properties['queue_id'] -and $cfg.queue_id) {
    $qid = [int]$cfg.queue_id
    Write-Info "Usando queue_id existente: $qid"
  } else {
    # Crear nueva entrada en la cola
    try {
      $postRes = Invoke-QueuePost -serverUrl $srvUrl -hostname $env:COMPUTERNAME -publicKeyPath $script:PublicKeyPath
      $qid = $postRes.id
      Write-Success "Entrada creada en la cola con ID: $qid"
      
      # Persistir queue_id
      $newCfg = @{
        queue_id = $qid
        hostname = $env:COMPUTERNAME
        server_url = $srvUrl
        created_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      }
      Save-Config $newCfg
      Write-Info "Queue ID guardado en config"
    } catch {
      Write-Err "Error al crear entrada en la cola: $_"
      exit 3
    }
  }

  # Polling
  Write-Info "Polling cada $PollIntervalSeconds segundos (Ctrl+C para cancelar)..."
  try {
    $iterations = 0
    while ($true) {
      Start-Sleep -Seconds $PollIntervalSeconds
      $iterations++
      $st = Get-QueueStatus -serverUrl $srvUrl -id $qid
      if (-not $st) { 
        Write-Host "." -NoNewline
        continue 
      }
      
      Write-Host ""  # nueva línea
      Write-Info "Status: $($st.status) (iteración $iterations)"
      
      if ($st.status -eq 'approved') {
        Write-Success "¡Aprobado! Agent ID: $($st.agent_id)"
        
        # Actualizar config con agent_id
        $finalCfg = @{
          agent_id = $st.agent_id
          hostname = $env:COMPUTERNAME
          server_url = $srvUrl
          approved_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        Save-Config $finalCfg
        Write-Success "Configuración guardada en: $script:ConfigPath"
        exit 0
      }
      elseif ($st.status -eq 'rejected') {
        $msg = if ($st.rejection_message) { $st.rejection_message } else { "Sin mensaje" }
        Write-Err "Entrada rechazada: $msg"
        exit 4
      }
    }
  } catch {
    Write-Err "Error durante polling: $_"
    exit 1
  }
}

function Invoke-CheckStatus {
  Write-Info "Verificando estado del agente..."
  
  $cfg = Get-Config
  if (-not $cfg) {
    Write-Err "No se encontró archivo de configuración en: $script:ConfigPath"
    Write-Info "Ejecute 'pswm.exe reg_init_check' para registrar el agente"
    exit 3
  }

  Write-Host "`n=== Estado del Agente ===" -ForegroundColor Yellow
  
  $agentId = if ($cfg.PSObject.Properties['agent_id']) { $cfg.agent_id } else { $null }
  $queueId = if ($cfg.PSObject.Properties['queue_id']) { $cfg.queue_id } else { $null }
  
  if ($agentId) {
    Write-Success "Agent ID: $agentId"
  } else {
    Write-Host "Agent ID: No registrado aún" -ForegroundColor Yellow
    if ($queueId) {
      Write-Info "Queue ID: $queueId (pendiente de aprobación)"
    }
  }

  $srvUrl = Get-ServerUrl
  Write-Host "Server URL: $srvUrl"

  $reachable = Test-ServerReachable $srvUrl
  if (-not $reachable) {
    Write-Err "Servidor: No accesible"
    exit 2
  }
  Write-Success "Servidor: Accesible"

  Write-Host "`n=== Archivos ===" -ForegroundColor Yellow
  Write-Host "Config: $script:ConfigPath $(if (Test-Path $script:ConfigPath) { '[OK]' } else { '[NO]' })"
  Write-Host "Public Key: $script:PublicKeyPath $(if (Test-Path $script:PublicKeyPath) { '[OK]' } else { '[NO]' })"
  Write-Host "Private Key: $script:PrivateKeyPath $(if (Test-Path $script:PrivateKeyPath) { '[OK]' } else { '[NO]' })"

  # Decide exit code: 0 = registered, 4 = pending approval, 0 also for present but no agent_id? Use pending for queue_id
  $agentId = if ($cfg.PSObject.Properties['agent_id']) { $cfg.agent_id } else { $null }
  $queueId = if ($cfg.PSObject.Properties['queue_id']) { $cfg.queue_id } else { $null }
  if ($agentId) {
    exit 0
  } elseif ($queueId) {
    exit 4
  } else {
    exit 1
  }
}

function Invoke-ViewConfig {
  Write-Info "Configuración actual:"
  
  if (-not (Test-Path $script:ConfigPath)) {
    Write-Err "No se encontró archivo de configuración: $script:ConfigPath"
    exit 1
  }

  Write-Host "`n=== $script:ConfigPath ===" -ForegroundColor Yellow
  Get-Content -Raw -Path $script:ConfigPath | Write-Host
  exit 0
}

function Invoke-ArchiveConfig([string]$Name) {
  Write-Info "Archiving local config to ZIP..."
  if (-not $Name -or $Name.Trim().Length -eq 0) {
    Write-Err "Nombre requerido: pswm.exe archive_config \"NAME\""
    exit 1
  }

  if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
  $archiveDir = Join-Path $OutDir 'config_archive'
  if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null }

  # Sanitize name for filename
  $invalid = [IO.Path]::GetInvalidFileNameChars() -join ''
  $safeName = -join ($Name.ToCharArray() | ForEach-Object { if ($invalid -contains $_) { '_' } else { $_ } })
  if (-not $safeName) { $safeName = "archive_$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
  $zipPath = Join-Path $archiveDir ($safeName + '.zip')

  # Collect files from OutDir (top-level files)
  $files = Get-ChildItem -Path $OutDir -File | Where-Object { $_.DirectoryName -eq (Get-Item $OutDir).FullName } | Select-Object -ExpandProperty FullName
  if (-not $files -or $files.Count -eq 0) {
    Write-Err "No se encontraron archivos en $OutDir para archivar"
    exit 1
  }

  try {
    if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
    Compress-Archive -Path $files -DestinationPath $zipPath -Force
    Write-Success "Archivado creado en: $zipPath"
  } catch {
    Write-Err "Error al crear el ZIP: $_"
    exit 1
  }

  # Remove originals after successful archive
  try {
    foreach ($f in $files) { Remove-Item -Path $f -Force }
    Write-Success "Archivos originales eliminados desde: $OutDir"
  } catch {
    Write-Err "Error al eliminar archivos originales: $_"
    exit 1
  }

  exit 0
}

function Invoke-RestoreConfig([string]$Name) {
  Write-Info "Restaurando configuración desde archivo..."
  if (-not $Name -or $Name.Trim().Length -eq 0) {
    Write-Err "Nombre requerido: pswm.exe restore_config \"NAME\""
    exit 1
  }

  if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
  $archiveDir = Join-Path $OutDir 'config_archive'
  if (-not (Test-Path $archiveDir)) {
    Write-Err "No existe carpeta de archivos archivados: $archiveDir"
    exit 1
  }

  # Ensure target dir has no config or keys
  $confExists = Test-Path (Join-Path $OutDir 'config.json')
  $pubExists = Test-Path (Join-Path $OutDir 'agent_public.pem')
  $privExists = Test-Path (Join-Path $OutDir 'agent_private.pem')
  if ($confExists -or $pubExists -or $privExists) {
    Write-Err "Hay archivos de configuración o certificados existentes en $OutDir. Abortar restauración."
    Write-Host "Archivos detectados: $(@(if ($confExists) { 'config.json' } else { }), (if ($pubExists) { 'agent_public.pem' } else { }), (if ($privExists) { 'agent_private.pem' } else { }) )" -ForegroundColor Yellow
    exit 1
  }

  # Locate zip
  $safeName = $Name
  $zipPath = Join-Path $archiveDir ($safeName + '.zip')
  if (-not (Test-Path $zipPath)) {
    Write-Err "Archivo de backup no encontrado: $zipPath"
    exit 1
  }

  try {
    Expand-Archive -Path $zipPath -DestinationPath $OutDir -Force
    Write-Success "Restauración completada: archivos extraídos a $OutDir"
  } catch {
    Write-Err "Error al extraer el ZIP: $_"
    exit 1
  }

  exit 0
}

function Invoke-GenCert {
  Write-Info "Generando nuevo par de claves RSA ($KeySize bits)..."
  
  if (-not (Test-Path $OutDir)) { 
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null 
  }

  # Backup de claves existentes
  if (Test-Path $script:PublicKeyPath) {
    $backup = "$($script:PublicKeyPath).backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $script:PublicKeyPath $backup
    Write-Info "Backup de public key: $backup"
  }

  if (Test-Path $script:PrivateKeyPath) {
    $backup = "$($script:PrivateKeyPath).backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $script:PrivateKeyPath $backup
    Write-Info "Backup de private key: $backup"
  }

  $kp = New-RsaKeyPairPem -bits $KeySize -privatePath $script:PrivateKeyPath -publicPath $script:PublicKeyPath
  Write-Success "Claves generadas exitosamente"
  Write-Host "Public key: $($kp.public)"
  Write-Host "Private key: $($kp.private)"
  
  Write-Host "`nNota: Si el agente ya está registrado, deberá re-registrarse con la nueva clave." -ForegroundColor Yellow
  exit 0
}

function Invoke-Version {
  Write-Host "psWinModel Reborn Agent v$script:Version" -ForegroundColor Cyan
  Write-Host "PowerShell $($PSVersionTable.PSVersion)"
  if ($script:UseLegacyRsa) {
    Write-Host "Modo: Legacy RSA (PowerShell < 7)" -ForegroundColor Yellow
  } else {
    Write-Host "Modo: Modern RSA (PowerShell 7+)" -ForegroundColor Green
  }
  exit 0
}

function Invoke-Help {
  Write-Host @"

psWinModel Reborn Agent - CLI v$script:Version

Uso: pswm.exe <comando> [opciones]

Comandos disponibles:
  reg_init_check   Registrar agente vía Cola de Aprobación (genera claves si necesario)
  check_status     Verificar conectividad y estado del agente
  view_config      Mostrar configuración actual (config.json)
  archive_config   Archivar config + claves a ZIP y eliminar originales
  restore_config   Restaurar config desde ZIP (solo si no existen archivos locales)
  gencert          Generar/regenerar par de claves RSA
  ping             Realizar un ping HTTP simple al servidor
  facts            Mostrar facts locales (OS, usuario, hostname)
  config set       Modificar valores básicos en config.json (ej: server_url)
  version          Mostrar versión del agente
  help             Mostrar esta ayuda

Opciones comunes:
  -ServerUrl <url>           URL del servidor (default: desde config o http://localhost:3000)
  -OutDir <path>             Directorio de datos (default: $env:ProgramData\pswm-reborn)
  -KeySize <bits>            Tamaño de clave RSA (default: 2048)
  -PollIntervalSeconds <n>   Intervalo de polling en segundos (default: 5)

Ejemplos:
  pswm.exe reg_init_check
  pswm.exe reg_init_check -ServerUrl https://mi-servidor.com
  pswm.exe archive_config "backup-20260117"
  pswm.exe restore_config "backup-20260117"
  pswm.exe check_status
  pswm.exe view_config
  pswm.exe gencert -KeySize 4096
  pswm.exe version

"@ -ForegroundColor Cyan
  exit 0
}

#endregion

#region Main Dispatcher

switch ($Command.ToLower()) {
  "reg_init_check" { Invoke-RegInitCheck }
  "check_status"   { Invoke-CheckStatus }
  "view_config"    { Invoke-ViewConfig }
  "archive_config" { Invoke-ArchiveConfig -Name $Arg1 }
  "restore_config" { Invoke-RestoreConfig -Name $Arg1 }
  "gencert"        { Invoke-GenCert }
  "version"        { Invoke-Version }
  "help"           { Invoke-Help }
  default {
    Write-Err "Comando desconocido: $Command"
    Write-Host "Ejecute 'pswm.exe help' para ver la lista de comandos disponibles"
    exit 1
  }
}

#endregion
