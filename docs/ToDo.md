** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

No tienes que modificar el contenido, nada mas que para marcarlo como hecho, si quieres puedes añadir algo bajo el punto que corresponda, comentarios que empiecen por # 

---

+ En la pestaña "Pacakages" de los detalles un Agente, bajo "PERFIL CHOCOLATEY ACTIVO" se muestra el badge con el perfil que aplica al agente, pero habíamos dicho que al hacer click en el badge, debía abrir una nueva ventana con "Perfiles de Chocolatey"  mostrando unicamente en el listado el perfil de chocolatey clickado.
> En la misma linea, con los "Despliegues de Choco" se abre la web, con el buscador rellenado con id:<id del despliege> pero no muestra ningun despliegue . Asegurate que se mestra el despliege seleccionado y tambien en el anterior el Perfil de Chocolatey seleccionado
> En la misma pestaña pars los paquetes de accion "adopt" que no están instalados has usado el emoji ⭕ y no me gusta , usa este 👻
+ He visto que el hace la descarga del agente esde la url de la api http://<servidor>:3000/api/updates/download y yo me refería que lo hiciera desde la url del enlace público http://<servidor>:3000/agent/pswm.exe del server
+ La pestaña nueva que agregamos a "Configuracion  del Servidor" llamada "Actualizaciones" quiero que la muevas dentro de "Versiones de Agente" y la llames "Beta" y dentro de la seccion muestra la version seleccionada, si no hay version seleccionado pues algo que diga que no está seleccionada.
> Adicionalmente, dentro de esa seccion se puede seleccionar un Grupo, y quier hacerlo mediante el selector de grupos predeterminado tipo popup que está documentado, y luego el grupo seleccionado se muestra como un badge igual que seleccionamos grupos dentro de la ficha de edicion de un "Agente", con la salvedad que aqui unicamente se puede seleccinar un grupo.
> Tambien el modo de actualización beta quiero que uses 3 botones igual que en modo de publicacion de "Versiones" dentro de Versiones de Agente.
+ En la ficha de Edicion de un Agtente en Ubicación no estas mostrando el badge predeterminado de ubicacion tal como  está documentado debe contener todo el path desde la organización hasta la localización final.


+ Cuando pulso sobre la pestaña "Beta" dentro de "Versiones de Agente" se abre automaticamente el selector de grupos predeterminados, sin posibilidad de cerrarlo.
> El selector de grupos solo debe abrirse para seleccionar un grupo cuando quiero elegir o cambiar el grupo que recibirá la version beta.
+ Cuando hago click sobre un badge de un "DESPLIEGUE DE CHOCOLATEY ACTIVO" en la pestaña "Packages" de un agente, abre la vista "Despliegues de Chocolatey"  , con el campo de búsqueda rellenado con id:<id del despliegue> per no se muestra nada en la lista como si no lo encontrara, dice "No hay despliegues que coincidan"

