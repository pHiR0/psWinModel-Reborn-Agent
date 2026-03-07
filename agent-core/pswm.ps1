<#
.SYNOPSIS
  psWinModel Reborn Agent - CLI principal

.DESCRIPTION
  Comandos disponibles:
    reg_init_check  - Registrar agente vÃ­a Cola de AprobaciÃ³n (si no hay agent_id)
    reg_token       - Registrar agente vÃ­a Token de Registro (instantÃ¡neo, sin aprobaciÃ³n)
    check_status    - Verificar conectividad y estado del agente
    view_config     - Mostrar configuraciÃ³n actual
    gencert         - Generar/regenerar par de claves RSA
    archive_config  - Archivar config y claves en ZIP y eliminar originales (uso: archive_config "NAME")
    restore_config  - Restaurar una configuraciÃ³n archivada (uso: restore_config "NAME")
    version         - Mostrar versiÃ³n del agente
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
  [string]$Token = $null,
  [string]$OutDir = "$env:ProgramData\pswm-reborn",
  [int]$KeySize = 2048,
  [int]$PollIntervalSeconds = 5
)

# ---------------------------------------------------------------------------
# Deteccion de doble-click / ejecucion directa desde Explorer
# Si no se paso ningun argumento ($Command quedÃ³ en su default "help") y el
# proceso padre es Explorer, redirigimos al comando gui ignorando el help.
# ---------------------------------------------------------------------------
if ($Command -eq 'help') {
  try {
    $parentPid  = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction SilentlyContinue).ParentProcessId
    $parentName = (Get-Process -Id $parentPid -ErrorAction SilentlyContinue).Name
    if ($parentName -match '^explorer$') {
      $Command = 'gui'
    }
  } catch { }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region ConfiguraciÃ³n
$script:Version = "0.1.0-mvp"
$script:ConfigPath = Join-Path $OutDir "config.json"
$script:PrivateKeyPath = Join-Path $OutDir "agent_private.pem"
$script:PublicKeyPath = Join-Path $OutDir "agent_public.pem"

# Detectar PowerShell version
$script:UseLegacyRsa = $PSVersionTable.PSVersion.Major -lt 7

# Modo GUI: cuando true, Exit-Cmd lanza una excepcion de string en vez de exit
$script:GuiMode = $false
#endregion

#region Exit Helper

function Exit-Cmd([int]$code) {
  # En modo GUI no podemos llamar a exit (lanzaria ExitException no capturable en ps2exe).
  # Lanzamos un string "EXIT:N" que el caller de la GUI captura con catch { if ($_ -match 'EXIT:(\d+)') }.
  if ($script:GuiMode) {
    throw "EXIT:$code"
  } else {
    exit $code
  }
}
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
    if ("$_" -match "^EXIT:\d+$") { throw }
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
    if ("$_" -match "^EXIT:\d+$") { throw }
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
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error POST queue: $_"
    throw $_
  }
}

