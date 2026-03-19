** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

No tienes que modificar el contenido, nada mas que para marcarlo como hecho. Lo que si quiero que hagas es añadir un descripcion de lo que has hecho, con detalles resumidos, bajo el punto que corresponda, comentarios que empiecen por #

Además quiero que cada vez que implementes una tareas o una característica, hagas un git commit , pero no hagas git push , excepto peticion expresa.

Antes de empezar designa un orden de las tareas o características, desde la mas sencilla a la mas complicada, para que las implementes en ese orden.

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

---

+ Las fechas que pusimos anteriormente  para indicar si la version del pswm era superior (Flecha Arriba Azul) o inferior (Fecha Abajo Roja) a la estable, son muy pequeñas, quiero que sean un poco mas visibles mas bolded, quizás un poco mas grande pero sin sobrepasar el tamaño de letra la propia version, simplemente quiero que sean visibles comodamente a la vista.
> Además me gustaría que esos casos el tipo de letra donde dice la version para las que sean superior o inferior a la estable, apareza en tipo cursiva
# Implementado: flechas cambiadas de text-sm a text-base font-bold en ambas vistas (lista y detalle). Versión en cursiva (italic) cuando difiere de la estable.
+ Se me da el caso de que un agente ha actualizado la version del pswm, pero finaliza la iteración y en los "Detalles del Agente" si apareciendo que tiene la version anterior. En la ultima fase del pswm quiero que tambien envíe la información de la version ya actualizada.
# Implementado: al lanzar el updater se guarda $script:PendingUpdateVersion con la versión destino. En Collect-Facts (Paso 6 post-iteración) se usa esa versión en lugar de leer del proceso en memoria, que aún tiene la versión antigua.
+ Al pswm para la accion restore_config agregale el parametro --force que quiere decir que lo restaure auque haya archivos o certificados existente, y los sobrescriba, eso si que muestren los warnings de que ha sido sobreescrito.
> Por si acaso si existe una config anterior, antes de sobreescribirlo salvas la existente con el nombre _autosave , eso si, si ya hay otro _autosave este si lo sobreescribimo sin contemplacion.
# Implementado: --force en restore_config. Con --force, crea backup _autosave de config.json, agent_public.pem y agent_private.pem existentes (sobreescribiendo cualquier _autosave anterior) y luego restaura el ZIP. Sin --force, se aborta si hay archivos existentes (comportamiento original). Ayuda actualizada con ejemplos.
+ Dentro de "Iteraciones en ejecuciones de scripts, en la columna detalles tenemos puesto un icono de un ojo (tachado/sin tachar segun estado) para que deslplieuge el stdout y stderr de la iteracion de objeto de forma inline, una vez desplegada tenemos en donde aparece el texto del stdout/sterr arriba a la derecha un icono con flechas que su tootltip es "Ampliar" y lo que hace es abrir un popup  con todo el stdout run. Bien quiero quitar el icono de ojo que lo muestra inline (ya no lo veremos inline) y poner el icono de ampliar, y que se abra el popup ya implementado.
# Implementado: eliminado icono ojo (toggle inline) y bloque de expansión inline en ambas vistas (desktop tabla y móvil cards). Reemplazado por icono de ampliar (flechas) que abre directamente el popup modal existente con stdout+stderr+error combinados.
+ He creado un "Despliegue de Choco" con obejtivo "Grupos", y he asignado mi máquina a uso de esos grupos. Los paquetes que he puesto en ese despliegue básicamente es sl Skype en modo uninstall. Cuando voy a la pestaña de los detalles de agente de mi equipo, luego a Packages, si bien arriba en "Despliegues de Chocolatey Activos" veo el nombre del despliegue, luego abajo en la lista de packages el skype me aparece en la zona de No gestionados, y entidiendo que debería aparecer en la zona de gestionados, y con el icono de de la cesta basura indicando que en la siguiente iteracion se desinstalará este paquete.
> Tambien he comprobado iterando "pswm iterate" que efectivamente no lo desinstala.
# Corregido: causa raíz era que los paquetes del despliegue habían desaparecido de la tabla choco_deployment_packages. El endpoint PUT /api/choco/deployments/:id borraba incondicionalmente los paquetes existentes antes de reinsertar; si el campo packages no venía en el body (undefined) los paquetes se perdían permanentemente. Fix: ahora solo se borran y reinsertan los paquetes cuando packages es explícitamente un Array. Datos restaurados manualmente en la DB.
+ El listado de "Despliegues de Chocolatey" y tambien el de "Despliegues" de powershell me gustaría que estuvieran agrupados segun el tipo que son los siguientes:
> Todos
> Organizaciones
> Localizaciones
> Grupos
> Agentes
> * Ese tambien es el orden de arriba abajo de las categorías. Si no hay integrantes de alguna categoría, no muestres la categoría.
# Implementado: ambas listas (Choco y PS) ahora ordenan por target_type (Todos→Organizaciones→Localizaciones→Grupos→Agentes) e insertan cabeceras de sección entre cada categoría. Las categorías sin despliegues no se muestran.
+ En la "Configuración del sistema"  quiero que añadamos una nueva pesta que va a ser para definir la configuracion de los agentes. La idea es poder desplegar configuraciones para los agentes desde la consola.
> La primera configuración que quiero desplegar es el tiempo de espera entre iteraciones de los agentes, que ahora mismo la tenemos definida en 90 minutos.
> Tendrás que editar tambien en el agente pswm para que interprete y almacene esta configuración.
> Si el pswm va a consultar una configuración concreta y no está establecida cogerá un valor por defecto hardcodeado, para esta primera el valor por defecto hardcodeado es 90 minutos.
> Tambien quiero en los facts (built-in) que reporta pswm en los del agente añada tambien un nuevo nodo con todas las configuraciones que le aplica.
# Implementado: nueva pestaña "Agentes" en Configuración del sistema con slider para intervalo de iteraciones (1-1440 min, default 90). Nuevo endpoint GET /api/settings/agent-config con autenticación dual (usuario/agente). En pswm.ps1: función Get-AgentConfig que consulta al servidor y cachea en agent_config.json; el servicio C# y el modo interactivo leen el intervalo desde el cache antes de cada sleep. Nuevo fact built-in agent_config que reporta la configuración aplicada.
+ Dentro del SideMenu, en "Automatización" renombra "Despliegues" como "Despliegues PowerShell"
# Implementado: label del menú lateral cambiado de "Despliegues" a "Despliegues PowerShell" en +layout.svelte.
+ Tambien me gustaría que añadieras los controles para poder ordenar de forma ascendente/descente por columna de todas (igual que lo que usamos en la vista "todos los clientes") a cada una de estas vistas:
> "Cola de Aprobación y Tokens"
> "Tokens de registro"
> "Etiquetas"
> "Scripts de PowerShell"
> "Despliegues de Powershell" -> Aqui respeta la agrupacion por categoría/tipo
> "Perfiles de Chocolatey"
> "Despliegues de Choco" -> Aqui respeta la agrupacion por categoría/tipo
> "Descargas Públicas de pswm.exe"
> "Usuarios"
# Implementado: cabeceras ordenables (▲/▼/⇅) en las 9 vistas. Patrón sortCol/sortDir/toggleSort con indicadores visuales. En despliegues PS y Choco se respeta la agrupación por categoría (TYPE_ORDER) como primer criterio de ordenación. En Cola se ordenan ID, Hostname, IP, Método, Fecha, Estado. En Tokens: Descripción, Usos, Caduca, Estado. Descargas: Versión, IP, User-Agent, Fecha.
+ En "Editar Agente" añade una sección para agregar o quitar etiquetas, usando el mismo metodo y similar interfaz qu usamos para gregar o quitar grupos
# Implementado: nueva sección "Etiquetas" en la página de edición del agente, debajo de "Grupos". Usa TagPickerModal.svelte (estilo amber/🏷️) para seleccionar tags disponibles. Badges amber con ✕ para quitar. En save() se hace diff de tags actuales vs seleccionados llamando agentsApi.tags.add() / agentsApi.tags.remove(). Carga tags existentes del agente en init().

