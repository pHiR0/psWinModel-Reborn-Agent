# psWinModel Reborn - Agent Core

Scripts y módulos del agente psWinModel Reborn.

## Desarrollo Rápido

### Script de Desarrollo: `dev_agent.ps1`

Script para desarrollo y pruebas que genera claves RSA, registra el agente en la cola y hace polling hasta la aprobación.

**Requisitos:**
- PowerShell 5.1+ (Windows PowerShell) o PowerShell 7+
- Servidor API corriendo (por defecto: `http://localhost:3000`)

**Uso:**

```powershell
# Uso básico (usa valores por defecto)
.\dev_agent.ps1

# Con parámetros personalizados
.\dev_agent.ps1 -ServerUrl http://localhost:3000 -Hostname mi-agente -PollIntervalSeconds 5

# Parámetros disponibles
-ServerUrl <string>           # URL del servidor API (default: http://localhost:3000)
-Hostname <string>            # Nombre del agente (default: $env:COMPUTERNAME)
-OutDir <string>              # Directorio de salida (default: C:\ProgramData\pswm-reborn)
-KeySize <int>                # Tamaño de la clave RSA (default: 2048)
-PollIntervalSeconds <int>    # Intervalo de polling (default: 5)
```

**Qué hace el script:**

1. **Genera par de claves RSA** (privada + pública) en formato PEM
   - Ruta legacy para PowerShell 5.1 (RSACryptoServiceProvider)
   - Ruta moderna para PowerShell 7+ (RSA.Create + Export APIs)
   
2. **Verifica conectividad** con el servidor API

3. **Envía solicitud de registro** a `/api/agents/queue`
   - Hostname
   - Public key (PEM)
   - Facts básicos (OS, usuario)

4. **Hace polling** al endpoint `/api/agents/queue/:id/status` hasta obtener:
   - `approved` → guarda configuración y continúa
   - `rejected` → sale con error

5. **Guarda configuración** en `config.json`:
   - `agent_id` asignado por el servidor
   - `hostname`, `server_url`
   - Rutas de claves privada/pública
   - Timestamp de aprobación

**Archivos generados:**

```
C:\ProgramData\pswm-reborn\
├── agent_private.pem    # Clave privada RSA (o XML en PS 5.1)
├── agent_public.pem     # Clave pública RSA (PEM)
└── config.json          # Configuración del agente (agent_id, etc.)
```

**Ejemplo de config.json:**

```json
{
  "agent_id": 10,
  "hostname": "mi-agente",
  "server_url": "http://localhost:3000",
  "approved_at": "2026-01-17 22:30:00",
  "private_key_path": "C:\\ProgramData\\pswm-reborn\\agent_private.pem",
  "public_key_path": "C:\\ProgramData\\pswm-reborn\\agent_public.pem"
}
```

---

## Estructura Futura: `pswm.exe`

El binario final `pswm.exe` seguirá una estructura de subcomandos/módulos:

```powershell
pswm <acción/módulo> [parámetros]
```

### Subcomandos Planeados

#### 1. Onboarding

```powershell
# Generar par de claves
pswm gencert --out "C:\ProgramData\pswm-reborn"

# Registrar en cola de aprobación
pswm register queue --server http://localhost:3000 --hostname mi-agente

# Registrar con OTP (onboarding automático)
pswm register otp --server http://localhost:3000 --code ABC123DEF456

# Registrar con admin (requiere token/creds)
pswm register admin --server http://localhost:3000 --token <JWT>
```

#### 2. Servicio

```powershell
# Instalar servicio
pswm install_svc

# Desinstalar servicio
pswm uninstall_svc

# Iniciar/detener servicio
pswm start_svc
pswm stop_svc
```

#### 3. Agente (modo runtime)

```powershell
# Ejecutar agente en modo desarrollo (sin instalar servicio)
pswm agent --dry-run --server http://localhost:3000

# Ejecutar agente (usa config.json para agent_id)
pswm agent --config "C:\ProgramData\pswm-reborn\config.json"
```

#### 4. Utilidades

```powershell
# Ver configuración
pswm config show

# Probar conectividad
pswm test connection --server http://localhost:3000

# Ver logs
pswm logs --tail 100
```

---

## Notas de Desarrollo

- **PowerShell 5.1 vs 7+**: El script detecta automáticamente la versión y usa APIs apropiadas.
- **Tamaño de payload**: El servidor debe configurarse con `limit: '10mb'` en body-parser para soportar claves RSA grandes.
- **Seguridad**: La clave privada debe protegerse con ACLs o DPAPI en producción.
- **Testing**: Usa el script `dev_agent.ps1` para desarrollo; el binario `pswm.exe` será la versión final.

---

## Flujo de Onboarding (Cola de Aprobación)

1. **Cliente ejecuta**: `.\dev_agent.ps1` (o futuro `pswm register queue`)
2. **Servidor recibe**: entrada en tabla `agent_queue` (status: `pending`)
3. **Admin aprueba**: vía UI (`/agents/queue`) o API (`POST /api/agents/queue/:id/approve`)
4. **Servidor crea**: registro en tabla `agents` y actualiza `agent_queue.status = 'approved'` + `agent_id`
5. **Cliente detecta**: polling a `/api/agents/queue/:id/status` devuelve `approved` + `agent_id`
6. **Cliente guarda**: `config.json` con `agent_id` para uso futuro
7. **Agente arranca**: con `agent_id` del config, se conecta al servidor y comienza a operar

---

## Próximos Pasos

- [ ] Implementar `pswm.exe` con estructura de subcomandos
- [ ] Añadir onboarding por OTP
- [ ] Añadir onboarding por admin directo
- [ ] Implementar instalación como servicio Windows
- [ ] Añadir tray icon (`pswm-tray.exe`)
- [ ] Implementar comunicación bidireccional con servidor
- [ ] Añadir ejecución de scripts remotos
- [ ] Implementar caché de scripts y facts