function Get-QueueStatus([string]$serverUrl, [int]$id) {
  $uri = "$serverUrl/api/agents/queue/$id/status"
  try {
    return Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
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
    Exit-Cmd 0
  }

  $srvUrl = Get-ServerUrl
  Write-Info "Server URL: $srvUrl"
  
  if (-not (Test-ServerReachable $srvUrl)) {
    Write-Err "Servidor no accesible: $srvUrl"
    Exit-Cmd 2
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
      if ("$_" -match "^EXIT:\d+$") { throw }
      Write-Err "Error al crear entrada en la cola: $_"
      Exit-Cmd 3
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
      
      Write-Host ""  # nueva lÃ­nea
      Write-Info "Status: $($st.status) (iteraciÃ³n $iterations)"
      
      if ($st.status -eq 'approved') {
        Write-Success "Â¡Aprobado! Agent ID: $($st.agent_id)"
        
        # Actualizar config con agent_id
        $finalCfg = @{
          agent_id = $st.agent_id
          hostname = $env:COMPUTERNAME
          server_url = $srvUrl
          approved_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        Save-Config $finalCfg
        Write-Success "ConfiguraciÃ³n guardada en: $script:ConfigPath"
        Exit-Cmd 0
      }
      elseif ($st.status -eq 'rejected') {
        $msg = if ($st.rejection_message) { $st.rejection_message } else { "Sin mensaje" }
        Write-Err "Entrada rechazada: $msg"
        Exit-Cmd 4
      }
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error durante polling: $_"
    Exit-Cmd 1
  }
}

function Invoke-RegToken {
  Write-Info "Ejecutando reg_token (registro via Token)..."

  # Token puede venir por -Token o como $Arg1
  $tkn = if ($Token) { $Token } elseif ($Arg1) { $Arg1 } else { $null }
  if (-not $tkn) {
    Write-Err "Debe proporcionar un token de registro: pswm.exe reg_token -Token `"MI_TOKEN`" o pswm.exe reg_token `"MI_TOKEN`""
    Exit-Cmd 1
  }

  if (-not (Test-Path $OutDir)) { 
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null 
    Write-Info "Directorio creado: $OutDir"
  }

  $cfg = Get-Config
  if ($cfg -and $cfg.PSObject.Properties['agent_id'] -and $cfg.agent_id) {
    Write-Success "Agente ya registrado con agent_id: $($cfg.agent_id)"
    Write-Host "Ruta config: $script:ConfigPath"
    Exit-Cmd 0
  }

  $srvUrl = Get-ServerUrl
  Write-Info "Server URL: $srvUrl"

  if (-not (Test-ServerReachable $srvUrl)) {
    Write-Err "Servidor no accesible: $srvUrl"
    Exit-Cmd 2
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

  # Leer clave publica
  $pubKey = Get-Content $script:PublicKeyPath -Raw

  # POST /api/agents/register/token
  Write-Info "Enviando registro con token..."
  try {
    $body = @{
      token      = $tkn
      hostname   = $env:COMPUTERNAME
      public_key = $pubKey
    } | ConvertTo-Json -Compress

    $resp = Invoke-RestMethod -Uri "$srvUrl/api/agents/register/token" `
      -Method POST -ContentType 'application/json' -Body $body -ErrorAction Stop

    if ($resp.agent_id) {
      Write-Success "Agente registrado correctamente! Agent ID: $($resp.agent_id)"

      $finalCfg = @{
        agent_id      = $resp.agent_id
        hostname      = $env:COMPUTERNAME
        server_url    = $srvUrl
        registered_via = 'token'
        registered_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      }
      Save-Config $finalCfg
      Write-Success "Configuracion guardada en: $script:ConfigPath"
      Exit-Cmd 0
    } else {
      Write-Err "Respuesta inesperada del servidor: $($resp | ConvertTo-Json -Compress)"
      Exit-Cmd 3
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    $errMsg = $_
    # Intentar extraer mensaje del servidor
    try {
      $errBody = $_.ErrorDetails.Message | ConvertFrom-Json
      if ($errBody.error) { $errMsg = $errBody.error }
    } catch { }
    Write-Err "Error al registrar con token: $errMsg"
    Exit-Cmd 3
  }
}

function Invoke-CheckStatus {
  Write-Info "Verificando estado del agente..."
  
  $cfg = Get-Config
  if (-not $cfg) {
    Write-Err "No se encontrÃ³ archivo de configuraciÃ³n en: $script:ConfigPath"
    Write-Info "Ejecute 'pswm.exe reg_init_check' para registrar el agente"
    Exit-Cmd 3
  }

  Write-Host "`n=== Estado del Agente ===" -ForegroundColor Yellow
  
  $agentId = if ($cfg.PSObject.Properties['agent_id']) { $cfg.agent_id } else { $null }
  $queueId = if ($cfg.PSObject.Properties['queue_id']) { $cfg.queue_id } else { $null }
  
  if ($agentId) {
    Write-Success "Agent ID: $agentId"
  } else {
    Write-Host "Agent ID: No registrado aÃºn" -ForegroundColor Yellow
    if ($queueId) {
      Write-Info "Queue ID: $queueId (pendiente de aprobaciÃ³n)"
    }
  }

  $srvUrl = Get-ServerUrl
  Write-Host "Server URL: $srvUrl"

  $reachable = Test-ServerReachable $srvUrl
  if (-not $reachable) {
    Write-Err "Servidor: No accesible"
    Exit-Cmd 2
  }
  Write-Success "Servidor: Accesible"

  Write-Host "`n=== Archivos ===" -ForegroundColor Yellow
  Write-Host "Config: $script:ConfigPath $(if (Test-Path $script:ConfigPath) { '[OK]' } else { '[NO]' })"
  Write-Host "Public Key: $script:PublicKeyPath $(if (Test-Path $script:PublicKeyPath) { '[OK]' } else { '[NO]' })"
  Write-Host "Private Key: $script:PrivateKeyPath $(if (Test-Path $script:PrivateKeyPath) { '[OK]' } else { '[NO]' })"

  # Decide exit code and try to enrich status with server-side info
  $agentId = if ($cfg.PSObject.Properties['agent_id']) { $cfg.agent_id } else { $null }
  $queueId = if ($cfg.PSObject.Properties['queue_id']) { $cfg.queue_id } else { $null }

  if ($agentId) {
    # Try to fetch public summary for this agent (organization, location, groups)
    try {
      $pubUri = "$srvUrl/api/agents/public/$agentId"
      $resp = Invoke-RestMethod -Uri $pubUri -Method Get -ErrorAction Stop
      if ($resp -and $resp.agent) {
        $ag = $resp.agent
        Write-Host "`n=== Info del Agente (servidor) ===" -ForegroundColor Yellow
        Write-Host "Nombre: $($ag.name)"
        if ($ag.organization) { Write-Host "Organizacion: $($ag.organization)" }
        if ($ag.location) { Write-Host "Localizacion: $($ag.location)" }
        if ($ag.groups -and $ag.groups.Count -gt 0) {
          $names = $ag.groups
          Write-Host "Grupos: $([string]::Join(', ', $names))"
        } else {
          Write-Host "Grupos: (ninguno)"
        }
      }
    } catch {
      # If server returned 403, present a clear disabled message and exit
      if ($_.Exception -and $_.Exception.Response) {
        try {
          $status = $_.Exception.Response.StatusCode.Value__
        } catch {
          if ("$_" -match "^EXIT:\d+$") { throw }
          $status = $null
        }
        if ($status -eq 403) {
          Write-Err "El agente estÃ¡ deshabilitado en el servidor (403)."
          Exit-Cmd 5
        }
      }
      Write-Info "No se pudo obtener info adicional del servidor: $_"
    }

    Exit-Cmd 0
  } elseif ($queueId) {
    Exit-Cmd 4
  } else {
    Exit-Cmd 1
  }
}

function Invoke-ViewConfig {
  Write-Info "ConfiguraciÃ³n actual:"
  
  if (-not (Test-Path $script:ConfigPath)) {
    Write-Err "No se encontrÃ³ archivo de configuraciÃ³n: $script:ConfigPath"
    Exit-Cmd 1
  }

  Write-Host "`n=== $script:ConfigPath ===" -ForegroundColor Yellow
  Get-Content -Raw -Path $script:ConfigPath | Write-Host
  Exit-Cmd 0
}

function Invoke-ArchiveConfig([string]$Name) {
  Write-Info "Archiving local config to ZIP..."
  if (-not $Name -or $Name.Trim().Length -eq 0) {
    Write-Err "Nombre requerido: pswm.exe archive_config \"NAME\""
    Exit-Cmd 1
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
    Exit-Cmd 1
  }

  try {
    if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
    Compress-Archive -Path $files -DestinationPath $zipPath -Force
    Write-Success "Archivado creado en: $zipPath"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error al crear el ZIP: $_"
    Exit-Cmd 1
  }

  # Remove originals after successful archive
  try {
    foreach ($f in $files) { Remove-Item -Path $f -Force }
    Write-Success "Archivos originales eliminados desde: $OutDir"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error al eliminar archivos originales: $_"
    Exit-Cmd 1
  }

  Exit-Cmd 0
}

function Invoke-RestoreConfig([string]$Name) {
  Write-Info "Restaurando configuraciÃ³n desde archivo..."
  if (-not $Name -or $Name.Trim().Length -eq 0) {
    Write-Err "Nombre requerido: pswm.exe restore_config \"NAME\""
    Exit-Cmd 1
  }

  if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
  $archiveDir = Join-Path $OutDir 'config_archive'
  if (-not (Test-Path $archiveDir)) {
    Write-Err "No existe carpeta de archivos archivados: $archiveDir"
    Exit-Cmd 1
  }

  # Ensure target dir has no config or keys
  $confExists = Test-Path (Join-Path $OutDir 'config.json')
  $pubExists = Test-Path (Join-Path $OutDir 'agent_public.pem')
  $privExists = Test-Path (Join-Path $OutDir 'agent_private.pem')
  if ($confExists -or $pubExists -or $privExists) {
    Write-Err "Hay archivos de configuraciÃ³n o certificados existentes en $OutDir. Abortar restauraciÃ³n."
    Write-Host "Archivos detectados: $(@(if ($confExists) { 'config.json' } else { }), (if ($pubExists) { 'agent_public.pem' } else { }), (if ($privExists) { 'agent_private.pem' } else { }) )" -ForegroundColor Yellow
    Exit-Cmd 1
  }

  # Locate zip
  $safeName = $Name
  $zipPath = Join-Path $archiveDir ($safeName + '.zip')
  if (-not (Test-Path $zipPath)) {
    Write-Err "Archivo de backup no encontrado: $zipPath"
    Exit-Cmd 1
  }

  try {
    Expand-Archive -Path $zipPath -DestinationPath $OutDir -Force
    Write-Success "RestauraciÃ³n completada: archivos extraÃ­dos a $OutDir"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error al extraer el ZIP: $_"
    Exit-Cmd 1
  }

  Exit-Cmd 0
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
  
  Write-Host "`nNota: Si el agente ya estÃ¡ registrado, deberÃ¡ re-registrarse con la nueva clave." -ForegroundColor Yellow
  Exit-Cmd 0
}

function Invoke-Version {
  Write-Host "psWinModel Reborn Agent v$script:Version" -ForegroundColor Cyan
  Write-Host "PowerShell $($PSVersionTable.PSVersion)"
  if ($script:UseLegacyRsa) {
    Write-Host "Modo: Legacy RSA (PowerShell < 7)" -ForegroundColor Yellow
  } else {
    Write-Host "Modo: Modern RSA (PowerShell 7+)" -ForegroundColor Green
  }
  Exit-Cmd 0
}

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsCompiled {
  # Detect if running as a compiled .exe (ps2exe sets $MyInvocation.MyCommand.CommandType to 'ExternalScript' but the path ends in .exe)
  $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  return ($exePath -like '*.exe' -and $exePath -notlike '*powershell*' -and $exePath -notlike '*pwsh*')
}

#region Service constants
$script:ServiceName = 'pswm-reborn'
$script:ServiceDisplayName = 'psWinModel Reborn Agent'
$script:ServiceDescription = 'Agente psWinModel Reborn - bucle de servicio'
$script:InstallDir = Join-Path $env:ProgramFiles 'pswm-reborn'
$script:SvcIntervalMinutes = 90
$script:SvcCommand = 'iterate'
#endregion

function Invoke-Svc {
  $intervalSec = $script:SvcIntervalMinutes * 60
  $cmd = $script:SvcCommand
  $svcName = $script:ServiceName

  # â”€â”€ C# ServiceBase implementation â”€â”€
  # This allows the PS2EXE-compiled binary to behave as a proper Windows service
  # by implementing the SCM (Service Control Manager) protocol via ServiceBase.
  $svcSource = @"
using System;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Threading;

public class PswmService : ServiceBase {
    private Thread _workerThread;
    private volatile bool _stopRequested;
    private readonly string _exeDir;
    private readonly string _logFile;
    private readonly int _intervalSec = $intervalSec;
    private readonly string _command = "$cmd";

    public PswmService() {
        ServiceName = "$svcName";
        CanStop = true;
        CanPauseAndContinue = false;
        AutoLog = true;
        _exeDir = Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName);
        string logDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "pswm-reborn", "logs");
        try { Directory.CreateDirectory(logDir); } catch { }
        _logFile = Path.Combine(logDir, "svc.log");
    }

    private void Log(string msg) {
        try {
            string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + msg + Environment.NewLine;
            File.AppendAllText(_logFile, line);
        } catch { }
    }

    protected override void OnStart(string[] args) {
        Log("SERVICE START");
        _stopRequested = false;
        _workerThread = new Thread(WorkerLoop);
        _workerThread.IsBackground = true;
        _workerThread.Start();
    }

    protected override void OnStop() {
        Log("SERVICE STOP requested");
        _stopRequested = true;
        if (_workerThread != null && _workerThread.IsAlive) {
            _workerThread.Join(TimeSpan.FromSeconds(30));
        }
        Log("SERVICE STOP completed");
    }

    private void WorkerLoop() {
        string pswmExe = Path.Combine(_exeDir, "pswm.exe");
        while (!_stopRequested) {
            try {
                Log("Ejecutando: pswm.exe " + _command);
                var psi = new ProcessStartInfo(pswmExe, _command) {
                    WorkingDirectory = _exeDir,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                var proc = Process.Start(psi);
                if (proc != null) {
                    string stdout = proc.StandardOutput.ReadToEnd();
                    string stderr = proc.StandardError.ReadToEnd();
                    proc.WaitForExit();
                    Log("Exit code: " + proc.ExitCode);
                    if (!string.IsNullOrWhiteSpace(stdout)) Log("STDOUT: " + stdout.TrimEnd());
                    if (!string.IsNullOrWhiteSpace(stderr)) Log("STDERR: " + stderr.TrimEnd());
                }
            } catch (Exception ex) {
                Log("ERROR: " + ex.Message);
            }
            // Sleep in 1-second ticks so we can react to stop requests quickly
            for (int i = 0; i < _intervalSec && !_stopRequested; i++) {
                Thread.Sleep(1000);
            }
        }
        Log("Worker loop finished");
    }

    public static void RunAsService() {
        ServiceBase.Run(new PswmService());
    }
}
"@

  # Compile the C# service type
  try {
    Add-Type -TypeDefinition $svcSource -ReferencedAssemblies 'System.ServiceProcess' -ErrorAction Stop
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    # If already loaded in this session, ignore; otherwise try full path
    if ($_.Exception.Message -notlike '*already exists*') {
      try {
        $svcDll = [IO.Path]::Combine(
          [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory(),
          'System.ServiceProcess.dll')
        Add-Type -TypeDefinition $svcSource -ReferencedAssemblies $svcDll -ErrorAction Stop
      } catch {
        if ("$_" -match "^EXIT:\d+$") { throw }
        if ($_.Exception.Message -notlike '*already exists*') {
          Write-Err "Error compilando tipo de servicio: $_"
          Exit-Cmd 1
        }
      }
    }
  }

  # â”€â”€ Try SCM mode (called by Windows Service Manager) â”€â”€
  try {
    [PswmService]::RunAsService()
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    # â”€â”€ Fallback: interactive/console loop (useful for debugging) â”€â”€
    Write-Info "Modo interactivo (no SCM). Ejecutando bucle de servicio..."

    if (-not (Test-IsAdmin)) {
      Write-Err "El comando svc requiere privilegios de administrador."
      Exit-Cmd 1
    }

    $myDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    $pswmExe = Join-Path $myDir 'pswm.exe'
    if (-not (Test-Path $pswmExe)) {
      Write-Err "No se encontro pswm.exe en: $myDir"
      Exit-Cmd 1
    }

    Write-Info "Directorio: $myDir"
    Write-Info "Comando: pswm.exe $cmd"
    Write-Info "Intervalo: $($script:SvcIntervalMinutes) minutos"

    while ($true) {
      $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
      Write-Info "[$ts] Ejecutando: pswm.exe $cmd"
      try {
        $proc = Start-Process -FilePath $pswmExe -ArgumentList $cmd -NoNewWindow -Wait -PassThru
        Write-Info "Exit code: $($proc.ExitCode)"
      } catch {
        if ("$_" -match "^EXIT:\d+$") { throw }
        Write-Err "Error ejecutando pswm.exe: $_"
      }
      Write-Info "Esperando $($script:SvcIntervalMinutes) minutos..."
      Start-Sleep -Seconds $intervalSec
    }
  }
}

function Invoke-Install {
  Write-Info "Instalando agente..."

  # Must be compiled
  if (-not (Test-IsCompiled)) {
    Write-Err "El comando install solo esta disponible para la version compilada (.exe)."
    Write-Host "Compile el agente con build.ps1 y ejecute pswm.exe install" -ForegroundColor Yellow
    Exit-Cmd 1
  }

  # Must be admin
  if (-not (Test-IsAdmin)) {
    Write-Err "El comando install requiere privilegios de administrador."
    Exit-Cmd 1
  }

  $srcExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  $destDir = $script:InstallDir
  $destPswm = Join-Path $destDir 'pswm.exe'
  $destSvc = Join-Path $destDir 'pswm_svc.exe'
  $destUpdater = Join-Path $destDir 'pswm_updater.exe'

  # Create install directory
  if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Write-Success "Directorio creado: $destDir"
  }

  # Copy binaries
  Write-Info "Copiando binarios a $destDir..."
  Copy-Item -Path $srcExe -Destination $destPswm -Force
  Write-Success "pswm.exe copiado"
  Copy-Item -Path $srcExe -Destination $destSvc -Force
  Write-Success "pswm_svc.exe copiado"
  Copy-Item -Path $srcExe -Destination $destUpdater -Force
  Write-Success "pswm_updater.exe copiado"

  # Check if service already exists
  $existingSvc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
  if ($existingSvc) {
    Write-Info "El servicio '$($script:ServiceName)' ya existe (estado: $($existingSvc.Status)). Se reconfigurara."
    if ($existingSvc.Status -eq 'Running') {
      Stop-Service -Name $script:ServiceName -Force -ErrorAction SilentlyContinue
      Write-Info "Servicio detenido."
    }
    # Remove and recreate to update binary path
    sc.exe delete $script:ServiceName | Out-Null
    Start-Sleep -Seconds 2
    Write-Info "Servicio anterior eliminado."
  }

  # Install service using New-Service
  $svcBinPath = "`"$destSvc`" svc"
  try {
    New-Service -Name $script:ServiceName `
               -BinaryPathName $svcBinPath `
               -DisplayName $script:ServiceDisplayName `
               -Description $script:ServiceDescription `
               -StartupType Manual | Out-Null
    Write-Success "Servicio '$($script:ServiceName)' instalado (StartupType: Manual)"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error al instalar el servicio: $_"
    Exit-Cmd 1
  }

  # Configure failure/recovery actions: restart on first and second failure
  sc.exe failure $script:ServiceName reset= 86400 actions= restart/60000/restart/60000// | Out-Null
  Write-Info "Acciones de recuperacion configuradas (reinicio automatico)."

  Write-Host ""
  Write-Host "=== Instalacion completada ===" -ForegroundColor Green
  Write-Host "Directorio: $destDir"
  Write-Host "  pswm.exe        - Agente principal (acciones sobre el equipo)"
  Write-Host "  pswm_svc.exe    - Bucle de servicio (llama periodicamente a pswm.exe)"
  Write-Host "  pswm_updater.exe- Gestor de actualizaciones"
  Write-Host "Servicio: $($script:ServiceName) (Manual)"
  Write-Host ""
  Write-Host "Para iniciar el servicio:  Start-Service $($script:ServiceName)" -ForegroundColor Cyan
  Write-Host "Para que arranque con el sistema: Set-Service $($script:ServiceName) -StartupType Automatic" -ForegroundColor Cyan
  Exit-Cmd 0
}

function Invoke-UninstallService {
  Write-Info "Desinstalando servicio..."

  if (-not (Test-IsAdmin)) {
    Write-Err "El comando uninstall_service requiere privilegios de administrador."
    Exit-Cmd 1
  }

  $existingSvc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
  if (-not $existingSvc) {
    Write-Err "El servicio '$($script:ServiceName)' no existe."
    Exit-Cmd 1
  }

  # Stop first if running
  if ($existingSvc.Status -eq 'Running') {
    Write-Info "Deteniendo servicio..."
    Stop-Service -Name $script:ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Success "Servicio detenido."
  }

  # Remove service
  try {
    sc.exe delete $script:ServiceName | Out-Null
    Write-Success "Servicio '$($script:ServiceName)' eliminado correctamente."
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error al eliminar el servicio: $_"
    Exit-Cmd 1
  }

  Write-Host ""
  Write-Host "Nota: Los archivos en $($script:InstallDir) NO se han eliminado." -ForegroundColor Yellow
  Write-Host "Para eliminarlos manualmente: Remove-Item -Recurse -Force '$($script:InstallDir)'" -ForegroundColor Yellow
  Exit-Cmd 0
}

#region Iterate - Bucle operativo completo

function Collect-Facts {
  <# Recopila facts del equipo local y los devuelve como array de hashtables. #>
  $facts = @()

  # --- OS ---
  $script:_osInstance = $null
  try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $script:_osInstance = $os
    if ($os) {
      $facts += @{ fact_key = 'os_name';      value = $os.Caption;             source = 'agent' }
      $facts += @{ fact_key = 'os_version';   value = $os.Version;             source = 'agent' }
      $facts += @{ fact_key = 'os_build';     value = $os.BuildNumber;         source = 'agent' }
      $facts += @{ fact_key = 'os_arch';      value = $os.OSArchitecture;      source = 'agent' }
      $facts += @{ fact_key = 'os_install_date'; value = $os.InstallDate.ToString('yyyy-MM-dd HH:mm:ss'); source = 'agent' }
      $facts += @{ fact_key = 'os_last_boot';    value = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'); source = 'agent' }
    }
  } catch { }

  # --- Hostname / Domain ---
  $facts += @{ fact_key = 'hostname'; value = $env:COMPUTERNAME; source = 'agent' }
  try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs) {
      $facts += @{ fact_key = 'domain';         value = $cs.Domain;          source = 'agent' }
      $facts += @{ fact_key = 'memory_total_gb'; value = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2); source = 'agent' }
      $facts += @{ fact_key = 'manufacturer';   value = $cs.Manufacturer;    source = 'agent' }
      $facts += @{ fact_key = 'model';          value = $cs.Model;           source = 'agent' }
    }
  } catch { }

  # --- CPU ---
  try {
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cpu) {
      $facts += @{ fact_key = 'cpu_name';  value = $cpu.Name.Trim();      source = 'agent' }
      $facts += @{ fact_key = 'cpu_cores'; value = $cpu.NumberOfCores;    source = 'agent' }
      $facts += @{ fact_key = 'cpu_logical_processors'; value = $cpu.NumberOfLogicalProcessors; source = 'agent' }
    }
  } catch { }

  # --- Discos ---
  try {
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    $diskInfo = @()
    foreach ($d in $disks) {
      $diskInfo += @{
        letter   = $d.DeviceID
        size_gb  = [math]::Round($d.Size / 1GB, 2)
        free_gb  = [math]::Round($d.FreeSpace / 1GB, 2)
        label    = $d.VolumeName
      }
    }
    $facts += @{ fact_key = 'disks'; value = ($diskInfo | ConvertTo-Json -Compress -Depth 3); source = 'agent' }
  } catch { }

  # --- Red ---
  try {
    $nics = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue
    $netInfo = @()
    foreach ($n in $nics) {
      $netInfo += @{
        description = $n.Description
        ip          = ($n.IPAddress | Where-Object { $_ -notmatch ':' }) -join ', '
        mac         = $n.MACAddress
        gateway     = ($n.DefaultIPGateway -join ', ')
      }
    }
    $facts += @{ fact_key = 'network_adapters'; value = ($netInfo | ConvertTo-Json -Compress -Depth 3); source = 'agent' }
  } catch { }

  # --- Usuario conectado ---
  try {
    $user = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    $facts += @{ fact_key = 'logged_user'; value = if ($user) { $user } else { 'N/A' }; source = 'agent' }
  } catch { }

  # --- Version del agente ---
  # Si estamos corriendo como binario compilado (.exe), leer FileVersion del propio ejecutable;
  # esa version la asigna build.ps1 con (Get-Date -Format 'yyyy.MM.dd.HHmmss').
  # Si corremos como script .ps1, usar la constante $script:Version.
  $agentVer = $script:Version
  if (Test-IsCompiled) {
    try {
      $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
      $fvi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
      # FileVersion primero; si viene vacío probar ProductVersion
      $ver = if ($fvi -and $fvi.FileVersion -and $fvi.FileVersion.Trim()) { $fvi.FileVersion.Trim() }`
              elseif ($fvi -and $fvi.ProductVersion -and $fvi.ProductVersion.Trim()) { $fvi.ProductVersion.Trim() }`
              else { $null }
      if ($ver) { $agentVer = $ver }
    } catch { }
  }
  $facts += @{ fact_key = 'agent_version'; value = $agentVer; source = 'agent' }

  # --- Tamaño y hash del pswm.exe (solo en modo compilado) ---
  if (Test-IsCompiled) {
    try {
      $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
      $fi = Get-Item -LiteralPath $exePath -ErrorAction Stop
      $sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256 -ErrorAction Stop).Hash
      $facts += @{ fact_key = 'agent_exe_size_bytes'; value = $fi.Length;  source = 'agent' }
      $facts += @{ fact_key = 'agent_exe_sha256';     value = $sha256;     source = 'agent' }
    } catch { }
  }

  # --- Uptime del sistema ---
  try {
    $osUp = if ($script:_osInstance) { $script:_osInstance } else { Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue }
    if ($osUp) {
      $uptimeSpan = (Get-Date) - $osUp.LastBootUpTime
      $uptimeObj = @{
        boot_time = $osUp.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
        days      = [int][math]::Floor($uptimeSpan.TotalDays)
        hours     = $uptimeSpan.Hours
        minutes   = $uptimeSpan.Minutes
        seconds   = $uptimeSpan.Seconds
      }
      $facts += @{ fact_key = 'uptime'; value = ($uptimeObj | ConvertTo-Json -Compress -Depth 2); source = 'agent' }
    }
  } catch { }

  # --- External facts (scripts .ps1 en external_facts/) ---
  $extDir = Join-Path $OutDir 'external_facts'
  if (Test-Path $extDir) {
    $extScripts = Get-ChildItem -Path $extDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue
    foreach ($es in $extScripts) {
      try {
        $output = & $es.FullName 2>$null | Out-String
        $facts += @{
          fact_key    = "ext_$($es.BaseName)"
          value       = $output.Trim()
          source      = 'external'
          script_name = $es.Name
        }
      } catch { }
    }
  }

  return $facts
}

function Send-Facts([string]$serverUrl, [int]$agentId, [array]$facts) {
  $body = @{ facts = $facts } | ConvertTo-Json -Depth 5 -Compress
  $uri  = "$serverUrl/api/facts/$agentId"
  try {
    $res = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
    return $res
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error enviando facts: $_"
    return $null
  }
}

function Get-PendingDeployments([string]$serverUrl, [int]$agentId) {
  $uri = "$serverUrl/api/deployments/agent/$agentId"
  try {
    $res = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
    return @($res.deployments)  # @() garantiza array aunque solo haya 1 elemento
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error obteniendo despliegues: $_"
    return @()
  }
}

function Execute-ScriptWithOutput([hashtable]$deployment, [string]$serverUrl, [int]$agentId, [string]$iterationId = '') {
  <# Ejecuta un script de un deployment, reporta al servidor y devuelve el resultado (ExitCode, Stdout, Stderr). #>
  $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

  $cacheDir = Join-Path $OutDir 'scripts_cache'
  if (-not (Test-Path $cacheDir)) { $null = New-Item -ItemType Directory -Path $cacheDir -Force }

  $scriptFile = Join-Path $cacheDir "script_$($deployment.script_id).ps1"
  [System.IO.File]::WriteAllText($scriptFile, $deployment.content, [System.Text.Encoding]::UTF8)

  $stdoutVal = ''; $stderrVal = ''; $exitCodeVal = -1; $errorMsg = $null
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdoutVal = $proc.StandardOutput.ReadToEnd()
    $stderrVal = $proc.StandardError.ReadToEnd()
    [void]$proc.WaitForExit(300000)
    $exitCodeVal = $proc.ExitCode
    if ($exitCodeVal -eq 0 -and -not [string]::IsNullOrWhiteSpace($stderrVal)) { $exitCodeVal = 1 }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    $errorMsg = "$_"
  }

  $maxLen = 50000
  # Tamaño REAL del output (en bytes UTF-8) antes de cualquier truncado o resumen
  $stdoutRealBytes = [System.Text.Encoding]::UTF8.GetByteCount($stdoutVal)
  $stderrRealBytes = [System.Text.Encoding]::UTF8.GetByteCount($stderrVal)
  # Versión truncada solo para el registro en Script Runs (visualización en UI)
  $stdoutDisplay = if ($stdoutVal.Length -gt $maxLen) { $stdoutVal.Substring(0, $maxLen) + "`n...[truncado]" } else { $stdoutVal }
  $stderrDisplay = if ($stderrVal.Length -gt $maxLen) { $stderrVal.Substring(0, $maxLen) + "`n...[truncado]" } else { $stderrVal }

  # Para scripts de tipo fact: si la ejecución fue OK y la salida es JSON válido,
  # reemplazar el stdout en Script Runs con un resumen legible en lugar del JSON crudo.
  if ($deployment.script_type -eq 'fact' -and $exitCodeVal -eq 0 -and -not [string]::IsNullOrWhiteSpace($stdoutVal)) {
    try {
      $parsedFact = $stdoutVal.Trim() | ConvertFrom-Json -ErrorAction Stop
      $topKeys = ($parsedFact.PSObject.Properties.Name) -join ', '
      $stdoutDisplay = "Fact Generado: $($deployment.name)`nClaves: $topKeys"
    } catch {
      # La salida no es JSON; se muestra el stdout truncado como de costumbre
    }
  }

  $finishedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

  Send-ScriptRun -serverUrl $serverUrl -agentId $agentId `
    -deploymentId $deployment.id -scriptId $deployment.script_id `
    -startedAt $startedAt -finishedAt $finishedAt `
    -exitCode $exitCodeVal -stdoutText $stdoutDisplay -stderrText $stderrDisplay -errorText $errorMsg `
    -iterationId $iterationId -stdoutBytes $stdoutRealBytes -stderrBytes $stderrRealBytes

  # Se devuelve el stdout COMPLETO (sin truncar) para que Invoke-Iterate pueda parsear el JSON de los facts
  return @{ ExitCode = $exitCodeVal; Stdout = $stdoutVal; Stderr = $stderrVal; Error = $errorMsg }
}

function Execute-Script([hashtable]$deployment, [string]$serverUrl, [int]$agentId, [string]$iterationId = '') {
  <# Ejecuta un script de un deployment y reporta el resultado directamente al servidor. #>
  $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

  $cacheDir = Join-Path $OutDir 'scripts_cache'
  if (-not (Test-Path $cacheDir)) { $null = New-Item -ItemType Directory -Path $cacheDir -Force }

  $scriptFile = Join-Path $cacheDir "script_$($deployment.script_id).ps1"
  [System.IO.File]::WriteAllText($scriptFile, $deployment.content, [System.Text.Encoding]::UTF8)

  $stdoutVal = ''; $stderrVal = ''; $exitCodeVal = -1; $errorMsg = $null
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdoutVal = $proc.StandardOutput.ReadToEnd()
    $stderrVal = $proc.StandardError.ReadToEnd()
    [void]$proc.WaitForExit(300000) # timeout 5min
    $exitCodeVal = $proc.ExitCode
    # Si el script produjo salida por stderr y el exit code es 0, forzar exit code 1
    if ($exitCodeVal -eq 0 -and -not [string]::IsNullOrWhiteSpace($stderrVal)) { $exitCodeVal = 1 }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    $errorMsg = "$_"
  }

  # Truncar stdout/stderr si es demasiado largo (max 50 KB)
  $maxLen = 50000
  # Capturar tamaño real ANTES de truncar
  $stdoutRealBytes = [System.Text.Encoding]::UTF8.GetByteCount($stdoutVal)
  $stderrRealBytes = [System.Text.Encoding]::UTF8.GetByteCount($stderrVal)
  if ($stdoutVal.Length -gt $maxLen) { $stdoutVal = $stdoutVal.Substring(0, $maxLen) + "`n...[truncado]" }
  if ($stderrVal.Length -gt $maxLen) { $stderrVal = $stderrVal.Substring(0, $maxLen) + "`n...[truncado]" }

  $finishedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

  # Reportar directamente al servidor
  Send-ScriptRun -serverUrl $serverUrl -agentId $agentId `
    -deploymentId $deployment.id -scriptId $deployment.script_id `
    -startedAt $startedAt -finishedAt $finishedAt `
    -exitCode $exitCodeVal -stdoutText $stdoutVal -stderrText $stderrVal -errorText $errorMsg `
    -iterationId $iterationId -stdoutBytes $stdoutRealBytes -stderrBytes $stderrRealBytes

  return $exitCodeVal
}

function Send-ScriptRun(
  [string]$serverUrl, [int]$agentId,
  $deploymentId, $scriptId,
  [string]$startedAt, [string]$finishedAt,
  $exitCode, [string]$stdoutText, [string]$stderrText, [string]$errorText,
  [string]$iterationId = '',
  [int]$stdoutBytes = 0, [int]$stderrBytes = 0
) {
  $body = ConvertTo-Json -Depth 3 -Compress @{
    deployment_id = $deploymentId
    agent_id      = $agentId
    script_id     = $scriptId
    started_at    = $startedAt
    finished_at   = $finishedAt
    exit_code     = $exitCode
    stdout        = $stdoutText
    stderr        = $stderrText
    error         = $errorText
    iteration_id  = $iterationId
    stdout_bytes  = $stdoutBytes
    stderr_bytes  = $stderrBytes
  }
  $uri = "$serverUrl/api/deployments/runs"
  try {
    Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error reportando script run: $_"
  }
}

function Get-PendingChocoDeployments([string]$serverUrl, [int]$agentId) {
  $uri = "$serverUrl/api/choco/deployments/agent/$agentId"
  try {
    $res = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
    return @($res.deployments)  # @() garantiza array aunque solo haya 1 elemento
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error obteniendo choco deployments: $_"
    return @()
  }
}

function Execute-ChocoDeployment([object]$deployment, [string]$serverUrl, [int]$agentId) {
  <# Ejecuta una operacion Chocolatey y reporta el resultado directamente al servidor. #>
  $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
  $action = $deployment.action
  $pkg    = $deployment.package_name
  $ver    = $deployment.version
  $chParams = $deployment.params

  $chocoArgs = ''
  switch ($action) {
    'install'   { $chocoArgs = "install $pkg -y" }
    'upgrade'   { $chocoArgs = "upgrade $pkg -y" }
    'uninstall' { $chocoArgs = "uninstall $pkg -y" }
    default     { $chocoArgs = "install $pkg -y" }
  }
  if ($ver)      { $chocoArgs += " --version=$ver" }
  if ($chParams) { $chocoArgs += " $chParams" }

  $stdoutVal = ''; $stderrVal = ''; $exitCodeVal = -1; $errorMsg = $null
  try {
    $chocoExe = (Get-Command choco -ErrorAction SilentlyContinue).Source
    if (-not $chocoExe) { $chocoExe = "$env:ProgramData\chocolatey\bin\choco.exe" }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $chocoExe
    $psi.Arguments = $chocoArgs
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdoutVal = $proc.StandardOutput.ReadToEnd()
    $stderrVal = $proc.StandardError.ReadToEnd()
    [void]$proc.WaitForExit(600000) # timeout 10min
    $exitCodeVal = $proc.ExitCode
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    $errorMsg = "$_"
  }

  $maxLen = 50000
  if ($stdoutVal.Length -gt $maxLen) { $stdoutVal = $stdoutVal.Substring(0, $maxLen) + "`n...[truncado]" }
  if ($stderrVal.Length -gt $maxLen) { $stderrVal = $stderrVal.Substring(0, $maxLen) + "`n...[truncado]" }

  $finishedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

  # Reportar directamente al servidor
  Send-ChocoRun -serverUrl $serverUrl -agentId $agentId `
    -deploymentId $deployment.id -packageId $deployment.package_id -actionName $action `
    -startedAt $startedAt -finishedAt $finishedAt `
    -exitCode $exitCodeVal -stdoutText $stdoutVal -stderrText $stderrVal -errorText $errorMsg

  return $exitCodeVal
}

function Send-ChocoRun(
  [string]$serverUrl, [int]$agentId,
  $deploymentId, $packageId, [string]$actionName,
  [string]$startedAt, [string]$finishedAt,
  $exitCode, [string]$stdoutText, [string]$stderrText, [string]$errorText
) {
  $body = ConvertTo-Json -Depth 3 -Compress @{
    deployment_id = $deploymentId
    agent_id      = $agentId
    package_id    = $packageId
    action        = $actionName
    started_at    = $startedAt
    finished_at   = $finishedAt
    exit_code     = $exitCode
    stdout        = $stdoutText
    stderr        = $stderrText
    error         = $errorText
  }
  $uri = "$serverUrl/api/choco/runs"
  try {
    Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error reportando choco run: $_"
  }
}

function Sync-ChocoInventory([string]$serverUrl, [int]$agentId) {
  <# Sincroniza la lista de paquetes Chocolatey instalados localmente con el servidor. #>
  try {
    $chocoExe = (Get-Command choco -ErrorAction SilentlyContinue).Source
    if (-not $chocoExe) { $chocoExe = "$env:ProgramData\chocolatey\bin\choco.exe" }
    if (-not (Test-Path $chocoExe)) {
      Write-Info "Chocolatey no instalado, saltando sincronizacion de inventario."
      return
    }

    $raw = & $chocoExe list --local-only --limit-output 2>$null
    $packages = @()
    foreach ($line in $raw) {
      if ($line -match '^(.+?)\|(.+)$') {
        $packages += @{
          name    = $matches[1]
          version = $matches[2]
          pinned  = $false
        }
      }
    }

    $body = @{
      agent_id = $agentId
      packages = $packages
    } | ConvertTo-Json -Depth 3 -Compress
    $uri = "$serverUrl/api/choco/agent-packages"
    Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop | Out-Null
    Write-Info "Inventario choco sincronizado: $($packages.Count) paquetes"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "No se pudo sincronizar inventario choco: $_"
  }
}

#region Update Functions

function Get-AgentVersion {
  <# Obtiene la version del ejecutable actual (FileVersion). Si es script, retorna $script:Version #>
  if (Test-IsCompiled) {
    try {
      $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
      $fi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
      if ($fi.FileVersion) { return $fi.FileVersion }
      if ($fi.ProductVersion) { return $fi.ProductVersion }
    } catch { }
  }
  return $script:Version
}

function Invoke-CheckAndApplyUpdate([string]$serverUrl) {
  <#
  .SYNOPSIS
    Comprueba si hay una actualizacion disponible en el servidor y la aplica.
    Soporta 3 modos del servidor:
      - disabled: no hay actualizaciones
      - upgrade: solo actualiza si la version del servidor es mayor
      - mandatory: fuerza la version publicada aunque sea inferior (permite downgrade)
    Usa pswm_updater.exe para reemplazar pswm.exe y pswm_svc.exe.
  #>
  if (-not (Test-IsCompiled)) {
    Write-Info "Update check omitido (modo script, no compilado)"
    return
  }

  $currentVersion = Get-AgentVersion
  Write-Info "Version actual: $currentVersion"

  # Consultar al servidor
  $uri = "$serverUrl/api/updates/check?current_version=$([System.Uri]::EscapeDataString($currentVersion))"
  try {
    $checkRes = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "No se pudo comprobar actualizaciones: $_"
    return
  }

  # Verificar modo
  $mode = if ($checkRes.mode) { $checkRes.mode } else { 'disabled' }
  if ($mode -eq 'disabled') {
    Write-Info "Actualizaciones desactivadas en el servidor"
    return
  }

  if (-not $checkRes.update_available) {
    Write-Info "No hay actualizaciones disponibles (modo: $mode)"
    return
  }

  $serverVersion = $checkRes.version
  if ($mode -eq 'upgrade') {
    Write-Info "Actualizacion disponible (modo upgrade): v$serverVersion"
  } elseif ($mode -eq 'mandatory') {
    Write-Info "Actualizacion forzada (modo mandatory): v$serverVersion"
  }

  # Descargar el binario
  $tempDir = Join-Path $OutDir 'update_temp'
  if (-not (Test-Path $tempDir)) { $null = New-Item -ItemType Directory -Path $tempDir -Force }
  $tempFile = Join-Path $tempDir 'pswm_update.exe'

  Write-Info "Descargando actualizacion..."
  $downloadUri = "$serverUrl/api/updates/download"
  try {
    Invoke-WebRequest -Uri $downloadUri -OutFile $tempFile -ErrorAction Stop
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error descargando actualizacion: $_"
    return
  }

  # Verificar SHA256
  $hash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash.ToLower()
  $expectedHash = $checkRes.sha256.ToLower()
  if ($hash -ne $expectedHash) {
    Write-Err "SHA256 no coincide! Esperado: $expectedHash, Obtenido: $hash"
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    return
  }
  Write-Success "SHA256 verificado correctamente"

  # Invocar pswm_updater.exe para reemplazar pswm.exe y pswm_svc.exe
  $myDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
  $updaterExe = Join-Path $myDir 'pswm_updater.exe'

  if (-not (Test-Path $updaterExe)) {
    Write-Err "pswm_updater.exe no encontrado en: $myDir"
    # Fallback: intentar copiar directamente si no hay servicio bloqueando
    try {
      $destPswm = Join-Path $myDir 'pswm.exe'
      Copy-Item -Path $tempFile -Destination $destPswm -Force
      Write-Success "pswm.exe actualizado directamente (sin updater)"
      $destSvc = Join-Path $myDir 'pswm_svc.exe'
      Copy-Item -Path $tempFile -Destination $destSvc -Force
      Write-Success "pswm_svc.exe actualizado directamente (sin updater)"
    } catch {
      Write-Err "Error actualizando directamente: $_"
    }
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    return
  }

  # Lanzar updater como proceso independiente:
  # pswm_updater.exe apply_update -Arg1 "<tempFile>"
  # El updater copiara el tempFile sobre pswm.exe y pswm_svc.exe
  Write-Info "Lanzando pswm_updater.exe para aplicar la actualizacion..."
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $updaterExe
    $psi.Arguments = "apply_update `"$tempFile`""
    $psi.UseShellExecute = $true
    $psi.CreateNoWindow = $true
    $psi.WindowStyle = 'Hidden'
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Write-Success "Updater lanzado. La actualizacion se aplicara en breve."
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error lanzando updater: $_"
  }
}

