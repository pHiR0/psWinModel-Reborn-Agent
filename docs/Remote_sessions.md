# Sesiones Remotas — Documento de Diseño

## 1. Visión General

Permitir al administrador abrir una consola de comandos interactiva (PowerShell / cmd) en un agente remoto directamente desde la consola web, sin necesidad de RDP, SSH ni herramientas de terceros.

**Flujo resumido:**

```
Consola Web  ←→  Servidor (WebSocket Hub)  ←→  Agente (pswm.exe remote_session)
   (xterm.js)        (ws relay + auth)           (proceso hijo PowerShell)
```

---

## 2. Activación por Agente

### 2.1 Setting en el servidor (BDD)

- Nueva columna en tabla `agents`: `remote_session_enabled INTEGER DEFAULT 0`
- Se activa/desactiva desde la ficha de edición del agente mediante un **switch slide**.
- También se puede activar desde la vista de detalles del agente (card superior).

### 2.2 Propagación al agente

- El agente consulta su configuración en cada iteración (`GET /api/settings/agent-config` o similar).
- El servidor incluye el campo `remote_session_enabled` en la respuesta.
- El agente almacena el valor en `agent_config.json`.

### 2.3 Proceso en el cliente

- Cuando `remote_session_enabled = true`, el agente lanza un **proceso independiente**:
  ```
  pswm.exe remote_session
  ```
- Este proceso:
  1. Establece un WebSocket hacia el servidor.
  2. Spawn de un proceso hijo `powershell.exe` (o `pwsh.exe` si está disponible) con stdin/stdout/stderr redirigidos.
  3. Hace de puente: lo que llega por el WebSocket se escribe en stdin del shell; lo que sale por stdout/stderr se envía al WebSocket.
- Si `remote_session_enabled` cambia a `false` en una iteración posterior, el agente mata el proceso `remote_session` si está corriendo.

### 2.4 Gestión del ciclo de vida del proceso

- El proceso principal del servicio (`pswm.exe agent` / servicio Windows) es quien decide si lanzar o detener el proceso de `remote_session`.
- Se almacena el PID del proceso hijo en un fichero `remote_session.pid` dentro de `C:\ProgramData\pswm-reborn\`.
- En cada iteración se verifica:
  - Si debe estar activo y no está corriendo → lanzar.
  - Si debe estar inactivo y está corriendo → detener.
  - Si está corriendo pero el proceso murió → relanzar (si sigue habilitado).

---

## 3. Protocolo WebSocket

### 3.1 Endpoints

**Servidor:**
- `ws(s)://<server>/ws/remote-session` — endpoint WebSocket para agentes y consola web.

**Autenticación:**
- El agente se autentica en el handshake WS usando su JWT RS256 existente (header `Authorization: Bearer <jwt>` en la petición de upgrade HTTP → WS).
- La consola web se autentica con el JWT del usuario (mismo mecanismo).

### 3.2 Tipos de mensaje (JSON)

Todos los mensajes siguen la estructura:
```json
{ "type": "<tipo>", "payload": { ... } }
```

#### Agente → Servidor
| Tipo | Descripción |
|------|-------------|
| `agent:register` | Registro inicial: `{ agentId, hostname }` |
| `agent:output` | Salida del shell: `{ data: "<texto>" }` |
| `agent:ping` | Heartbeat (prueba de vida) |
| `agent:exit` | El proceso shell terminó: `{ exitCode }` |

#### Servidor → Agente
| Tipo | Descripción |
|------|-------------|
| `server:input` | Entrada del usuario: `{ data: "<texto>" }` |
| `server:resize` | Cambio de tamaño del terminal: `{ cols, rows }` |
| `server:pong` | Respuesta a ping |
| `server:disconnect` | Orden de desconexión |

#### Consola Web → Servidor  
| Tipo | Descripción |
|------|-------------|
| `web:connect` | Solicitar conexión a un agente: `{ agentId }` |
| `web:input` | Enviar texto al agente: `{ agentId, data }` |
| `web:resize` | Redimensionar terminal: `{ agentId, cols, rows }` |
| `web:ping` | Heartbeat del navegador |
| `web:disconnect` | Cerrar sesión: `{ agentId }` |

#### Servidor → Consola Web
| Tipo | Descripción |
|------|-------------|
| `server:output` | Salida del agente: `{ agentId, data }` |
| `server:status` | Estado de conexión: `{ agentId, status: "connected"|"disconnected"|"reconnecting" }` |
| `server:pong` | Respuesta a ping |
| `server:error` | Error: `{ message }` |

### 3.3 Flujo de conexión