+ Cuando voy a crear un despliege de choco, me sale un alert que dice Error: Internal y no lo crea
# Corregido en src/routes/choco.js: variable groupId no estaba definida en POST /deployments. Añadido crypto.randomUUID() y packages ahora es opcional (array vacío por defecto).
+ En todos los sitios que se registra la IP está detectando la IP de la máquina que tiene instalado el cloudflared tunnel y no la real del cliente.
> Ten en cuenta esto porque se puede dar el caso de que sean conexiones por clodflared o directas y en ambas quiero que se detecte la IP real.
> Los sitios que ahora mismo recuerdo donde se registran las IP son los siguientes : En la ficha de cada agente, En la cola de aprobación, en mi perfil en la gestion de sesiones activas, En la pestaña de "Descargas públicas" de "Versiones de Agentes", en las gestion de sesiones activas de la gestion de usuarios.
> Revisa por si se me queda algun otro sitio que registre la IP
# Corregido: creado src/utils.js con getRealIp(req) que prioriza CF-Connecting-IP > X-Forwarded-For > req.ip. Aplicado en index.js (login + descarga), middleware/agent_auth.js, routes/agents.js (registro token + cola), routes/facts.js.
+ En la vista de "Todos los agentes", quiero hacer varios cambios:
> El orden por defecto es por la columna "Ultimo Contacto" primero los mas recientes
> Tambien quiero tener la posibilidad de ir seleccionado en cada columna para ordenar el listado por esa columna y ascentente o descendente
> Cuando tengo seleccionado una Org / Ubicacion y refresco la pagina, quiero que preserve tanto la busqueda en el texto cmo la Org / Ubicacion
> El selector de Ubicacion aqui, debería permitirme seleccionar tambien una organización, pero como es el "Selector de Localizaciones" no permite seleccionar una ORganización, modifica para que al menos aqui permita seleccionar si quiero solo la organización.
> Cuando un agente está deshabilitado, y ocultarlo por defecto, ya que al desactivarlo tambien lo consideramos inactivo.
# Implementado en agents/+page.svelte: orden por defecto last_contact DESC, cabeceras ordenables con ▲▼, filtros (texto, org, ubicación, inactivos, deshabilitados) persistidos en URL (?q=&orgId=&locId=&sortCol=&sortDir=&showDisabled=), LocationPickerModal con allowOrgOnly=true, checkbox "Mostrar deshabilitados" (ocultos por defecto). Import page de $app/stores eliminado.
+ Dentro de la ficha de agente en la pestaña "Paquetes" en la seccion Paquetes no gestionados, la columna "Fijado" va a la izquierda de la columna "Actualizacion Disponible" : El orden de seria "Paquete","Version","Actualización disponible", "Fijado"
# Corregido en agents/[id]/+page.svelte: columnas reordenadas a Paquete | Versión | Actualización disponible | Fijado.
+ Me está pasando que me solicita el usuario y contraseña despues de estar una hora sin conectar, pero aún así me siguen apareciendo en "Mis sesiones activas" , o arreglamos para que se mantenga mas tiempo o si me vuelve a pedir credenciales que elimine la otra anterior que es inválida.
# Corregido: JWT extendido de 12h a 7d en src/index.js. La query de sesiones activas (GET /me/sessions y GET /:id/sessions) ahora filtra revoked=0 AND expires_at>CURRENT_TIMESTAMP. Al hacer login se eliminan automáticamente las sesiones expiradas del usuario.

+ Quiero que cuando edito o creo una Organización no lo haga en la misma página inline,  ya que siguen apareciendo el resto de organzaciones y no es buena experiencia de usuario. Quiero una página dedicada la edicion/creación de la organición, incluso cuando estoy clonando
> Esto tambien pasa con "Scripts de PowerShell", "Grupos", "Despliegues", "Perfiles de Chocolatey", "Despliegues de Chocolatey", "Usuarios", y quizás algun sitio mas, evitemos este comportamiento de forma general
> Implementado: páginas dedicadas new/edit para Organizaciones, Grupos, Usuarios, Scripts, Despliegues PS, Perfiles Chocolatey, Despliegues Chocolatey. Cada lista actualizada con enlaces a las páginas dedicadas. Clonado abre el formulario de nueva entrada con datos pre-rellenados vía ?clone=<id>.
> Solucionalos todos
+ Cuando hay agentes en cola de espera para ser aprobados muestras un boliche rojo con la cantidad de ellos, quiero tambien que cuando se enrolen nuevos agentes de forma automática con token , muestre un boliche igual pero en color azul en "Todos los Agente"
> Mientras esté el boliche los agentes en la vista "Gestion de Agentes" se verán con un emoji junto al nombre que indique que son nuevas incorporaciones
> Implementado: badge azul en sidebar «Todos los Agentes» con contador de agentes enrollados por token desde la última visita al listado. Badge 🆕 junto al nombre del agente en la tabla. Se considera «visto» cuando el usuario visita /agents: se actualiza localStorage.agentsLastSeen = Date.now(). Sidebar refresca el contador cada 60s (mismo intervalo que el badge rojo de cola).
> El criterio para marcarlo como visto y quitar el boliche azul te dejo que lo sugieras y lo implementes, ademas despues de implementarlo, dime 4 alternativas.