+ El "pswm view_config" tambien debería mostrar la agent_config y los hashes de los .pem
# Implementado: Invoke-ViewConfig ampliado en pswm.ps1. Ahora muestra 3 secciones: (1) config.json como antes, (2) agent_config.json (o mensaje si no existe), (3) Hashes SHA256 de agent_public.pem y agent_private.pem (o aviso si no existen).
+ He estado revisando las iteraciones de algunos equipos y se da el caso que se intenta desinstalar y actualizar el mismo paquete en misma iteracion (adjunto captura), esto no tiene sentido , si un paquete va a ser desinstalado, no debería ni intentar actualizarse. Esto no se si lo debemos hacer server-side o pswm-side, creo que deberíamos hacerlo en ambos sides o como minimo server-side
# Implementado: corrección en pswm.ps1 (Fase 8). Antes del bucle de upgrades se construye un hashtable $uninstallNames con los nombres en minúsculas de todos los paquetes con acción 'uninstall'. En cada iteración del bucle se comprueba si el paquete está en ese set y, si es así, se omite con log "marcado para desinstalar, se omite la actualización". Server-side no requería cambio: el endpoint /resolved ya devuelve correctamente los paquetes con action:'uninstall'; la lógica de upgrade era responsabilidad del agente.

+ Ahora se muestra el cursos parpadeando y tambien el texto mientras se escribe, pero o se muestra el texto de prompt donde indica la ubicacion ( ejemplo -> PS C:\Program Files\pswm-reborn>). No tiene porque se el mismo que pone powershell.exe pero algo que sea identificativo
+ En la vista "Todos los agentes" en acciones si el agente/equipo tiene activo "Sesión Remota Habilitada" , acciones, mostrar el botón del icono del terminal, pero el color debe varias si está el WS conectado o no. Al hacer click lleva a la seccion "Terminal" dentro de la ficha del Agente, y si es posble que automaticametne se abra el terminal, como si hubieramos pulsado "Abrir Terminal"
+ En la lista de Sesiones remotas, muestras los agentes con sesiones remota habilitada. Aquellos que tienen el WS Conectado, aparecen con un icono de un boliche verde con latidos, pues ese mismo icono, si lo tiene activo, quiero que apareza en "Todos los agentes" en la columna estado
> Tambien en la lista de sesiones remotas, quiero apareza El Owner, la anotacion y el Badge de la localización de cada agente.
+ En los interfaces de terminales que usamos para interactuar con la sesion remota quiero añadir algo donde podamos lanzar cualquiera de los scripts que están en "Scripts PowerShell", la dorma de seleccionarlo que sea mediante un popup.