function Invoke-ApplyUpdate {
  <#
  .SYNOPSIS
    Comando apply_update: ejecutado por pswm_updater.exe para reemplazar pswm.exe y pswm_svc.exe.
    Uso: pswm_updater.exe apply_update "<ruta_al_nuevo_exe>"
  #>
  $sourceFile = $Arg1
  if (-not $sourceFile -or -not (Test-Path $sourceFile)) {
    Write-Err "Archivo de actualizacion no encontrado: $sourceFile"
    Exit-Cmd 1
  }

  $myDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
  $destPswm = Join-Path $myDir 'pswm.exe'
  $destSvc = Join-Path $myDir 'pswm_svc.exe'

  # Esperar un momento para que el proceso que nos lanzo termine
  Start-Sleep -Seconds 3

  $success = $true

  # Reemplazar pswm.exe
  try {
    # Primero intentar renombrar el antiguo como backup
    $backupPswm = Join-Path $myDir 'pswm.exe.bak'
    if (Test-Path $destPswm) {
      try { Move-Item -Path $destPswm -Destination $backupPswm -Force } catch {
        Write-Info "No se pudo crear backup de pswm.exe: $_ (intentando sobrescribir)"
      }
    }
    Copy-Item -Path $sourceFile -Destination $destPswm -Force
    Write-Success "pswm.exe actualizado"
    # Limpiar backup si exito
    if (Test-Path $backupPswm) { Remove-Item $backupPswm -Force -ErrorAction SilentlyContinue }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error actualizando pswm.exe: $_"
    $success = $false
    # Intentar rollback
    $backupPswm = Join-Path $myDir 'pswm.exe.bak'
    if (Test-Path $backupPswm) {
      try { Move-Item -Path $backupPswm -Destination $destPswm -Force; Write-Info "Rollback pswm.exe completado" } catch { }
    }
  }

  # Reemplazar pswm_svc.exe (puede estar bloqueado por el servicio)
  try {
    $backupSvc = Join-Path $myDir 'pswm_svc.exe.bak'
    if (Test-Path $destSvc) {
      try { Move-Item -Path $destSvc -Destination $backupSvc -Force } catch {
        Write-Info "No se pudo crear backup de pswm_svc.exe: $_ (intentando sobrescribir)"
      }
    }
    Copy-Item -Path $sourceFile -Destination $destSvc -Force
    Write-Success "pswm_svc.exe actualizado"
    if (Test-Path $backupSvc) { Remove-Item $backupSvc -Force -ErrorAction SilentlyContinue }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error actualizando pswm_svc.exe: $_"
    $success = $false
    $backupSvc = Join-Path $myDir 'pswm_svc.exe.bak'
    if (Test-Path $backupSvc) {
      try { Move-Item -Path $backupSvc -Destination $destSvc -Force; Write-Info "Rollback pswm_svc.exe completado" } catch { }
    }
  }

  # Guardar copia del nuevo exe para autoreemplazar pswm_updater.exe en la proxima iteracion
  # (no podemos reemplazarnos a nosotros mismos mientras estamos en ejecucion)
  if ($success) {
    $pendingUpdater = Join-Path $myDir 'pswm_updater.exe.pending'
    try {
      Copy-Item -Path $sourceFile -Destination $pendingUpdater -Force
      Write-Info "pswm_updater.exe.pending guardado para autoreemplazo en proxima iteracion"
    } catch {
      Write-Info "No se pudo guardar pending updater: $_ (se sincronizara por version en la proxima iteracion)"
    }
  }

  # Limpiar archivo temporal
  Remove-Item $sourceFile -Force -ErrorAction SilentlyContinue

  if ($success) {
    Write-Success "=== Actualizacion aplicada correctamente ==="
    # Registrar en log
    $logDir = Join-Path $env:ProgramData 'pswm-reborn' 'logs'
    if (-not (Test-Path $logDir)) { $null = New-Item -ItemType Directory -Path $logDir -Force }
    $logFile = Join-Path $logDir 'update.log'
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$ts UPDATE APPLIED - pswm.exe and pswm_svc.exe replaced" | Out-File -FilePath $logFile -Append -Encoding utf8
  } else {
    Write-Err "=== Actualizacion parcial o fallida ==="
  }

  Exit-Cmd $(if ($success) { 0 } else { 1 })
}

