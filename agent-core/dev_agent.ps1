<#
.SYNOPSIS
  Script de desarrollo para el agente: genera par de claves RSA, publica la entrada en la cola y hace polling hasta aprobación.

.DESCRIPTION
  - Genera RSA private/public PEM (usando .NET APIs, requiere PowerShell 7+).
  - Comprueba conectividad con el servidor (Test-NetConnection).
  - Hace POST a /api/agents/queue con hostname y public_key.
  - Hace polling a /api/agents/queue/:id/status hasta obtener 'approved' o 'rejected'.

.EXAMPLE
  .\dev_agent.ps1 -ServerUrl http://localhost:3000 -Hostname my-test-agent
#>

param(
  [string]$ServerUrl = 'http://localhost:3000',
  [string]$Hostname = $env:COMPUTERNAME,
  [string]$OutDir = "$env:ProgramData\pswm-reborn",
  [int]$KeySize = 2048,
  [int]$PollIntervalSeconds = 5
)

Set-StrictMode -Version Latest

# Decide implementation based on PowerShell version
$useLegacyRsa = $false
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Host "PowerShell <7 detectado: usando ruta legacy RSACryptoServiceProvider para generación de claves.";
  $useLegacyRsa = $true
} else {
  Write-Host "PowerShell 7+ detectado: usando APIs modernas para generación de claves.";
}

function Wrap-Base64($s) {
  $out = ""
  for ($i=0; $i -lt $s.Length; $i += 64) {
    $len = [Math]::Min(64, $s.Length - $i)
    $out += $s.Substring($i, $len) + "`n"
  }
  return $out.TrimEnd("`n")
}