+ En "Sesiones Remotas" me aparece el boliche verde con 1, como que hay un equipo conectado. Posbiblemente es un equipo que lo tiene habilitado, aunque ya le quité el setting "Sesión Remota Habilitada" , supongo que hasta que no itere no termina el proceso "pswm.exe remote_session", quiero que hagas 2 cosas
> Cuando se deshabilite el setting "Sesión Remota Habilitada", hacer lo propio para que el "pswm.exe remote_session" termine
> Igualmente en "Sesiones Remotas", ahora mismo mostramos "Agentes con Sesion Remota Habilitada", quiero que tambien se muestren los "Agentes con WS conectado" aunque tenga el setting "Sesión Remota Habilitada" deshabilitado.
# Implementado: Server (agents.js PUT) ahora envía server:disconnect con razón remote_session_disabled al agente vía WS cuando se deshabilita el setting, y cierra todas las sesiones de usuario activas. Agente (pswm.ps1 Invoke-RemoteSession) al recibir ese mensaje actualiza agent_config.json local poniendo remote_session_enabled=false, evitando reconexión. Página de sesiones (sessions/+page.svelte) ahora muestra agentes con remote_session_enabled O con WS conectado. SessionManager permite conexión de usuario si el agente tiene WS activo aunque el setting esté deshabilitado.
+ En la vista "Gestion de Agentes" quiero hacer 2 cambios:
> Arriba donde está el filtro de búsqueda tenemos "Mostrar inactivos","Mostrar deshabiltados", quiero unificarlos en un popup tipo viñeta, en lugar de usar checkboxes, usar switches slide, y además añade un nuevo que sea "Mostrar con session remota conectada"
> En las acciones quiero tener opcion para habilitar/deshabilitar el setting "Sesión Remota Habilitada" de los Agents selecionados.
> Los botones de acciones quiero que los juntes un poco, reduciendo el espacio horizontal entre ellos y quita el de "Deshabilitar Agente"
> Si puedes amplia un poco horizontalmente la tabla ya que el badge de "Ubicacion" se está convirtiendo en multilinea por la longitud.
> Tambien podemos reducir un poco el espacio horizontal entre la columna del ID , y la columna a la izquierda que tiene el checkbox.
> Aunque un agente tenga el setting "Sesión Remota Habilitada" deshabilitado, si tiene el WS conectado, muestra el icono verde con pulsos que ya usamos, y en la pestaña "Terminal" del mismo agente, mostrar igual que si tuviera el setting "Sesión Remota Habilitada" habilitado y listo para abrir el terminal. En definitiva, el setting define si debe o no iniciarse la sesion remota, pero el estado y los acceso se muestran si el agente está conectado.
# Implementado: filtros unificados en popup con switches slide (inactivos, deshabilitados, sesión remota conectada). Acciones masivas habilitar/deshabilitar sesión remota en dropdown. Eliminado botón individual deshabilitar. Reducido spacing en columnas checkbox/ID/acciones. Tabla ampliada a 90rem. Botón terminal visible si WS conectado aunque setting deshabilitado. Pestaña Terminal del agente muestra contenido si WS conectado.
+ Quiero añadir un setting global en "Sesiones Remotas", que esté bajo el setting  "Habilitar sesiones remotas globalmente" y que se llame, habilitar "Sesión Remota Habilitada" en equipos con interaciones erroneas, que es justamente para que lo habilite en los equipos en el que las 3 ultimas iteraciones han terminado con errores.
> Aqui hay que estar atentos, para que según pswm.exe termine la tercera iteración erronea registrada, ejecute sobre la marcha el proceso del remote session. Pero no lo ejecuta "pswm.exe" tal como está definido lo ejecuta "pswm_svc.exe" pero tras finalizar la tercer iteración errónea.
# Implementado: nuevo setting remote_session_on_error_iterations en página de Sesiones Remotas (switch bajo el global). Server-side: en PATCH de iteraciones, si had_errors=1 y el setting está activo, consulta las 3 últimas iteraciones; si todas erróneas activa remote_session_enabled en el agente. Agente: tras Finish-AgentIteration refresca agent_config.json llamando Get-AgentConfig, para que pswm_svc.exe detecte el cambio en ManageRemoteSession y lance remote_session inmediatamente.
+ En toda la seccion "Sesiones remotas" sustituye los checkbock tradicionales por Switches Tipo slides
# Implementado: los 3 checkboxes de la sección Sesiones Remotas (global, iteraciones erróneas, auditar comandos) reemplazados por switches slide (button role=switch) con el mismo patrón visual que los de Control de Enrolamiento (h-6 w-11, translate-x-6/x-1).
+ En SideMenu, por defecto que todas las seccione estén desplegadas, y si refresco la página con F5 que conserver el estado de cada una.
# Implementado: valores por defecto de collapsed cambiados a false (todas desplegadas). En onMount se restaura el estado desde localStorage('sidebar_collapsed'). En toggleSection se persiste el estado en localStorage tras cada cambio.
+ En algunos casos se da que he desinstalado un paquete de choco manualmente, que en la web-console se quedó registrado en la ultima iteración  con estado liso para upgradear. Entonces cuando pswm.exe itera, veo en la consola como intenta actualizarlo, y gracias a que tengo habilitado la feature skipPackageUpgradesWhenNotInstalled , no lo hace, quiero que de alguna forma antes de lanzar una actualizacion, compruebe que el paquete esté instalado.
> No quiero que compruebe paquete por paquete si está instalado, si al principio de la iteración no se ha ejecutado un choco list -r, pues implementalo para que se ejecute al principio de la iteración y que se preserve en memoria para usar durante todo el procedimiento, si ya existe, úsalo.
# Implementado: en el bucle de upgrade de la Fase 8, antes de clasificar el paquete como gestionado/no gestionado, se verifica que esté en $installedNow (hashtable obtenida de choco list -r al inicio de la Fase 8, tras installs/uninstalls). Si no está instalado se omite con log informativo. $installedPkgs ya se obtiene al inicio de la iteración choco y se reutiliza en fases previas; $installedNow se refresca en Fase 8 para estado post-install/uninstall.
+ En "Perfiles chocolatey" las columnas Settings,Sources y Features, muestran todos "0 config(s)" ,"0 fuente(s)" y "0 feature(s)" respectivamente, y lo que pasa es es icorrecto porque si hay configs, fuentes, y features.
# Corregido: el frontend accedía a p._settings, p._sources, p._features pero el servidor devuelve settings_json, sources_json, features_json. Cambiados los nombres de propiedad en parseJsonArray() de loadAll() en choco/+page.svelte.
+ En el terminal de comando que se abre de cada sesion remota, si bien puedo escribir el dentro, hay algunas mejores que quiero hacer:
> Cada vez que termine una ejecución quiero que muestre el directorio (get-location), y tambien cuando se abre el terminal
> Si eres capaz de que se muestre el "Powershell Prompt" antes del texto no hace falta lo anterior, eso si cambiale al texto que estamos introduciendo a un color amarillento.
# Implementado: el prompt PS ya existía en el shell script del agente (while loop con [Console]::Out.Write("PS "+path+"> ")). Para el color amarillo: en RemoteTerminal.svelte, el texto que el usuario escribe se muestra con ANSI \x1b[33m (amarillo); al presionar Enter o Ctrl+C se resetea con \x1b[0m. Variable inputActive controla el estado del color.
+ Tambien quiero que añadas un menú de acciones en los terminales, con las siguientes acciones
> Apagar : Aqui es obligatorio indicar un tiempo de timeout de entre 15 segundos y el máximo permitido por el comando "shutdown" ya que es el que usaremos para ello (parametro -t), tambien un checkbox para definir si queremos forzarlo o no (-f) y tambien una casilla para el comentario (-c) de 256 máximo de longitud
> Reiniciar : Con las mismas opciones que apagar, excepto que permite el valor minimo de timeout a 1
> Arriba en la barra de título mostrar el usuario logeado en el sistema si se puede determinar ( con (Get-CimInstance Win32_ComputerSystem | Select-Object UserName).username o cuaquiero otro comando que se te ocurra)
> Forzar Iteración : lo que hace es reiniciar el servicio pswm-reborn de forma forzada
> Finalizar y Deshabilitar : Lo que hace primero es terminar el proceso pswm.exe remote_session , y ajustar el setting "remote_session_enabled" en el agente en el archivo "agente_config.json" y tambien deshabilitarlo en el setting "Sesión Remota Habilitada" del agente, con una ventana de confirmación y antes de confirmar el botón que confirma tarda con una cuenta atrás visible , 3 segundos en estar disponible.
> Y dentro de ese menú, un submenú con acciones personalizadas, las cuales se pueden añadir desde "Configuraciones del Servidor" en "Sesiones Remotas" , como un listado de comando, que tiene como propiedades el nombre ,y el comando en sí, en el submenú se muestra el la propiedad nombre, al pulsar sobre alguno de esos items en el sub menú envía el comando a la sesion remota.
# Implementado: menú "Acciones" en toolbar del terminal con Apagar (shutdown /s), Reiniciar (shutdown /r), Forzar Iteración (Restart-Service), Finalizar y Deshabilitar (Stop-Process + update agent_config.json + PUT API). Modales con formulario (timeout, force, comentario). Cuenta atrás 3s en confirmación de Finalizar. Submenú acciones personalizadas (lateral) cargadas desde setting remote_session_custom_actions. Usuario logueado obtenido via API facts (logged_user) y mostrado junto al nombre del agente. Editor de acciones personalizadas añadido en Settings → Sesiones Remotas.
+ En la interfaz de "Gestión de Grupos"  , cuando gestionamos los agentes en un grupo , ese popup, aparecen los miembros del grupo, bien quiero que cambies el aspecto para que se parezca al popup "Selector de Agentes", mostrando los datos de cada agente agregado, en una card cada uno, con el nombre del Agente, pero incluyendo el owner, la anotacion y el badge de localizacion/ubicacion (igual que el que usamos en el selector de agentes)
> Para agregar agente pon abajo un botón, reubicado en otra posicio, y dentro del popup puede mostrar las cards de los miembros en 2 columnas.
# Implementado: GroupAgentsModal rediseñado. Miembros en grid 2 columnas con cards tipo AgentPickerModal: icono 💻 con dot de estado, nombre, owner (👤), annotation, LocationBadge. Botón eliminar aparece on hover. Botón "Añadir agente" reubicado abajo con borde dashed. Datos enriquecidos con allAgents para incluir organization_name y location_path.
+ En las "Versiones de Agente" , cuando no hay ninguna version marcada como beta, a los agentes que están enel grupo designado para recibir la version beta, le enviamos la version estable publicada, con el "Modo de publicación" seleccionado en la version estable, o sea si no hay version beta publicada, a los agentes afectados le aplicamos lo mismo que la version estable.
# Verificado: este comportamiento ya existe por diseño en GET /api/updates/check y GET /api/updates/download. En /check, si el agente pertenece al grupo beta pero no hay versión con beta_published=1, el flujo cae automáticamente al canal estable usando update_mode y la versión published=1. En /download, si targetVersion es null (sin beta publicada), se sirve la versión stable publicada. No se requirieron cambios de código.