function Sync-UpdaterBinary {
  <#
  .SYNOPSIS
    Sincroniza pswm_updater.exe con la version actual de pswm.exe.
    Primero intenta aplicar un .pending guardado por Invoke-ApplyUpdate.
    Si no hay pending, compara versiones y copia si difieren.
    Se llama siempre al final de cada iteracion (con o sin errores).
  #>
  if (-not (Test-IsCompiled)) { return }

  $myDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
  $pswmExe     = Join-Path $myDir 'pswm.exe'
  $updaterExe  = Join-Path $myDir 'pswm_updater.exe'
  $pendingExe  = Join-Path $myDir 'pswm_updater.exe.pending'

  # --- Paso 1: aplicar pending si existe (guardado por el updater al terminar la actualizacion) ---
  if (Test-Path $pendingExe) {
    Write-Info "Encontrado pswm_updater.exe.pending, aplicando autoreemplazo..."
    try {
      if (Test-Path $updaterExe) { Remove-Item $updaterExe -Force }
      Move-Item -Path $pendingExe -Destination $updaterExe -Force
      Write-Success "pswm_updater.exe autoreemplazado desde .pending"
    } catch {
      if ("$_" -match "^EXIT:\d+$") { throw }
      Write-Info "Error aplicando .pending: $_ (reintentando con copia)"
      try {
        Copy-Item -Path $pendingExe -Destination $updaterExe -Force
        Remove-Item $pendingExe -Force -ErrorAction SilentlyContinue
        Write-Success "pswm_updater.exe autoreemplazado (copia)"
      } catch {
        Write-Info "Error en copia de .pending: $_"
      }
    }
    return
  }

  # --- Paso 2: sincronizar por version si difieren ---
  if (-not (Test-Path $pswmExe)) { return }

  $pswmVersion    = ''
  $updaterVersion = ''

  try {
    $fi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($pswmExe)
    $pswmVersion = if ($fi.FileVersion) { $fi.FileVersion } else { '' }
  } catch { }

  if (Test-Path $updaterExe) {
    try {
      $fi2 = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($updaterExe)
      $updaterVersion = if ($fi2.FileVersion) { $fi2.FileVersion } else { '' }
    } catch { }
  }

  if ($pswmVersion -eq $updaterVersion -and $pswmVersion -ne '') {
    Write-Info "pswm_updater.exe ya esta sincronizado (v$pswmVersion)"
    return
  }

  Write-Info "Sincronizando pswm_updater.exe por version: pswm=$pswmVersion updater=$updaterVersion"
  try {
    if (Test-Path $updaterExe) { Remove-Item $updaterExe -Force }
    Copy-Item -Path $pswmExe -Destination $updaterExe -Force
    Write-Success "pswm_updater.exe sincronizado a v$pswmVersion"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error sincronizando updater por version: $_"
  }
}