```
         Web Console              Servidor                   Agente
             │                       │                          │
             │                       │  ◄── WS connect ──────  │  (agent:register)
             │                       │  ── server:pong ──────► │
             │                       │                          │
             │  ── web:connect ──►   │                          │
             │  ◄── server:status ── │  (connected)             │
             │                       │                          │
             │  ── web:input ──────► │  ── server:input ──────► │
             │                       │  ◄── agent:output ────── │
             │  ◄── server:output ── │                          │
             │                       │                          │
             │       (cada 30s)      │                          │
             │  ── web:ping ───────► │                          │
             │  ◄── server:pong ──── │                          │
             │                       │  ◄── agent:ping ──────── │  (cada 30s)
             │                       │  ── server:pong ────────►│
```

---

## 4. Heartbeat y Reconexión

### 4.1 Prueba de vida (heartbeat)

- **Intervalo de ping:** cada **30 segundos** (tanto agente como web).
- **Timeout de inactividad:** si cualquiera de las dos partes no recibe tráfico (datos o ping/pong) en **40 segundos**, considera la conexión muerta y la cierra.

### 4.2 Reconexión del agente

- Si la conexión WS se pierde, el proceso `pswm.exe remote_session` reintentar la conexión cada **15 segundos**, indefinidamente mientras `remote_session_enabled = true`.
- El proceso shell (PowerShell) se mantiene vivo durante la reconexión. Si la reconexión se establece, se reanuda el relay. Si el proceso shell muere, se crea uno nuevo.
- El servidor mantiene el estado `reconnecting` para ese agente hasta que reconecte o pase el timeout de inactividad de 24h.
- La consola web muestra el estado de reconexión en tiempo real.

### 4.3 Auto-desactivación por inactividad

- Si no se ha enviado **ningún comando** (mensajes de tipo `web:input`) a un agente durante **24 horas**, el servidor:
  1. Cambia `remote_session_enabled = 0` en la BDD.
  2. Envía `server:disconnect` al agente.
  3. Registra un log de auditoría.
- En la siguiente iteración, el agente detecta el cambio y mata el proceso `remote_session`.

---

## 5. Interfaz Web (Consola)

### 5.1 Emulador de terminal

- Usar **xterm.js** (librería estándar para terminales en web).
- Se integra como un componente Svelte: `RemoteTerminal.svelte`.
- Ubicación en la UI:
  - **Opción A (recomendada):** Botón/icono en la vista de detalles del agente que abre un **drawer/panel inferior** resizable con el terminal.
  - **Opción B:** Ventana nueva/popup dedicada.

### 5.2 Icono en "Todos los Agentes"

- En la columna de estado o en una micro-columna dedicada:
  - 🖥️ **gris** → Remote sessions **no habilitado** (no mostrar nada, o mostrar sutil).
  - 🟢 **terminal verde** → Habilitado **y conectado** (el proceso WS del agente está activo).
  - 🟡 **terminal amarillo** → Habilitado pero **reconectando/esperando**.
  - No mostrar icono si no está habilitado (para no añadir ruido visual).
- Al hacer clic en el icono verde se abre directamente la consola remota.

### 5.3 Vista de detalles del agente

- Nueva pestaña o sección: **"Terminal Remoto"**.
- Contenido:
  - Estado de la conexión (conectado / desconectado / reconectando).
  - Switch para habilitar/deshabilitar.
  - Terminal xterm.js embebido (cuando está conectado).
  - Últimos logs de conexión/desconexión.

---

## 6. Seguridad

### 6.1 Autenticación

- **Agente:** JWT RS256 (el mismo que usa para la API REST). Se valida en el handshake del WebSocket.
- **Usuario web:** JWT del usuario. Se verifica rol `admin` antes de permitir conectar a un agente.

### 6.2 Autorización

- Solo usuarios con rol **admin** pueden abrir sesiones remotas.
- (Futuro) Se puede añadir un permiso granular (`can_remote_session`).

### 6.3 Auditoría y logging

- Tabla `remote_sessions` en BDD:
  ```sql
  CREATE TABLE remote_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TEXT,
    ended_reason TEXT,  -- 'user_disconnect', 'agent_disconnect', 'timeout_24h', 'error'
    commands_count INTEGER DEFAULT 0,
    ip_address TEXT,
    FOREIGN KEY(agent_id) REFERENCES agents(id),
    FOREIGN KEY(user_id) REFERENCES users(id)
  );
  ```
- Cada comando enviado se puede registrar (opcional, activable por setting: `remote_session_audit_commands`).
- Si se activa, tabla `remote_session_commands`:
  ```sql
  CREATE TABLE remote_session_commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    command TEXT NOT NULL,
    sent_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(session_id) REFERENCES remote_sessions(id)
  );
  ```