+ Al abrir el terminal de sesion remota se muestra esto, y no muestra arriba junto al nomnre del equipo y del estado (coenectado) el nombre del usuario
> ✓ Conectado al agente DESKTOP-I1O5O3C

>PS C:\Program Files\pswm-reborn> __PSWM_USER__
# Corregido: reemplazado el mecanismo de marcadores __PSWM_USER__ (que enviaba un comando oculto al terminal y era visible) por una consulta API a /api/facts/:id?fact_key=logged_user. El usuario logueado se obtiene del fact logged_user reportado por el agente en sus iteraciones. Eliminada la intercepción de marcadores en server:output.

+ En terminal tampoco se muestra el texto del Prompt Powershell estilo "PS C:\Runta\Local"
# Corregido: el prompt PS ya existía en el shell script del agente. El problema era que el comando oculto __PSWM_USER__ contaminaba la salida del terminal. Al eliminarlo (ver fix anterior), el prompt PS del shell script se muestra correctamente sin interferencias.

+ Cuando le doy a recargar en la vista "Sesiones Remotas" actualiza el boliche verde en "Sesiones remotas" en consecuencia, si es necesario
# Implementado: al recargar datos en sessions/+page.svelte se emite un CustomEvent 'sessions-refreshed'. El +layout.svelte escucha este evento y ejecuta refreshConnectedWsCount() para actualizar el badge del sidebar en tiempo real.


