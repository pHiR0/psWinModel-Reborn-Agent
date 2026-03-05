# psWinModel Reborn — Guion del Producto

## 1. Visión General

**psWinModel Reborn** es una plataforma de **gestión y administración remota para flotas de equipos Windows**, inspirada en Puppet y soluciones MDM. Consta de tres componentes:

| Componente | Repo | Tecnología | Función |
|---|---|---|---|
| **Servidor** | `psWinModel-Reborn-Server` | Node.js + Express + SQLite | API REST central, lógica de negocio, almacenamiento |
| **Consola Web** | `psWinModel-Reborn-Server/web-console` | SvelteKit + Tailwind | Panel de administración para el operador |
| **Agente** | `psWinModel-Reborn-Agent` | PowerShell (.ps1) → .exe (ps2exe) | Cliente instalado en cada equipo Windows gestionado |

### Flujo General

```
┌─────────────┐         HTTPS/REST          ┌──────────────────┐
│   Agente    │ ◄─────────────────────────► │    Servidor API  │
│ (pswm.exe)  │   facts, scripts, choco    │  (Node+Express)  │
│   Windows   │   resultados, estado       │    + SQLite      │
└─────────────┘                             └────────┬─────────┘
                                                     │
                                            ┌────────▼─────────┐
                                            │  Consola Web     │
                                            │  (SvelteKit)     │
                                            │  Puerto 5173     │
                                            └──────────────────┘
```

## 2. Ciclo de Vida de un Agente

### 2.1 Onboarding (Registro)

Tres métodos de registro soportados:

1. **Cola de Aprobación** (método principal, ya funcional):
   - Agente envía `POST /api/agents/queue` con hostname, public_key, facts_snapshot
   - Admin revisa en la consola web `/agents/queue` y aprueba/rechaza
   - Agente hace polling `GET /api/agents/queue/:id/status` hasta obtener `approved`
   - Al aprobar se crea el agente definitivo con `agent_id`

2. **OTP** (código de un solo uso reutilizable):
   - Admin genera código OTP con org/location predeterminados
   - Agente envía `POST /api/agents/register/otp` con el código
   - Se registra automáticamente en la org/location del OTP

3. **Admin Directo** (registro manual vía API autenticada):
   - Admin envía `POST /api/agents/register/admin` con token JWT

### 2.2 Instalación como Servicio

Una vez registrado (o durante el registro vía GUI):

```
pswm.exe install
  → Copia a C:\Program Files\pswm-reborn\
  → pswm.exe         (agente principal - ejecuta acciones)
  → pswm_svc.exe     (bucle de servicio - llama periódicamente a pswm.exe)
  → pswm_updater.exe (futuro: gestor de actualizaciones)
  → Registra servicio Windows "pswm-reborn" (StartupType: Manual)
```

### 2.3 Bucle Operativo (Iteración)

El servicio (`pswm_svc.exe svc`) ejecuta periódicamente (cada 90 min) el comando `iterate`:

```
pswm.exe iterate
  │
  ├── 1. Subir Facts (hardware, SO, red, discos, etc.)
  │     POST /api/facts/:agent_id/facts
  │
  ├── 2. Consultar Scripts pendientes
  │     GET /api/deployments/agent/:agent_id
  │     Para cada script pendiente:
  │       → Descargar contenido
  │       → Ejecutar con timeout
  │       → Reportar resultado: POST /api/deployments/runs
  │
  ├── 3. Consultar Chocolatey deployments pendientes
  │     GET /api/choco/deployments/agent/:agent_id
  │     Para cada deployment:
  │       → Ejecutar choco install/upgrade/uninstall
  │       → Reportar resultado: POST /api/choco/runs
  │
  ├── 4. Sincronizar inventario Chocolatey
  │     choco list → POST /api/choco/agent-packages
  │
  └── 5. Reportar check_status
        (conectividad OK, versión agente, timestamp)
```

### 2.4 Entidades del Sistema

