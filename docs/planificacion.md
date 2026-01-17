# Planificación del Proyecto: psWinModel Reborn

## Descripción General
psWinModel Reborn es una solución de gestión y administración remota para equipos Windows. El proyecto incluye:
- **Servidor**: API y consola web para la administración.
- **Agente**: Software instalado en los equipos Windows para la comunicación con el servidor.

## Componentes
1. **Servidor**
   - API para gestionar agentes.
   - Consola web para administración y monitoreo.
2. **Agente**
   - Lógica para interactuar con el servidor.
   - Icono en la barra de tareas para acciones locales.

## Tecnologías Iniciales
- **Servidor**:
  - Lenguaje: Por definir (Node.js, Python, etc.).
  - Base de datos: Por definir (MySQL, PostgreSQL, etc.).
  - Framework web: Por definir (Express.js, Flask, etc.).
- **Agente**:
  - Lenguaje: PowerShell (compilado con ps2exe).

## Próximos Pasos
- Definir tecnologías específicas.
- Diseñar la arquitectura inicial.
- Implementar prototipos básicos.

## Comportamiento y responsabilidades del Agente
El agente implementará las capacidades necesarias para soportar los flujos de onboarding, ejecución de recursos (facts, scripts, Chocolatey) y operaciones en tiempo real (iteración forzada, consola remota).

### Onboarding (registro)
- Soportar tres métodos de registro:
  - **Admin-driven**: el agente realiza el primer contacto tras crearse desde la consola por un admin; el admin define `organization` y `location` y puede entregar instrucciones.
  - **OTP**: el agente presenta un `code` OTP en el primer contacto; el OTP ya incluye `organization` y `location` y decrementa `uses` en el servidor.
  - **Queue**: el agente se registra en modo `queue` con datos mínimos (hostname, public_key opcional, facts); espera aprobación manual.
- En el primer contacto el agente podrá: generar localmente su par de claves (pública/privada) y subir la `public_key`, o usar una clave existente provista por el instalador.
- El agente debe exponer un modo seguro para enviar la clave pública y datos iniciales (facts) al servidor y recibir confirmación de registro/ID.

### Comunicación y polling
- El agente mantendrá dos canales básicos:
  - **Conexiones salientes HTTP/HTTPS** para polling periódico y envío de `facts`, `script_runs`, `choco_runs` y sincronización de inventario.
  - **Conexión persistente WebSocket** saliente hacia el servidor para recibir señales push (iteración forzada), notificaciones y sesiones remotas.
- El agente debe autorizarse usando JWT o credenciales provisionales en el primer contacto.

### Facts y facts externos
- Ejecutar scripts de `external_facts` locales (PowerShell) en una carpeta configurable, con límites de tiempo y tamaño de salida.
- Validar que la salida sea JSON válido; enviar facts al servidor como `fact_key` / `value` JSON.

### Ejecución de Scripts PowerShell (desde repositorio)
- Descargar `content` de script y ejecutarlo en un entorno controlado local:
  - Aplicar timeouts y límites de memoria.
  - Capturar `stdout`, `stderr`, `exit_code` y duración, y reportar en `script_runs`.
  - Marcar ejecuciones únicas (`single_run`) y evitar re-ejecución cuando proceda.
- Implementar sandboxing mínimo (ejecutar en proceso separado, controlar permisos, evitar elevación automática).

### Gestión Chocolatey
- Ejecutar operaciones `install/update/uninstall/pin/unpin` según `choco_deployments` recibidos.
- Mantener y sincronizar `agent_choco_packages` localmente y reportar operaciones en `choco_runs`.
- Implementar `upgrade_all --ignore-pinned` según `upgrade_interval_hours` resuelto por jerarquía de settings.

### Señales forzadas y control remoto
- Responder a mensajes WebSocket para forzar iteraciones, ejecutar jobs pendientes o procesar despliegues.
- Para la consola remota interactiva:
  - Crear un PTY local y ejecutar PowerShell conectado a stdin/stdout/stderr.
  - Enviar eventos y transcript por el canal WebSocket al servidor.
  - Aplicar timeouts, límites y, opcionalmente, requerir consentimiento local según política.

### Reporte y resiliencia
- Enviar resultados (`script_runs`, `choco_runs`, facts) al servidor y reintentar con backoff en caso de fallo de red.
- Registrar localmente eventos críticos para diagnóstico si la conexión está intermitente.

