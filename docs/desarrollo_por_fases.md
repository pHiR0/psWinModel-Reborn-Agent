# Desarrollo por Fases — psWinModel Reborn (Agent)

Documento de fases para el desarrollo del Agente, basado en `planificacion.md`.

## Resumen del stack y decisiones
- Lenguaje principal: PowerShell (compilado con `ps2exe`)
- Ejecutables: `pswm.exe` (servicio) y `pswm-tray.exe` (tray por sesión)
- Carpeta de instalación/almacenamiento: `C:\ProgramData\pswm-reborn`
- Funcionalidades principales: facts, external facts, ejecución de scripts, Chocolatey integration, WebSocket persistente, consola remota (PTY)

---

## Fase 0 — Preparación del agente (0.5-1 semana)
Objetivo: esqueleto del proyecto, estructura y herramientas de build.

Tareas:
- Inicializar proyecto PowerShell con estructura: `src/`, `tools/`, `build/`, `tests/`.
- Añadir scripts de build que compilen `pswm.ps1` a `pswm.exe` con `ps2exe`.
- Documentar flujo de releases y firma de binarios.

Criterios de aceptación:
- `pswm.exe --help` y `pswm-tray.exe --help` muestran ayuda básica.

Entregables:
- Scripts de build y README de desarrollo del agente.

---

## Fase 1 — Ejecución básica y configuración (1-2 semanas)
Objetivo: comportamiento básico del agente: configuración, almacenamiento de certificado y primer contacto.

Tareas:
- Implementar `pswm gencert` para generar par de claves y guardar `agent.pub`, `agent.crt` en `C:\ProgramData\pswm-reborn` con protección DPAPI o ACLs.
- Implementar `pswm install_svc` que crea la carpeta, ajusta permisos y registra el servicio Windows (usando `New-Service` o wrapper).
- Implementar primer contacto: `pswm agent` que conecta al servidor (`/api/agents/register/otp` o `/api/agents/register/admin`) y envía `public_key` y facts iniciales.

Criterios de aceptación:
- Carpeta `C:\ProgramData\pswm-reborn` creada con permisos correctos.
- El agente puede generar y guardar su clave pública y privada de forma segura.

Entregables:
- Instalador/guías y comandos de gestión del servicio.

---

## Fase 2 — Facts, external facts y sincronización (1-2 semanas)
Objetivo: ejecutar y subir facts periódicamente y soportar external facts.

Tareas:
- Ejecutar scripts en carpeta `external_facts` y validar JSON de salida.
- Implementar subida periódica de facts al endpoint `/api/agents/:id/facts`.
- Implementar reintentos con backoff y manejo de fallos.

Criterios de aceptación:
- Agente envía facts válidos y el servidor los persiste.

Entregables:
- Logs de ejecución y documentación de formato de facts.

---

## Fase 3 — Ejecutor de Scripts PowerShell (1-2 semanas)
Objetivo: descargar scripts del repositorio y ejecutarlos de forma segura, reportando `script_runs`.

Tareas:
- Endpoints para obtener despliegues y descargar `content`.
- Ejecutar scripts con timeouts, captura de `stdout`/`stderr`/`exit_code`, reporte a `/api/script_runs`.
- Respetar `single_run` y `requirements`.

Criterios de aceptación:
- El agente ejecuta script remoto y el servidor registra `script_runs` con datos completos.

Entregables:
- Implementación del ejecutor y tests de integración.

---

## Fase 4 — Chocolatey integration (1-2 semanas)
Objetivo: ejecutar operaciones choco y mantener inventario local.

Tareas:
- Implementar ejecución segura de `choco` con captura de salida y reporte a `/api/choco_runs`.
- Mantener `agent_choco_packages` local y sincronizar con el servidor.
- Implementar scheduler local para `upgrade_all` según `upgrade_interval_hours` resuelto.

Criterios de aceptación:
- Acciones `install/update/uninstall/pin/unpin` se registran correctamente.

Entregables:
- Documentación de comandos y ejemplos.

---

## Fase 5 — WebSocket persistente y señal forzada (1-2 semanas)
Objetivo: mantener conexión WS con el servidor para recibir señales y sesiones remotas.

Tareas:
- Implementar cliente WS que se autentica y reintenta automáticamente.
- Manejar mensajes de `force-iterate`, `start-remote-session`, `deploy-script`.
- En `start-remote-session`, crear PTY y canalizar I/O.

Criterios de aceptación:
- Agente responde a `force-iterate` con ACK y ejecuta ciclo inmediato.

Entregables:
- Cliente WS probado con servidor de prueba.

---

## Fase 6 — Consola tray y experiencia de usuario (1 semana)
Objetivo: `pswm-tray.exe` que muestre icono y menú de acciones.

Tareas:
- Implementar UI mínima para mostrar estado, logs recientes y acciones (checkin, ejecutar script localmente, abrir agente UI).
- Integración con el servicio local para enviar comandos al proceso service.

Criterios de aceptación:
- Tray funcional en sesión de usuario con acceso a acciones comunes.

Entregables:
- Binario `pswm-tray.exe` y documentación de instalación por usuario.

---

## Fase 7 — Hardening, testing y deployment (1-2 semanas)
Objetivo: asegurar el agente y preparar procesos de actualización.

Tareas:
- Proteger clave privada con DPAPI/ACLs y documentar recuperación.
- Tests de integración (simulador de servidor) para flows críticos.
- Firma de binarios y verificación en runtime.

Criterios de aceptación:
- Binarios firmados y tests de integración que cubren onboarding, script_runs y choco_runs.

Entregables:
- Guía de despliegue e instalación silent/automática.

---

## Operaciones posteriores
- Mantenimiento del repositorio de scripts, políticas de consentimiento para sesiones remotas, rotación de claves, y actualizaciones.

---

*Documento generado automáticamente como base de planificación por fases.*
