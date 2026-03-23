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
  [int]$PollIntervalSeconds = 5,
  [switch]$RemoveFiles,
  [switch]$LogExtendedInfo,
  [switch]$Install,
  [switch]$ShowChocoWindow,
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$ExtraArgs = @()
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
# Leer versión real del FileInfo si estamos compilados como .exe
try {
  $__exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  if ($__exePath -like '*.exe' -and $__exePath -notlike '*powershell*' -and $__exePath -notlike '*pwsh*') {
    $__fi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($__exePath)
    $__v = if ($__fi.FileVersion) { $__fi.FileVersion } elseif ($__fi.ProductVersion) { $__fi.ProductVersion } else { $null }
    if ($__v) {
      $__v = $__v.Trim()
      # ps2exe almacena la versión como System.Version (numérico), lo que elimina ceros iniciales.
      # El 4º segmento corresponde a HHmmS (5 dígitos); restauramos el cero inicial si es necesario.
      $__vParts = $__v -split '\.'
      if ($__vParts.Length -eq 4 -and $__vParts[0] -match '^\d{4}$' -and $__vParts[3] -match '^\d+$') {
        $__vParts[3] = $__vParts[3].PadLeft(5, '0')
        $__v = $__vParts -join '.'
      }
      $script:Version = $__v
    }
  }
} catch { }
$script:ConfigPath = Join-Path $OutDir "config.json"
$script:PrivateKeyPath = Join-Path $OutDir "agent_private.pem"
$script:PublicKeyPath = Join-Path $OutDir "agent_public.pem"
# Caché de 'choco outdated -r' (16h) y lock local de última actualización Chocolatey
$script:ChocoOutdatedCachePath = Join-Path $OutDir 'choco_outdated_cache.json'
$script:ChocoUpdateLockPath    = Join-Path $OutDir 'choco_update_lock.json'

# Detectar PowerShell version
$script:UseLegacyRsa = $PSVersionTable.PSVersion.Major -lt 7

# Modo GUI: cuando true, Exit-Cmd lanza una excepcion de string en vez de exit
$script:GuiMode = $false
# --log-extended-info: registra invocaciones de powershell.exe y choco.exe
# La detección lee los args del proceso real para funcionar tanto en .ps1 como en pswm.exe compilado
$_rawCmdLine = [System.Environment]::GetCommandLineArgs() -join ' '
$script:LogExtendedInfo = $LogExtendedInfo.IsPresent `
  -or ($ExtraArgs -match 'log.extended.info') `
  -or ($_rawCmdLine -match '--log-extended-info')
# --remove-files: eliminar archivos al desinstalar servicio
$script:RemoveFiles = $RemoveFiles.IsPresent `
  -or ($ExtraArgs -contains '--remove-files') `
  -or ($_rawCmdLine -match '--remove-files')
# --install: instalar servicio tras registro
$script:InstallOnRegister = $Install.IsPresent `
  -or ($ExtraArgs -contains '--install') `
  -or ($_rawCmdLine -match '(?:^|\s)--install(?:\s|$)')
# --force: omitir comprobación de versión en el comando update
$script:Force = ($ExtraArgs -contains '--force') -or ($_rawCmdLine -match '(?:^|\s)--force(?:\s|$)')
# --show-choco-window: mostrar ventana de choco.exe en foreground (debug interactivo)
$script:ShowChocoWindow = $ShowChocoWindow.IsPresent `
  -or ($ExtraArgs -contains '--show-choco-window') `
  -or ($_rawCmdLine -match '--show-choco-window')
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
  $pub = [string](Get-Content -Raw -Path $publicKeyPath)
  $os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
  $facts = @{ os = $os; user = $env:USERNAME; hostname = $hostname }
  # Agregar marca, modelo y MACs para mostrar en la cola de aprobación
  try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs) {
      $facts['manufacturer'] = $cs.Manufacturer
      $facts['model']        = $cs.Model
    }
  } catch { }
  try {
    $adapters = Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "AdapterTypeId = 0 AND MACAddress IS NOT NULL" -ErrorAction SilentlyContinue
    if ($adapters) {
      $facts['mac_addresses'] = @($adapters | ForEach-Object { "$($_.Name): $($_.MACAddress)" })
    }
  } catch { }
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

#region Agent JWT RS256

# Variable de script para cachear el JWT generado durante la iteración
$script:AgentJwt = $null

function ConvertTo-Base64Url([byte[]]$bytes) {
  $b64 = [System.Convert]::ToBase64String($bytes)
  return $b64.TrimEnd('=').Replace('+','-').Replace('/','_')
}

function New-AgentJWT([int]$agentId) {
  <#
  .SYNOPSIS
    Genera un JWT RS256 firmado con la clave privada del agente.
    Header: {"alg":"RS256","typ":"JWT"}
    Payload: {"agent_id":<id>,"iat":<unix>,"exp":<unix+5400>,"jti":"<uuid>"}
    TTL: 90 minutos (5400 segundos)
  #>
  if (-not (Test-Path $script:PrivateKeyPath)) {
    throw "Clave privada no encontrada: $script:PrivateKeyPath"
  }

  # Header
  $headerJson = '{"alg":"RS256","typ":"JWT"}'
  $headerB64 = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($headerJson))

  # Payload
  $now = [DateTimeOffset]::UtcNow
  $iat = [int64]$now.ToUnixTimeSeconds()
  $exp = [int64]($iat + 5400)
  $jti = [guid]::NewGuid().ToString()
  $payloadJson = "{`"agent_id`":$agentId,`"iat`":$iat,`"exp`":$exp,`"jti`":`"$jti`"}"
  $payloadB64 = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($payloadJson))

  # Data to sign
  $dataToSign = "$headerB64.$payloadB64"
  $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($dataToSign)

  # Sign with RSA-SHA256
  if (-not $script:UseLegacyRsa) {
    # PowerShell 7+
    $privPem = [string](Get-Content -Raw -Path $script:PrivateKeyPath)
    $rsa = [System.Security.Cryptography.RSA]::Create()
    try {
      $rsa.ImportFromPem($privPem)
      $sigBytes = $rsa.SignData($dataBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } finally {
      $rsa.Dispose()
    }
  } else {
    # PowerShell 5.1 — la clave privada se almacena como XML
    $privXml = [string](Get-Content -Raw -Path $script:PrivateKeyPath)
    $csp = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    try {
      $csp.FromXmlString($privXml)
      $sigBytes = $csp.SignData($dataBytes, [System.Security.Cryptography.SHA256CryptoServiceProvider]::new())
    } finally {
      $csp.Dispose()
    }
  }

  $sigB64 = ConvertTo-Base64Url $sigBytes
  $jwt = "$dataToSign.$sigB64"
  $script:AgentJwt = $jwt
  return $jwt
}

function Get-AgentAuthHeaders() {
  <# Devuelve un hashtable con los headers de autenticación del agente #>
  if (-not $script:AgentJwt) {
    throw "JWT del agente no generado. Llame a New-AgentJWT primero."
  }
  return @{ 'Authorization' = "Bearer $($script:AgentJwt)" }
}

function Invoke-AgentRestMethod {
  <#
  .SYNOPSIS
    Wrapper de Invoke-RestMethod que añade automáticamente el header Authorization con el JWT del agente.
    Acepta los mismos parámetros que Invoke-RestMethod.
  #>
  param(
    [string]$Uri,
    [string]$Method = 'Get',
    [string]$Body = $null,
    [string]$ContentType = 'application/json',
    [string]$OutFile = $null
  )
  $headers = Get-AgentAuthHeaders
  $params = @{
    Uri     = $Uri
    Method  = $Method
    Headers = $headers
    ErrorAction = 'Stop'
  }
  if ($Body) {
    # Forzar UTF-8 como bytes para evitar re-encoding de caracteres no-ASCII (PS5.1)
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $params['Body'] = $bodyBytes
    $params['ContentType'] = "$ContentType; charset=utf-8"
  }
  if ($OutFile) { $params['OutFile'] = $OutFile }
  return Invoke-RestMethod @params
}

function Invoke-AgentWebRequest {
  <#
  .SYNOPSIS
    Wrapper de Invoke-WebRequest que añade automáticamente el header Authorization con el JWT del agente.
  #>
  param(
    [string]$Uri,
    [string]$OutFile = $null
  )
  $headers = Get-AgentAuthHeaders
  $params = @{
    Uri     = $Uri
    Headers = $headers
    ErrorAction = 'Stop'
  }
  if ($OutFile) { $params['OutFile'] = $OutFile }
  return Invoke-WebRequest @params
}

#endregion Agent JWT RS256

#region Agent Config