+ En la actualización de paquetes de Chocolatey (Fase 8), si el paquete tiene definidos parámetros en el despliegue (action install o adopt), también hay que usar esos parámetros al ejecutar el upgrade
> Implementado en agent-core/pswm.ps1: en el bucle de actualización de la Fase 8 se busca el paquete en $managedInstallOrAdopt y, si tiene .params, se añaden al comando "choco upgrade <pkg> -y". El log también indica los parámetros usados.

+ En el popup que sale al pulsar el icono de info en los paquetes de la pestaña Chocolatey de la ficha de agente, el badge que muestra el despliegue al que está sujeto el paquete debe ser clicable igual que los badges de la zona "Despliegues Chocolatey Activos", abriendo una nueva ventana con ese despliegue filtrado
> Implementado en web-console/src/routes/(app)/agents/[id]/+page.svelte: añadido deplId a managedPkgsMap, helper getDeploymentIdForPackage, y los <span> del badge convertidos en <button> con on:click={() => window.open('/choco/deployments?q=id:${dId}', '_blank')}.

+ Tras los ultimos cambios, en "Despliegues de Chocolatey" y "Perfiles de Chocolatey" no carga se queda el texto "Cargando..."
# Corregido: faltaban las funciones loadAll() y onMount() en choco/+page.svelte y choco/deployments/+page.svelte (eliminadas por el script de fix). También faltaba handleDelete en perfiles. Añadidas las tres funciones en ambos archivos.
+ Para los "choco upgrade -y" junto con $managedInstallOrAdopt que implementamos anteriormente, no te olvides tambien de añadir por defecto el parametro --no-progress , a fin de eliminar ruido de la salida de texto de los comandos.
# Añadido --no-progress en el comando upgrade de la Fase 8 en pswm.ps1. Ahora es "upgrade $pkgName -y --no-progress [+ params si los tiene]".
+ Respecto al boliche azul que hemos implementado para resaltar que hay equipo nuevos con enrolamiento por token, quiero proponer una alternativa al visto, que sea cuando pulse explicitamente sobre el boliche azul
> Ademas quiero que cuando pase el punto por encima cambiede color se ponga verde con un simbolo de "Marca de Verificacion" ademas haga popup un tooltip estilo viñeta, hacia la derecha que diga marcar como visto X equipos nuevos.
# Implementado: el badge azul en el sidebar es ahora un botón interactivo. Al hacer hover → cambia a verde con ✓ y muestra tooltip tipo viñeta "Marcar como visto · X equipos nuevos". Al hacer click → llama markTokenAgentsSeen() que guarda localStorage.agentsLastSeen y resetea el contador. Ya no se marca automáticamente al visitar /agents.

+ El popup junto al boliche azul , estilo viñeta que dice "Marcar como visto X euipos nuevos" , se ve cortada cuando sobresale por la derecha de la zona del side menu (adjunto captura)
> Además cuando ejecuto desde npm run dev , me gustaría poder activar el boliche azul al fin de poder testearlo, añade una configuracion dentro de la configuracion del sistema en una nueva pestaña que se llame "DEV - LAB"
# Corregido: tooltip ahora usa position:fixed calculado con getBoundingClientRect() — ya no se corta. DEV-LAB añadido en Configuración → pestaña 🧪 DEV - LAB con toggle para forzar el boliche azul (guarda en localStorage devLab_forceBlueBadge).
+ El emoji 🆕 que aparece cuando es un agente de nueva icorporación , quiero que apareza a la izquierda del ID del equipo, y quitalo de estar junto al nombre
# Corregido: 🆕 ahora aparece a la izquierda del ID en su propia columna. Eliminado del campo nombre.
+ En el DashBoard general en la Card Agentes, el recuento tiene que ser de todos menos lo desactivados, pero debajo, en el pie de la card indicas el total real, con desactivados.
# Corregido: stats.agents = agentes con status !== 'disabled'. Si el total difiere, se muestra pie: "Total con deshabilitados: N".