#endregion

function Invoke-Iterate {
  <#
  .SYNOPSIS
    Ciclo operativo completo del agente: facts, scripts, choco, status, update check.
  #>
  Write-Info "=== Iniciando iteracion ==="

  # Generar iteration_id unico basado en ticks de fecha/hora actual
  $script:IterationId = [string](Get-Date).Ticks
  Write-Info "Iteration ID: $($script:IterationId)"

  # Flag para rastrear si la iteracion tuvo errores
  $script:IterationHadErrors = $false

  # Validar config
  $cfg = Get-Config
  if (-not $cfg -or -not $cfg.PSObject.Properties['agent_id'] -or -not $cfg.agent_id) {
    Write-Err "El agente no esta registrado. Ejecute 'pswm.exe reg_init_check' primero."
    Exit-Cmd 1
  }

  $agentId = [int]$cfg.agent_id
  $srvUrl  = Get-ServerUrl

  Write-Info "Agent ID: $agentId | Server: $srvUrl"

  if (-not (Test-ServerReachable $srvUrl)) {
    Write-Err "Servidor no accesible: $srvUrl"
    Exit-Cmd 2
  }

  # ---- PASO 1: Facts ----
  Write-Info "Paso 1/4: Recopilando y enviando facts..."
  try {
    $facts = Collect-Facts
    $res = Send-Facts -serverUrl $srvUrl -agentId $agentId -facts $facts
    if ($res) {
      Write-Success "Facts enviados: $($res.count) registros"
    } else {
      Write-Info "No se pudieron enviar facts (continuando)"
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error recopilando/enviando facts: $_ (continuando)"
  }

  # ---- PASO 2: Scripts pendientes ----
  Write-Info "Paso 2/4: Consultando scripts pendientes..."
  try {
    $deployments = @(Get-PendingDeployments -serverUrl $srvUrl -agentId $agentId)
    if ($deployments -and $deployments.Count -gt 0) {
      Write-Info "$($deployments.Count) despliegue(s) de scripts encontrados"

      # Separar en fact scripts y action scripts
      $factDeps   = @($deployments | Where-Object { $_.script_type -eq 'fact' })
      $actionDeps = @($deployments | Where-Object { $_.script_type -ne 'fact' })
      Write-Info "  Facts: $($factDeps.Count) | Actions: $($actionDeps.Count)"

      # Primero ejecutar todos los fact scripts
      if ($factDeps.Count -gt 0) {
        Write-Info "  --- Ejecutando fact scripts ---"
        foreach ($dep in $factDeps) {
          if (-not $dep.enabled) { continue }
          Write-Info "  [FACT] Ejecutando script '$($dep.name)' (deployment $($dep.id), script $($dep.script_id))..."
          $depHash = @{
            id          = $dep.id
            script_id   = $dep.script_id
            content     = $dep.content
            script_type = 'fact'
            name        = $dep.name
          }
          $factResult = Execute-ScriptWithOutput -deployment $depHash -serverUrl $srvUrl -agentId $agentId -iterationId $script:IterationId
          Write-Info "    Exit code: $($factResult.ExitCode)"
          if ($factResult.ExitCode -eq 0 -and $factResult.Stdout) {
            # Intentar parsear la salida como JSON y enviar como facts
            try {
              $parsedJson = $factResult.Stdout | ConvertFrom-Json -ErrorAction Stop
              $factKey = ($dep.name -replace '[^a-zA-Z0-9_]','_').ToLower()
              $factArray = @(
                @{
                  fact_key    = $factKey
                  value       = $factResult.Stdout.Trim()
                  source      = 'script'
                  script_name = $dep.name
                }
              )
              $factBody = ConvertTo-Json -Depth 5 -Compress @{ facts = $factArray }
              $factUri = "$srvUrl/api/facts/$agentId"
              Invoke-RestMethod -Uri $factUri -Method Post -Body $factBody -ContentType 'application/json' -ErrorAction Stop | Out-Null
              Write-Success "    Fact generado: $factKey"
            } catch {
              if ("$_" -match "^EXIT:\d+$") { throw }
              Write-Info "    Salida no es JSON valido o error enviando fact: $_ (continuando)"
            }
          }
          if ($factResult.ExitCode -ne 0) { $script:IterationHadErrors = $true }
        }
      }

      # Luego ejecutar todos los action scripts
      if ($actionDeps.Count -gt 0) {
        Write-Info "  --- Ejecutando action scripts ---"
        foreach ($dep in $actionDeps) {
          if (-not $dep.enabled) { continue }
          Write-Info "  [ACTION] Ejecutando script '$($dep.name)' (deployment $($dep.id), script $($dep.script_id))..."
          $depHash = @{
            id        = $dep.id
            script_id = $dep.script_id
            content   = $dep.content
          }
          $exitC = Execute-Script -deployment $depHash -serverUrl $srvUrl -agentId $agentId -iterationId $script:IterationId
          Write-Info "    Exit code: $exitC"
          if ($exitC -ne 0) { $script:IterationHadErrors = $true }
        }
      }

      Write-Success "Scripts procesados"
    } else {
      Write-Info "No hay scripts pendientes"
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error procesando scripts: $_ (continuando)"
    $script:IterationHadErrors = $true
  }

  # ---- PASO 3: Chocolatey deployments ----
  Write-Info "Paso 3/5: Consultando choco deployments..."
  try {
    $chocoDeployments = @(Get-PendingChocoDeployments -serverUrl $srvUrl -agentId $agentId)
    if ($chocoDeployments -and $chocoDeployments.Count -gt 0) {
      Write-Info "$($chocoDeployments.Count) choco deployment(s) encontrados"
      foreach ($cd in $chocoDeployments) {
        Write-Info "  Ejecutando choco $($cd.action) $($cd.package_name)..."
        $exitC = Execute-ChocoDeployment -deployment $cd -serverUrl $srvUrl -agentId $agentId
        Write-Info "    Exit code: $exitC"
        if ($exitC -ne 0) { $script:IterationHadErrors = $true }
      }
      Write-Success "Choco deployments procesados"
    } else {
      Write-Info "No hay choco deployments pendientes"
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error procesando choco: $_ (continuando)"
    $script:IterationHadErrors = $true
  }

  # ---- PASO 4: Sincronizar inventario Chocolatey ----
  Write-Info "Paso 4/5: Sincronizando inventario Chocolatey..."
  try {
    Sync-ChocoInventory -serverUrl $srvUrl -agentId $agentId
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error sincronizando inventario choco: $_ (continuando)"
    $script:IterationHadErrors = $true
  }

  # ---- PASO 5: Check update ----
  Write-Info "Paso 5/5: Comprobando actualizaciones..."
  try {
    Invoke-CheckAndApplyUpdate -serverUrl $srvUrl
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error comprobando actualizaciones: $_ (continuando)"
  }

  # ---- Post-iteracion: Sincronizar pswm_updater.exe (siempre, con o sin errores) ----
  if (Test-IsCompiled) {
    try {
      Sync-UpdaterBinary
    } catch {
      if ("$_" -match "^EXIT:\d+$") { throw }
      Write-Info "Error sincronizando updater: $_ (continuando)"
    }
  }

  Write-Success "=== Iteracion completada ==="
  Exit-Cmd 0
}

#endregion

function Invoke-DummyIterate {
  <#
  .SYNOPSIS
    Escribe fecha, hora, parametros, PID y usuario en el archivo de prueba.
  #>
  $dataDir = "$env:ProgramData\pswm-reborn"
  if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
  }

  $logFile = Join-Path $dataDir 'test.txt'
  $now     = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $user    = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  $allArgs = $PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }
  $argsStr = if ($allArgs) { $allArgs -join ' ' } else { '(ninguno)' }

  $entry = @"
------------------------------------------------------------
Fecha/Hora : $now
Parametros : $argsStr
PID        : $PID
Usuario    : $user
------------------------------------------------------------
"@

  Add-Content -Path $logFile -Value $entry -Encoding UTF8
  Write-Success "Entrada escrita en: $logFile"
  Write-Host $entry
}

function Invoke-Gui {
  <#
  .SYNOPSIS
    Interfaz grafica WinForms.
    - Sin instalar/registrar: formulario de instalacion con URL del servidor.
    - Instalado y registrado : controles Start/Stop servicio + visor live de svc.log.
  #>

  # Cargar WinForms ANTES de la comprobacion de admin para poder mostrar MessageBox si hay error
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  # --- Verificar privilegios de administrador ---
  $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    try {
      # Detectar si corremos como .exe compilado o como script .ps1
      $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
      $isCompiledExe = $exePath -notmatch 'powershell|pwsh' -and ($exePath -like '*.exe')
      if ($isCompiledExe) {
        $launchArgs = 'gui'
        if ($script:ServerUrl) { $launchArgs += " -ServerUrl `"$script:ServerUrl`"" }
        Start-Process -FilePath $exePath -ArgumentList $launchArgs -Verb RunAs
      } else {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.ScriptName }
        if (-not $scriptPath) {
          # Fallback: usar ruta del script actual
          $scriptPath = $MyInvocation.MyCommand.Definition
        }
        $launchArgs = "-ExecutionPolicy Bypass -File `"$scriptPath`" gui"
        if ($script:ServerUrl) { $launchArgs += " -ServerUrl `"$script:ServerUrl`"" }
        $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue)
        if (-not $psExe) { $psExe = (Get-Command powershell -ErrorAction SilentlyContinue) }
        Start-Process -FilePath $psExe.Source -ArgumentList $launchArgs -Verb RunAs
      }
    } catch {
      [System.Windows.Forms.MessageBox]::Show(
        "No se pudo obtener privilegios de administrador.`n`nError: $_`n`nPor favor, ejecute pswm.exe como Administrador manualmente.",
        'psWinModel Reborn - Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
      ) | Out-Null
    }
    return
  }

  $dataDir   = "$env:ProgramData\pswm-reborn"
  $svcLogPath = Join-Path $dataDir 'logs\svc.log'
  $configPath = Join-Path $dataDir 'config.json'

  # Â¿EstÃ¡ instalado el servicio Y existe agent_id en config?
  $svcObj     = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
  $agentId    = $null
  if (Test-Path $configPath) {
    try {
      $cfg = Get-Content -Raw $configPath | ConvertFrom-Json
      if ($cfg.PSObject.Properties['agent_id']) { $agentId = $cfg.agent_id }
    } catch { }
  }
  $isRegistered = ($svcObj -ne $null) -and ($agentId -ne $null)

  if (-not $isRegistered) {
    # ---- Formulario de instalacion ----
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'psWinModel Reborn - Instalacion'
    $form.Size            = New-Object System.Drawing.Size(500, 310)
    $form.StartPosition   = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox     = $false

    # URL del servidor
    $lblUrl = New-Object System.Windows.Forms.Label
    $lblUrl.Text     = 'URL del servidor:'
    $lblUrl.Location = New-Object System.Drawing.Point(20, 20)
    $lblUrl.Size     = New-Object System.Drawing.Size(120, 20)

    $txtUrl = New-Object System.Windows.Forms.TextBox
    $txtUrl.Text     = (Get-ServerUrl)
    $txtUrl.Location = New-Object System.Drawing.Point(150, 17)
    $txtUrl.Size     = New-Object System.Drawing.Size(310, 20)

    # Metodo de registro
    $lblMethod = New-Object System.Windows.Forms.Label
    $lblMethod.Text     = 'Metodo de registro:'
    $lblMethod.Location = New-Object System.Drawing.Point(20, 52)
    $lblMethod.Size     = New-Object System.Drawing.Size(130, 20)

    $rbQueue = New-Object System.Windows.Forms.RadioButton
    $rbQueue.Text     = 'Cola de Aprobacion'
    $rbQueue.Location = New-Object System.Drawing.Point(150, 50)
    $rbQueue.Size     = New-Object System.Drawing.Size(155, 20)
    $rbQueue.Checked  = $true

    $rbToken = New-Object System.Windows.Forms.RadioButton
    $rbToken.Text     = 'Token de Registro'
    $rbToken.Location = New-Object System.Drawing.Point(310, 50)
    $rbToken.Size     = New-Object System.Drawing.Size(150, 20)

    # Campo de token (solo visible si se selecciona Token)
    $lblToken = New-Object System.Windows.Forms.Label
    $lblToken.Text     = 'Token:'
    $lblToken.Location = New-Object System.Drawing.Point(20, 82)
    $lblToken.Size     = New-Object System.Drawing.Size(120, 20)
    $lblToken.Visible  = $false

    $txtToken = New-Object System.Windows.Forms.TextBox
    $txtToken.Location = New-Object System.Drawing.Point(150, 79)
    $txtToken.Size     = New-Object System.Drawing.Size(310, 20)
    $txtToken.Visible  = $false

    # Toggle visibilidad del campo token segun seleccion
    $rbToken.Add_CheckedChanged({
      $lblToken.Visible = $rbToken.Checked
      $txtToken.Visible = $rbToken.Checked
    })

    # Label de estado
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text      = ''
    $lblStatus.Location  = New-Object System.Drawing.Point(20, 160)
    $lblStatus.Size      = New-Object System.Drawing.Size(440, 60)
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue

    # Boton instalar
    $btnInstall = New-Object System.Windows.Forms.Button
    $btnInstall.Text     = 'Instalar'
    $btnInstall.Location = New-Object System.Drawing.Point(180, 115)
    $btnInstall.Size     = New-Object System.Drawing.Size(130, 30)

    $btnInstall.Add_Click({
      $btnInstall.Enabled = $false
      $lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue

      $useToken = $rbToken.Checked
      if ($useToken -and -not $txtToken.Text.Trim()) {
        $lblStatus.Text      = 'Debe introducir un token de registro.'
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        $btnInstall.Enabled  = $true
        return
      }

      $lblStatus.Text = 'Registrando agente...'
      $form.Refresh()

      $script:GuiMode = $true   # desactiva exit, usa throw "EXIT:N"

      # --- Paso 1: registro (cola o token) ---
      $regOk = $false
      try {
        $script:ServerUrl = $txtUrl.Text.Trim()
        if ($useToken) {
          $script:Token = $txtToken.Text.Trim()
          Invoke-RegToken
        } else {
          Invoke-RegInitCheck
        }
        $regOk = $true
      } catch {
        if ("$_" -match 'EXIT:(\d+)') {
          if ([int]$matches[1] -eq 0) { $regOk = $true }
          else {
            $lblStatus.Text      = "Error en registro (codigo $($matches[1]))"
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            $btnInstall.Enabled  = $true
          }
        } else {
          $lblStatus.Text      = "Error en registro: $_"
          $lblStatus.ForeColor = [System.Drawing.Color]::Red
          $btnInstall.Enabled  = $true
        }
      }
      if (-not $regOk) { $script:GuiMode = $false; return }

      # --- Paso 2: install ---
      $lblStatus.Text = 'Instalando servicio...'
      $form.Refresh()
      try {
        Invoke-Install
        $lblStatus.Text      = 'Instalacion completada. Puedes cerrar esta ventana.'
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
      } catch {
        if ("$_" -match 'EXIT:(\d+)') {
          if ([int]$matches[1] -eq 0) {
            $lblStatus.Text      = 'Instalacion completada. Puedes cerrar esta ventana.'
            $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
          } else {
            $lblStatus.Text      = "Error en instalacion (codigo $($matches[1]))"
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            $btnInstall.Enabled  = $true
          }
        } else {
          $lblStatus.Text      = "Error en instalacion: $_"
          $lblStatus.ForeColor = [System.Drawing.Color]::Red
          $btnInstall.Enabled  = $true
        }
      }

      $script:GuiMode = $false  # restaurar modo normal
    })

    $form.Controls.AddRange(@($lblUrl, $txtUrl, $lblMethod, $rbQueue, $rbToken, $lblToken, $txtToken, $btnInstall, $lblStatus))
    [void]$form.ShowDialog()

  } else {
    # ---- Formulario de gestion + visor de log ----
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = "psWinModel Reborn - Gestion del Servicio  (agent: $agentId)"
    $form.Size            = New-Object System.Drawing.Size(700, 500)
    $form.StartPosition   = 'CenterScreen'
    $form.FormBorderStyle = 'Sizable'

    $pnlTop = New-Object System.Windows.Forms.Panel
    $pnlTop.Dock   = 'Top'
    $pnlTop.Height = 55

    $lblSvcStatus = New-Object System.Windows.Forms.Label
    $lblSvcStatus.Location  = New-Object System.Drawing.Point(20, 15)
    $lblSvcStatus.Size      = New-Object System.Drawing.Size(200, 25)
    $lblSvcStatus.Font      = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

    $btnStart = New-Object System.Windows.Forms.Button
    $btnStart.Text     = 'Iniciar servicio'
    $btnStart.Location = New-Object System.Drawing.Point(230, 13)
    $btnStart.Size     = New-Object System.Drawing.Size(140, 28)

    $btnStop = New-Object System.Windows.Forms.Button
    $btnStop.Text     = 'Detener servicio'
    $btnStop.Location = New-Object System.Drawing.Point(380, 13)
    $btnStop.Size     = New-Object System.Drawing.Size(140, 28)

    $txtLog = New-Object System.Windows.Forms.RichTextBox
    $txtLog.Dock      = 'Fill'
    $txtLog.ReadOnly  = $true
    $txtLog.Font      = New-Object System.Drawing.Font('Consolas', 9)
    $txtLog.BackColor = [System.Drawing.Color]::Black
    $txtLog.ForeColor = [System.Drawing.Color]::LightGreen
    $txtLog.ScrollBars = 'Vertical'

    $pnlTop.Controls.AddRange(@($lblSvcStatus, $btnStart, $btnStop))
    $form.Controls.AddRange(@($pnlTop, $txtLog))

    # Guardamos referencias en $script: para que los scriptblocks del timer puedan acceder
    $script:Gui_SvcName    = $script:ServiceName
    $script:Gui_SvcLogPath = $svcLogPath
    $script:Gui_LogOffset  = 0          # bytes ya leidos del log
    $script:Gui_LblStatus  = $lblSvcStatus
    $script:Gui_BtnStart   = $btnStart
    $script:Gui_BtnStop    = $btnStop
    $script:Gui_TxtLog     = $txtLog

    $timerTick = {
      # -- Actualizar estado del servicio --
      $s = Get-Service -Name $script:Gui_SvcName -ErrorAction SilentlyContinue
      if ($s) {
        $script:Gui_LblStatus.Text      = "Servicio: $($s.Status)"
        $script:Gui_LblStatus.ForeColor = if ($s.Status -eq 'Running') {
          [System.Drawing.Color]::DarkGreen } else { [System.Drawing.Color]::DarkRed }
        $script:Gui_BtnStart.Enabled = ($s.Status -ne 'Running')
        $script:Gui_BtnStop.Enabled  = ($s.Status -eq 'Running')
      } else {
        $script:Gui_LblStatus.Text      = 'Servicio: NO instalado'
        $script:Gui_LblStatus.ForeColor = [System.Drawing.Color]::Gray
        $script:Gui_BtnStart.Enabled   = $false
        $script:Gui_BtnStop.Enabled    = $false
      }

      # -- Leer nuevas lineas del log (FileShare.ReadWrite para no interferir con el servicio) --
      if (Test-Path $script:Gui_SvcLogPath) {
        try {
          $fs = [System.IO.File]::Open(
            $script:Gui_SvcLogPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
          )
          $fileLen = $fs.Length
          if ($fileLen -gt $script:Gui_LogOffset) {
            $fs.Seek($script:Gui_LogOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader  = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
            $newText = $reader.ReadToEnd()
            $reader.Dispose()
            $script:Gui_LogOffset = $fileLen
            if ($newText.Length -gt 0) {
              $script:Gui_TxtLog.AppendText($newText)
              $script:Gui_TxtLog.ScrollToCaret()
            }
          } elseif ($fileLen -lt $script:Gui_LogOffset) {
            # El log fue rotado/truncado; releer desde el principio
            $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader  = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
            $script:Gui_TxtLog.Text = $reader.ReadToEnd()
            $reader.Dispose()
            $script:Gui_LogOffset = $fileLen
            $script:Gui_TxtLog.ScrollToCaret()
          }
          $fs.Dispose()
        } catch { }
      }
    }

    $btnStart.Add_Click({
      try   { Start-Service -Name $script:Gui_SvcName -ErrorAction Stop }
      catch { [System.Windows.Forms.MessageBox]::Show("Error iniciando servicio: $_", 'Error') }
      & $timerTick
    })

    $btnStop.Add_Click({
      try   { Stop-Service -Name $script:Gui_SvcName -Force -ErrorAction Stop }
      catch { [System.Windows.Forms.MessageBox]::Show("Error deteniendo servicio: $_", 'Error') }
      & $timerTick
    })

    # Timer para refresco live del log y estado del servicio
    $timer          = New-Object System.Windows.Forms.Timer
    $timer.Interval = 2000   # cada 2 segundos
    $timer.Add_Tick($timerTick)

    $form.Add_Shown({
      # Cargar las ultimas 20 lineas del log al abrir el formulario
      if (Test-Path $script:Gui_SvcLogPath) {
        try {
          $fs = [System.IO.File]::Open(
            $script:Gui_SvcLogPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
          )
          $script:Gui_LogOffset = $fs.Length
          $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
          $reader     = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
          $allContent = $reader.ReadToEnd()
          $reader.Dispose()
          $fs.Dispose()

          $lines  = $allContent -split "`n"
          $last20 = if ($lines.Count -gt 20) { $lines[($lines.Count - 20)..($lines.Count - 1)] } else { $lines }
          $script:Gui_TxtLog.Text = ($last20 -join "`n").TrimStart("`n")
          $script:Gui_TxtLog.SelectionStart = $script:Gui_TxtLog.Text.Length
          $script:Gui_TxtLog.ScrollToCaret()
        } catch { }
      }
      & $timerTick
      $timer.Start()
    })
    $form.Add_FormClosed({ $timer.Stop(); $timer.Dispose() })

    [void]$form.ShowDialog()
  }
}

