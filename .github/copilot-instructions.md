## Copilot Chat Instructions - psWinModel Reborn (Agent)
- No ejecutes `ps2exe` ni builds de binarios sin indicación explícita; las compilaciones y firmas de binarios requieren revisión.
- Antes de arrancar pruebas que contacten con el servidor, verifica que el servidor API (puerto 3000 por defecto) está accesible con `Test-NetConnection -ComputerName localhost -Port 3000`.
- Debes tener siempre actualizado el comando "pswm.exe help" para ver las opciones disponibles. Con todos los nuevos comandos y parametros que se añadan, el comando de ayuda es la referencia definitiva.


### 🎯 Objetivo: Agente psWinModel Reborn
Repositorio del agente: cliente en PowerShell que se instala como servicio (`pswm.exe`) y opcionalmente como `pswm-tray.exe` en sesión de usuario. Aquí se documentan comandos de desarrollo, flujos de onboarding (cola/OTP/admin) y prácticas de seguridad.

**Stack y artefactos**:
- Lenguaje principal: PowerShell (scripts en `agent-core/`)
- Binarios: opcionalmente generados con `ps2exe` (no ejecutar sin permiso)
- Datos locales: `C:\ProgramData\pswm-reborn` (configuración, certificados, `external_facts`, `scripts_cache`)
- Simulador: `agent-core/queue_agent.js` (Node.js) para probar onboarding sin instalar binarios

### Estructura relevante
- `agent-core/` — scripts del agente, simuladores y helpers (incluye `queue_agent.js` para pruebas de cola)
- `tray-icon/` — recursos para el binario tray (UI por sesión)
- `docs/` — planificación y fases del agente

### Comandos y flujos rápidos (PowerShell / Node)
- Comprobar servidor API disponible:
```powershell
Test-NetConnection -ComputerName localhost -Port 3000
```
- Ejecutar simulador de cola (desde el repo del agente):
```powershell
node agent-core/queue_agent.js http://<server:port> "MiHost" "optional-public-key"
```
- Ejecutar el agente en modo desarrollo (ejecutar script PowerShell directamente):
```powershell
# en PowerShell (elevado si es necesario)
cd agent-core
pwsh .\pswm.ps1 agent --dry-run --server http://localhost:3000
```
- Generar/guardar par de claves (comando esperado):
```powershell
pwsh .\pswm.ps1 gencert --out "C:\ProgramData\pswm-reborn"
```
- Instalar servicio (requiere privilegios):
```powershell
pwsh .\pswm.ps1 install_svc
```

### Onboarding — Cola de Aprobación (MVP)
- Flujo soportado en el servidor:
  1. Agente -> `POST /api/agents/queue` (simulador o agente real) para enviar `hostname`, `public_key` y `facts`.
  2. Admin -> revisar `/api/agents/queue` y `POST /api/agents/queue/:id/approve` para crear el agente definitivo.
  3. Agente -> `GET /api/agents/queue/:id/status` para hacer polling hasta que el estado sea `approved`.

- Para pruebas locales sin instalar el agente, usa el simulador Node:
```powershell
node agent-core/queue_agent.js http://localhost:3000 MiHost "optional-public-key"
```
Esto devuelve el `id` de la entrada en la cola y hace polling periódicamente hasta obtener `approved` o `rejected`.

### Buenas prácticas y seguridad
- Nunca almacenes la clave privada en texto plano con permisos amplios. Usa DPAPI o ACLs y guarda en `C:\ProgramData\pswm-reborn` con permisos restringidos.
- Limita el tamaño de `stdout`/`stderr` que el agente envía al servidor (truncar si es necesario).
- Registrar auditoría y guardar logs rotativos en `C:\ProgramData\pswm-reborn\logs`.

### Pruebas E2E recomendadas (rápidas)
1. Asegúrate de que `psWinModel-Reborn-Server` está en marcha y migraciones aplicadas:
```powershell
# en repo server
node src/run_migrations.js
node src/index.js
```
2. Desde repo agente (simulador):
```powershell
node agent-core/queue_agent.js http://localhost:3000 test-agent-01
```
3. En el servidor (desde API o UI) aprobar la entrada con `POST /api/agents/queue/:id/approve`.
4. Verificar que el simulador muestra `approved` y devuelve `agent_id`.

### Restricciones operativas
- NO ejecutes builds de binarios ni despliegues automáticos sin autorización.
- NO automatices commits/merges en `git` desde scripts sin aprobación previa.

### Comunicación
- Responder siempre en ESPAÑOL.
- Para confirmaciones rápidas usa `Read-Host` en PowerShell cuando se te solicite en una iteración.

---

Si quieres, adapto este documento para generar un script PowerShell `dev` que facilite `gencert`, `install_svc` y pruebas de cola en un solo comando.