+ La pestaña "DEV - LAB" en Configuracion del Servidor, solo debe estar disponible si el web console se está ejecutando con npm run dev
# Implementado: import { dev } from '$app/environment' en settings/+page.svelte. El botón de la pestaña DEV-LAB se envuelve en {#if dev}{/if}. En producción (build) la variable dev es false y la pestaña no aparece.
+ He publicado en el canal Beta una version nueva del agente:
> La version del agente Estable es actualmente 2026.3.12.03474 con modo de publicación Upgrade
> He publicado en el canal beta la version 2026.3.13.02081 con modo de actualizacion beta a Upgrade
> He metido un agente en el grupo designado para actualizaciones beta
> He lanzado manualmente una iteracion en ese agente con "pswm iterate" y me da el siguiente error
----
PS C:\Program Files\pswm-reborn> .\pswm.exe iterate
[INFO] === Iniciando iteracion ===
[INFO] Iteration ID: 639089707242612006
[INFO] Agent ID: 4 | Server: https://pswm-server.phiro.es
[INFO] [TimeSync] Iniciando sincronización de reloj...
[OK] [TimeSync] Reloj sincronizado (drift: 1s)
[INFO] [RegisterKey] Registrando clave pública en el servidor (agent_id: 4)...
[INFO] [RegisterKey] El servidor ya tiene una clave válida para este agente.
[OK] JWT RS256 generado (TTL: 90 min)
[INFO] Paso 1/4: Recopilando y enviando facts...
[OK] Facts enviados: 22 registros
[INFO] Paso 2/4: Consultando scripts pendientes...
[INFO] 4 despliegue(s) de scripts encontrados
[INFO]   Facts: 2 | Actions: 2
[INFO]   --- Ejecutando fact scripts ---
[INFO]   [FACT] Ejecutando script 'Get-BitLocker' (deployment 1, script 3)...
[INFO]     Exit code: 0
[OK]     Fact generado: get_bitlocker
[INFO]   [FACT] Ejecutando script 'Get-Services' (deployment 2, script 2)...
[INFO]     Exit code: 0
[OK]     Fact generado: get_services
[INFO]   --- Ejecutando action scripts ---
[INFO]   [ACTION] Ejecutando script 'ShowRunAsDifferentUserInStart' (deployment 3, script 1)...
[INFO]     Exit code: 0
[INFO]   [ACTION] Ejecutando script 'remedy-CVE202230190' (deployment 4, script 4)...
[INFO]     Exit code: 0
[OK] Scripts procesados
[INFO] Paso 3/5: Obteniendo configuración Chocolatey resuelta...
[INFO]   Config resuelta: 21 paquete(s), perfil: upgrade-all
[INFO]   Recolectando estado actual de Chocolatey...
[INFO]   Estado: 29 paquetes, 2 pins, 1 sources, 30 features
[INFO]   Fase 1: Sincronizando sources...
[INFO]   Fase 2: Sincronizando features...
[INFO]   Fase 3: Sincronizando configuración...
[INFO]   Fase 6: Instalando paquetes...
[INFO]     7zip ya instalado (v26.0.0), saltando instalación
[INFO]     googlechrome ya instalado (v146.0.7680.66), saltando instalación
[INFO]     winrar ya instalado (v7.20.0), saltando instalación
[INFO]     adobereader ya instalado (v2025.1.21223), saltando instalación
[INFO]     anydesk ya instalado (v9.6.11), saltando instalación
[INFO]     autoruns ya instalado (v14.11.0), saltando instalación
[INFO]     googledrive ya instalado (v121.0.1), saltando instalación
[INFO]     handbrake ya instalado (v1.11.0), saltando instalación
[INFO]     jre8 ya instalado (v8.0.481), saltando instalación
[INFO]     paint.net ya instalado (v5.1.12), saltando instalación
[INFO]     pdfcreator ya instalado (v6.2.2), saltando instalación
[INFO]     tcping ya instalado (v0.39.20180614), saltando instalación
[INFO]     vlc ya instalado (v3.0.23), saltando instalación
[INFO]   Fase 6b: Adoptando 8 paquete(s) (sólo si ya instalados)...
[INFO]     chocolatey-compatibility.extension adoptado sin cambio de versión (v1.0.0)
[INFO]     chocolatey-core.extension adoptado sin cambio de versión (v1.4.0)
[INFO]     chocolatey-os-dependency.extension no está instalado, adoptarlo ignorado
[INFO]     chocolatey-windowsupdate.extension adoptado sin cambio de versión (v1.0.5)
[INFO]     dontsleep no está instalado, adoptarlo ignorado
[INFO]     dontsleep.install no está instalado, adoptarlo ignorado
[INFO]     foxitreader no está instalado, adoptarlo ignorado
[INFO]     spotify no está instalado, adoptarlo ignorado
[INFO]   Fase 7: Ajustando pins...
[INFO]   Fase 8: Saltando actualización - lock local: última hace 0.9d, frecuencia=1 días. (C:\ProgramData\pswm-reborn\choco_update_lock.json)
[INFO]   Resultado choco: OK
[OK] Configuración Chocolatey procesada
[INFO] Paso 4/5: Sincronizando inventario Chocolatey...
[INFO]   [choco outdated] Usando caché (-1.9h de antigüedad, límite 16h). Archivo: C:\ProgramData\pswm-reborn\choco_outdated_cache.json
[INFO] Inventario choco sincronizado: 29 paquetes (21 gestionados)
[INFO] Paso 5/5: Comprobando actualizaciones...
[INFO] Version actual: 2026.03.12.03474
[INFO] Actualizacion disponible (modo upgrade): v2026.3.13.2081
[INFO] Descargando actualizacion...
[ERROR] Error descargando actualizacion: {"error":"no update available"}
[INFO] pswm_updater.exe ya esta sincronizado (v2026.03.12.03474)
[INFO] Paso 6: Re-generando facts (post-iteracion)...
[OK] Facts post-iteracion enviados: 22 registros
[OK]     Fact script post-iter actualizado: get_bitlocker
[OK]     Fact script post-iter actualizado: get_services
[OK] === Iteracion completada en 1m 2seg ===
PS C:\Program Files\pswm-reborn> .\pswm.exe version
psWinModel Reborn Agent v2026.03.12.03474
PowerShell 5.1.26100.1591
Modo: Legacy RSA (PowerShell < 7)
PS C:\Program Files\pswm-reborn> .\pswm.exe version
psWinModel Reborn Agent v2026.03.12.03474
PowerShell 5.1.26100.1591
Modo: Legacy RSA (PowerShell < 7)
PS C:\Program Files\pswm-reborn> .\pswm.exe iterate
[INFO] === Iniciando iteracion ===
[INFO] Iteration ID: 639089710787264519
[INFO] Agent ID: 4 | Server: https://pswm-server.phiro.es
[INFO] [TimeSync] Iniciando sincronización de reloj...
[OK] [TimeSync] Reloj sincronizado (drift: 1s)
[INFO] [RegisterKey] Registrando clave pública en el servidor (agent_id: 4)...
[INFO] [RegisterKey] El servidor ya tiene una clave válida para este agente.
[OK] JWT RS256 generado (TTL: 90 min)
[INFO] Paso 1/4: Recopilando y enviando facts...
[OK] Facts enviados: 22 registros
[INFO] Paso 2/4: Consultando scripts pendientes...
[INFO] 4 despliegue(s) de scripts encontrados
[INFO]   Facts: 2 | Actions: 2
[INFO]   --- Ejecutando fact scripts ---
[INFO]   [FACT] Ejecutando script 'Get-BitLocker' (deployment 1, script 3)...
[INFO]     Exit code: 0
[OK]     Fact generado: get_bitlocker
[INFO]   [FACT] Ejecutando script 'Get-Services' (deployment 2, script 2)...
[INFO]     Exit code: 0
[OK]     Fact generado: get_services
[INFO]   --- Ejecutando action scripts ---
[INFO]   [ACTION] Ejecutando script 'ShowRunAsDifferentUserInStart' (deployment 3, script 1)...
[INFO]     Exit code: 0
[INFO]   [ACTION] Ejecutando script 'remedy-CVE202230190' (deployment 4, script 4)...
[INFO]     Exit code: 0
[OK] Scripts procesados
[INFO] Paso 3/5: Obteniendo configuración Chocolatey resuelta...
[INFO]   Config resuelta: 21 paquete(s), perfil: upgrade-all
[INFO]   Recolectando estado actual de Chocolatey...
[INFO]   Estado: 29 paquetes, 2 pins, 1 sources, 30 features
[INFO]   Fase 1: Sincronizando sources...
[INFO]   Fase 2: Sincronizando features...
[INFO]   Fase 3: Sincronizando configuración...
[INFO]   Fase 6: Instalando paquetes...
[INFO]     7zip ya instalado (v26.0.0), saltando instalación
[INFO]     googlechrome ya instalado (v146.0.7680.66), saltando instalación
[INFO]     winrar ya instalado (v7.20.0), saltando instalación
[INFO]     adobereader ya instalado (v2025.1.21223), saltando instalación
[INFO]     anydesk ya instalado (v9.6.11), saltando instalación
[INFO]     autoruns ya instalado (v14.11.0), saltando instalación
[INFO]     googledrive ya instalado (v121.0.1), saltando instalación
[INFO]     handbrake ya instalado (v1.11.0), saltando instalación
[INFO]     jre8 ya instalado (v8.0.481), saltando instalación
[INFO]     paint.net ya instalado (v5.1.12), saltando instalación
[INFO]     pdfcreator ya instalado (v6.2.2), saltando instalación
[INFO]     tcping ya instalado (v0.39.20180614), saltando instalación
[INFO]     vlc ya instalado (v3.0.23), saltando instalación
[INFO]   Fase 6b: Adoptando 8 paquete(s) (sólo si ya instalados)...
[INFO]     chocolatey-compatibility.extension adoptado sin cambio de versión (v1.0.0)
[INFO]     chocolatey-core.extension adoptado sin cambio de versión (v1.4.0)
[INFO]     chocolatey-os-dependency.extension no está instalado, adoptarlo ignorado
[INFO]     chocolatey-windowsupdate.extension adoptado sin cambio de versión (v1.0.5)
[INFO]     dontsleep no está instalado, adoptarlo ignorado
[INFO]     dontsleep.install no está instalado, adoptarlo ignorado
[INFO]     foxitreader no está instalado, adoptarlo ignorado
[INFO]     spotify no está instalado, adoptarlo ignorado
[INFO]   Fase 7: Ajustando pins...
[INFO]   Fase 8: Saltando actualización - lock local: última hace 0.9d, frecuencia=1 días. (C:\ProgramData\pswm-reborn\choco_update_lock.json)
[INFO]   Resultado choco: OK
[OK] Configuración Chocolatey procesada
[INFO] Paso 4/5: Sincronizando inventario Chocolatey...
[INFO]   [choco outdated] Usando caché (-1.8h de antigüedad, límite 16h). Archivo: C:\ProgramData\pswm-reborn\choco_outdated_cache.json
[INFO] Inventario choco sincronizado: 29 paquetes (21 gestionados)
[INFO] Paso 5/5: Comprobando actualizaciones...
[INFO] Version actual: 2026.03.12.03474
[INFO] Actualizacion disponible (modo upgrade): v2026.3.13.2081
[INFO] Descargando actualizacion...
[ERROR] SHA256 no coincide! Esperado: 2e4eb2e642cc0f22e08faa24156d49a6f68dad7eb6041ad02e7338a3aac664d7, Obtenido: 5fcc28eea35319e9fd2f9e970ae19d5e634e5c39ba6fec7aa28c5f1187674d8e
[INFO] pswm_updater.exe ya esta sincronizado (v2026.03.12.03474)
[INFO] Paso 6: Re-generando facts (post-iteracion)...
[OK] Facts post-iteracion enviados: 22 registros
[OK]     Fact script post-iter actualizado: get_bitlocker
[OK]     Fact script post-iter actualizado: get_services
[OK] === Iteracion completada en 1m 1seg ===
PS C:\Program Files\pswm-reborn>
----
# Corregido: el endpoint GET /api/updates/download ahora usa req.agentId (del JWT via agentAuthMiddleware) para comprobar si el agente está en el grupo beta. Si está en beta y beta_update_mode != 'disabled', sirve la versión con beta_published=1. Si no, cae al canal estable (published=1). Así el SHA256 que devuelve /check y el binario de /download siempre corresponden al mismo canal.