function Get-AgentConfig {
  param([string]$serverUrl, [int]$agentId)
  $configDir = "$env:ProgramData\pswm-reborn"
  $configFile = Join-Path $configDir 'agent_config.json'
  try {
    $result = Invoke-AgentRestMethod -Uri "$serverUrl/api/settings/agent-config" -Method Get
    if ($result -and $result.config) {
      if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
      $result.config | ConvertTo-Json -Depth 5 | Set-Content -Path $configFile -Force -Encoding UTF8
      return $result.config
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "[AgentConfig] Error consultando config del servidor: $_ (usando cache local)"
  }
  # Fallback: cache local
  if (Test-Path $configFile) {
    try { return (Get-Content $configFile -Raw | ConvertFrom-Json) } catch {}
  }
  # Default hardcodeado
  return [PSCustomObject]@{ iteration_interval_minutes = 90 }
}

#endregion Agent Config

#region Time Sync

function Invoke-TimeSync([string]$serverUrl, [int]$agentId) {
  <#
  .SYNOPSIS
    Sincroniza el reloj del agente con el servidor usando RSA.
    1. Firma el timestamp UTC actual con la clave privada del agente.
    2. POST /api/time/sync con { agent_id, signed_timestamp: { data, signature } }
    3. Si status='sync_needed', descifra el timestamp del servidor y ajusta el reloj.
    No requiere JWT (es pre-JWT).
  #>
  Write-Info "[TimeSync] Iniciando sincronización de reloj..."

  if (-not (Test-Path $script:PrivateKeyPath)) {
    Write-Info "[TimeSync] Clave privada no encontrada. Omitiendo."
    return
  }

  # Timestamp UTC actual
  $nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
  $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($nowUtc)

  # Firmar con clave privada
  if (-not $script:UseLegacyRsa) {
    $privPem = [string](Get-Content -Raw -Path $script:PrivateKeyPath)
    $rsa = [System.Security.Cryptography.RSA]::Create()
    try {
      $rsa.ImportFromPem($privPem)
      $sigBytes = $rsa.SignData($dataBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } finally {
      $rsa.Dispose()
    }
  } else {
    $privXml = [string](Get-Content -Raw -Path $script:PrivateKeyPath)
    $csp = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    try {
      $csp.FromXmlString($privXml)
      $sigBytes = $csp.SignData($dataBytes, [System.Security.Cryptography.SHA256CryptoServiceProvider]::new())
    } finally {
      $csp.Dispose()
    }
  }

  $sigB64 = [System.Convert]::ToBase64String($sigBytes)

  $body = @{
    agent_id         = $agentId
    signed_timestamp = @{
      data      = $nowUtc
      signature = $sigB64
    }
  } | ConvertTo-Json -Depth 3 -Compress

  try {
    $res = Invoke-RestMethod -Uri "$serverUrl/api/time/sync" -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "[TimeSync] Error contactando servidor: $_ (continuando)"
    return
  }

  if ($res.status -eq 'ok') {
    Write-Success "[TimeSync] Reloj sincronizado (drift: $($res.drift_seconds)s)"
    return
  }

  if ($res.status -eq 'sync_needed') {
    Write-Info "[TimeSync] Desfase detectado ($($res.drift_seconds)s). Ajustando reloj..."
    $encBytes = [System.Convert]::FromBase64String($res.encrypted_server_time)

    # Descifrar con clave privada (OAEP SHA-256)
    if (-not $script:UseLegacyRsa) {
      $rsa2 = [System.Security.Cryptography.RSA]::Create()
      try {
        $privPem2 = [string](Get-Content -Raw -Path $script:PrivateKeyPath)
        $rsa2.ImportFromPem($privPem2)
        $plainBytes = $rsa2.Decrypt($encBytes, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
      } finally {
        $rsa2.Dispose()
      }
    } else {
      $csp2 = New-Object System.Security.Cryptography.RSACryptoServiceProvider
      try {
        $privXml2 = [string](Get-Content -Raw -Path $script:PrivateKeyPath)
        $csp2.FromXmlString($privXml2)
        # RSACryptoServiceProvider (PS5.1/CryptoAPI) no soporta OAEP-SHA256 directamente.
        # Exportamos la clave a RSACng que sí lo soporta en .NET 4.6+.
        $rsaCng = [System.Security.Cryptography.RSACng]::new()
        try {
          $rsaCng.ImportParameters($csp2.ExportParameters($true))
          $plainBytes = $rsaCng.Decrypt($encBytes, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA256)
        } finally {
          $rsaCng.Dispose()
        }
      } finally {
        $csp2.Dispose()
      }
    }

    $serverTimeStr = [System.Text.Encoding]::UTF8.GetString($plainBytes)
    $serverTime = [DateTimeOffset]::Parse($serverTimeStr)
    $localTime = $serverTime.LocalDateTime

    try {
      Set-Date -Date $localTime -ErrorAction Stop | Out-Null
      Write-Success "[TimeSync] Reloj ajustado a: $localTime"
    } catch {
      if ("$_" -match "^EXIT:\d+$") { throw }
      Write-Err "[TimeSync] No se pudo ajustar el reloj (requiere permisos de administrador): $_"
    }
  }
}

#endregion Time Sync

function Register-AgentKey([string]$serverUrl, [int]$agentId) {
  <#
  .SYNOPSIS
    Registra (o reemplaza) la clave pública del agente en el servidor.
    Se usa cuando el servidor indica 'invalid_public_key' — situación que puede
    darse en agentes registrados ANTES de que se implementase JWT RS256, o si la
    clave nunca se almacenó correctamente.

    Prueba de posesión: el agente firma { agent_id, ts } con su clave privada y
    envía la firma junto con la clave pública → el servidor verifica con la clave
    enviada y sólo acepta si la clave almacenada es inválida o nula.
    Sin JWT (bootstrap).
  #>
  Write-Info "[RegisterKey] Registrando clave pública en el servidor (agent_id: $agentId)..."

  if (-not (Test-Path $script:PrivateKeyPath)) {
    Write-Err "[RegisterKey] Clave privada no encontrada en $($script:PrivateKeyPath)"
    return $false
  }
  if (-not (Test-Path $script:PublicKeyPath)) {
    Write-Err "[RegisterKey] Clave pública no encontrada en $($script:PublicKeyPath)"
    return $false
  }

  $pubPem  = [string](Get-Content -Raw -Path $script:PublicKeyPath)
  $proofData = @{ agent_id = $agentId; ts = [DateTimeOffset]::UtcNow.ToString('o') } | ConvertTo-Json -Compress
  $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($proofData)

  # Firmar con clave privada (RSA-SHA256)
  if (-not $script:UseLegacyRsa) {
    $privPem = [string](Get-Content -Raw -Path $script:PrivateKeyPath)
    $rsa = [System.Security.Cryptography.RSA]::Create()
    try {
      $rsa.ImportFromPem($privPem)
      $sigBytes = $rsa.SignData($dataBytes,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } finally { $rsa.Dispose() }
  } else {
    $privXml = [string](Get-Content -Raw -Path $script:PrivateKeyPath)
    $csp = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    try {
      $csp.FromXmlString($privXml)
      $sigBytes = $csp.SignData($dataBytes, [System.Security.Cryptography.SHA256CryptoServiceProvider]::new())
    } finally { $csp.Dispose() }
  }

  $sigB64 = [System.Convert]::ToBase64String($sigBytes)

  $body = @{
    public_key = $pubPem
    proof      = @{
      data      = $proofData
      signature = $sigB64
    }
  } | ConvertTo-Json -Depth 4 -Compress

  try {
    $res = Invoke-RestMethod -Uri "$serverUrl/api/agents/$agentId/register-key" `
      -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
    Write-Success "[RegisterKey] Clave pública registrada correctamente."
    return $true
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    $errMsg = "$_"
    if ($errMsg -match 'agent_already_has_valid_key') {
      Write-Info "[RegisterKey] El servidor ya tiene una clave válida para este agente."
      return $false
    }
    Write-Err "[RegisterKey] Error en el registro de clave: $errMsg"
    return $false
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

  # --install: instalar servicio y salir (el servicio llamara pswm iterate periodicamente)
  if ($script:InstallOnRegister) {
    Write-Host ""
    Write-Info "--install: agente en cola de aprobacion (queue_id: $qid)."
    Write-Info "Instalando el servicio ahora. El propio servicio comprobara el estado de aprobacion."
    if ((Test-IsCompiled) -and (Test-IsAdmin)) {
      $existSvc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
      if (-not $existSvc) {
        $svcOk = Install-ServiceCore
        if ($svcOk) { Enable-ServiceAutostart }
      } else {
        Enable-ServiceAutostart
      }
    } else {
      Write-Host "Nota: --install requiere pswm.exe compilado y ejecutado como Administrador." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Success "Listo. Queue ID: $qid"
    Write-Info "Una vez que el administrador apruebe el equipo en la consola web, el agente empezara a operar automaticamente."
    Exit-Cmd 0
  }

  # Polling con intervalos adaptativos:
  #   Iteraciones 1-3   -> 5 segundos
  #   Iteraciones 4-23  -> 30 segundos
  #   Iteraciones 24+   -> 60 segundos
  Write-Info "Polling en espera de aprobacion (intervalos adaptativos, Ctrl+C para cancelar)..."
  try {
    $iterations = 0
    while ($true) {
      $waitSec = if ($iterations -lt 3) { 5 } elseif ($iterations -lt 23) { 30 } else { 60 }
      Start-Sleep -Seconds $waitSec
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
  $pubKey = [string](Get-Content -Raw -Path $script:PublicKeyPath)

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

      # --install: instalar y arrancar servicio tras registro exitoso
      if ($script:InstallOnRegister) {
        Write-Host ""
        Write-Info "--install: instalando/configurando servicio..."
        if ((Test-IsCompiled) -and (Test-IsAdmin)) {
          $existSvc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
          if (-not $existSvc) {
            $svcOk = Install-ServiceCore
            if ($svcOk) { Enable-ServiceAutostart }
          } else {
            Enable-ServiceAutostart
          }
        } else {
          Write-Host "Nota: --install requiere pswm.exe compilado y ejecutado como Administrador." -ForegroundColor Yellow
        }
      }

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
  Write-Info "Configuración actual:"

  if (-not (Test-Path $script:ConfigPath)) {
    Write-Err "No se encontró archivo de configuración: $script:ConfigPath"
    Exit-Cmd 1
  }

  # --- config.json ---
  Write-Host "`n=== $script:ConfigPath ===" -ForegroundColor Yellow
  Get-Content -Raw -Path $script:ConfigPath | Write-Host

  # --- agent_config.json ---
  $agentConfigPath = Join-Path $OutDir 'agent_config.json'
  Write-Host "`n=== agent_config.json ===" -ForegroundColor Yellow
  if (Test-Path $agentConfigPath) {
    Get-Content -Raw -Path $agentConfigPath | Write-Host
  } else {
    Write-Host "  (no existe — se usarán valores por defecto)" -ForegroundColor DarkGray
  }

  # --- Hashes SHA256 de certificados PEM ---
  Write-Host "`n=== Hashes de certificados (.pem) ===" -ForegroundColor Yellow
  foreach ($pemFile in @($script:PublicKeyPath, $script:PrivateKeyPath)) {
    $label = Split-Path $pemFile -Leaf
    if (Test-Path $pemFile) {
      $sha256 = (Get-FileHash -Path $pemFile -Algorithm SHA256).Hash
      Write-Host ("  {0,-30}  SHA256: {1}" -f $label, $sha256)
    } else {
      Write-Host ("  {0,-30}  (no existe)" -f $label) -ForegroundColor DarkGray
    }
  }

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

  # Ensure target dir has no config or keys (salvo --force)
  $confExists = Test-Path (Join-Path $OutDir 'config.json')
  $pubExists = Test-Path (Join-Path $OutDir 'agent_public.pem')
  $privExists = Test-Path (Join-Path $OutDir 'agent_private.pem')
  if (($confExists -or $pubExists -or $privExists) -and -not $script:Force) {
    Write-Err "Hay archivos de configuraciÃ³n o certificados existentes en $OutDir. Abortar restauraciÃ³n."
    Write-Host "Archivos detectados: $(@(if ($confExists) { 'config.json' } else { }), (if ($pubExists) { 'agent_public.pem' } else { }), (if ($privExists) { 'agent_private.pem' } else { }) )" -ForegroundColor Yellow
    Write-Host "Usa --force para sobreescribir (se creara backup _autosave)." -ForegroundColor Yellow
    Exit-Cmd 1
  }

  # --force: hacer backup _autosave de archivos existentes antes de sobreescribir
  if ($script:Force -and ($confExists -or $pubExists -or $privExists)) {
    $autosaveDir = Join-Path $archiveDir '_autosave'
    if (Test-Path $autosaveDir) { Remove-Item -Path $autosaveDir -Recurse -Force }
    New-Item -ItemType Directory -Path $autosaveDir -Force | Out-Null
    foreach ($fname in @('config.json', 'agent_public.pem', 'agent_private.pem')) {
      $src = Join-Path $OutDir $fname
      if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $autosaveDir $fname) -Force
        Write-Warning "Backup _autosave: $fname"
      }
    }
    Write-Info "Backup _autosave creado en: $autosaveDir"
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
    private Process _remoteSessionProc;

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

    private int GetConfigInterval() {
        try {
            string configFile = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "pswm-reborn", "agent_config.json");
            if (File.Exists(configFile)) {
                string json = File.ReadAllText(configFile);
                var match = System.Text.RegularExpressions.Regex.Match(
                    json, @"""iteration_interval_minutes""\s*:\s*(\d+)");
                if (match.Success) {
                    int minutes = int.Parse(match.Groups[1].Value);
                    if (minutes >= 1 && minutes <= 1440) return minutes * 60;
                }
            }
        } catch { }
        return _intervalSec;
    }

    private void WorkerLoop() {
        string pswmExe = Path.Combine(_exeDir, "pswm.exe");
        while (!_stopRequested) {
            // Manage remote_session BEFORE iterate (so it starts immediately on service start if enabled)
            try { ManageRemoteSession(pswmExe); } catch (Exception ex) { Log("RS ERROR pre-iterate: " + ex.Message); }
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
                    // Leer stdout y stderr en threads paralelos para evitar deadlock de pipe
                    // (ReadToEnd secuencial puede bloquearse si el hijo llena el buffer de stderr
                    //  mientras nuestro hilo esta bloqueado leyendo stdout)
                    string stdout = "";
                    string stderr = "";
                    var stdoutThread = new Thread(() => { try { stdout = proc.StandardOutput.ReadToEnd(); } catch { } });
                    var stderrThread = new Thread(() => { try { stderr = proc.StandardError.ReadToEnd(); } catch { } });
                    stdoutThread.IsBackground = true;
                    stderrThread.IsBackground = true;
                    stdoutThread.Start();
                    stderrThread.Start();

                    // Timeout watchdog: si iterate supera 2x el intervalo configurado, matar el proceso
                    int timeoutMs = GetConfigInterval() * 2 * 1000;
                    bool exited = proc.WaitForExit(timeoutMs);
                    if (!exited) {
                        Log("WATCHDOG: pswm.exe " + _command + " supera " + (timeoutMs / 60000) + " minutos sin terminar. Matando proceso (PID: " + proc.Id + ")...");
                        try { proc.Kill(); } catch (Exception killEx) { Log("Kill error: " + killEx.Message); }
                        proc.WaitForExit(5000);
                    }
                    // Esperar a que los lectores de pipe terminen (el proceso ya cerro sus streams)
                    stdoutThread.Join(5000);
                    stderrThread.Join(5000);

                    Log("Exit code: " + proc.ExitCode + (exited ? "" : " [KILLED by watchdog]"));
                    if (!string.IsNullOrWhiteSpace(stdout)) Log("STDOUT: " + stdout.TrimEnd());
                    if (!string.IsNullOrWhiteSpace(stderr)) Log("STDERR: " + stderr.TrimEnd());
                }
            } catch (Exception ex) {
                Log("ERROR: " + ex.Message);
            }
            // Manage remote_session process lifecycle
            try { ManageRemoteSession(pswmExe); } catch (Exception ex) { Log("RS ERROR: " + ex.Message); }
            // Read interval from config (updated by iterate) or use default
            int sleepSec = GetConfigInterval();
            Log("Esperando " + (sleepSec / 60) + " minutos...");
            for (int i = 0; i < sleepSec && !_stopRequested; i++) {
                Thread.Sleep(1000);
            }
        }
        // Stop remote_session on service stop
        StopRemoteSession();
        Log("Worker loop finished");
    }

    private bool IsRemoteSessionEnabled() {
        try {
            string configFile = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "pswm-reborn", "agent_config.json");
            if (File.Exists(configFile)) {
                string json = File.ReadAllText(configFile);
                var match = System.Text.RegularExpressions.Regex.Match(
                    json, @"""remote_session_enabled""\s*:\s*true", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                return match.Success;
            }
        } catch { }
        return false;
    }

    private void ManageRemoteSession(string pswmExe) {
        bool shouldRun = IsRemoteSessionEnabled();
        bool isRunning = _remoteSessionProc != null && !_remoteSessionProc.HasExited;

        // Check remote_session.pid for externally started processes (e.g. admin ran pswm.exe remote_session manually)
        if (shouldRun && !isRunning) {
            string pidFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "pswm-reborn", "remote_session.pid");
            if (File.Exists(pidFile)) {
                try {
                    int extPid = int.Parse(File.ReadAllText(pidFile).Trim());
                    var extProc = Process.GetProcessById(extPid);
                    if (extProc != null && !extProc.HasExited) {
                        Log("RS: External remote_session already running (PID: " + extPid + "), skipping launch");
                        return;
                    }
                } catch { /* PID file stale or process gone, ignore */ }
            }
        }

        if (shouldRun && !isRunning) {
            Log("RS: Launching remote_session process");
            try {
                var rsPsi = new ProcessStartInfo(pswmExe, "remote_session") {
                    WorkingDirectory = _exeDir,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                _remoteSessionProc = Process.Start(rsPsi);
                Log("RS: Started (PID: " + (_remoteSessionProc != null ? _remoteSessionProc.Id.ToString() : "?") + ")");
            } catch (Exception ex) {
                Log("RS: Failed to start: " + ex.Message);
            }
        } else if (!shouldRun && isRunning) {
            Log("RS: Stopping remote_session (disabled)");
            StopRemoteSession();
        } else if (shouldRun && isRunning) {
            Log("RS: remote_session running (PID: " + _remoteSessionProc.Id + ")");
        }
    }

    private void StopRemoteSession() {
        if (_remoteSessionProc != null && !_remoteSessionProc.HasExited) {
            try {
                _remoteSessionProc.Kill();
                _remoteSessionProc.WaitForExit(5000);
                Log("RS: Process stopped");
            } catch (Exception ex) {
                Log("RS: Error stopping: " + ex.Message);
            }
        }
        _remoteSessionProc = null;
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
    Write-Info "Intervalo por defecto: $($script:SvcIntervalMinutes) minutos (se actualizará desde config del servidor)"

    function Manage-RemoteSessionFallback($exe, $currentProc) {
      $cfgFile = Join-Path "$env:ProgramData\pswm-reborn" 'agent_config.json'
      $shouldRun = $false
      if (Test-Path $cfgFile) {
        try {
          $acfg = Get-Content $cfgFile -Raw | ConvertFrom-Json
          if ($acfg.remote_session_enabled -eq $true) { $shouldRun = $true }
        } catch {}
      }
      $isRunning = $currentProc -and (-not $currentProc.HasExited)
      # Check PID file for externally started processes
      if ($shouldRun -and -not $isRunning) {
        $pidFile = Join-Path "$env:ProgramData\pswm-reborn" 'remote_session.pid'
        if (Test-Path $pidFile) {
          try {
            $extPid = [int](Get-Content $pidFile -Raw).Trim()
            $extProc = Get-Process -Id $extPid -ErrorAction SilentlyContinue
            if ($extProc) {
              Write-Info "RS: External remote_session running (PID $extPid), skipping"
              return $currentProc
            }
          } catch {}
        }
      }
      if ($shouldRun -and -not $isRunning) {
        Write-Info "RS: Launching remote_session"
        try {
          $currentProc = Start-Process -FilePath $exe -ArgumentList 'remote_session' -NoNewWindow -PassThru
          Write-Info "RS: Started (PID: $($currentProc.Id))"
        } catch { Write-Err "RS: Failed to start: $_" }
      } elseif (-not $shouldRun -and $isRunning) {
        Write-Info "RS: Stopping remote_session (disabled)"
        try { $currentProc.Kill(); $currentProc.WaitForExit(5000) } catch {}
        $currentProc = $null
      }
      return $currentProc
    }

    $rsProc = $null

    while ($true) {
      # Manage remote_session BEFORE iterate
      $rsProc = Manage-RemoteSessionFallback $pswmExe $rsProc
      $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
      Write-Info "[$ts] Ejecutando: pswm.exe $cmd"
      try {
        $proc = Start-Process -FilePath $pswmExe -ArgumentList $cmd -NoNewWindow -Wait -PassThru
        Write-Info "Exit code: $($proc.ExitCode)"
      } catch {
        if ("$_" -match "^EXIT:\d+$") { throw }
        Write-Err "Error ejecutando pswm.exe: $_"
      }
      # Manage remote_session AFTER iterate
      $rsProc = Manage-RemoteSessionFallback $pswmExe $rsProc
      # Read interval from config file (updated by iterate) or use default
      $cfgIntervalMin = $script:SvcIntervalMinutes
      $cfgFile = Join-Path "$env:ProgramData\pswm-reborn" 'agent_config.json'
      if (Test-Path $cfgFile) {
        try {
          $cfgJson = Get-Content $cfgFile -Raw | ConvertFrom-Json
          if ($cfgJson.iteration_interval_minutes -ge 1 -and $cfgJson.iteration_interval_minutes -le 1440) {
            $cfgIntervalMin = [int]$cfgJson.iteration_interval_minutes
          }
        } catch {}
      }
      Write-Info "Esperando $cfgIntervalMin minutos..."
      Start-Sleep -Seconds ($cfgIntervalMin * 60)
    }
  }
}

function Install-ServiceCore {
  <#
  .SYNOPSIS
    Nucleo de instalacion del agente como servicio Windows.
    No llama Exit-Cmd. Devuelve $true si exitoso, $false si fallo.
  #>
  $srcExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  $destDir = $script:InstallDir
  $destPswm = Join-Path $destDir 'pswm.exe'
  $destSvc = Join-Path $destDir 'pswm_svc.exe'
  $destUpdater = Join-Path $destDir 'pswm_updater.exe'

  # Crear directorio de instalacion
  if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Write-Success "Directorio creado: $destDir"
  }

  # Copiar binarios
  Write-Info "Copiando binarios a $destDir..."
  try {
    Copy-Item -Path $srcExe -Destination $destPswm -Force
    Write-Success "pswm.exe copiado"
    Copy-Item -Path $srcExe -Destination $destSvc -Force
    Write-Success "pswm_svc.exe copiado"
    Copy-Item -Path $srcExe -Destination $destUpdater -Force
    Write-Success "pswm_updater.exe copiado"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error al copiar binarios: $_"
    return $false
  }

  # Parar y eliminar servicio existente para recrearlo
  $existingSvc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
  if ($existingSvc) {
    Write-Info "El servicio '$($script:ServiceName)' ya existe (estado: $($existingSvc.Status)). Se reconfigurara."
    if ($existingSvc.Status -eq 'Running') {
      Stop-Service -Name $script:ServiceName -Force -ErrorAction SilentlyContinue
      Write-Info "Servicio detenido."
    }
    sc.exe delete $script:ServiceName | Out-Null
    Start-Sleep -Seconds 2
    Write-Info "Servicio anterior eliminado."
  }

  # Crear servicio con inicio automatico
  $svcBinPath = "`"$destSvc`" svc"
  try {
    New-Service -Name $script:ServiceName `
               -BinaryPathName $svcBinPath `
               -DisplayName $script:ServiceDisplayName `
               -Description $script:ServiceDescription `
               -StartupType Automatic | Out-Null
    Write-Success "Servicio '$($script:ServiceName)' instalado (StartupType: Automatic)"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error al instalar el servicio: $_"
    return $false
  }

  # Configurar acciones de recuperacion: reinicio automatico en fallos
  sc.exe failure $script:ServiceName reset= 86400 actions= restart/60000/restart/60000// | Out-Null
  Write-Info "Acciones de recuperacion configuradas (reinicio automatico)."

  return $true
}

function Enable-ServiceAutostart {
  <#
  .SYNOPSIS
    Configura el servicio en inicio automatico y lo inicia si no estaba corriendo.
  #>
  $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
  if (-not $svc) {
    Write-Err "Servicio '$($script:ServiceName)' no encontrado, no se puede configurar inicio automatico."
    return
  }
  try {
    Set-Service -Name $script:ServiceName -StartupType Automatic -ErrorAction Stop
    Write-Success "Servicio configurado en inicio automatico (Automatic)."
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "No se pudo configurar inicio automatico: $_"
  }
  # Refrescar estado
  $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
  if ($svc -and $svc.Status -ne 'Running') {
    try {
      Start-Service -Name $script:ServiceName -ErrorAction Stop
      Write-Success "Servicio '$($script:ServiceName)' iniciado correctamente."
    } catch {
      if ("$_" -match "^EXIT:\d+$") { throw }
      Write-Err "No se pudo iniciar el servicio: $_"
    }
  } elseif ($svc -and $svc.Status -eq 'Running') {
    Write-Info "El servicio ya estaba en ejecucion."
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

  $ok = Install-ServiceCore
  if (-not $ok) {
    Exit-Cmd 1
  }

  $destDir = $script:InstallDir
  Write-Host ""
  Write-Host "=== Instalacion completada ===" -ForegroundColor Green
  Write-Host "Directorio: $destDir"
  Write-Host "  pswm.exe        - Agente principal (acciones sobre el equipo)"
  Write-Host "  pswm_svc.exe    - Bucle de servicio (llama periodicamente a pswm.exe)"
  Write-Host "  pswm_updater.exe- Gestor de actualizaciones"
  Write-Host "Servicio: $($script:ServiceName) (Automatic)"
  Write-Host ""
  Enable-ServiceAutostart
  Exit-Cmd 0
}

function Invoke-UpdateBinaries {
  <#
  .SYNOPSIS
    Actualiza los binarios del agente (pswm.exe, pswm_svc.exe, pswm_updater.exe) en el
    directorio de instalacion. Solo toca los .exe; no modifica configuracion ni el registro
    del servicio Windows (solo lo para y vuelve a arrancar si es necesario).
    Si el servicio estaba arrancado lo para antes de copiar y lo reanuda al terminar.
    Si el servicio estaba parado no se arranca tras la actualizacion.
  #>

  # Solo disponible como binario compilado
  if (-not (Test-IsCompiled)) {
    Write-Err "El comando update solo esta disponible para la version compilada (.exe)."
    Exit-Cmd 1
  }

  # Requiere admin
  if (-not (Test-IsAdmin)) {
    Write-Err "El comando update requiere privilegios de administrador."
    Exit-Cmd 1
  }

  $srcExe   = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  $destDir  = $script:InstallDir
  $destPswm = Join-Path $destDir 'pswm.exe'

  # Crear directorio si no existe aun (primera instalacion limpia)
  if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Write-Success "Directorio creado: $destDir"
  }

  # Leer version del nuevo binario (el que estamos ejecutando)
  $fiNew = $null
  try {
    $fiNew = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($srcExe)
  } catch {
    Write-Err "No se pudo leer la version del binario actual: $_"
    Exit-Cmd 1
  }
  $verNew = if ($fiNew.FileVersion) { $fiNew.FileVersion.Trim() } else { '0.0.0.0' }

  # Comprobar version instalada (si existe)
  if (-not $script:Force -and (Test-Path $destPswm)) {
    try {
      $fiInst   = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($destPswm)
      $verInst  = if ($fiInst.FileVersion) { $fiInst.FileVersion.Trim() } else { '0.0.0.0' }

      # Normalizar: ps2exe puede generar "2026, 3, 12, 3095" con comas
      $parsedNew  = [System.Version]::Parse(($verNew  -replace ',\s*', '.'))
      $parsedInst = [System.Version]::Parse(($verInst -replace ',\s*', '.'))

      Write-Info "Version instalada : $verInst"
      Write-Info "Version nueva     : $verNew"

      if ($parsedNew -le $parsedInst) {
        Write-Err "La version nueva ($verNew) no es superior a la instalada ($verInst). Abortando."
        Write-Host "Usa --force para forzar la actualizacion igualmente." -ForegroundColor Yellow
        Exit-Cmd 1
      }
      Write-Info "Version superior detectada. Procediendo con la actualizacion..."
    } catch {
      Write-Err "No se pudo comparar versiones: $_"
      Write-Host "Usa --force para omitir la comprobacion de version." -ForegroundColor Yellow
      Exit-Cmd 1
    }
  } elseif ($script:Force) {
    Write-Info "[--force] Comprobacion de version omitida."
    if (Test-Path $destPswm) {
      try {
        $fiInst = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($destPswm)
        Write-Info "Version instalada actualmente : $($fiInst.FileVersion)"
      } catch { }
    }
    Write-Info "Version que se instalara      : $verNew"
  } else {
    Write-Info "No hay instalacion previa. Instalando binarios desde cero..."
    Write-Info "Version que se instalara: $verNew"
  }

  # Guardar estado del servicio
  $svc        = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
  $wasRunning = $svc -and $svc.Status -eq 'Running'

  if ($wasRunning) {
    Write-Info "Deteniendo servicio '$($script:ServiceName)'..."
    try {
      Stop-Service -Name $script:ServiceName -Force -ErrorAction Stop
      # Esperar hasta 10 segundos a que libere el file lock del exe
      $waited = 0
      do {
        Start-Sleep -Milliseconds 500
        $waited += 500
        $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
      } while ($svc -and $svc.Status -ne 'Stopped' -and $waited -lt 10000)
      Write-Success "Servicio detenido."
    } catch {
      Write-Err "No se pudo detener el servicio: $_"
      Exit-Cmd 1
    }
  } elseif ($svc) {
    Write-Info "Servicio '$($script:ServiceName)' existe pero no esta en ejecucion (estado: $($svc.Status))."
  } else {
    Write-Info "Servicio '$($script:ServiceName)' no instalado. Se actualizan solo los binarios."
  }

  # Copiar los tres binarios (todos son copias del mismo exe)
  $destSvc     = Join-Path $destDir 'pswm_svc.exe'
  $destUpdater = Join-Path $destDir 'pswm_updater.exe'
  $copyOk      = $true

  foreach ($entry in @(@{Name='pswm.exe'; Dst=$destPswm}, @{Name='pswm_svc.exe'; Dst=$destSvc}, @{Name='pswm_updater.exe'; Dst=$destUpdater})) {
    try {
      Copy-Item -Path $srcExe -Destination $entry.Dst -Force -ErrorAction Stop
      Write-Success "$($entry.Name) actualizado"
    } catch {
      Write-Err "Error al copiar $($entry.Name): $_"
      $copyOk = $false
      break
    }
  }

  # Restaurar estado del servicio (aunque haya fallo parcial)
  if ($wasRunning) {
    Write-Info "Reanudando servicio '$($script:ServiceName)'..."
    try {
      Start-Service -Name $script:ServiceName -ErrorAction Stop
      Write-Success "Servicio reanudado."
    } catch {
      Write-Err "No se pudo rearrancar el servicio: $_"
      Exit-Cmd 1
    }
  } else {
    Write-Info "El servicio no estaba en ejecucion antes de actualizar; se deja parado."
  }

  if (-not $copyOk) { Exit-Cmd 1 }

  # Leer version final instalada para confirmar
  try {
    $fiDone = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($destPswm)
    $verDone = if ($fiDone.FileVersion) { $fiDone.FileVersion.Trim() } else { '?' }
  } catch { $verDone = '?' }

  Write-Host ""
  Write-Host "=== Actualizacion completada ===" -ForegroundColor Green
  Write-Host "Directorio : $destDir"
  Write-Host "Version    : $verDone"
  Write-Host "Servicio   : $(if ($wasRunning) { 'reanudado' } else { 'sin cambios (estaba parado/no instalado)' })"
  Write-Host ""
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

  # Si se pasó --remove-files, eliminar el directorio de instalación completo
  if ($script:RemoveFiles) {
    Write-Host ""
    Write-Info "Eliminando directorio de instalacion '$($script:InstallDir)'..."
    if (Test-Path $script:InstallDir) {
      try {
        Remove-Item -Path $script:InstallDir -Recurse -Force -ErrorAction Stop
        Write-Success "Directorio '$($script:InstallDir)' eliminado correctamente."
      } catch {
        if ("$_" -match "^EXIT:\d+$") { throw }
        Write-Err "No se pudo eliminar el directorio '$($script:InstallDir)': $_"
        Write-Host "Intentando eliminar solo los .exe..." -ForegroundColor Yellow
        $exesToRemove = @('pswm.exe', 'pswm_svc.exe', 'pswm_updater.exe', 'pswm-tray.exe')
        foreach ($exeName in $exesToRemove) {
          $exePath = Join-Path $script:InstallDir $exeName
          if (Test-Path $exePath) {
            try {
              Remove-Item -Path $exePath -Force -ErrorAction Stop
              Write-Success "Eliminado: $exePath"
            } catch {
              Write-Err "  No se pudo eliminar $exePath : $_"
            }
          }
        }
      }
    } else {
      Write-Info "Directorio '$($script:InstallDir)' ya no existe, nada que eliminar."
    }
  } else {
    Write-Host ""
    Write-Host "Nota: Los archivos en $($script:InstallDir) NO se han eliminado." -ForegroundColor Yellow
    Write-Host "Para eliminarlos: pswm.exe uninstall_service --remove-files" -ForegroundColor Yellow
    Write-Host "  o manualmente: Remove-Item -Recurse -Force '$($script:InstallDir)'" -ForegroundColor Yellow
  }

  Exit-Cmd 0
}

#region Iterate - Bucle operativo completo

function Collect-Facts {
  param([string]$serverUrl = '', [int]$agentId = 0)
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
    $driveTypeMap = @{ 0='Unknown'; 1='NoRoot'; 2='Removable'; 3='Fixed'; 4='Network'; 5='Optical'; 6='Ram' }
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue
    $diskInfo = [ordered]@{}
    foreach ($d in $disks) {
      $letter = ($d.DeviceID -replace ':','').ToUpper()   # "C:" -> "C"
      $sizeGb  = if ($d.Size)      { [math]::Round($d.Size      / 1GB, 2) } else { 0 }
      $freeGb  = if ($d.FreeSpace) { [math]::Round($d.FreeSpace / 1GB, 2) } else { 0 }
      $typeName = if ($driveTypeMap.ContainsKey([int]$d.DriveType)) { $driveTypeMap[[int]$d.DriveType] } else { 'Unknown' }
      $entry = [ordered]@{
        letter     = $d.DeviceID
        label      = if ($d.VolumeName) { $d.VolumeName } else { '' }
        size_gb    = $sizeGb
        free_gb    = $freeGb
        type       = $typeName
        filesystem = if ($d.FileSystem) { $d.FileSystem } else { $null }
        uuid       = if ($d.VolumeSerialNumber) { $d.VolumeSerialNumber } else { $null }
      }
      $diskInfo[$letter] = $entry
    }
    $facts += @{ fact_key = 'disks'; value = ($diskInfo | ConvertTo-Json -Compress -Depth 4); source = 'agent' }
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
      if ($ver) {
        # Normalizar: ps2exe elimina ceros iniciales del 4º segmento (HHmmS, 5 dígitos).
        $__vp = $ver -split '\.'
        if ($__vp.Length -eq 4 -and $__vp[0] -match '^\d{4}$' -and $__vp[3] -match '^\d+$') {
          $__vp[3] = $__vp[3].PadLeft(5, '0')
          $ver = $__vp -join '.'
        }
        $agentVer = $ver
      }
    } catch { }
  }
  $facts += @{ fact_key = 'agent_version'; value = $agentVer; source = 'agent' }

  # Si hay una actualizacion pendiente (updater lanzado este ciclo), usar la version destino
  if ($script:PendingUpdateVersion) {
    $facts = @($facts | ForEach-Object {
      if ($_.fact_key -eq 'agent_version') {
        @{ fact_key = 'agent_version'; value = $script:PendingUpdateVersion; source = 'agent' }
      } else { $_ }
    })
  }

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

  # --- Chocolatey (fact built-in) ---
  try {
    $chocoExe = Get-ChocoExePath
    if ($chocoExe) {
      $chocoVersion  = if ($null -ne ($chocoRaw = (& $chocoExe -v -r 2>$null))) { "$chocoRaw".Trim() } else { $null }
      if (-not $chocoVersion) { $chocoVersion = (Get-Item $chocoExe).VersionInfo.FileVersion }
      $chocoSources  = Get-ChocoSources -chocoExe $chocoExe
      $chocoFeatures = Get-ChocoFeatures -chocoExe $chocoExe

      # Obtener lastUpdate y perfil desde el servidor (best-effort)
      $lastUpdate  = $null
      $profileObj  = $null
      if ($serverUrl -and $agentId -gt 0) {
        try {
          $resolved = Get-ResolvedChocoConfig -serverUrl $serverUrl -agentId $agentId
          if ($resolved) {
            $lastUpdate = $resolved.last_update
            $p = $resolved.profile
            if ($p) {
              $profileObj = @{
                name                = $p.name
                description         = $p.description
                UpdateMode          = $p.update_mode
                UpdateFrecuencyDays = $p.upgrade_frequency_days
                Chocolatey_Policy   = $p.choco_self_policy
              }
            }
          }
        } catch { }
      }

      $chocoConfig = Get-ChocoConfig -chocoExe $chocoExe

      $chocoFact = @{
        installed  = $true
        exe        = $chocoExe
        version    = $chocoVersion
        sources    = $chocoSources
        features   = $chocoFeatures
        config     = $chocoConfig
        lastUpdate = $lastUpdate
        profile    = $profileObj
      }
      $facts += @{ fact_key = 'chocolatey'; value = ($chocoFact | ConvertTo-Json -Compress -Depth 5); source = 'agent' }
    } else {
      $facts += @{ fact_key = 'chocolatey'; value = '{"installed": false}'; source = 'agent' }
    }
  } catch {
    $facts += @{ fact_key = 'chocolatey'; value = '{"installed": false, "error": "' + "$_".Replace('"','\"') + '"}'; source = 'agent' }
  }

  # --- Agent config (configuración aplicada desde el servidor) ---
  if ($script:AgentServerConfig) {
    $facts += @{ fact_key = 'agent_config'; value = ($script:AgentServerConfig | ConvertTo-Json -Compress -Depth 5); source = 'agent' }
  }

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
    $res = Invoke-AgentRestMethod -Uri $uri -Method Post -Body $body
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
    $res = Invoke-AgentRestMethod -Uri $uri -Method Get
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
    if ($script:LogExtendedInfo) { Write-Info "    [EXT-LOG] powershell.exe $($psi.Arguments)" }
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
    if ($script:LogExtendedInfo) { Write-Info "    [EXT-LOG] powershell.exe $($psi.Arguments)" }
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
    Invoke-AgentRestMethod -Uri $uri -Method Post -Body $body | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error reportando script run: $_"
  }
}

function Get-ResolvedChocoConfig([string]$serverUrl, [int]$agentId) {
  <# Obtiene la configuración choco resuelta (merged) para este agente #>
  $uri = "$serverUrl/api/choco/resolved/$agentId"
  try {
    $res = Invoke-AgentRestMethod -Uri $uri -Method Get
    return $res.resolved  # { profile, packages, last_update }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error obteniendo choco config resuelta: $_"
    return $null
  }
}

function Get-ChocoExePath {
  $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
  $exe = if ($chocoCmd) { $chocoCmd.Source } else { $null }
  if (-not $exe) { $exe = "$env:ProgramData\chocolatey\bin\choco.exe" }
  if (Test-Path $exe) { return $exe }
  return $null
}

# ─── Colectores de estado actual ───

function Get-ChocoInstalledPackages([string]$chocoExe) {
  <# Devuelve hashtable: nombre -> version #>
  $result = @{}
  try {
    if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe list -r" }
    $raw = & $chocoExe list -r 2>$null
    foreach ($line in $raw) {
      if ($line -match '^(.+?)\|(.+)$') {
        $result[$matches[1].ToLower()] = $matches[2]
      }
    }
  } catch { Write-Info "Error listando paquetes instalados: $_" }
  return $result
}

function Get-ChocoPinnedPackages([string]$chocoExe) {
  <# Devuelve hashset de nombres de paquetes fijados #>
  $result = @{}
  try {
    if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe pin list -r" }
    $raw = & $chocoExe pin list -r 2>$null
    foreach ($line in $raw) {
      if ($line -match '^(.+?)\|') {
        $result[$matches[1].ToLower()] = $true
      }
    }
  } catch { Write-Info "Error listando paquetes pinned: $_" }
  return $result
}

function Get-ChocoSources([string]$chocoExe) {
  <# Devuelve hashtable: nombre -> { url, priority, disabled } #>
  $result = @{}
  try {
    if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe source list -r" }
    $raw = & $chocoExe source list -r 2>$null
    foreach ($line in $raw) {
      $parts = $line -split '\|'
      if ($parts.Count -ge 2) {
        $result[$parts[0]] = @{
          url      = $parts[1]
          disabled = if ($parts.Count -ge 3 -and $parts[2] -eq 'True') { $true } else { $false }
          priority = if ($parts.Count -ge 5) { [int]$parts[4] } else { 0 }
        }
      }
    }
  } catch { Write-Info "Error listando sources: $_" }
  return $result
}

function Get-ChocoConfig([string]$chocoExe) {
  <# Devuelve hashtable: key -> value #>
  $result = @{}
  try {
    if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe config list -r" }
    $raw = & $chocoExe config list -r 2>$null
    foreach ($line in $raw) {
      # choco config list -r produce: key|value|descripcion
      $parts = $line -split '\|'
      if ($parts.Count -ge 2) {
        $result[$parts[0]] = $parts[1]
      }
    }
  } catch { Write-Info "Error listando config: $_" }
  return $result
}

function Get-ChocoFeatures([string]$chocoExe) {
  <# Devuelve hashtable: nombre -> enabled(bool) #>
  $result = @{}
  try {
    if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe feature list -r" }
    $raw = & $chocoExe feature list -r 2>$null
    foreach ($line in $raw) {
      # choco feature list -r produce: nombre|Enabled|descripcion  o  nombre|Disabled|descripcion
      $parts = $line -split '\|'
      if ($parts.Count -ge 2) {
        $featureName    = $parts[0]
        $featureEnabled = ($parts[1] -eq 'Enabled' -or $parts[1] -eq 'True')
        $result[$featureName] = $featureEnabled
      }
    }
  } catch { Write-Info "Error listando features: $_" }
  return $result
}

function Get-ChocoOutdated([string]$chocoExe, [double]$cacheMaxHours = 16) {
  <#
  .SYNOPSIS
    Devuelve hashtable: nombre -> available_version.
    Limita la llamada a choco.org según $cacheMaxHours.
    El resultado se cachea en $script:ChocoOutdatedCachePath.
  #>
  $cachePath = $script:ChocoOutdatedCachePath

  # Verificar si existe caché válida
  if (Test-Path $cachePath) {
    try {
      $cacheData = Get-Content $cachePath -Raw -ErrorAction Stop | ConvertFrom-Json
      if ($cacheData.timestamp) {
        $cacheAgH = ([DateTime]::UtcNow - [DateTime]::Parse($cacheData.timestamp)).TotalHours
        if ($cacheAgH -lt $cacheMaxHours) {
          Write-Info "  [choco outdated] Usando caché ($([math]::Round($cacheAgH, 1))h de antigüedad, límite ${cacheMaxHours}h). Archivo: $cachePath"
          $result = @{}
          if ($cacheData.packages) {
            foreach ($prop in $cacheData.packages.PSObject.Properties) {
              $result[$prop.Name] = $prop.Value
            }
          }
          return $result
        } else {
          Write-Info "  [choco outdated] Caché expirada ($([math]::Round($cacheAgH, 1))h >= ${cacheMaxHours}h), regenerando..."
        }
      }
    } catch { Write-Info "  [choco outdated] Caché inválida o ilegible, regenerando..." }
  }

  $result = @{}
  try {
    Write-Info "  [choco outdated] Ejecutando 'choco outdated -r' (consulta a servidores Chocolatey)..."
    if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe outdated -r" }
    $raw = & $chocoExe outdated -r 2>$null
    foreach ($line in $raw) {
      $parts = $line -split '\|'
      if ($parts.Count -ge 3) {
        $result[$parts[0].ToLower()] = $parts[2]  # available version
      }
    }
    # Guardar en caché
    try {
      $cacheObj = @{
        timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        packages  = $result
      }
      $cacheObj | ConvertTo-Json -Depth 3 -Compress | Set-Content -Path $cachePath -Encoding UTF8 -Force
      Write-Info "  [choco outdated] $($result.Count) paquetes desactualizados. Caché guardada en: $cachePath"
    } catch { Write-Info "  [choco outdated] Error guardando caché: $_" }
  } catch { Write-Info "Error consultando outdated: $_" }
  return $result
}

# ─── Ejecución por fases (diff-based) ───

function Invoke-ChocoPhased([object]$resolved, [string]$serverUrl, [int]$agentId, [string]$iterationId) {
  <#
  .SYNOPSIS
    Ejecuta la configuración choco resuelta para este agente de forma inteligente:
    1. Recolecta estado actual
    2. Diff y aplica sources
    3. Diff y aplica features
    4. Diff y aplica config (settings)
    5. Desinstalar paquetes marcados como uninstall
    6. Instalar paquetes marcados como install que no están ya instalados
    7. Ajustar pins
    8. Actualizar si la frecuencia lo permite
  #>
  $profile = $resolved.profile
  $packages = @($resolved.packages)

  $chocoExe = Get-ChocoExePath
  if (-not $chocoExe) {
    Write-Info "  Chocolatey no instalado, no se puede procesar configuración."
    return -1
  }

  $hadErrors = $false

  # Recolectar estado actual
  Write-Info "  Recolectando estado actual de Chocolatey..."
  $installedPkgs = Get-ChocoInstalledPackages -chocoExe $chocoExe
  $pinnedPkgs    = Get-ChocoPinnedPackages -chocoExe $chocoExe
  $currentSources  = Get-ChocoSources -chocoExe $chocoExe
  $currentConfig   = Get-ChocoConfig -chocoExe $chocoExe
  $currentFeatures = Get-ChocoFeatures -chocoExe $chocoExe

  Write-Info "  Estado: $($installedPkgs.Count) paquetes, $($pinnedPkgs.Count) pins, $($currentSources.Count) sources, $($currentFeatures.Count) features"

  # ── Fase 1: Sources ──
  if ($profile -and $profile.sources) {
    Write-Info "  Fase 1: Sincronizando sources..."
    $desiredSources = $profile.sources  # PSCustomObject: name -> {url, priority, disabled, user, pass}
    foreach ($srcProp in @($desiredSources.PSObject.Properties)) {
      $srcName = $srcProp.Name
      $desired = $srcProp.Value
      $current = $currentSources[$srcName]
      $needUpdate = $false
      if (-not $current) {
        $needUpdate = $true
        Write-Info "    Source '$srcName': NUEVA"
      } elseif ($current.url -ne $desired.url -or $current.priority -ne $desired.priority -or $current.disabled -ne $desired.disabled) {
        $needUpdate = $true
        Write-Info "    Source '$srcName': ACTUALIZAR"
      }
      if ($needUpdate) {
        $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        try {
          if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe source remove --name=`"$srcName`" -y" }
          & $chocoExe source remove --name="$srcName" -y 2>&1 | Out-Null
          $addArgs = @('source', 'add', "--name=$srcName", "--source=$($desired.url)", '-y')
          if ($desired.priority) { $addArgs += "--priority=$($desired.priority)" }
          if ($desired.user) { $addArgs += "--user=$($desired.user)"; $addArgs += "--password=$($desired.pass)" }
          if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe $($addArgs -join ' ')" }
          & $chocoExe @addArgs 2>&1 | Out-Null
          if ($desired.disabled) {
            if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe source disable --name=`"$srcName`" -y" }
            & $chocoExe source disable --name="$srcName" -y 2>&1 | Out-Null
          }
          Write-Info "    Source '$srcName' aplicada"
        } catch {
          if ("$_" -match "^EXIT:\d+$") { throw }
          Write-Info "    Error aplicando source '$srcName': $_"
          $hadErrors = $true
        }
        $finishedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        Send-ChocoRun -serverUrl $serverUrl -agentId $agentId -packageName "source:$srcName" -actionName 'config' `
          -startedAt $startedAt -finishedAt $finishedAt -exitCode 0 -iterationId $iterationId
      }
    }
  }

  # ── Fase 2: Features ──
  if ($profile -and $profile.features) {
    Write-Info "  Fase 2: Sincronizando features..."
    $desiredFeatures = $profile.features  # PSCustomObject: name -> enabled(bool)
    foreach ($fProp in @($desiredFeatures.PSObject.Properties)) {
      $fName = $fProp.Name
      $desired = [bool]$fProp.Value
      $current = $currentFeatures[$fName]
      if ($null -eq $current -or $current -ne $desired) {
        $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        try {
          if ($desired) {
            Write-Info "    choco feature enable --name=$fName"
            & $chocoExe feature enable --name="$fName" -y 2>&1 | Out-Null
          } else {
            Write-Info "    choco feature disable --name=$fName"
            & $chocoExe feature disable --name="$fName" -y 2>&1 | Out-Null
          }
        } catch {
          if ("$_" -match "^EXIT:\d+$") { throw }
          Write-Info "    Error aplicando feature '$fName': $_"
          $hadErrors = $true
        }
        $finishedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        Send-ChocoRun -serverUrl $serverUrl -agentId $agentId -packageName "feature:$fName" -actionName 'config' `
          -startedAt $startedAt -finishedAt $finishedAt -exitCode 0 -iterationId $iterationId
      }
    }
  }

  # ── Fase 3: Config (settings) ──
  if ($profile -and $profile.settings) {
    Write-Info "  Fase 3: Sincronizando configuración..."
    $desiredSettings = $profile.settings  # PSCustomObject: key -> value
    foreach ($sProp in @($desiredSettings.PSObject.Properties)) {
      $sKey = $sProp.Name
      $desired = $sProp.Value
      $current = $currentConfig[$sKey]
      if ($current -ne $desired) {
        $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        try {
          Write-Info "    choco config set --name=$sKey --value=$desired"
          & $chocoExe config set --name="$sKey" --value="$desired" -y 2>&1 | Out-Null
        } catch {
          if ("$_" -match "^EXIT:\d+$") { throw }
          Write-Info "    Error aplicando config '$sKey': $_"
          $hadErrors = $true
        }
        $finishedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        Send-ChocoRun -serverUrl $serverUrl -agentId $agentId -packageName "config:$sKey" -actionName 'config' `
          -startedAt $startedAt -finishedAt $finishedAt -exitCode 0 -iterationId $iterationId
      }
    }
  }

  # ── Fase 4: Choco self policy ──
  if ($profile -and $profile.choco_self_policy) {
    $selfPolicy = $profile.choco_self_policy
    if ($selfPolicy -eq 'upgrade') {
      $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
      Write-Info "  choco upgrade chocolatey -y"
      if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe upgrade chocolatey -y" }
      try {
        & $chocoExe upgrade chocolatey -y 2>&1 | Out-Null
      } catch { if ("$_" -match "^EXIT:\d+$") { throw }; Write-Info "    Error: $_"; $hadErrors = $true }
      $finishedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
      Send-ChocoRun -serverUrl $serverUrl -agentId $agentId -packageName 'chocolatey' -actionName 'upgrade' `
        -startedAt $startedAt -finishedAt $finishedAt -exitCode 0 -iterationId $iterationId
    } elseif ($selfPolicy -eq 'pin') {
      $isPinned = $pinnedPkgs.ContainsKey('chocolatey')
      if (-not $isPinned) {
        Write-Info "  choco pin add --name=chocolatey"
        if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe pin add --name=chocolatey" }
        try { & $chocoExe pin add --name=chocolatey 2>&1 | Out-Null } catch { if ("$_" -match "^EXIT:\d+$") { throw } }
      }
    }
  }

  # ── Fase 5: Desinstalar paquetes marcados como uninstall ──
  $uninstallPkgs = @($packages | Where-Object { $_.action -eq 'uninstall' })
  $adoptPkgs     = @($packages | Where-Object { $_.action -eq 'adopt' })
  if ($uninstallPkgs.Count -gt 0) {
    Write-Info "  Fase 5: Desinstalando $($uninstallPkgs.Count) paquete(s)..."
    foreach ($pkg in $uninstallPkgs) {
      $pkgNameLower = $pkg.package_name.ToLower()
      if (-not $installedPkgs.ContainsKey($pkgNameLower)) {
        Write-Info "    $($pkg.package_name) no está instalado, saltando"
        continue
      }
      $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
      # Si está pinned, desfijar primero
      if ($pinnedPkgs.ContainsKey($pkgNameLower)) {
        Write-Info "    Desfijando $($pkg.package_name) antes de desinstalar"
        if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe pin remove --name=`"$($pkg.package_name)`" -y" }
        try { & $chocoExe pin remove --name="$($pkg.package_name)" -y 2>&1 | Out-Null } catch { if ("$_" -match "^EXIT:\d+$") { throw } }
      }
      $exitCodeVal = Run-ChocoCmd -chocoExe $chocoExe -cmdArgs "uninstall $($pkg.package_name) -y" `
        -serverUrl $serverUrl -agentId $agentId -packageName $pkg.package_name -action 'uninstall' `
        -startedAt $startedAt -iterationId $iterationId
      if ($exitCodeVal -ne 0) { $hadErrors = $true }
    }
  }

  # ── Fase 6: Instalar paquetes marcados como install que no están instalados ──
  $installPkgs = @($packages | Where-Object { $_.action -eq 'install' })
  if ($installPkgs.Count -gt 0) {
    Write-Info "  Fase 6: Instalando paquetes..."
    foreach ($pkg in $installPkgs) {
      $pkgNameLower = $pkg.package_name.ToLower()
      if ($installedPkgs.ContainsKey($pkgNameLower)) {
        Write-Info "    $($pkg.package_name) ya instalado (v$($installedPkgs[$pkgNameLower])), saltando instalación"
        continue
      }
      $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
      $installArgs = "install $($pkg.package_name) -y"
      if ($pkg.version -and $pkg.version -ne 'latest') { $installArgs += " --version=$($pkg.version)" }
      if ($pkg.params) { $installArgs += " $($pkg.params)" }
      $exitCodeVal = Run-ChocoCmd -chocoExe $chocoExe -cmdArgs $installArgs `
        -serverUrl $serverUrl -agentId $agentId -packageName $pkg.package_name -action 'install' `
        -startedAt $startedAt -iterationId $iterationId
      if ($exitCodeVal -ne 0) { $hadErrors = $true }
      # Pin inmediato si corresponde
      if ($pkg.pinned -and $exitCodeVal -eq 0) {
        if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe pin add --name=`"$($pkg.package_name)`" -y" }
        try { & $chocoExe pin add --name="$($pkg.package_name)" -y 2>&1 | Out-Null } catch { if ("$_" -match "^EXIT:\d+$") { throw } }
      }
    }
  }

  # ── Fase 6b: Forzar versión deseada en paquetes 'adopt' ya instalados ──
  if ($adoptPkgs.Count -gt 0) {
    Write-Info "  Fase 6b: Adoptando $($adoptPkgs.Count) paquete(s) (sólo si ya instalados)..."
    foreach ($pkg in $adoptPkgs) {
      $pkgNameLower = $pkg.package_name.ToLower()
      if (-not $installedPkgs.ContainsKey($pkgNameLower)) {
        Write-Info "    $($pkg.package_name) no está instalado, adoptarlo ignorado"
        continue
      }
      $installedVer = $installedPkgs[$pkgNameLower]
      $desiredVer   = if ($pkg.version -and $pkg.version -ne 'latest') { $pkg.version } else { $null }
      if ($desiredVer -and $installedVer -ne $desiredVer) {
        Write-Info "    Adoptando $($pkg.package_name): instalada v$installedVer → deseada v$desiredVer"
        $startedAt   = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        $installArgs = "install $($pkg.package_name) -y --version=$desiredVer"
        if ($pkg.params) { $installArgs += " $($pkg.params)" }
        $exitCodeVal = Run-ChocoCmd -chocoExe $chocoExe -cmdArgs $installArgs `
          -serverUrl $serverUrl -agentId $agentId -packageName $pkg.package_name -action 'adopt' `
          -startedAt $startedAt -iterationId $iterationId
        if ($exitCodeVal -ne 0) { $hadErrors = $true }
      } else {
        Write-Info "    $($pkg.package_name) adoptado sin cambio de versión (v$installedVer)"
      }
    }
  }

  # ── Fase 7: Ajustar pins en paquetes ya instalados ──
  Write-Info "  Fase 7: Ajustando pins..."
  # Refrescar lista de pins
  $pinnedPkgs = Get-ChocoPinnedPackages -chocoExe $chocoExe
  # Incluye tanto install como adopt (ambos aplican pin si el paquete está instalado)
  $managedInstallOrAdopt = @($installPkgs) + @($adoptPkgs)
  foreach ($pkg in $managedInstallOrAdopt) {
    $pkgNameLower = $pkg.package_name.ToLower()
    if (-not $installedPkgs.ContainsKey($pkgNameLower)) { continue }
    $isPinned = $pinnedPkgs.ContainsKey($pkgNameLower)
    if ($pkg.pinned -and -not $isPinned) {
      Write-Info "    Pin add: $($pkg.package_name)"
      if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe pin add --name=`"$($pkg.package_name)`" -y" }
      try { & $chocoExe pin add --name="$($pkg.package_name)" -y 2>&1 | Out-Null } catch { if ("$_" -match "^EXIT:\d+$") { throw } }
    } elseif (-not $pkg.pinned -and $isPinned) {
      Write-Info "    Pin remove: $($pkg.package_name)"
      if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $chocoExe pin remove --name=`"$($pkg.package_name)`" -y" }
      try { & $chocoExe pin remove --name="$($pkg.package_name)" -y 2>&1 | Out-Null } catch { if ("$_" -match "^EXIT:\d+$") { throw } }
    }
  }

  # ── Fase 8: Consultar outdated (según frecuencia) y actualizar paquetes (cada iteración) ──
  # La frecuencia limita SOLO la ejecución de 'choco outdated -r', no los upgrades.
  # Los upgrades se intentan en cada iteración basándose en choco_outdated_cache.json.
  $freqDays = $profile.upgrade_frequency_days
  if ($freqDays -and $freqDays -ge 1) {
    $outdatedCacheHours = [double]$freqDays * 24
  } else {
    $outdatedCacheHours = 12
  }

  Write-Info "  Fase 8: Consultando paquetes desactualizados (caché máx ${outdatedCacheHours}h, modo: $($profile.update_mode))..."
  $outdated = Get-ChocoOutdated -chocoExe $chocoExe -cacheMaxHours $outdatedCacheHours
  $pinnedPkgs = Get-ChocoPinnedPackages -chocoExe $chocoExe

  if ($profile.update_mode -eq 'disabled') {
    if ($outdated.Count -gt 0) {
      Write-Info "  Fase 8: Modo deshabilitado — $($outdated.Count) paquete(s) con actualización disponible (no se actualizan)"
    } else {
      Write-Info "  Fase 8: Modo deshabilitado — todos los paquetes están al día"
    }
  } else {
    # Refrescar versiones instaladas para comparar con el caché de outdated
    $installedNow = Get-ChocoInstalledPackages -chocoExe $chocoExe

    # Conjunto de paquetes marcados para desinstalar (en minúsculas) — nunca se actualizan
    $uninstallNames = @{}
    foreach ($u in $uninstallPkgs) { $uninstallNames[$u.package_name.ToLower()] = $true }

    # Construir lista de paquetes actualizables: solo aquellos en cache outdated cuya versión instalada actual < disponible
    $toUpdateManaged = @()
    $toUpdateUnmanaged = @()
    foreach ($pkgName in $outdated.Keys) {
      # No actualizar paquetes que están marcados para desinstalar
      if ($uninstallNames.ContainsKey($pkgName)) {
        Write-Info "    $pkgName marcado para desinstalar, se omite la actualización"
        continue
      }
      # Verificar que el paquete esté instalado antes de intentar actualizarlo
      if (-not $installedNow.ContainsKey($pkgName)) {
        Write-Info "    $pkgName no está instalado, se omite la actualización"
        continue
      }
      $isPinned = $pinnedPkgs.ContainsKey($pkgName)
      if ($isPinned) {
        Write-Info "    $pkgName está pinned, no se actualiza (v$($outdated[$pkgName]) disponible)"
        continue
      }
      # Verificar si el paquete sigue necesitando actualización (versión instalada < disponible)
      if ($installedNow.ContainsKey($pkgName)) {
        $installedVer = $installedNow[$pkgName]
        $availableVer = $outdated[$pkgName]
        if ($installedVer -eq $availableVer) {
          Write-Info "    $pkgName ya actualizado a v$installedVer, saltando"
          continue
        }
      }
      # Clasificar como gestionado o no gestionado
      $isManaged = $false
      foreach ($mp in $managedInstallOrAdopt) {
        if ($mp.package_name.ToLower() -eq $pkgName) { $isManaged = $true; break }
      }
      if ($isManaged) {
        $toUpdateManaged += $pkgName
      } else {
        $toUpdateUnmanaged += $pkgName
      }
    }

    if ($profile.update_mode -eq 'managed-only') {
      # Solo actualizar paquetes gestionados
      if ($toUpdateUnmanaged.Count -gt 0) {
        Write-Info "    $($toUpdateUnmanaged.Count) paquete(s) no gestionados con actualización disponible (saltados en modo managed-only)"
      }
      $toUpdate = $toUpdateManaged
    } else {
      # upgrade-all: primero gestionados, luego no gestionados
      $toUpdate = $toUpdateManaged + $toUpdateUnmanaged
    }

    if ($toUpdate.Count -eq 0) {
      Write-Info "  Fase 8: No hay paquetes que actualizar en esta iteración"
    } else {
      Write-Info "  Fase 8: Actualizando $($toUpdate.Count) paquete(s)..."
      $anyUpgraded = $false
      foreach ($pkgName in $toUpdate) {
        $startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
        $upgradeArgs = "upgrade $pkgName -y --no-progress"
        # Si el paquete tiene parámetros definidos en el despliegue, usarlos también al actualizar
        $managedPkg = $managedInstallOrAdopt | Where-Object { $_.package_name.ToLower() -eq $pkgName } | Select-Object -First 1
        if ($managedPkg -and $managedPkg.params) { $upgradeArgs += " $($managedPkg.params)" }
        if ($managedPkg -and $managedPkg.params) {
          Write-Info "    Actualizando $pkgName (con parámetros: $($managedPkg.params))..."
        } else {
          Write-Info "    Actualizando $pkgName..."
        }
        $exitCodeVal = Run-ChocoCmd -chocoExe $chocoExe -cmdArgs $upgradeArgs `
          -serverUrl $serverUrl -agentId $agentId -packageName $pkgName -action 'upgrade' `
          -startedAt $startedAt -iterationId $iterationId
        if ($exitCodeVal -ne 0) { $hadErrors = $true } else { $anyUpgraded = $true }
      }

      # Marcar timestamp de última actualización en servidor (solo si hubo algún upgrade exitoso)
      if ($anyUpgraded) {
        $updateTs = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        try {
          $body = @{ timestamp = $updateTs } | ConvertTo-Json -Compress
          Invoke-AgentRestMethod -Uri "$serverUrl/api/choco/resolved/$agentId/mark-update" -Method Post -Body $body | Out-Null
        } catch {
          if ("$_" -match "^EXIT:\d+$") { throw }
          Write-Info "    Error marcando timestamp de actualización en servidor: $_"
        }
      }
    }
  }

  return $(if ($hadErrors) { 1 } else { 0 })
}