### 6.4 Restricciones de seguridad

- El shell que se abre en el agente corre con los permisos del servicio `pswm-reborn` (típicamente SYSTEM). Valorar si se debe:
  - Limitar comandos peligrosos (blacklist configurable).
  - Ejecutar el shell con un usuario con menos privilegios (configurable).
- **Rate-limiting:** máximo N sesiones simultáneas por servidor (configurable, default 5).
- **Tamaño de buffer:** limitar el tamaño máximo de datos por mensaje WS (ej. 64 KB) para evitar abusos.

---

## 7. Arquitectura del Servidor (Express + ws)

### 7.1 Dependencias nuevas

- `ws` (librería WebSocket para Node.js) — ya es una dependencia común y ligera.

### 7.2 Estructura de archivos sugerida

```
src/
  websocket/
    index.js          ← Setup del WS server, attach al HTTP server
    auth.js           ← Validación de JWT en upgrade del WS
    sessionManager.js ← Mapa de agentes conectados, relay de mensajes
    heartbeat.js      ← Lógica de ping/pong y timeouts
```

### 7.3 Mapa de conexiones en memoria

```javascript
// sessionManager.js
const agentSockets = new Map();   // agentId → { ws, hostname, connectedAt, lastActivity }
const userSockets = new Map();    // sessionKey → { ws, userId, agentId, connectedAt }
```

### 7.4 Integración con Express

```javascript
// En src/index.js
const { createServer } = require('http');
const server = createServer(app);
const { setupWebSocket } = require('./websocket');
setupWebSocket(server, app.locals.conn);
server.listen(PORT, ...);
```

---

## 8. Arquitectura del Agente (PowerShell)

### 8.1 Comando `pswm.exe remote_session`

Nuevo comando en `pswm.ps1` que:

1. Lee la configuración (`config.json`) para obtener `server_url` y `agent_id`.
2. Genera JWT RS256 para autenticarse.
3. Abre conexión WebSocket hacia `ws(s)://<server>/ws/remote-session`.
4. Spawn `powershell.exe` con `-NoProfile -NonInteractive` y stdin/stdout/stderr redirigidos.
5. Loop principal:
   - Recibe mensajes WS → escribe en stdin del shell.
   - Lee stdout/stderr del shell → envía por WS.
   - Cada 30s → envía `agent:ping`.
   - Si no recibe tráfico en 40s → cierra y reintenta.
6. En caso de desconexión WS → reintenta cada 15s.
7. Si recibe `server:disconnect` → mata el shell y sale.

### 8.2 Integración con el servicio

En el loop principal del servicio (`pswm.exe agent`), tras cada iteración:

```powershell
# Gestión de remote_session
$rsEnabled = $agentConfig.remote_session_enabled
$rsPid = Get-RemoteSessionPid   # Lee remote_session.pid
if ($rsEnabled -and -not $rsPid) {
    Start-RemoteSession          # Lanza pswm.exe remote_session en background
} elseif (-not $rsEnabled -and $rsPid) {
    Stop-RemoteSession           # Mata el proceso
}
```

### 8.3 WebSocket en PowerShell

- Usar `System.Net.WebSockets.ClientWebSocket` (.NET nativo, disponible en PS 5.1+).
- No requiere dependencias externas.

---

## 9. Consideraciones Adicionales y Sugerencias

### 9.1 Múltiples sesiones simultáneas

- Permitir que varios administradores vean la misma sesión del mismo agente (modo "shared/broadcast").
- O bien sesiones independientes por usuario (cada uno con su propio shell).
- **Recomendación:** empezar con una sola sesión activa por agente. Si otro admin quiere conectar, puede "observar" (read-only) o tomar el control.

### 9.2 Historial de sesión

- Guardar un log/transcript de cada sesión (stdout completo) como blob o fichero, consultable desde la consola web.
- Útil para auditoría y compliance.

### 9.3 Notificaciones

- Cuando un admin abre una sesión remota, registrar una notificación/evento visible en el dashboard.
- Notificar si el agente se desconecta inesperadamente durante una sesión activa.

### 9.4 Timeout de sesión configurable

- El timeout de 24h por inactividad debería ser un setting del servidor (tabla `settings`), no hardcodeado.
- Default: 24h, pero configurable desde "Configuración del Servidor" → "Sesiones Remotas".

### 9.5 Indicador visual en el agente (tray)

- Si `pswm-tray.exe` está corriendo, mostrar un icono/notification cuando hay una sesión remota activa, para que el usuario del equipo sepa que alguien está conectado.

### 9.6 Shell configurable

- Por defecto `powershell.exe`, pero contemplar la posibilidad de elegir:
  - `pwsh.exe` (PowerShell 7+)
  - `cmd.exe`