+ Tras una reciente implantación hemos introducido un fallo en los "Despliegues de Chocolatey" , tanto cuando voy a crear uno nuevo como cuando edito uno existente, en los "Paquetes" debemos definir el nombre del paquete, la accion , version , parametros y pin; pues en la accion ahora tenemos Instalar, Desinstalar y Actualizar, y antes eran Instalar, Desinstalar y Adoptar . Revisa en versiones anteriores para dejar esas opciones como antes, respetando la posibles dependencias.> Implementado: opciones `upgrade`→`adopt` en los dos formularios (new y edit). `actionLabel`/`actionColor` actualizados en las 3 páginas de despliegues choco para manejar `adopt` (color `bg-purple-100 text-purple-800`).
+ En la vista "Todos los agentes" hemos introducido recuentemente el boliche azul que indica los nuevos agentes enrolados mediante token. Pues parece ser que almacenamos en local la fecha en la que hemos pulsado la validacion de visto, y eso debería estar almacenado en la bdd en el perfil de cada usuario para que sea transversal a las diferentes maquinas donde pueda iniciar sesion.
> Implementado: nueva columna `token_agents_seen_at TEXT` en tabla `users` (migración automática). Endpoint `GET /api/users/me` y `PUT /api/users/me/preferences`. El layout lee/guarda desde la API; `agents/+page.svelte` también lee desde la API en onMount.
+ En la vista "Todos los agentes" en la columna estado quiero que pongas un icono de alerta/adevertencia en aquellos equipos que las ultimas 3 iteraciones han finalizado "Con errores"
> Implementado: subquery SQL en `GET /api/agents` que comprueba si las últimas 3 iteraciones finalizadas tienen `had_errors=1`. Campo `last3_all_errors` añadido. En la columna Estado del listado se muestra ⚠️ con tooltip si el campo es verdadero.
+ Tambien en la vista de detalles del agente arriba en la card donde aparece el nombre del equipo y debajo el ID <ID > · Hostname: <HOST EQUIPO> , quiero que tambien apareza el owner del equipo si está definido.
> Implementado: en `agents/[id]/+page.svelte` la línea del header card muestra `· 👤 {agent.owner}` si está definido.
+ En la visa "Todos los agentes" en la columna version , a todos aquellos equipos que tengan la misma version que la publicada en el canal beta les pongas un pequeño badge en rojo con el texto BETA como superindice junto a la version que tienen instalada.
> Tambien dentro en la pagina de "Detalles del Agentes" junto a al valor de "Version agente" si procede
> Implementado: nuevo endpoint `GET /api/updates/beta-version` (auth requerida, cualquier rol). En `agents/+page.svelte` y `agents/[id]/+page.svelte` se carga la versión beta y se muestra badge rojo `BETA` junto a la versión si coincide.
+ En los despliegues de Powershell, tenemos la opcion ejecutar una sola vez. Quiero tener alguna forma de controlar los scripts de ese despliegue que ya se ha ejecutado en algun equipo y ver el resultado, y poder resetear para cada equipo en cocreto el estado como que ya se ha ejecutado para que lo reitere.
> Cada script que tenga que se ejecutado una sola vez, se dará por ejecutado cuando se haya ejecutado con salida sin errores, si tiene errores se seguirá reintentando durantes las siguientes iteraciones.
> En las iteraciones este tipo de ejecuciones de scripts me gustaría que estuvieran acompañadas de un emoji propicio para indicar que es de una sola ejecución (lo pondríamos justo a la derecha del nombre del script en la iteración)
> Implementado: endpoints `GET /api/deployments/:id/single-run-status` y `DELETE /api/deployments/:id/single-run-status/:agentId`. Corregida lógica de salto del agente (solo salta si exit_code=0). Badge 🔂 en nombre del despliegue, botón en acciones que abre modal con tabla de equipos + botón de reseteo. Emoji 🔂 en iteraciones junto al nombre del script cuando `single_run=1`. Query `runs/agent/:id` incluye campo `single_run`.
+ El estilo del badge de beta lo quiero fondo rojo con letras blancas, mas pequeño y ubicado a la derecha del numero de la version con un espacio de por medio.
> Implementado: badge cambiado a `bg-red-600 text-white text-[10px]` en ambas vistas (lista y detalle agente).
+ Me sale el boliche azul como que hay un equipo nuevo, le doy a "Marcar como visto 1 equipo nuevo" y desaparece, pero si recargo la pagina vuelve a aparecer.
> Resuelto por la Tarea 2: al persistir `token_agents_seen_at` en la BDD (usuario), el reload carga el timestamp correcto desde la API y el badge no reaparece.+ En la vista "Todos los agentes" hemos introducido recuentemente el boliche azul que indica los nuevos agentes enrolados mediante token. Pues parece ser que almacenamos en local la fecha en la que hemos pulsado la validacion de visto, y eso debería estar almacenado en la bdd en el perfil de cada usuario para que sea transversal a las diferentes maquinas donde pueda iniciar sesion.
# Marcado como implementado (tarea duplicada de la anterior).