function New-RsaKeyPairPem([int]$bits, [string]$privatePath, [string]$publicPath) {
  if (-not $useLegacyRsa) {
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
    # Legacy implementation for PowerShell 5.1 using RSACryptoServiceProvider
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

      # helper to build sequence from parts
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

      # Build only the public key PEM (SubjectPublicKeyInfo) from modulus/exponent
      $n = $parameters.Modulus
      $e = $parameters.Exponent

      $pubparts = @((EncodeInteger $n),(EncodeInteger $e))
      $rsapubseq = BuildSequence($pubparts)

      # wrap RSAPublicKey in BIT STRING (0x03)
      $bitList = New-Object 'System.Collections.Generic.List[byte]'
      $bitList.Add([byte]0x03)
      $lenEnc = EncodeLength($rsapubseq.Length + 1)
      foreach ($b2 in $lenEnc) { $bitList.Add($b2) }
      $bitList.Add([byte]0x00)
      foreach ($b2 in $rsapubseq) { $bitList.Add($b2) }
      $bitstring = $bitList.ToArray()

      # AlgorithmIdentifier for rsaEncryption OID (06 09 2A 86 48 86 F7 0D 01 01 01) + NULL (05 00)
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

      function BytesToBase64([byte[]]$arr) { return [System.Convert]::ToBase64String($arr) }

      $pubB64 = BytesToBase64 $spki
      $pubPem = "-----BEGIN PUBLIC KEY-----`n" + (Wrap-Base64 $pubB64) + "`n-----END PUBLIC KEY-----`n"

      # For private key fallback, store XML key (not PEM) for development convenience
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

function Check-ServerReachable([string]$url) {
  try {
    $u = [uri]$url
  } catch {
    Throw "ServerUrl inválida: $url"
  }
  $h = $u.Host
  $p = $u.Port
  Write-Host "Comprobando conectividad a $($h):$($p)..."
  $r = Test-NetConnection -ComputerName $h -Port $p -WarningAction SilentlyContinue
  return $r.TcpTestSucceeded
}

function Post-Queue([string]$serverUrl, [string]$hostname, [string]$publicKeyPath) {
  $pub = Get-Content -Raw -Path $publicKeyPath
  $os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
  $facts = @{ os = $os; user = $env:USERNAME; hostname = $hostname }
  $payload = @{ hostname = $hostname; public_key = $pub; facts = $facts } | ConvertTo-Json -Depth 5 -Compress
  $uri = "$serverUrl/api/agents/queue"
  Write-Host "POST $uri (payload size: $($payload.Length) bytes)"
  try {
    $res = Invoke-RestMethod -Uri $uri -Method Post -Body $payload -ContentType 'application/json' -ErrorAction Stop
    return $res
  } catch {
    Write-Error "Error POST queue: $_"
    throw $_
  }
}

function Get-QueueStatus([string]$serverUrl, [int]$id) {
  $uri = "$serverUrl/api/agents/queue/$id/status"
  try {
    return Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
  } catch {
    Write-Error "Error GET status: $_"
    return $null
  }
}

# main limpio: reutiliza config.json, genera claves solo si faltan,
# crea entrada en la cola cuando procede y hace polling hasta aprobación
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

if (-not (Check-ServerReachable $ServerUrl)) {
  Write-Warning "Servidor $ServerUrl no accesible en el puerto detectado. Asegúrate de que el server está arriba en el puerto correspondiente."
}

$privPath = Join-Path $OutDir "agent_private.pem"
$pubPath = Join-Path $OutDir "agent_public.pem"
$configPath = Join-Path $OutDir "config.json"

# Load existing config if present
$existingConfig = $null
if (Test-Path $configPath) {
  try { $existingConfig = Get-Content -Raw -Path $configPath | ConvertFrom-Json } catch { $existingConfig = $null }
}

if ($existingConfig -and $existingConfig.agent_id) {
  Write-Host "Ya existe agent_id en config.json: $($existingConfig.agent_id) - no se crea nueva entrada."
  Write-Host "Ruta config: $configPath"
  exit 0
}

# Ensure keys exist (generate only if missing)
if (-not (Test-Path $pubPath) -or -not (Test-Path $privPath)) {
  Write-Host "Generando par de claves RSA de $KeySize bits en: $OutDir"
  $kp = New-RsaKeyPairPem -bits $KeySize -privatePath $privPath -publicPath $pubPath
  Write-Host "Public key guardada en: $($kp.public)"
} else {
  Write-Host "Claves ya existentes encontradas en $OutDir"
  $kp = @{ private = $privPath; public = $pubPath }
}

# If we have a previous queue_id in config, reuse it and poll; otherwise POST a new queue entry
$qid = $null
if ($existingConfig -and $existingConfig.queue_id) {
  $qid = [int]$existingConfig.queue_id
  Write-Host "Usando queue_id existente desde config.json: $qid"
} else {
  try {
    $postRes = Post-Queue -serverUrl $ServerUrl -hostname $Hostname -publicKeyPath $kp.public
    $qid = $postRes.id
    if (-not $qid) { Write-Error "Respuesta inesperada del servidor: $($postRes | ConvertTo-Json -Depth 3)"; exit 2 }
    Write-Host "Entrada creada en la cola con id: $qid"

    # persist queue_id so subsequent runs reuse it
    $cfg = @{
      queue_id = $qid
      hostname = $Hostname
      server_url = $ServerUrl
      public_key_path = $pubPath
      private_key_path = $privPath
      created_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $cfg | ConvertTo-Json -Depth 5 | Out-File -FilePath $configPath -Encoding utf8 -Force
    Write-Host "Queue ID persistido en: $configPath"
  } catch {
    Write-Error "Error al crear la entrada en la cola: $_"
    exit 1
  }
}

Write-Host "Iniciando polling cada $PollIntervalSeconds segundos..."
try {
  while ($true) {
    Start-Sleep -Seconds $PollIntervalSeconds
    $st = Get-QueueStatus -serverUrl $ServerUrl -id $qid
    if (-not $st) { continue }
    Write-Host "Status: $($st.status)"
    if ($st.status -eq 'approved') {
      Write-Host "Aprobado: agent_id=$($st.agent_id)"

      # update config: set agent_id and remove queue_id
      $config = @{
        agent_id = $st.agent_id
        hostname = $Hostname
        server_url = $ServerUrl
        approved_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        private_key_path = $privPath
        public_key_path = $pubPath
      }
      $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $configPath -Encoding utf8 -Force
      Write-Host "Configuración guardada en: $configPath"

      # fetch agent details if available
      try {
        $agent = Invoke-RestMethod -Uri "$ServerUrl/api/agents/$($st.agent_id)" -Method Get -ErrorAction Stop
        Write-Host "Agent details:`n$($agent | ConvertTo-Json -Depth 5)"
      } catch {
        Write-Warning "No se pudo obtener detalles del agente: $_"
      }
      break
    } elseif ($st.status -eq 'rejected') {
      if ($st.rejection_message) {
        Write-Error "Entrada rechazada: $($st.rejection_message)"
      } else {
        Write-Error "Entrada rechazada"
      }
      break
    }
  }
} catch {
  Write-Error "Error durante el polling: $_"
  exit 1
}

Write-Host "Flujo completado."