- Se podría hacer un setting por agente o global.

### 9.7 Comandos de control desde la consola web

- Botón "Ctrl+C" (enviar señal de interrupción al proceso).
- Botón "Limpiar terminal".
- Botón "Descargar transcript" (exportar el historial de la sesión).

### 9.8 Cola de comandos offline (futuro)

- Si el agente no está conectado por WS pero tiene `remote_session_enabled`, poder encolar un comando que se ejecutará cuando reconecte.
- Esto es más complejo y puede ser una fase futura.

### 9.9 Redimensionamiento del terminal

- El terminal xterm.js en la web reporta `cols` y `rows` al conectar y al redimensionar.
- El agente aplica esos valores al proceso shell usando `$Host.UI.RawUI.BufferSize` / `WindowSize` o via WinAPI `SetConsoleScreenBufferSize`.

### 9.10 Compatibilidad con Cloudflare Tunnel

- Cloudflare Tunnel soporta WebSockets de forma nativa (no requiere configuración adicional si el tunnel ya está activo).
- Verificar que los headers de upgrade HTTP→WS pasan correctamente a través del tunnel.

---

## 10. Plan de Implementación por Fases

### Fase 1 — Infraestructura base
- [ ] Añadir columna `remote_session_enabled` a tabla `agents`.
- [ ] Switch slide en la ficha de edición del agente.
- [ ] Incluir `remote_session_enabled` en la respuesta de agent-config.
- [ ] Setup servidor WebSocket (`ws` library) con autenticación JWT.
- [ ] Tabla `remote_sessions` para auditoría.

### Fase 2 — Agente (cliente WS)
- [ ] Nuevo comando `pswm.exe remote_session`.
- [ ] Conexión WS con JWT RS256.
- [ ] Spawn de PowerShell con relay stdin/stdout.
- [ ] Heartbeat (ping cada 30s, timeout 40s).
- [ ] Reconexión automática cada 15s.
- [ ] Gestión del PID desde el servicio principal.

### Fase 3 — Consola Web
- [ ] Instalar `xterm.js` + `xterm-addon-fit` en web-console.
- [ ] Componente `RemoteTerminal.svelte`.
- [ ] Conexión WS desde el navegador con JWT de usuario.
- [ ] Icono de estado en "Todos los Agentes".
- [ ] Pestaña/panel "Terminal Remoto" en detalles del agente.

### Fase 4 — Hardening y UX
- [ ] Auto-desactivación por inactividad de 24h.
- [ ] Setting configurable para timeout de inactividad.
- [ ] Auditoría de comandos (opcional, activable).
- [ ] Rate-limiting de sesiones simultáneas.
- [ ] Notificación en tray del agente.
- [ ] Botones de control (Ctrl+C, limpiar, descargar transcript).

---

## 11. Dependencias Técnicas

| Componente | Tecnología | Notas |
|---|---|---|
| Servidor WS | `ws` (npm) | Ligero, estándar Node.js |
| Terminal Web | `xterm.js` + addons | Emulador de terminal en canvas |
| Cliente WS (agente) | `System.Net.WebSockets.ClientWebSocket` | .NET nativo, PS 5.1+ |
| Shell remoto | `powershell.exe` / `pwsh.exe` | Process spawn con pipes |
| Autenticación | JWT RS256 (existente) | Mismo mecanismo que la API |

---

## 12. Diagrama de Componentes

```
┌──────────────────┐      HTTPS/WSS        ┌──────────────────────┐       WSS          ┌─────────────────┐
│   Consola Web    │◄─────────────────────►│   Servidor Express    │◄──────────────────►│   Agente pswm   │
│                  │                        │                       │                    │                 │
│  ┌────────────┐  │                        │  ┌─────────────────┐  │                    │  ┌───────────┐  │
│  │  xterm.js  │  │   web:input/output     │  │  WS Hub         │  │  agent:input/out   │  │ PS shell  │  │
│  │  terminal  │──┼───────────────────────►│  │  sessionManager │──┼──────────────────►│  │ (stdin/   │  │
│  │            │◄─┼────────────────────────│  │  heartbeat      │◄─┼──────────────────││  │  stdout)  │  │
│  └────────────┘  │                        │  └─────────────────┘  │                    │  └───────────┘  │
│                  │                        │                       │                    │                 │
│                  │                        │  ┌─────────────────┐  │                    │  remote_session │
│                  │                        │  │  SQLite (audit)  │  │                    │  .pid           │
│                  │                        │  └─────────────────┘  │                    │                 │
└──────────────────┘                        └──────────────────────┘                    └─────────────────┘
```