function Invoke-Help {
  Write-Host @"

psWinModel Reborn Agent - CLI v$script:Version

Uso: pswm.exe <comando> [opciones]

Comandos disponibles:
  reg_init_check      Registrar agente via Cola de Aprobacion (genera claves si necesario)
  reg_token           Registrar agente via Token de Registro (uso: reg_token -Token "xxx" o reg_token "xxx")
  check_status        Verificar conectividad y estado del agente
  view_config         Mostrar configuracion actual (config.json)
  archive_config      Archivar config + claves a ZIP y eliminar originales
  restore_config      Restaurar config desde ZIP (solo si no existen archivos locales)
  gencert             Generar/regenerar par de claves RSA
  install             Instalar agente como servicio Windows (requiere .exe y admin)
  uninstall_service   Desinstalar servicio Windows del agente
  svc                 Bucle de servicio (uso interno, ejecutado por el servicio)
  iterate             Ciclo operativo: recopila facts, ejecuta scripts/choco pendientes, sincroniza, check update
                      El servidor controla el modo de actualizacion:
                        - disabled: no se proporcionan actualizaciones
                        - upgrade: solo actualiza si la version del servidor es mayor
                        - mandatory: fuerza la version publicada (permite downgrade)
  dummy_iterate       Escribe fecha, params, PID y usuario en ProgramData\pswm-reborn\test.txt
  apply_update        Aplicar actualizacion (uso interno, ejecutado por pswm_updater.exe)
  gui                 Abre la interfaz grafica (instalacion o gestion del servicio)
  version             Mostrar version del agente
  help                Mostrar esta ayuda

Opciones comunes:
  -ServerUrl <url>           URL del servidor (default: desde config o http://localhost:3000)
  -Token <string>            Token de registro (para reg_token)
  -OutDir <path>             Directorio de datos (default: \$env:ProgramData\pswm-reborn)
  -KeySize <bits>            Tamano de clave RSA (default: 2048)
  -PollIntervalSeconds <n>   Intervalo de polling en segundos (default: 5)

Ejemplos:
  pswm.exe reg_init_check
  pswm.exe reg_init_check -ServerUrl https://mi-servidor.com
  pswm.exe reg_token -Token "mi-token-aqui"
  pswm.exe reg_token "mi-token" -ServerUrl https://mi-servidor.com
  pswm.exe archive_config "backup-20260117"
  pswm.exe restore_config "backup-20260117"
  pswm.exe check_status
  pswm.exe view_config
  pswm.exe install
  pswm.exe uninstall_service
  pswm.exe gencert -KeySize 4096
  pswm.exe iterate
  pswm.exe dummy_iterate
  pswm.exe gui
  pswm.exe version

"@ -ForegroundColor Cyan
  Exit-Cmd 0
}

#endregion

#region Main Dispatcher

switch ($Command.ToLower()) {
  "reg_init_check"    { Invoke-RegInitCheck }
  "reg_token"          { Invoke-RegToken }
  "check_status"      { Invoke-CheckStatus }
  "view_config"       { Invoke-ViewConfig }
  "archive_config"    { Invoke-ArchiveConfig -Name $Arg1 }
  "restore_config"    { Invoke-RestoreConfig -Name $Arg1 }
  "gencert"           { Invoke-GenCert }
  "svc"               { Invoke-Svc }
  "install"           { Invoke-Install }
  "uninstall_service" { Invoke-UninstallService }
  "iterate"           { Invoke-Iterate }
  "dummy_iterate"     { Invoke-DummyIterate }
  "apply_update"      { Invoke-ApplyUpdate }
  "gui"               { Invoke-Gui }
  "version"           { Invoke-Version }
  "help"              { Invoke-Help }
  default {
    Write-Err "Comando desconocido: $Command"
    Write-Host "Ejecute 'pswm.exe help' para ver la lista de comandos disponibles"
    Exit-Cmd 1
  }
}

#endregion