function Run-ChocoCmd(
  [string]$chocoExe, [string]$cmdArgs,
  [string]$serverUrl, [int]$agentId,
  [string]$packageName, [string]$action,
  [string]$startedAt, [string]$iterationId
) {
  <# Ejecuta un comando choco y reporta el resultado al servidor #>
  # Añadir --no-progress si no está presente (reduce ruido en la salida de logs)
  if ($cmdArgs -notmatch '--no-progress') {
    $cmdArgs = "$cmdArgs --no-progress"
  }
  $cmdLine = "$chocoExe $cmdArgs"

  $stdoutVal = ''; $stderrVal = ''; $exitCodeVal = -1; $errorMsg = $null
  try {
    Write-Info "    CMD: $cmdLine"
    if ($script:LogExtendedInfo) { Write-Info "  [EXT-LOG] $cmdLine" }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $chocoExe
    $psi.Arguments = $cmdArgs
    if ($script:ShowChocoWindow) {
      # Modo ventana visible para depuración interactiva
      $psi.UseShellExecute       = $true
      $psi.CreateNoWindow        = $false
      $psi.RedirectStandardOutput = $false
      $psi.RedirectStandardError  = $false
      $proc = [System.Diagnostics.Process]::Start($psi)
      [void]$proc.WaitForExit(600000)
      $exitCodeVal = $proc.ExitCode
      $stdoutVal = '(salida no capturada en modo --show-choco-window)'
    } else {
      $psi.UseShellExecute = $false
      $psi.CreateNoWindow  = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError  = $true
      $proc = [System.Diagnostics.Process]::Start($psi)
      $stdoutVal = $proc.StandardOutput.ReadToEnd()
      $stderrVal = $proc.StandardError.ReadToEnd()
      [void]$proc.WaitForExit(600000) # timeout 10min
      $exitCodeVal = $proc.ExitCode
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    $errorMsg = "$_"
  }

  # Anteponer la línea de comando al stdout para trazabilidad
  $cmdHeader = "CMD: $cmdLine`n$('=' * 70)`n"
  $stdoutVal = $cmdHeader + $stdoutVal

  $maxLen = 50000
  if ($stdoutVal.Length -gt $maxLen) { $stdoutVal = $stdoutVal.Substring(0, $maxLen) + "`n...[truncado]" }
  if ($stderrVal.Length -gt $maxLen) { $stderrVal = $stderrVal.Substring(0, $maxLen) + "`n...[truncado]" }

  $finishedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

  Send-ChocoRun -serverUrl $serverUrl -agentId $agentId `
    -packageName $packageName -actionName $action `
    -startedAt $startedAt -finishedAt $finishedAt `
    -exitCode $exitCodeVal -stdoutText $stdoutVal -stderrText $stderrVal -errorText $errorMsg `
    -iterationId $iterationId

  Write-Info "    $packageName exit code: $exitCodeVal"
  return $exitCodeVal
}

function Send-ChocoRun(
  [string]$serverUrl, [int]$agentId,
  $deploymentGroupId, [string]$packageName, [string]$actionName,
  [string]$startedAt, [string]$finishedAt,
  $exitCode, [string]$stdoutText, [string]$stderrText, [string]$errorText,
  [string]$iterationId
) {
  $body = ConvertTo-Json -Depth 3 -Compress @{
    deployment_group_id = $deploymentGroupId
    agent_id      = $agentId
    package_name  = $packageName
    action        = $actionName
    started_at    = $startedAt
    finished_at   = $finishedAt
    exit_code     = $exitCode
    stdout        = $stdoutText
    stderr        = $stderrText
    error         = $errorText
    iteration_id  = $iterationId
  }
  $uri = "$serverUrl/api/choco/runs"
  try {
    Invoke-AgentRestMethod -Uri $uri -Method Post -Body $body | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error reportando choco run: $_"
  }
}

function Sync-ChocoInventory([string]$serverUrl, [int]$agentId, [object]$resolvedPackages) {
  <# Sincroniza inventario choco con info de managed, available_version, etc. #>
  try {
    $chocoExe = Get-ChocoExePath
    if (-not $chocoExe) {
      Write-Info "Chocolatey no instalado, saltando sincronización de inventario."
      return
    }

    $installed = Get-ChocoInstalledPackages -chocoExe $chocoExe
    $pinned    = Get-ChocoPinnedPackages -chocoExe $chocoExe
    $outdated  = Get-ChocoOutdated -chocoExe $chocoExe

    # Construir lookup de paquetes gestionados
    $managedLookup = @{}
    if ($resolvedPackages) {
      foreach ($rp in $resolvedPackages) {
        $managedLookup[$rp.package_name.ToLower()] = $rp
      }
    }

    $packages = @()
    foreach ($pkgName in $installed.Keys) {
      $managedInfo = $managedLookup[$pkgName]
      # Solo marcar available_version si realmente difiere de la versión instalada
      $availVer = if ($outdated.ContainsKey($pkgName) -and $outdated[$pkgName] -ne $installed[$pkgName]) { $outdated[$pkgName] } else { $null }
      $packages += @{
        name              = $pkgName
        version           = $installed[$pkgName]
        pinned            = if ($pinned.ContainsKey($pkgName)) { $true } else { $false }
        available_version = $availVer
        managed           = if ($managedInfo) { $true } else { $false }
        deploy_params     = if ($managedInfo) { $managedInfo.params } else { $null }
        deploy_action     = if ($managedInfo) { $managedInfo.action } else { $null }
      }
    }

    $body = @{
      agent_id = $agentId
      packages = $packages
    } | ConvertTo-Json -Depth 3 -Compress
    $uri = "$serverUrl/api/choco/agent-packages"
    Invoke-AgentRestMethod -Uri $uri -Method Post -Body $body | Out-Null
    Write-Info "Inventario choco sincronizado: $($packages.Count) paquetes ($($managedLookup.Count) gestionados)"
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

function Invoke-CheckAndApplyUpdate([string]$serverUrl, [int]$agentId = 0, [string]$iterationId = '') {
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

  # Consultar al servidor (incluye agent_id para soportar canal beta)
  $agentIdParam = if ($agentId -and $agentId -gt 0) { "&agent_id=$agentId" } else { "" }
  $uri = "$serverUrl/api/updates/check?current_version=$([System.Uri]::EscapeDataString($currentVersion))$agentIdParam"
  try {
    $checkRes = Invoke-AgentRestMethod -Uri $uri -Method Get
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
    Invoke-AgentWebRequest -Uri $downloadUri -OutFile $tempFile
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

  # Registrar la actualización en la iteración (si hay contexto de iteración)
  if ($agentId -gt 0 -and $iterationId -ne '') {
    Send-UpdateRun -serverUrl $serverUrl -agentId $agentId -iterationId $iterationId `
      -fromVersion $currentVersion -toVersion $serverVersion `
      -myDir $myDir -downloadedFile $tempFile
  }

  # Comprobar si hay una sesión remota activa antes de aplicar la actualización.
  # El proceso remote_session escribe su PID en remote_session.pid mientras está en marcha.
  $rsPidFile = Join-Path "$env:ProgramData\pswm-reborn" 'remote_session.pid'
  if (Test-Path $rsPidFile) {
    try {
      $rsPid = [int](Get-Content $rsPidFile -ErrorAction Stop)
      $rsProc = Get-Process -Id $rsPid -ErrorAction SilentlyContinue
      if ($rsProc) {
        Write-Info "Actualizacion pospuesta: hay una sesion remota activa (PID $rsPid). Se reintentara en la siguiente iteracion."
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return
      }
    } catch {}
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
    # Guardar la version destino para que Collect-Facts (Paso 6) la envie al servidor
    $script:PendingUpdateVersion = $serverVersion
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

function Start-AgentIteration([string]$serverUrl, [int]$agentId, [string]$iterationId) {
  <# Notifica al servidor el inicio de una iteración #>
  try {
    $body = ConvertTo-Json -Compress @{
      iteration_id = $iterationId
      started_at   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    }
    Invoke-AgentRestMethod -Uri "$serverUrl/api/agents/$agentId/iterations" -Method Post -Body $body | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "  [ITER] Error registrando inicio de iteración: $_ (no fatal)"
  }
}

function Finish-AgentIteration([string]$serverUrl, [int]$agentId, [string]$iterationId, [bool]$hadErrors) {
  <# Notifica al servidor el fin de una iteración con estado y timestamp #>
  try {
    $statusVal = if ($hadErrors) { 'failed' } else { 'completed' }
    $body = ConvertTo-Json -Compress @{
      status      = $statusVal
      finished_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
      had_errors  = if ($hadErrors) { 1 } else { 0 }
    }
    Invoke-AgentRestMethod -Uri "$serverUrl/api/agents/$agentId/iterations/$iterationId" -Method Patch -Body $body | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "  [ITER] Error registrando fin de iteración: $_ (no fatal)"
  }
}

function Send-ChocoInstallRun([string]$serverUrl, [int]$agentId, [string]$iterationId, [string]$startedAt, [int]$exitCode, [string]$stdout) {
  <# Registra en script_runs la instalación de Chocolatey con run_type='choco_install' #>
  try {
    $body = ConvertTo-Json -Compress @{
      agent_id     = $agentId
      run_type     = 'choco_install'
      started_at   = $startedAt
      finished_at  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
      exit_code    = $exitCode
      stdout       = if ($stdout.Length -gt 10000) { $stdout.Substring(0, 10000) + "`n...[truncado]" } else { $stdout }
      iteration_id = $iterationId
    }
    Invoke-AgentRestMethod -Uri "$serverUrl/api/deployments/runs" -Method Post -Body $body | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "  [CHOCO-INSTALL] Error registrando instalación en iteración: $_ (no fatal)"
  }
}

function Get-BinaryFileInfo([string]$path) {
  <# Devuelve un hashtable con nombre, ruta, tamaño KB, SHA256 y FileVersion de un binario.
     Devuelve $null si el archivo no existe o hay error. #>
  if (-not (Test-Path $path -PathType Leaf)) { return $null }
  try {
    $fi    = Get-Item $path -ErrorAction Stop
    $hash  = (Get-FileHash -Path $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower()
    $fvi   = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)
    return @{
      nombre    = $fi.Name
      ruta      = $fi.FullName
      tamano_kb = [Math]::Round($fi.Length / 1024, 2)
      sha256    = $hash
      version   = if ($fvi.FileVersion) { $fvi.FileVersion } else { '-' }
    }
  } catch { return $null }
}

function Format-FileInfoLines([string]$label, $info) {
  <# Formatea las líneas de información de un archivo para el stdout. #>
  if (-not $info) { return @("  $label : no encontrado") }
  return @(
    "  $($info.nombre)"
    "    Ruta        : $($info.ruta)"
    "    Tamano      : $($info.tamano_kb) KB"
    "    FileVersion : $($info.version)"
    "    SHA256      : $($info.sha256)"
  )
}

function Send-UpdateRun([string]$serverUrl, [int]$agentId, [string]$iterationId,
                        [string]$fromVersion, [string]$toVersion,
                        [string]$myDir = '', [string]$downloadedFile = '') {
  <# Registra en script_runs la actualización del agente con run_type='agent_update' #>
  try {
    $lines = @()
    $lines += "Actualizacion de agente: v$fromVersion -> v$toVersion"
    $lines += ""
    $lines += "Version anterior : v$fromVersion"
    $lines += "Version nueva    : v$toVersion"

    if ($myDir) {
      $lines += ""
      $lines += "=== Archivos ANTES de la actualizacion ==="
      foreach ($name in @('pswm.exe', 'pswm_svc.exe')) {
        $info = Get-BinaryFileInfo (Join-Path $myDir $name)
        $lines += Format-FileInfoLines $name $info
      }
    }

    if ($downloadedFile) {
      $lines += ""
      $lines += "=== Archivo descargado (nueva version) ==="
      $info = Get-BinaryFileInfo $downloadedFile
      $lines += Format-FileInfoLines (Split-Path -Leaf $downloadedFile) $info
    }

    $stdout = $lines -join "`n"
    $startedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    $body = ConvertTo-Json -Compress @{
      agent_id     = $agentId
      run_type     = 'agent_update'
      started_at   = $startedAt
      finished_at  = $startedAt
      exit_code    = 0
      stdout       = $stdout
      iteration_id = $iterationId
    }
    Invoke-AgentRestMethod -Uri "$serverUrl/api/deployments/runs" -Method Post -Body $body | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "  [UPDATE] Error registrando actualizacion en iteracion: $_ (no fatal)"
  }
}

function Invoke-Iterate {
  <#
  .SYNOPSIS
    Ciclo operativo completo del agente: facts, scripts, choco, status, update check.
  #>
  Write-Info "=== Iniciando iteracion ==="

  # Generar iteration_id unico basado en ticks de fecha/hora actual
  $script:IterationId = [string](Get-Date).Ticks
  $script:IterationStartTime = Get-Date
  Write-Info "Iteration ID: $($script:IterationId)"

  # Flag para rastrear si la iteracion tuvo errores
  $script:IterationHadErrors = $false
  # Resetear flag de actualizacion pendiente (se fija en Invoke-CheckAndApplyUpdate si hay update)
  $script:PendingUpdateVersion = $null

  # Validar config
  $cfg = Get-Config

  # Verificar si el agente esta en estado "queued" (queue_id pero sin agent_id)
  $hasQueueId = $cfg -and $cfg.PSObject.Properties['queue_id'] -and $cfg.queue_id
  $hasAgentId = $cfg -and $cfg.PSObject.Properties['agent_id'] -and $cfg.agent_id

  if ($hasQueueId -and -not $hasAgentId) {
    $srvUrlCheck = Get-ServerUrl
    $qid = [int]$cfg.queue_id
    Write-Info "Agente en cola de aprobacion (queue_id: $qid). Iniciando polling hasta aprobacion/rechazo..."
    Write-Info "Intervalos adaptativos: iter 1-3 -> 5s | iter 4-23 -> 30s | iter 24+ -> 60s"
    Write-Info "Pulse Ctrl+C para cancelar."
    $pollIter = 0
    $approved = $false
    try {
      while ($true) {
        $waitSec = if ($pollIter -lt 3) { 5 } elseif ($pollIter -lt 23) { 30 } else { 60 }
        Write-Info "Esperando ${waitSec}s... (iter $($pollIter + 1))"
        Start-Sleep -Seconds $waitSec
        $pollIter++

        $qst = Get-QueueStatus -serverUrl $srvUrlCheck -id $qid
        if (-not $qst) {
          Write-Host "." -NoNewline
          continue
        }

        Write-Host ""
        Write-Info "Estado actual: $($qst.status)"

        if ($qst.status -eq 'approved') {
          Write-Success "Aprobado! Agent ID: $($qst.agent_id). Actualizando configuracion..."
          $approvedCfg = @{
            agent_id    = $qst.agent_id
            hostname    = $env:COMPUTERNAME
            server_url  = $srvUrlCheck
            approved_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
          }
          Save-Config $approvedCfg
          Write-Success "Configuracion guardada. Continuando con la iteracion..."
          $cfg = Get-Config
          $approved = $true
          break
        } elseif ($qst.status -eq 'rejected') {
          $msg = if ($qst.rejection_message) { $qst.rejection_message } else { "Sin mensaje" }
          Write-Err "Equipo rechazado: $msg. El agente no puede operar."
          Exit-Cmd 4
        }
        # Si sigue pending, continua el bucle
      }
    } catch {
      if ("$_" -match "^EXIT:\d+$") { throw }
      Write-Err "Error durante polling de aprobacion: $_"
      Exit-Cmd 1
    }
    if (-not $approved) { Exit-Cmd 0 }
  }

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

  # ---- PRE-PASO: Sincronización de reloj (antes de generar JWT) ----
  try {
    Invoke-TimeSync -serverUrl $srvUrl -agentId $agentId
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "[TimeSync] Error en sincronización de reloj: $_ (continuando)"
  }

  # ---- PRE-PASO: Asegurar que la clave pública está registrada en el servidor ----
  # Register-AgentKey sólo actualiza la BD si la clave almacenada es nula o inválida
  # (retorna $false silenciosamente cuando ya existe clave válida).
  Register-AgentKey -serverUrl $srvUrl -agentId $agentId | Out-Null

  # ---- PRE-PASO: Generar JWT RS256 para autenticar todas las llamadas ----
  try {
    $jwt = New-AgentJWT -agentId $agentId
    Write-Success "JWT RS256 generado (TTL: 90 min)"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error generando JWT del agente: $_. No se puede continuar."
    Exit-Cmd 5
  }

  Start-AgentIteration -serverUrl $srvUrl -agentId $agentId -iterationId $script:IterationId

  # ---- PRE-PASO: Consultar configuración del servidor ----
  try {
    $script:AgentServerConfig = Get-AgentConfig -serverUrl $srvUrl -agentId $agentId
    $cfgInterval = $script:AgentServerConfig.iteration_interval_minutes
    Write-Success "Config del servidor obtenida (intervalo: ${cfgInterval} min)"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error consultando config del servidor: $_ (continuando con defaults)"
    $script:AgentServerConfig = [PSCustomObject]@{ iteration_interval_minutes = 90 }
  }

  # ---- PASO 1: Facts ----
  Write-Info "Paso 1/4: Recopilando y enviando facts..."
  try {
    $facts = Collect-Facts -serverUrl $srvUrl -agentId $agentId
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
              Invoke-AgentRestMethod -Uri $factUri -Method Post -Body $factBody | Out-Null
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

  # ---- Auto-instalar Chocolatey si no está disponible ----
  try {
    if (-not (Get-ChocoExePath)) {
      Write-Info "Chocolatey no encontrado. Intentando instalar desde configuración del servidor..."
      $chocoInstallStartedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
      $chocoScriptUri = "$srvUrl/api/settings/choco-install-script?agent_id=$agentId"
      $scriptRes = Invoke-AgentRestMethod -Uri $chocoScriptUri -Method Get
      if ($scriptRes.script -and $scriptRes.script.Trim()) {
        $tmpScript = [System.IO.Path]::GetTempFileName() + '.ps1'
        [System.IO.File]::WriteAllText($tmpScript, $scriptRes.script, [System.Text.Encoding]::UTF8)
        Write-Info "  Ejecutando script de instalación de Chocolatey..."
        $psiChoco = New-Object System.Diagnostics.ProcessStartInfo
        $psiChoco.FileName  = 'powershell.exe'
        $psiChoco.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$tmpScript`""
        if ($script:LogExtendedInfo) { Write-Info "    [EXT-LOG] powershell.exe $($psiChoco.Arguments)" }
        $psiChoco.UseShellExecute = $false; $psiChoco.CreateNoWindow = $true
        $psiChoco.RedirectStandardOutput = $true; $psiChoco.RedirectStandardError = $true
        $procChoco = [System.Diagnostics.Process]::Start($psiChoco)
        $chocoOut = $procChoco.StandardOutput.ReadToEnd()
        $chocoErr = $procChoco.StandardError.ReadToEnd()
        [void]$procChoco.WaitForExit(120000)
        $chocoInstallExitCode = $procChoco.ExitCode
        Write-Info "  Instalación Chocolatey exit code: $chocoInstallExitCode"
        if ($chocoOut) { Write-Info "  STDOUT: $($chocoOut.Substring(0, [Math]::Min($chocoOut.Length, 500)))" }
        if ($chocoErr) { Write-Info "  STDERR: $($chocoErr.Substring(0, [Math]::Min($chocoErr.Length, 200)))" }
        # Refrescar PATH para que choco.exe sea encontrado sin reiniciar sesión
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH','User')
        try { Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue } catch {}
        $chocoInstalled = Get-ChocoExePath
        if ($chocoInstalled) { Write-Success "  Chocolatey instalado correctamente." }
        else {
          Write-Info "  No se pudo verificar la instalación de Chocolatey tras ejecutar el script."
          $script:IterationHadErrors = $true
        }
        # Registrar la instalación en la iteración con icono distinto
        $chocoInstallOutput = "📦 Instalación de Chocolatey`n$('=' * 60)`nCMD: powershell.exe $($psiChoco.Arguments)`n$chocoOut"
        if ($chocoErr) { $chocoInstallOutput += "`nSTDERR:`n$chocoErr" }
        Send-ChocoInstallRun -serverUrl $srvUrl -agentId $agentId -iterationId $script:IterationId `
          -startedAt $chocoInstallStartedAt -exitCode $chocoInstallExitCode -stdout $chocoInstallOutput
      } else {
        Write-Info "  No hay script de instalación de Chocolatey configurado en el servidor."
      }
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error intentando instalar Chocolatey: $_ (continuando)"
  }

  # ---- PASO 3: Chocolatey (config resuelta + ejecución por fases) ----
  Write-Info "Paso 3/5: Obteniendo configuración Chocolatey resuelta..."
  $resolvedPackages = $null
  try {
    $resolved = Get-ResolvedChocoConfig -serverUrl $srvUrl -agentId $agentId
    if ($resolved) {
      $pkgCount = if ($resolved.packages) { @($resolved.packages).Count } else { 0 }
      $hasProfile = if ($resolved.profile) { "perfil: $($resolved.profile.update_mode)" } else { "sin perfil" }
      Write-Info "  Config resuelta: $pkgCount paquete(s), $hasProfile"
      $resolvedPackages = $resolved.packages
      $exitC = Invoke-ChocoPhased -resolved $resolved -serverUrl $srvUrl -agentId $agentId -iterationId $script:IterationId
      Write-Info "  Resultado choco: $(if ($exitC -eq 0) { 'OK' } else { "con errores (code $exitC)" })"
      if ($exitC -ne 0) { $script:IterationHadErrors = $true }
      Write-Success "Configuración Chocolatey procesada"
    } else {
      Write-Info "  No hay configuración Chocolatey para este agente"
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error procesando choco: $_ (continuando)"
    $script:IterationHadErrors = $true
  }

  # ---- PASO 4: Sincronizar inventario Chocolatey ----
  Write-Info "Paso 4/5: Sincronizando inventario Chocolatey..."
  try {
    Sync-ChocoInventory -serverUrl $srvUrl -agentId $agentId -resolvedPackages $resolvedPackages
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error sincronizando inventario choco: $_ (continuando)"
    $script:IterationHadErrors = $true
  }

  # ---- PASO 5: Check update ----
  Write-Info "Paso 5/5: Comprobando actualizaciones..."
  try {
    Invoke-CheckAndApplyUpdate -serverUrl $srvUrl -agentId $agentId -iterationId $script:IterationId
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

  # ---- PASO 6: Re-generar facts post-iteración ----
  # Re-enviamos los facts built-in para reflejar cualquier cambio producido durante la iteración
  Write-Info "Paso 6: Re-generando facts (post-iteracion)..."
  try {
    $factsPost = Collect-Facts -serverUrl $srvUrl -agentId $agentId
    $resPost = Send-Facts -serverUrl $srvUrl -agentId $agentId -facts $factsPost
    if ($resPost) { Write-Success "Facts post-iteracion enviados: $($resPost.count) registros" }
    # Re-ejecutar scripts de tipo fact si los hubo en esta iteracion
    if ($null -ne $deployments -and $deployments.Count -gt 0) {
      $factDepsPost = @($deployments | Where-Object { $_.script_type -eq 'fact' -and $_.enabled })
      foreach ($dep in $factDepsPost) {
        $depHash = @{ id=$dep.id; script_id=$dep.script_id; content=$dep.content; script_type='fact'; name=$dep.name }
        $fr = Execute-ScriptWithOutput -deployment $depHash -serverUrl $srvUrl -agentId $agentId -iterationId $script:IterationId
        if ($fr.ExitCode -eq 0 -and $fr.Stdout) {
          try {
            $fkey = ($dep.name -replace '[^a-zA-Z0-9_]','_').ToLower()
            $fb = ConvertTo-Json -Depth 5 -Compress @{ facts = @(@{ fact_key=$fkey; value=$fr.Stdout.Trim(); source='script'; script_name=$dep.name }) }
            Invoke-AgentRestMethod -Uri "$srvUrl/api/facts/$agentId" -Method Post -Body $fb | Out-Null
            Write-Success "    Fact script post-iter actualizado: $fkey"
          } catch { if ("$_" -match "^EXIT:\d+$") { throw } }
        }
      }
    }
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Info "Error en facts post-iteracion: $_ (continuando)"
  }

  # Calcular duracion
  $duration = (Get-Date) - $script:IterationStartTime
  $durStr = ''
  if ($duration.Hours -gt 0) { $durStr += "$($duration.Hours)h " }
  if ($duration.Minutes -gt 0 -or $duration.Hours -gt 0) { $durStr += "$($duration.Minutes)m " }
  $durStr += "$($duration.Seconds)seg"

  # Notificar fin de iteracion al servidor
  Finish-AgentIteration -serverUrl $srvUrl -agentId $agentId -iterationId $script:IterationId -hadErrors $script:IterationHadErrors

  # Refrescar agent_config.json post-iteración (el servidor puede haber activado remote_session tras 3 errores)
  try {
    Get-AgentConfig -serverUrl $srvUrl -agentId $agentId | Out-Null
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
  }

  Write-Success "=== Iteracion completada en $durStr ==="
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

#region Remote Session

function Invoke-RemoteSession {
  <#
  .SYNOPSIS
    Cliente WebSocket para sesiones remotas.
    Conecta al servidor via WS, lanza powershell.exe con stdin/stdout/stderr redirigidos
    y hace de puente entre el WebSocket y el proceso shell.
    Reconecta automaticamente cada 15s si pierde conexion.
  #>
  Write-Info "=== Iniciando Remote Session ==="

  $cfg = Get-Config
  if (-not $cfg -or -not $cfg.PSObject.Properties['agent_id'] -or -not $cfg.agent_id) {
    Write-Err "El agente no esta registrado. No se puede iniciar sesion remota."
    Exit-Cmd 1
  }

  $agentId = [int]$cfg.agent_id
  $srvUrl  = Get-ServerUrl

  Write-Info "Agent ID: $agentId | Server: $srvUrl"

  # Build WebSocket URL
  $wsUrl = $srvUrl -replace '^http', 'ws'
  $wsUrl = "$wsUrl/ws/remote-session"

  # Generate JWT for auth
  try {
    $jwt = New-AgentJWT -agentId $agentId
    Write-Success "JWT RS256 generado"
  } catch {
    if ("$_" -match "^EXIT:\d+$") { throw }
    Write-Err "Error generando JWT: $_"
    Exit-Cmd 5
  }

  # PID file for lifecycle management
  $pidFile = Join-Path "$env:ProgramData\pswm-reborn" 'remote_session.pid'
  try { [IO.File]::WriteAllText($pidFile, "$PID") } catch {}

  # Main reconnection loop
  $reconnectDelay = 15
  while ($true) {
    $shellProc = $null
    $wsClient = $null
    $wsDisconnected = $false  # true = WS lost, false = shell exited normally
    try {
      # Connect WebSocket
      $wsClient = New-Object System.Net.WebSockets.ClientWebSocket
      $wsClient.Options.SetRequestHeader('Authorization', "Bearer $jwt")
      $cts = New-Object System.Threading.CancellationTokenSource

      Write-Info "Conectando a $wsUrl ..."
      $connectTask = $wsClient.ConnectAsync([Uri]$wsUrl, $cts.Token)
      $connectTask.Wait(30000)

      if ($wsClient.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        Write-Err "No se pudo conectar al WebSocket (estado: $($wsClient.State))"
        throw "connection_failed"
      }

      Write-Success "WebSocket conectado"

      # Send agent:register
      $regMsg = @{ type = 'agent:register'; payload = @{ agentId = $agentId; hostname = $env:COMPUTERNAME } } | ConvertTo-Json -Compress
      $regBytes = [System.Text.Encoding]::UTF8.GetBytes($regMsg)
      $sendTask = $wsClient.SendAsync(
        (New-Object System.ArraySegment[byte](,$regBytes)),
        [System.Net.WebSockets.WebSocketMessageType]::Text,
        $true, $cts.Token)
      $sendTask.Wait(5000)

      # Start PowerShell child process
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = 'powershell.exe'
      # Prompt loop: PowerShell con stdin redirigido no emite prompt automaticamente.
      # Usamos -EncodedCommand para evitar problemas de comillas.
      $shellScript = 'while($true){[Console]::Out.Write("PS "+(Get-Location).Path+"> ");[Console]::Out.Flush();$l=[Console]::In.ReadLine();if($null -eq $l -or $l -eq "exit"){break};if($l.Trim() -eq ""){continue};try{Invoke-Expression $l}catch{Write-Host ("ERROR: "+$_.Exception.Message) -ForegroundColor Red}}'
      $psi.Arguments = "-NoProfile -NoLogo -EncodedCommand " + [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($shellScript))
      $psi.UseShellExecute = $false
      $psi.CreateNoWindow = $true
      $psi.RedirectStandardInput = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      $shellProc = [System.Diagnostics.Process]::Start($psi)

      Write-Info "Shell PowerShell iniciado (PID: $($shellProc.Id))"

      # Background job: read shell stdout and send to WS
      $outputBuffer = New-Object System.Text.StringBuilder
      $lastPing = [DateTime]::UtcNow
      $lastActivity = [DateTime]::UtcNow
      $receiveBuffer = New-Object byte[] 65536

      # Start async stdout/stderr reading (BaseStream: captura prompts sin newline)
      $stdoutBuf = New-Object byte[] 4096
      $stderrBuf = New-Object byte[] 4096
      $stdoutTask = $shellProc.StandardOutput.BaseStream.ReadAsync($stdoutBuf, 0, $stdoutBuf.Length)
      $stderrTask = $shellProc.StandardError.BaseStream.ReadAsync($stderrBuf, 0, $stderrBuf.Length)

      # Start WS receive task ONCE — never cancel it (canceling ClientWebSocket aborts the socket)
      $seg = New-Object System.ArraySegment[byte](,$receiveBuffer)
      $recvTask = $wsClient.ReceiveAsync($seg, [System.Threading.CancellationToken]::None)

      # Main relay loop
      while ($wsClient.State -eq [System.Net.WebSockets.WebSocketState]::Open -and -not $shellProc.HasExited) {
        $didWork = $false

        # 1. Read from WS (non-blocking: Wait(0) returns immediately without canceling)
        try {
          if ($recvTask.Wait(0)) {
            if ($recvTask.IsFaulted) {
              Write-Info "Error en recepcion WS"
              $wsDisconnected = $true
              break
            }
            $result = $recvTask.Result
            if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
              Write-Info "WebSocket cerrado por servidor"
              $wsDisconnected = $true
              break
            }
            if ($result.Count -gt 0) {
              $msgText = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $result.Count)
              $lastActivity = [DateTime]::UtcNow
              try {
                $msg = $msgText | ConvertFrom-Json
                switch ($msg.type) {
                  'server:input' {
                    if ($msg.payload -and $msg.payload.data -and -not $shellProc.HasExited) {
                      $shellProc.StandardInput.Write($msg.payload.data)
                      $shellProc.StandardInput.Flush()
                    }
                  }
                  'server:resize' {
                    # PowerShell console resize - best effort
                  }
                  'server:pong' {
                    # Heartbeat response
                  }
                  'server:disconnect' {
                    $dcReason = if ($msg.payload -and $msg.payload.reason) { $msg.payload.reason } else { 'unknown' }
                    Write-Info "Servidor solicita desconexion (razon: $dcReason)"
                    if ($dcReason -eq 'remote_session_disabled') {
                      # Update local agent_config.json so we don't reconnect
                      $cfgPath = Join-Path "$env:ProgramData\pswm-reborn" 'agent_config.json'
                      if (Test-Path $cfgPath) {
                        try {
                          $localCfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
                          $localCfg.remote_session_enabled = $false
                          $localCfg | ConvertTo-Json -Depth 10 | Set-Content $cfgPath -Encoding UTF8
                          Write-Info "agent_config.json actualizado: remote_session_enabled = false"
                        } catch { Write-Warn "No se pudo actualizar agent_config.json: $_" }
                      }
                    }
                    $wsDisconnected = $true
                    break
                  }
                  'server:session_start' {
                    Write-Info "Sesion iniciada (session_id: $($msg.payload.sessionId))"
                  }
                  'server:session_end' {
                    Write-Info "Sesion terminada (session_id: $($msg.payload.sessionId))"
                  }
                }
              } catch {}
              $didWork = $true
            }
            # Rearm receive for next message
            $seg = New-Object System.ArraySegment[byte](,$receiveBuffer)
            $recvTask = $wsClient.ReceiveAsync($seg, [System.Threading.CancellationToken]::None)
          }
        } catch {
          $wsDisconnected = $true
          break
        }

        # 2. Read stdout from shell
        if ($stdoutTask.IsCompleted) {
          $n = $stdoutTask.Result
          if ($n -gt 0) {
            $text = [System.Text.Encoding]::UTF8.GetString($stdoutBuf, 0, $n)
            $outPayload = @{ type = 'agent:output'; payload = @{ data = $text } } | ConvertTo-Json -Compress
            $outBytes = [System.Text.Encoding]::UTF8.GetBytes($outPayload)
            try {
              $sendT = $wsClient.SendAsync(
                (New-Object System.ArraySegment[byte](,$outBytes)),
                [System.Net.WebSockets.WebSocketMessageType]::Text,
                $true, $cts.Token)
              $sendT.Wait(5000)
            } catch {}
            $lastActivity = [DateTime]::UtcNow
            $didWork = $true
          }
          if (-not $shellProc.HasExited) {
            $stdoutBuf = New-Object byte[] 4096
            $stdoutTask = $shellProc.StandardOutput.BaseStream.ReadAsync($stdoutBuf, 0, $stdoutBuf.Length)
          }
        }

        # 3. Read stderr from shell
        if ($stderrTask.IsCompleted) {
          $n2 = $stderrTask.Result
          if ($n2 -gt 0) {
            $errText = [System.Text.Encoding]::UTF8.GetString($stderrBuf, 0, $n2)
            $errPayload = @{ type = 'agent:output'; payload = @{ data = $errText } } | ConvertTo-Json -Compress
            $errBytes = [System.Text.Encoding]::UTF8.GetBytes($errPayload)
            try {
              $sendE = $wsClient.SendAsync(
                (New-Object System.ArraySegment[byte](,$errBytes)),
                [System.Net.WebSockets.WebSocketMessageType]::Text,
                $true, $cts.Token)
              $sendE.Wait(5000)
            } catch {}
            $lastActivity = [DateTime]::UtcNow
            $didWork = $true
          }
          if (-not $shellProc.HasExited) {
            $stderrBuf = New-Object byte[] 4096
            $stderrTask = $shellProc.StandardError.BaseStream.ReadAsync($stderrBuf, 0, $stderrBuf.Length)
          }
        }

        # 4. Send heartbeat ping every 30s
        if (([DateTime]::UtcNow - $lastPing).TotalSeconds -ge 30) {
          $pingMsg = @{ type = 'agent:ping'; payload = @{} } | ConvertTo-Json -Compress
          $pingBytes = [System.Text.Encoding]::UTF8.GetBytes($pingMsg)
          try {
            $pingT = $wsClient.SendAsync(
              (New-Object System.ArraySegment[byte](,$pingBytes)),
              [System.Net.WebSockets.WebSocketMessageType]::Text,
              $true, $cts.Token)
            $pingT.Wait(5000)
          } catch {}
          $lastPing = [DateTime]::UtcNow
        }

        # 5. Check inactivity timeout (40s)
        if (([DateTime]::UtcNow - $lastActivity).TotalSeconds -ge 40) {
          Write-Info "Timeout de inactividad WS (40s sin trafico). Reconectando..."
          $wsDisconnected = $true
          break
        }

        if (-not $didWork) {
          Start-Sleep -Milliseconds 50
        }
      }

      # Shell exited notification
      if ($shellProc.HasExited) {
        $exitMsg = @{ type = 'agent:exit'; payload = @{ exitCode = $shellProc.ExitCode } } | ConvertTo-Json -Compress
        $exitBytes = [System.Text.Encoding]::UTF8.GetBytes($exitMsg)
        try {
          $exitT = $wsClient.SendAsync(
            (New-Object System.ArraySegment[byte](,$exitBytes)),
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true, $cts.Token)
          $exitT.Wait(5000)
        } catch {}
      }

    } catch {
      if ("$_" -match "^EXIT:\d+$") { throw }
      Write-Info "Error en sesion remota: $_ (reintentando en ${reconnectDelay}s)"
      $wsDisconnected = $true
    } finally {
      # Cleanup
      if ($shellProc -and -not $shellProc.HasExited) {
        try { $shellProc.Kill() } catch {}
      }
      if ($wsClient -and $wsClient.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
        try {
          $closeCts = New-Object System.Threading.CancellationTokenSource(5000)
          $wsClient.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'closing', $closeCts.Token).Wait(5000)
        } catch {}
      }
      if ($wsClient) { try { $wsClient.Dispose() } catch {} }
    }

    # Check if we should still be running (check agent_config.json)
    $cfgFile = Join-Path "$env:ProgramData\pswm-reborn" 'agent_config.json'
    $shouldRun = $false
    if (Test-Path $cfgFile) {
      try {
        $acfg = Get-Content $cfgFile -Raw | ConvertFrom-Json
        if ($acfg.remote_session_enabled -eq $true) { $shouldRun = $true }
      } catch {}
    }

    if (-not $shouldRun) {
      Write-Info "remote_session_enabled = false. Terminando proceso remote_session."
      break
    }

    # Regenerate JWT before reconnecting (it may have expired)
    try {
      $jwt = New-AgentJWT -agentId $agentId
    } catch {
      if ("$_" -match "^EXIT:\d+$") { throw }
      Write-Info "Error regenerando JWT: $_ (reintentando igualmente)"
    }

    Write-Info "Reconectando en ${reconnectDelay}s..."
    if ($wsDisconnected) {
      Start-Sleep -Seconds $reconnectDelay
    }
  }

  # Cleanup PID file
  try { if (Test-Path $pidFile) { Remove-Item $pidFile -Force } } catch {}
  Write-Info "=== Remote Session finalizada ==="
  Exit-Cmd 0
}

#endregion Remote Session

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

function Invoke-ResetTimersLock {
  <#
  .SYNOPSIS
    Elimina la caché de 'choco outdated -r' y el lock local de última actualización Chocolatey.
    Esto fuerza que en la próxima iteración se vuelva a ejecutar 'choco outdated -r'
    (la caché controla la frecuencia de consulta de paquetes desactualizados).
  #>
  Write-Host ""
  Write-Host "=== reset_timers_lock ===" -ForegroundColor Cyan
  Write-Host ""

  # 1. Caché de 'choco outdated -r'
  $cachePath = $script:ChocoOutdatedCachePath
  Write-Host "1. Caché choco outdated: $cachePath" -ForegroundColor Yellow
  if (Test-Path $cachePath) {
    try {
      $cacheData = Get-Content $cachePath -Raw -ErrorAction Stop | ConvertFrom-Json
      Write-Host "   Timestamp caché  : $($cacheData.timestamp)" -ForegroundColor Gray
      Write-Host "   Paquetes cacheados: $(@($cacheData.packages.PSObject.Properties).Count)" -ForegroundColor Gray
      Remove-Item $cachePath -Force -ErrorAction Stop
      Write-Host "   ✓ Eliminado" -ForegroundColor Green
    } catch {
      Write-Host "   ✗ Error leyendo/eliminando: $_" -ForegroundColor Red
    }
  } else {
    Write-Host "   (no existe, nada que eliminar)" -ForegroundColor DarkGray
  }

  Write-Host ""

  # 2. Lock local de última actualización Chocolatey
  $lockPath = $script:ChocoUpdateLockPath
  Write-Host "2. Lock local actualización Choco: $lockPath" -ForegroundColor Yellow
  if (Test-Path $lockPath) {
    try {
      $lockData = Get-Content $lockPath -Raw -ErrorAction Stop | ConvertFrom-Json
      Write-Host "   Timestamp lock    : $($lockData.timestamp)" -ForegroundColor Gray
      if ($lockData.started_at) {
        Write-Host "   Inicio proceso    : $($lockData.started_at)" -ForegroundColor Gray
      }
      Remove-Item $lockPath -Force -ErrorAction Stop
      Write-Host "   ✓ Eliminado" -ForegroundColor Green
    } catch {
      Write-Host "   ✗ Error leyendo/eliminando: $_" -ForegroundColor Red
    }
  } else {
    Write-Host "   (no existe, nada que eliminar)" -ForegroundColor DarkGray
  }

  Write-Host ""
  Write-Host "Resultado: en la próxima iteración se ejecutará 'choco outdated -r'" -ForegroundColor Cyan
  Write-Host "           y el proceso de actualización de paquetes Chocolatey." -ForegroundColor Cyan
  Write-Host ""
  Exit-Cmd 0
}

function Invoke-Help {
  Write-Host @"

psWinModel Reborn Agent - CLI v$script:Version

Uso: pswm.exe <comando> [opciones]

Comandos disponibles:
  reg_init_check      Registrar agente via Cola de Aprobacion (genera claves si necesario)
                      Sin --install: hace polling hasta que el admin apruebe/rechace (intervalos adaptativos)
                      Con --install: instala el servicio y sale. El servicio verificara la aprobacion en cada iterate.
  reg_token           Registrar agente via Token de Registro (uso: reg_token -Token "xxx" o reg_token "xxx")
                      Opcion: --install  Como en reg_init_check, instala el servicio tras registro exitoso
  check_status        Verificar conectividad y estado del agente
  view_config         Mostrar configuracion actual (config.json)
  archive_config      Archivar config + claves a ZIP y eliminar originales
  restore_config      Restaurar config desde ZIP (solo si no existen archivos locales)
                      Opcion: --force  Sobreescribe archivos existentes (crea backup _autosave)
  gencert             Generar/regenerar par de claves RSA
  install             Instalar agente como servicio Windows (requiere .exe y admin)
                      Configura el servicio en inicio automatico (Automatic) y lo arranca
  update              Actualizar binarios del agente en el directorio de instalacion (requiere .exe y admin)
                      Compara versiones: solo instala si la nueva es superior a la instalada
                      Si el servicio estaba en ejecucion lo para antes y lo reanuda al terminar
                      Si no estaba en ejecucion solo actualiza los binarios, no lo arranca
                      Opcion: --force  Omite la comprobacion de version (permite downgrade o reinstalar misma version)
  uninstall_service   Desinstalar servicio Windows del agente
                      Opcion: --remove-files  Elimina el directorio de instalacion completo
  svc                 Bucle de servicio (uso interno, ejecutado por el servicio)
  iterate             Ciclo operativo: recopila facts, ejecuta scripts/choco pendientes, sincroniza, check update
                      El servidor controla el modo de actualizacion:
                        - disabled: no se proporcionan actualizaciones
                        - upgrade: solo actualiza si la version del servidor es mayor
                        - mandatory: fuerza la version publicada (permite downgrade)
                      Opciones especificas de iterate:
                        --show-choco-window     Muestra las ventanas de choco.exe en primer plano (foreground).
                                                Util para depuracion interactiva o ver que ocurre si choco se
                                                queda colgado. En este modo NO se captura stdout/stderr de choco.
                        --log-extended-info     Registra en el log cada invocacion de powershell.exe y choco.exe
                                                con su linea de comando completa y parametros.
  remote_session      Inicia cliente WebSocket para sesiones remotas interactivas.
                      Conecta al servidor, lanza powershell.exe y hace relay stdin/stdout via WS.
                      Reconecta automaticamente cada 15s si pierde conexion.
                      Gestionado automaticamente por el servicio (svc) segun agent_config.json.
  reset_timers_lock   Elimina la cache de 'choco outdated -r' y el lock local de actualizacion.
                      Fuerza que en la proxima iteracion se re-ejecute la consulta de
                      actualizaciones y el proceso de upgrade de paquetes Chocolatey.
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
  pswm.exe restore_config "backup-20260117" --force
  pswm.exe check_status
  pswm.exe view_config
  pswm.exe install
  pswm.exe update
  pswm.exe update --force
  pswm.exe uninstall_service
  pswm.exe uninstall_service --remove-files
  pswm.exe gencert -KeySize 4096
  pswm.exe iterate
  pswm.exe iterate --show-choco-window
  pswm.exe iterate --log-extended-info
  pswm.exe iterate --show-choco-window --log-extended-info
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
  "update"            { Invoke-UpdateBinaries }
  "uninstall_service" { Invoke-UninstallService }
  "iterate"           { Invoke-Iterate }
  "remote_session"    { Invoke-RemoteSession }
  "reset_timers_lock" { Invoke-ResetTimersLock }
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