### Seguridad y restricciones
- Nunca ejecutar contenido remoto en el servidor; toda ejecución ocurre en el agente.
- Aplicar validación/limpieza de entradas y salidas (truncado, escapes) antes de enviarlas al servidor.
- Proteger la clave privada del agente en almacenamiento seguro local (definir later: DPAPI, protected file, o similar).
- Registrar y auditar intentos de registro, ejecuciones y sesiones remotas.

### Configuración y políticas locales
- Carpetas configurables: `external_facts`, `scripts_cache`.
- Parámetros configurables: timeouts por tipo de ejecución, tamaño máximo de stdout/stderr a enviar, política de consentimiento para consola remota.

### Operaciones de mantenimiento
- Modo de actualización del agente (autoupdate o manual), con firmas/checksums para evitar código no autorizado.

## Ejecutables del Agente y modo Servicio
El agente tendrá dos ejecutables principales:

- `pswm.exe` (ejecutable principal, compilado con `ps2exe`): ejecutable de línea de comandos que acepta una acción/sectión como primer parámetro seguido de parámetros, por ejemplo:
  - `pswm install_svc`
  - `pswm gencert`
  - `pswm agent --dry-run`

  Este binario será el que se instale como servicio de sistema (Windows Service). Debe incluir subcomandos para instalación/actualización/desinstalación del servicio, para generar/rotar certificados y para ejecutar el agente en modo foreground (útil para debugging y `--dry-run`).

- `pswm-tray.exe` (ejecutable por sesión de usuario): proceso que se ejecuta en la sesión interactiva del usuario, muestra el icono en la bandeja y ofrece el menú de acciones locales (conexión a consola local, estado, abrir logs, etc.).

Requisitos y comportamiento:
- El servicio `pswm.exe` deberá poder instalarse como servicio Windows (p.ej. usando `New-Service` o un wrapper como `nssm`), ejecutarse bajo una cuenta de servicio dedicada y contar con opciones para controlar inicio automático, dependencia y restart on failure.
- El instalador (`pswm install_svc`) realizará:
  - Crear la carpeta de datos `C:\ProgramData\pswm-reborn` (si no existe).
  - Establecer permisos seguros sobre la carpeta (solo Administradores y la cuenta de servicio tendrán permisos de escritura; lectura según política).
  - Instalar el servicio Windows apuntando a `pswm.exe service` o similar.
  - Añadir `C:\ProgramData\pswm-reborn` al `PATH` del sistema (lectura) para que los ejecutables sean accesibles desde cualquier ruta; esto requiere privilegios elevadas y deberá hacerse con cuidado (evitar sobrescribir PATH, sólo añadir si no existe).

- El tray `pswm-tray.exe` se instalará por usuario (p. ej. en el perfil) y arrancará en el login de sesión si el usuario tiene permiso.

Almacenamiento de certificados y configuración:
- La ubicación principal será `C:\ProgramData\pswm-reborn`.
- Archivos a almacenar: certificado público (`agent.crt`), clave pública (`agent.pub`), configuración (`config.json`), y otros artefactos (`scripts_cache`, `external_facts`).
- La clave privada del agente no debe almacenarse en texto plano con permisos amplios. Opciones recomendadas:
  - Usar Windows DPAPI para cifrar la clave privada por máquina o por cuenta de servicio.
  - Guardar la clave privada en un archivo protegido con ACLs que permitan sólo la cuenta de servicio y Administradores leerla.
- Incluir un mecanismo `pswm gencert` para generar un par de claves (si el flujo de instalación lo exige) y guardar la clave de forma segura.

Logs y diagnóstico:
- El servicio escribirá logs rotativos en `C:\ProgramData\pswm-reborn\logs` con niveles (info, warn, error, debug) y cuidará el tamaño/retención.
- `pswm-tray.exe` podrá exponer logs por usuario y enlaces para abrir logs del servicio.

Consideraciones de actualización y seguridad:
- Actualizaciones del binario deberían verificarse por firma/checksum antes de aplicarse.
- La modificación del `PATH` del sistema debe documentarse y llevar opción reversible en desinstalación.
- El proceso de instalación/desinstalación debe ser idempotente y registrar acciones en `logs` y `settings`.