```
Organization (empresa/tenant)
  └── Location (sede/oficina, jerárquico con parent_id)
       └── Agent (equipo Windows)
            ├── Tags (etiquetas libres para clasificar)
            ├── Groups (agrupaciones lógicas)
            ├── Facts (datos recopilados: HW, SW, red, custom)
            └── Choco Packages (inventario instalado)

Scripts (repositorio centralizado de .ps1)
  └── Deployments (asignación a targets: org/location/group/agent)
       └── Runs (ejecuciones con stdout/stderr/exit_code)

Choco Packages (catálogo de paquetes)
  └── Choco Deployments (install/upgrade/uninstall a targets)
       └── Choco Runs (resultados de ejecución)
```

### 2.5 Targeting (Despliegues)

Los scripts y paquetes choco se despliegan a **targets**, que pueden ser:
- `organization` → afecta a todos los agentes de esa organización
- `location` → afecta a agentes de esa ubicación
- `group` → afecta a agentes de ese grupo
- `agent` → afecta a un agente específico

El agente consulta sus despliegues pendientes y el servidor resuelve los targets.

## 3. Estado Actual del MVP

### Servidor (≈80% implementado)
- ✅ 22 tablas en SQLite con esquema completo
- ✅ ~70+ endpoints API REST implementados
- ✅ 15 páginas en la consola web (dashboard, agentes, cola, scripts, despliegues, choco, orgs, locations, grupos, tags, usuarios)
- ✅ Auth JWT con rotación de secrets
- ✅ Onboarding: cola, OTP y admin directo
- ✅ CRUD completo: scripts, despliegues, choco, organizaciones, etc.
- ❌ WebSocket (futuro: force-iterate, consola remota)
- ❌ Resolución jerárquica de choco_settings
- ❌ Logs de auditoría sistemáticos

### Agente (≈40% implementado)
- ✅ Build con ps2exe funcional
- ✅ Onboarding por cola con polling
- ✅ Generación de claves RSA (PS5+PS7 compatible)
- ✅ Instalación como servicio Windows
- ✅ GUI básica (instalación + gestión de servicio)
- ✅ Gestión de config (view, archive, restore)
- ❌ **Comando `iterate`** (el bucle operativo completo)
- ❌ Subida de facts al servidor
- ❌ Ejecución de scripts desde despliegues
- ❌ Integración con Chocolatey
- ❌ WebSocket client

## 4. Gaps Críticos para MVP Funcional

**La brecha principal es que el agente solo puede registrarse y verificar conectividad, pero no ejecuta ninguna acción operativa.** Se necesita:

1. **`iterate`** — comando que ejecute el ciclo completo: facts → scripts → choco → status
2. **Facts** — recopilar datos del equipo y enviarlos al servidor
3. **Ejecutor de scripts** — descargar y ejecutar scripts asignados por despliegues
4. **Chocolatey** — ejecutar operaciones choco y sincronizar inventario
5. **El servicio debe llamar a `iterate`** en vez de `check_status`

## 5. Arquitectura de Archivos del Agente

```
C:\Program Files\pswm-reborn\
  pswm.exe           ← Agente principal (todas las acciones)
  pswm_svc.exe       ← Copia para el servicio (llama a pswm.exe iterate)
  pswm_updater.exe   ← Copia para auto-actualización (futuro)

C:\ProgramData\pswm-reborn\
  config.json         ← agent_id, server_url, hostname
  agent_private.pem   ← Clave privada RSA
  agent_public.pem    ← Clave pública RSA
  external_facts\     ← Scripts .ps1 para facts personalizados
  scripts_cache\      ← Cache de scripts descargados
  logs\
    svc.log           ← Log del servicio
```

## 6. Tecnologías y Dependencias

| Componente | Stack |
|---|---|
| Servidor API | Node.js, Express, better-sqlite3, jsonwebtoken, bcryptjs |
| Consola Web | SvelteKit 2, Tailwind CSS, Vite |
| Agente | PowerShell 5.1+, ps2exe (compilación), WinForms (.NET) |
| Base de Datos | SQLite (archivo `data/data.db`) |
| Comunicación | HTTPS REST (futuro: WebSocket para señales y consola remota) |