+ Permite conexiones al proyecto cuando he ejecutado npm run dev desde otras ips de mi red local, para los 2 proyectos, el server como el web-console
# Implementado: vite.config.ts con server.host='0.0.0.0' y proxy /api→localhost:3000. api.ts usa URL relativa ('') por defecto — funciona vía proxy en dev y mismo origen en producción.
+ Cuando recargo la web, me sigue apareciendo el boliche azul a pesar de haber dado click a "Marcar como visto 1 equipo nuevo"
# Implementado: persistencia dual en markTokenAgentsSeen() (localStorage + BDD). En onMount se toma el máximo entre BDD y localStorage, con localStorage como fallback inmediato si la API falla.
+ La ubicacion del badge BETA aparece debajo de la verion lo quiero a la izquierda, además la quiero poco ma pequeña sobr todo en cuanto a lo alto del badge, pero que se siga viendo el texto BETA correctamente.
# Implementado: badge movido a la IZQUIERDA de la versión en agents/+page.svelte (inline-flex) y agents/[id]/+page.svelte. Padding vertical cambiado de py-0.5 a py-px para menor altura. Elimina salto de línea.

+ Me equivoque el badge de beta lo quiero a la derecha de la version (en la vista "Todos los Agentes"), pero el formato , estilo y dimensiones que tiene ahora mismo es el perfecto, conservalo pero cambialo a la derecha del numero de la version.
# Implementado: badge movido a la DERECHA en agents/+page.svelte (versión primero, badge después). En agents/[id]/+page.svelte se mantiene a la izquierda.
>  Dentro de la vista de "Detalles del Agente" si quiero que esté a la izquierda, tal como está ahora mismo.
+ Cuando cargo la vista "Todos los agentes" se ve bien, pero si le doy a recargar, me sale Cannot GET /agents y en la consola de dev de firefox me sale esto:
# Corregido: el proxy en vite.config.ts usaba '/agent' (sin barra final) que capturaba también '/agents' y lo reenviaba al servidor Express (404). Cambiado a '/agent/' para que solo intercepte rutas de descarga como /agent/pswm.exe.
---
Navega a http://localhost:5173/agents
GET
http://localhost:5173/agents
[HTTP/1.1 404 Not Found 3ms]

Content-Security-Policy: La configuración de la página bloqueó la carga de un recurso (media-src) en data: porque viola la siguiente directiva: “default-src 'none'” agents
Content-Security-Policy: La configuración de la página bloqueó la carga de un recurso (img-src) en http://localhost:5173/favicon.ico porque viola la siguiente directiva: “default-src 'none'”
---