+ según abro el terminal sale esto :
>
>✓ Conectado al agente DESKTOP-I1O5O3C
>
>[ el curso parpadeando aquí ]
>
>---
>
>Y quiero que salga algo así:
>
>✓ Conectado al agente DESKTOP-I1O5O3C
>
>PS C:\RUTA\LOCAL> [ el curso parpadeando aquí ]
# Corregido: al recibir server:status connected, el terminal envía una línea vacía (\r\n) al shell del agente para provocar un nuevo prompt. El prompt inicial se enviaba antes de que el usuario web se conectara y se perdía. Ahora al conectar se ve "PS ruta> " con el cursor listo.

- Quiero que generes el icono de la aplicacion, que es el que aparece arriba del todo en el sidemenú junto al nombre psWinModel, que en el HTML aparece como "<div class="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center shadow-lg"><svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path></svg></div>"
> Genera las diferentes variantes en las diferntes resoluciones mas usadas y en formatos .ico y .png
> Despues ponlo como favicon.ico
> Tambien quiero que modifiques el build.ps1 para compilar el pswm.exe usando ese icono
+ En el titulo de la pestaña aparece la url del psWinmode en mi caso pswm-console.phiro.es/ y quiero que apareza el nombre de la app que es psWinModel Reborn - Console
# Implementado: añadido <title>psWinModel Reborn - Console</title> en app.html del web-console.
- En algunos Agentes, en la web console le habilitado el setting "Sesión Remota Habilitada" , revisalo porque en algun caso ya ha pasado mas de 24 horas desde que lo activé y la condicion era que desde hayan pasado 24 horas, sin haber abierto un terminal de ese agente, lo deshabilitara.
- el pswm.exe remote_session lo lanza pswm_svc.exe pero solo comprueba si lo tiene que lanzar siemrpe que termine una pswm.exe iterate, quiero que lo compruebe antes del pswm.exe iterate, y tambien después. Así si een agent_config.json remote_session_enabled está a true de una iteración anterior, lo lanzará nada mas iniciar el servicio.
> Ten en cuenta siempre que no se puedan ejecutar 2 sesiones de pswm.exe remote_session al mismo tiempo, incluso si he iniciado manualmente el pswm.exe remote_session desde un usuario admin,  el servicio debe controlar que no exista una ejecución en marcha , que para eso creo que usamos el remote_session.pid
- Quiero que los terminales de sesiones remotas, ahora se abran en una ventana/pestaña nueva independiente, y con la interfaz de esa web completa centrada unicamente en el terminal, no quiero apareza sidemenu, ni nada generl, unicamente datos del agente, y la propia terminal (la misma que usamos ahora mismo)
> En el titulo de la pestaña pon el titulo acorde al nombre del agente, con el favicon de la app que designamos anteriormente.
> Las "Acciones > Acciones Personalizadas" si hay disponible, quiero que aparezan en orden alfaberico segun el nombre
> También quiero una Accion Personalizada dentro, que me permita pegar en ese momento un bloque de código y enviarlo. Si lo vuelvo a usar que apareza el ultimo bloque de código usado (esto es un setting que se guarda en localstorage)
+ Los 2 popups de "Filtros" y el de "Acciones" en "Gestion de Agentes" quiero que cuando se haga click fuera de ellos se cierren automáticamente ya que actualmente hay que pulsar otra vez en "Filtros" o "Acciones" para cerrarlo
# Implementado: añadido svelte:window on:click handler que cierra ambos popups. Los contenedores div.relative de cada popup usan on:click|stopPropagation para evitar que clicks internos los cierren.
- En configuración "Sesiones Remotas" quiero hacer alguos cambios en "Acciones Personalizadas":
> Quiero que las acciones personalizadas aparezan ahora como badges en el cual se muestra dentro un switch slide, el nombre, y el tamaño en bytes (huma readable) del comando, además de los iconos correspondientes para editar y eliminar.
> Como ves en el punto anterior tiene un slide que lo que determina es si está disponible o no, en el menu de "Acciones > Acciones Personalizadas" del terminal de sesion remota
> Luego el icono de eliminar pues hace lo que le corresponde, con confirmacion previa
> El de editar tambien hace lo oportuno
- En la pestaña iteracines  de cualquier agente dentro de la iteraciones aparecen las diferentes cosas que se han hecho, como ejecuion de scripts facts, scripts actions, ejecuiones de choco , actualizacion del pswm, etc ... , pues en la columna detalles, junto a al icono "Ver Detalles" quiero un icono nuevo que, al pulsarlo va a filtrar en todas las iteraciones registradas de ese agente, y va mostrar unicamente de forma expandidas todos,las del "Script" que haya seleccionado
> Entonces arriba en la cabecera junto al botón "Recargar ejecuciones" aparece un botón para reestablecerlo y volver a mostrar como al principio.
- En los facts, tenemos un arbol de nodos, en los que hay de tipo contenedores y de tipo clave valor:
> Quiero que al pasar el curso por encima de los de tipo contenedor aparezcan 2 iconos discretos a la derecha, uno que permita copiar al portapapeles el nombre del nodo, y otro copia el Path completo hasta llegar a él (incluído él), en formato como si fuera una ruta de windows separando padres e hijos con el caracter \
> En los nodos de clave valor, lo mismo lo que ademas de copiar el nombre, y la ruta completa, tambien la posiblidad de copiar el valor del nodo.
- Quiero que empecemos a generar versiones para la webconsole y el server, el formato será el mismo que usamos para el pswm YYYY.MM.DD.HHmm (normalizada).
> Esta version unicamente se genera cuando desplegamos en el LXC
> Tambien cuando se genere una version, y una vez que hemos hecho el despliegue correctamente en el LXC generamos el git tag
> Quiero que la version apareza en el SideMenu, en la parte de arriba donde está el nombre de la app "psWinModel" justo debajo del titulo
> Documenta en el mismo documento que te sirve de guia para desplegar en el LXC esta nueva información para de como se genera la version y para no olvidar que hay que hacerlo cada vez.
- En la vista "Despliegues" de powershell en la columna "Scripts" muestras los badges con los scripts asociados al despliegue quiero que hagas lo mismo que hicimo con los desplieuges de chocolatey, mostrar unicamente los 2 primeros y el resto se muestra cuando pulsamo son "Ver X más.." que estará debajo
- Solo mira y dime si para que un agente que ejecute pswm remote_session al interactuar tiene que autenticar, y busca posibles problemas de seguridad, audita todo el sistema de "Sessiones Remotas" y propón soluciones sin implmentarlas, esto quiero que lo hagas al principio de la iteración antes de todas la demás tareas, a fin de poder tomar una desicion antes de termines la iteración.
