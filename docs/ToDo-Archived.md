
+ Agrega al agente el comando svc, que lo que hace es llamar periodicamente al comando pswm.exe en su mismo directorio:
> Primero detecta que está ejecutando con privilegios de admin, sino sale
> Tiene que tener parametrizado cada cuanto tiempo lo va lanzar, podemos emppezar por 90 minutos.
> Pero según arranca lo lanza una vez y espera que termine, el tiempo de iteración es desde que termina.
> Tambien hay que parametrizar internamente con que parametros vamos a llamar a pswm.exe ;por ahor lo llamar con los parametros "check_status"
+ Agrega al agente un comando llamado install , que lo que hace es:
> Primero detecta si se está ejecutando como un .exe o sea está compilado, si no, solo muestra un mensaje indicando que solo está disponible para la versión compilada.
> La ruta de instalacion será "$($env:ProgramFiles)\pswm-reborn\pswm.exe" creando las carpeta si no existen.
> Copia el pswm.exe en esa ruta; este es el agente principal y es el que lleva a cabo las acciones sobre el equipo
> Crea otra copia que se llamará pswm_svc.exe ; esta será la copia que se ejecute como servicio, que luego llamará periodicamente al pswm.exe con su parametro correcto para que itere
> Y otra copia que se llamara pswm_updater.exe ; esta será la copia que se encargue de gestionar las actualizaciones del propio ejecutable, en todas sus variantes de copias.
> Luego quiero que instales como servicio el pswm_svc.exe para que se ejecute con el parametro svc, hazlo con el cmdlet new-service. Agregale todo lo necesario para que pueda soportar trabajar como un servicio de windows. De entrada el startupType que sea manual.
+ En consecuencia agrega el comando uninstall_service.


+ Agrega al agente otro comando que es dummy_iterate
> Esto crea un archivo en $env:Programdata\pswm-reborn\test.txt
> En el mismo escribe fecha y hora, parametros usados de la linea de comando, PID y usuario bajo el que se ejecuta.
+ Agrega tambien al agente otro comando que es gui
> Es una interfaz grafica, Donde tiene un botón que pone Instalar, y solicite la url del servidor y ejecute reg_init_check y tambien ejecute install , para que instale el servicio tambien.
> Que detecte si ya está instalado y registrado , y si lo esta la interfaz será otra que lo unico que permite es iniciar o parar el servicio, y ver el contenido "live mode" del fichero de log svc.log
+ Si es posible detectar que el pswm.exe se ha ejecutado con doble click o single click y sin parametros extras , desde navegadores o desde el explorer, que en lugar de mostrar la salida de help muestre la interfaz gui


+ Con lo hemos desarrollado hasa ahora y toda la documentanción que hay disponible creo que ya puedes inferir lo que pretendo y el producto que quiero tener desarrollado,y la forma en la que quiero que funcionne para todos los repos cargados en el workspace. Es por ello que quiero que documentes un guion de todo lo que hayas inferido, y que desarrolles todo lo que puedas hasta tener un MVP en todos los productos del workspace
> Creado docs/guion_producto.md con la vision completa del producto
> Implementado comando 'iterate' en pswm.ps1: recopila facts (OS, CPU, RAM, disco, red, external_facts), ejecuta scripts pendientes, ejecuta choco deployments, sincroniza inventario Chocolatey
> Helpers: Collect-Facts, Send-Facts, Get-PendingDeployments, Execute-Script, Send-ScriptRun, Get-PendingChocoDeployments, Execute-ChocoDeployment, Send-ChocoRun, Sync-ChocoInventory
> Actualizado help y dispatcher para el nuevo comando iterate

+ En los detalles del agente en la webconsole tambien quiero que aparezca la version del pswm.exe , que es básicamente el fileversion del mismo.
+ En Scripts Runs no se está registrando el Exit Code, aparecen todos con N/A
+ En la vista de Facts por ejemplo disks y network adapters, aparecen codigo JSON, muestralo formateado de una forma agradabe al usuaio y buena experiencia de usuario, quizas puedes poner una tree view simulando al explorador de windows, cualquier otra que creas mas oportuna
+ Para los scripts de powershell estaría bien implementar  un botón que compruebe que la sintaxis está bien tal como lo sueles hacer a veces tu mismo
> En esto tendrás que comprobar si se puede ejectuar powershell po pwsh en la máquina donde se está ejecutando el servidor ya que mientras lo desarrollo estoy en windows pero cuando termine y lo publique el servidor será un linux. Si no tiene powershell que el botón esté presente pero deshabilitado y con un tooltiptext que indique que es necesario instalar powershell en el servidor.
+ En los despliegues:
> Tiene un ID pero quiero que tambien tengan un nombre ya que identificarlos por el Id de un vistazo no es comodo
> Los de tipo location cuando los estamos editando y queremo agregar localización el popup modal que aparece (Agregar location) no es nada intuitivo, quiero que uses el mismo que usamos al crear un despliegue (Seleccionar Organización y Ubicación)
> Tambien los en este mismo tipo de deslpiegues (location) solo muestras el badge final de la location asignada, y quier que muestre igual que muestras la ubicacion de los agentes "🏢 ORGANIZACION" > locationLevel1 > locationlevel2 ...
+ En la vista "Todo los Agentes" En la columna ubicacion quiero que muestres la ubicacion Quiero que muestres todo el path de la ubicacion sin mostrar la ORGANIZACIón ya que quiero que añadas la columna ORGANIZACIÓN
+ El estado aparece siempre pending podriamos darle una vuelta y mejorarlo a tu criterio.
+ El ultimo contacto, quiero que tooltip texto nos diga cuanto tiempo hace del ultimo contacto, ajustandose a los rangos , ejemplos:
> Hace X minutos
> Hace X horas
> Hace X dias
> Hace X semanas
> Hace X meses
> Hace X años

+ En la version del Agente quiero que muestre el FileVersion del pswm.exe
+ He visto un script que tiene salida por stderr, y el exit code es 0, como minimo el exit code debería ser 1 , revisa esto
+ Cuando le doy a Verificar sintaxis me sale algo como lo siguiente en rojo , y eso no me hace inferir nada no lo entiendo:
❌ Errores de sintaxis:

    Attributes : {}
    UsingStatements : {}
    ParamBlock :
    BeginBlock :
    ProcessBlock :
    EndBlock : (get-date).ToString() | out c:\testDate.txt
    DynamicParamBlock :
    ScriptRequirements :
    Extent : (get-date).ToString() | out c:\testDate.txt
    Parent :
    OK
+ Además cuando  salgo de la edición del script powershell y vuelvo a entrar sigue estando el texto
+ En los despliegues de tipo location cuando los editamos, quiero que muestres las localizaciones y ubicaciones asignada complemtas igual que la muestras la ubicacion cuando editas un agente ejemplo -> "🏢 pHiSoft  >  Casa"

+ En la webconsole estas mostrando como "Version Agente" = 0.1.0-mvp y fijate que cuando compilamos usamos esto para asignar la version al ejectutable --> "version = (Get-Date -Format 'yyyy.MM.dd.HHmmss')" esta es la version real del agente, la 0.1.0-mvp es unicamente si pswm se ejecuta como script pswm.ps1, repito si es como ejecutable , la version del fileinfo del pswm.exe.
+ Sigues mostrando Exit Code 0 en la ejecuciones de escript cuando es una ejecución que ha fallado y tiene stderr
+ Luego he verificado la sintaxis de este script "(get-date).ToString() | c:\testDate.txt" y me sale Sintaxis válida , lo he puesto mal a proposito
> NOTA: Este comportamiento es CORRECTO. El analizador de PowerShell considera válida esa sintaxis porque piping a una ruta (c:\testDate.txt como comando) es sintácticamente legal en PS. El error ocurre en tiempo de ejecución, no de compilación. Se ha mejorado el mensaje en la UI para aclarar que "Sintáxis válida" no implica que no haya errores de ejecución.

+ Cada vez que se lance una iteracion de pswm.exe debe generarse un uuid unico pero lo generamos en base a los ticks de la fecha y hora actual. Este tiene que ser reportado en cada vesz quese reporta la ejecución de un script powershell para agruparlos por ese uuid en la web console dentro de "Ejecuciones de Scripts"
> Implementado: $script:IterationId = [string](Get-Date).Ticks generado al inicio de Invoke-Iterate. Se pasa a Execute-Script → Send-ScriptRun → campo iteration_id en script_runs. En la webconsole los runs se agrupan por iteration_id con cabecera colapsable.
+ Implementa tambien la configuración del server /settings:
> La primera opcion es el tiempo de retención de las ejecuciones de scripts en días, en un rango entre 1 y 30 dias.
> Pero no quiere decir los ultimos X dias, sino datos esas cantidad de días, por ejemplo si ponemos 3 dias de retencion, y el equipo se enciende nada mas que los lunes, pues retendrá datos por cantidad de 3 dias, es decir de cada uno de los , es decir de los 3 ultimos lunes. Si por medio ubiera alguna otra iteración ya se eliminarian otro lunes y solo sería el lunes mas reciente ese otro día en medio y el siguiente lunes, evidentemente si el equipo itera todos los días pues coincidirá con los ultimos 3 dias. 
> Otro ejemplo si un equipo hace 1 año que no itera, y vuelve a iterar justo despues de un año, mantendrá la del dia mas reciente, de las antiguas iteraciones hasta contabilizar 3 dias, pero ten en cuenta no son 3 dias de tiempo, sino iteraciones de 3 dias , evidentemente todas y cada una de las iteraciones que hayan sucedido en cad uno de esos dias.
> Implementado: GET/PUT /api/settings con clave retention_days (1-30, default 7). Algoritmo applyRetention por agente: obtiene fechas únicas de started_at (desc), conserva las N primeras, elimina el resto. Se ejecuta automáticamente tras cada script run y manualmente desde POST /api/settings/retention/apply. Página /settings en webconsole con slider y botón "Aplicar Retención Ahora".

+ Cuando subo un pswm.exe al servidor quiero que sea el propio servidor quien determine la version a partir del fileinfo del archivo. No se si está implementado pero quiero que el servidor pueda alojar varias versiones del archivo, y la publico en 2 modos, mandatory, eso quiere decir que aunque el agente tenga una version superior a la publicada en el servidor, el agente debe "downgradear" a la version del server, y lueo en modo upgrade que quiere decir que el agente actualiza la version solo si la del servidor es mayo a la que el tiene, si son iguales o la del servidor es inferior entonces se queda con la que tiene.
> Tener varias versiones del pswm.exe en el servidor hace que sea necesario seleccionar cual es la que queremos publicar.
> Tambien se me ocurre el modo desactivado, para que el servidor no proporcione actualizaciones mientras este modo esté activo.
> Genera tambien los md5 o sha al subirlo
> Implementado: Sistema multi-versión completo en el servidor (tabla agent_updates). Auto-detección de FileVersion vía PowerShell al subir .exe. Hashes SHA256+MD5 generados al subir. 3 modos de publicación: mandatory (fuerza downgrade), upgrade (solo mayor), disabled (sin actualizaciones). UI en /settings con tabla de versiones, botones publicar/despublicar/eliminar, selector de modo. Agente actualizado para respetar los modos del servidor.

+ En "Script Runs" no estoy viendo agrupadas las ejecuciones por el IterationID que implementamos antes. Corrigelo.
> Implementado: reescrita la lógica de agrupación en agents/[id]/+page.svelte. Se eliminó el @const inline (se recalculaba en cada render reseteando el estado de expansión). Ahora usa reactive block $: groupedRuns con mapas expandedIterations y expandedRuns independientes.
+ Si le doy a editar a una Organizacion no pasa nada
> Implementado: la variable `editing` no estaba declarada con `let` en organizations/+page.svelte. Añadido `let editing: any = null;` que hacía que la función handleEdit no pudiese asignar el objeto y el formulario de edición nunca se mostraba.
+ A los script  quiero que se les pueda asignar un orderID, a fin de cuando se sirvan todos los script se ejecuten en ese orden, si dos scripts tienen el mismo orderID, se determinan por otro parametro , que puede ser el nombre o el id, lo dejo a tu eleccion. Al final de todo se ejecutan los que no tengan asignado order id. Los primero que se ejecutan son los que tengan el order numérico mas bajo, valores de 0 en adelante.
> Implementado: columna order_id INTEGER en tabla scripts (db.js + migración automática). API scripts.js: GET ordena por (nulls al final, order_id ASC, name ASC); POST/PUT aceptan order_id. API deployments.js: endpoint del agente incluye script_order_id y ordena igual. Web console scripts/+page.svelte: campo "Orden de ejecución" en crear/editar, columna Orden en tabla. Desempate: name ASC, luego id ASC.
+ Cuando ejecutamos el gui , si no es con permisos de administrador redirigir a ejecutarlo con privilegios elevados.
> Implementado: al inicio de Invoke-Gui se verifica IsInRole(Administrator). Si no se es admin se detecta si corre como .exe compilado o como script .ps1 y se relanza con Start-Process -Verb RunAs con los mismos argumentos (incluyendo -ServerUrl si aplica), luego hace return.

+ He ejecutado el gui por el metodo de doble click desde el explorador de windows y no ha solicitado la elevación de permisos.
> Corregido: Se mueve Add-Type WinForms ANTES de la comprobación de admin para poder mostrar MessageBox en caso de error. Se envuelve Start-Process -Verb RunAs en try-catch con MessageBox para capturar errores de elevación (UAC denegado, etc.).
+ En "Scripts Runs" siguen sin estar agrupadas las ejecuciones, centrate en esto que ya es la tercera vez que te lo comento, todas la ejecuciones de una misma iteracion deben estar agrupadas dentro del mismo Comprimible.
> Corregido (3ª vez): eliminado el bloque reactivo $: que no se disparaba correctamente. Ahora computeGroups() se llama directamente dentro de loadScriptRuns() tras asignar los datos, garantizando que los grupos se calculan siempre.
+ Quiero tambien que los Agentes tengan 2 campos editables, uno es el Owner y otro anotación.
> El Owner es el dueño o persona asignada al equipo
> Anotación es un pequeño texto libre.
> Ambos quiero que aparezan en el listado de Agentes, pero bajo el nombre del Agente.
> Implementado: columnas owner y annotation añadidas a tabla agents (con migración automática). PUT /api/agents/:id actualiza ambos campos. Listado de agentes muestra owner (👤) y annotation (📝) bajo el nombre. Detalles del agente muestra ambos. Página de edición incluye inputs para ambos.
+ Quiero que en los detalles del agente se muestre la IP del angente, no me refiero a la que recopile el propio agente sino a la IP desde donde hace la conexion contra el servidor.
> Implementado: en facts.js se captura req.headers['x-forwarded-for'] || req.ip y se guarda en agents.last_ip. En detalles del agente se muestra como "IP remota".
+ Para unir agentes ahora mismo tenemos implementado el sistema de cola de aprobación de agentes, ahora quiero implementar un método por token.
> Se genera un token, el token tendrá fecha de caducidad
> Tambien puede tener opcionalmente numero de usos
> El token hay que vincularlo a una organización y ubicación que es donde se vincularán los agentes que lo usen.
> Implementa tanto las opciones en el server, la web console, y en el agente.
> En el agente hay que tener en cuenta que se puede hacer mediante linea de comandos desatendido, y mediante gui, en el cual ya tenemos 2 metodos, por lo que hay que añadir algo para que el usuario seleccione el método.
> Implementado: tabla enrollment_tokens en db.js (token, org, location, max_uses, expires_at, revoked). 4 endpoints en agents.js (GET/POST tokens, DELETE revoke, POST register/token). Web console: sección "Tokens de Registro" en página de cola con crear/revocar/copiar y tabla completa. Agente: comando reg_token (CLI con -Token param), función Invoke-RegToken, GUI con selector RadioButton Cola/Token y campo token.

+ En la webconsole , en la "Cola de Aprobación de Agentes" quiero que cambies la estructura, "Cola de Aprobación de Agentes" y "Tokens" , separados en Tabs.
> Para ambos añade paginación de 20 items, pero que permita seleccionar en un desplegable otras paginaciones de 50,100, y 200
> Implementado: queue/+page.svelte reescrito con activeTab ('queue'|'tokens'), paginación independiente para cada tab con selector de 20/50/100/200 items y botones Anterior/Siguiente.
+ Tambien quiero que se puedan editar los Tokens, para:
> Aumentar los usos
> Cambiar la caducidad
> Cambiar la ubicacion
> Cambiar la descripcion
> El resto igual
> Implementado: PUT /api/agents/tokens/:id en agents.js (actualiza description, max_uses, expires_at, location_id, organization_id con COALESCE). api.ts: tokens.update(). Modal de edición en la tab Tokens de queue/+page.svelte con selector org/ubicación.
+ En Configuración tambien quiero que lo reordenes usando tabs.
> Implementado: settings/+page.svelte con tabs 'Retención' y 'Actualizaciones', variable activeSettingsTab.
+ En la ficha de los agentes:
> no se refleja el Hostname ni la fecha de creacion "Creado"
> La organización y ubicacion quiero que se muestre igual que las estas mostrando en los despliegues con un buget tipo pildora con todo el path y incluyendo los emojis 🏢  y 📍 segun corresponda
> Implementado: agents/[id]/+page.svelte — Hostname usa agent.name (columna real), Creado usa agent.registered_at (columna real). Org/ubicación reemplazadas por badge píldora con 🏢+📍.
+ Como por ahora no están desarrollandos puedes dejarlos presente pero con estido deshabilitado la seccion chocolatey /choco y depliegues choco /choco/deployments , tambien sesiones remotas /sessions
> Implementado: +layout.svelte — items /choco, /choco/deployments y /sessions tienen disabled:true. Se renderizan como <span> con opacity-40, cursor-not-allowed y badge 'pronto' en ambos bloques de nav.
+ Deberiamos usar un icono, no tiene porque ser emoji sino de algun esquema de iconos famosos, para identificar los scripts powersherll, usarlo en su seccion y tambien dentro de los depoyments y los "Scripts Runs"
> Implementado: SVG Heroicons v1 terminal/command-line (path: M8 9l3 3-3 3m5 0h3M5 20...) en color text-blue-600. Añadido en: heading 'Scripts PowerShell' en scripts/+page.svelte, heading 'Ejecuciones de Scripts' en agents/[id]/+page.svelte, tab 'Script Runs' con icon prop en tabs array, label 'Scripts PowerShell' en deployments/+page.svelte.

+ En la ficha de agente, si "Ultimo contacto" y "Ultima vez visto" son iguales mostrar solo el primero.
> Ya implementado: agents/[id]/+page.svelte usa `{#if agent.last_seen && agent.last_seen !== agent.last_contact}` para mostrar solo el primer campo cuando son iguales.
+ En la vista "Todos los Agentes" quiero poder filtrar por :
> Organización
> Ubicación
> Tambien un campo para buscar texto entre nombre del agente, owner y anotación
> Implementado: agents/+page.svelte — filtros de org/ubicación con popup grid 3 col (mismo que despliegues), buscador por nombre/owner/anotación, switch Mostrar Inactivos, paginado con selector de 20/50/100/200.
+ En la cola de aprobación:
> Es necesario distinguir el metodo de aprobación por ahora aprobacion manual en cola, y automatica por token, a parte de indicarlo como texto, tambien un icono para cada tipo de aprobación lo haría mas agradable a la hora de localizarlo.
> Si fue manual, hay que registrar el usuario que lo aprobó
> Si fue por token, hay que indicar el token y la IP que tenía el agente en ese momento al registrarse, no hace falta mostrar el token solo algo como que diga "mostrar token" y entonce si lo despliegue
> Implementado: tabla unificada en queue/+page.svelte muestra columna Método con icono 🔑=Token (azul) y 📋=Cola manual (pizarra). Columna "Aprobado por" muestra usuario admin o botón "Token" clicable que abre popup con el valor del token. IP visible en columna dedicada.
+ En los "Tokens de registro"
> Cada token debe tener registrado quien lo creó, y la fecha y hora, podríamos ponerle un discreto icono de info para que muestre esa informacion al pulsarlo.
> Implementado: campos created_by_name y created_at en tabla enrollment_tokens. Botón icono ℹ️ junto al icono 📋 en la tabla de tokens muestra popup posicionado bajo el icono con usuario creador y fecha.
+ Los Scripts Powershell a primera vista, quiero que estén ordenados por OrderID, tambien quiero que estén paginados a 20 por defecto y :
> Tener un buscardor para buscar por nombre , o descripcion
> Implementado: scripts/+page.svelte con búsqueda por nombre/descripción, paginado 20 con selector 20/50/100, ordenación por order_id.
+ en la vista Despliegues:
> Ver el ID no me aporta nada podemos ocultarlo, podemos poner un dicreto icono de info con un tooltip con el ID
> Tammbien quiero un buscador de texto apra buscar por nombre scripts, o location
> Y tambien un filtro por seleccion de Ubicacion.
> También quiego paginado aquí de 20 por defecto.
> Implementado: deployments/+page.svelte — ID oculto con icono 🛈 tooltip, buscador texto deplSearch, filtro por location (select de locationList), paginado 20 con selector 20/50/100.
+ Tal como hemos estado haciendo en las vistas "Todos los agentes","Grupos","Etiquetas","Organizaciones" y "Usuarios", tambien quiero opciones de paginado a 20 por defecto y buscador dentro de la vista/seccion
> Implementado en todas: groups, tags, organizations, users tienen búsqueda por nombre/descripción y paginado 20/50/100.
+ Añade tambien la página del perfil del usuario, donde podrá cambiar por ahora su contraseña:
> Minimo 8 caracteres.
> Implementado: web-console/src/routes/(app)/profile/+page.svelte con cambio de contraseña (validación mínimo 8 caracteres).
+ Al hacer click sobre el nombre del Agente quiero que entre a los detalles del agente lo mismo que el icono del ojo
> Implementado: el nombre del agente en agents/+page.svelte es un `<a href="/agents/{agent.id}">` que lleva a los detalles.
+ En la configuración quiero tener la opcion de descargar alguans de las versiones del pswm.exe que están subidas.
> Implementado: settings/+page.svelte — tabla de versiones con botón "Descargar" en cada fila que llama a GET /api/updates/:id/download-file y descarga el .exe.

+ En la Gestion de agentes, en el buscador el selector de Organizacion y ubicacion, quiero que sea el mismo selector con un popup que usamos para seleccionar una ubicacion. Con este metodo podemos prescindir del dropdown Organizacion y Ubicacion.
+ En seccion "Cola de aprobación" la seccion "Registros por Token" y "Cola de aprobación" pueden estar mezclados en una misma tabla con los siguiente datos:
> ID, Hostname, IP, Método, Fecha Solicitud,Estado,Aprobado por
> En la columna "Aprobado por" , aparecerá el nombre de usuario que lo aprobó, o si es un token pon el texto <token> (o algo similar mas agradablea la experiencia de usuario) y si hacemos click sobre él despliega el codigo del token
+ Mejoras sobre el icono de info de cada uno de los tokens en "Tokens de registro"
> Pon el  icono justo a la derecha del icono para copiar el token, con esto puedes eliminar la columna creado.
> Cuando hago click sobre el icono no se ve el popup completo queda atrapado dentro de la tabla de los Tokens y tengo que hacer scroll con la rueda del mouse
+ En la configuración quiero una opcion que indicando una cantidad de días en las que un agente no contacte se considera inactivo, y en ese caso no se muestra en la vistas Todos los agentes.
> Añadiremos un switch en la barra de búsqueda y filstrado que diga "Mostrar Inactivos"

+ Los cambios hechos en "Todos los agente" la lista de "Gestion de agentes" se ha estropeado:
+ Ahora aparece "No hay agentes registrados" y si hay al menos uno
> Implementado: La causa era que fetch('/api/settings') usaba URL relativa (puerto 5173 en lugar de 3000) y el Promise.all completo fallaba. Solucionado: (1) agents+orgs se cargan en un Promise.all separado, (2) settings se carga después en su propio try/catch sin bloquear, (3) inactiveThresholdDays default cambiado a 0 para no filtrar hasta que se cargue el valor real.
+ En el nuevo selector de "Org/Ubicacion" no está bien implementado, sale un popup, dejando el fondo negro y el popup dice "Filtrar por Org / Ubicacion" y debajo "Sin Organizaciones" y esto es falso, quiero que el popup que se muestre sea el mismo que usamos, dentro de los despliegues, cuando editamos uno de tipo location, el popup que se despliega para "Seleccionar Organización y Ubicacion"
> Implementado: modal reemplazado por layout grid 3 columnas (igual que despliegues): columna izquierda = lista de organizaciones con botón "Sólo" en hover; columna derecha = TreeNode lazy de ubicaciones de la org activa.

+ Quiero que a los despliegues se les añada un icono para diferenciarlos segun el Objetivo que son "Todos", "Grupos","Organizaciones","Localizaciones","Agentes"
+ Tambien en los despliegues la columna "Objetivos", no me aporta nada la ocultamos.
> Implementado: eliminada columna "Objetivos" del thead y tbody. Añadido icono de color por tipo de objetivo en la columna Nombre: 🌐 verde=Todos, 👥 morado=Grupos, 🏢 azul=Orgs, 📍 amarillo=Localizaciones, 🖥 pizarra=Agentes. El texto del tipo también lleva el color correspondiente.
+ Quiero que los facts de los agentes sean mostrados como uan treeview en formato Windows Classic Tree View
> Implementado: reescrita la tab Facts en agents/[id]/+page.svelte con arbol agrupado por categoría (prefix del fact_key). Nodos carpeta expandibles con ▶/▼ e icono de folder amarillo. Facts simples como hojas con líneas conectoras estilo Windows. Facts JSON expandibles con sub-árbol recursivo mostrando claves/valores indentados.
+ También me gustaría tener disponible junto al botón  "Recargar" uno que permita bajar un JSON con todos los facts del agente. Quiero que ambos botones tengan iconos representativos en lugar del texto.
> Implementado: botón Recargar convertido a icono SVG (flecha circular). Añadido botón Descargar JSON con icono de descarga (flecha hacia abajo). La descarga genera agent-{id}-facts.json parseando JSON facts a objetos nativos.
+ El popup que se muestra al pulsar sobre el icono de info,en los "Tokens de registros", que muestra el usuario que lo ha creado y la fecha que se creó el token, aparece arriba del todo a la derecha del cuerpo de la webapp, lo suyo es que aparezca bajo el icono info, como si surgiera una viñeta del mismo.
> Implementado: añadido estado tokenInfoPopupPos con coordenadas calculadas del getBoundingClientRect() del botón. El popup usa fixed con top/left dinámicos en lugar de top-4 right-4. Incluye flecha indicadora (triangulito) en la parte superior. Overlay transparente para cerrar al hacer clic fuera.

+ En los facts de agentes:
> Por defecto quiero que aparezcan todos colapsed, y haya por algun lado de la interfaz botones para expadir todo y/o colapsar todo.
> Además quier que los valores que sean tipo JSON los conviertas en objetos y los integres en el treeview
+ En los Scripts powershell, vamos a hacer un cambio importante.
> Vamos a añadir facts personalizados.
> Para ello los scripts de powershell tienen que tener una propiedad que puede ser action o fact. El tipo action es tal cual está ahora se ejecuta y se registra la salida en "Scripts Runs" del agente. El tipo fact, tambien se ejecuta, pero la salida debe ser puramente y en su totalidad un json.
> Para los tipo fact, si la salida es correcta y es un JSON, en el "Sripts Runs" no mostramos stdout, solo mostramos Fact Generado el nombre del objeto y objetos del primer nivel del json. En caso de que no se haya ejecutado bien mostradmos el stdout, y el stderr si lo tiene, igual que cualquier otro script.
> Los de tipo fact que se hayan ejecutado correctamente, deben icorporarse a la seccion de Facts del agente, añadirse a los que se generan de forma interna (built-in)
> En la vista ejecuciones de scripts debemos diferenciar correctametne los de tipo action a los de tipo fact, usa un icono distintivo para cada uno, y lo pones en la columna "Script" de cada uno a la izquierda del nombre.
> La forma en la que se van a ejecutar en el agente es como hasta ahora, respetando el  OrderId, pero además ahora haremos 2 agrupaciones, por un lado los facts script y por otro los actions scripts y en el agente primero ejecutamos todos los facts scripts y luego los actions scripts.
> En la vista de "Facts" en los agente, los nodos generados por facts BuiltIn los dejamos con el color folder amarillo al estilo Windows Explorer como está actualmente, pero los generados por facts personalizados le pondremos un color azul o azulado, el resto de objeto bajo el nodo se quedan igual.
> En caso de que en el nivel uno del arbo haya 2 nodos o mas con el mismo nombre (colisiones) me gustaría que aparecieran todos pero con un simbolo (‼️) , si no puede ser añadeles al nombre algo para diferenciarlos, se me ocurre poner ocmo sufijo entre [] , el id del script que lo genera.
+ Toda la interfaz que tenemos de "Actualización del Agente" dentro de "Configuración" me gustaría sacarla al Side Menú, pero no se en que seccion colocarlo, así que sácalo y colocalo en la seccion que creas que tiene mas encaje
+ A los script como vamos a asignarle un tipo (fact, action) y ya hemos indicado que vamos a usar un icono identificativo para cada tipo, quiero qu uses ese icono en la vista "Scripts PowerShell" junto al nombre y tambien en los "Despliegues" en la columna "Scripts" junto al nombre de cada uno ( a la derecha)
+ En todas partes de la web console, quiero que unifiques los botones de acciones y uses los iconos representativos para cada uno de ellos y el tooltip para el texto, revisa en todos sitios de la webconsole:
> "Versiones de agentes" , "Despliegues" , "Scripts de Powershell", "Organizaciones", "Gestion de Etiquetas", "Grupos", "Tokens de registro", "Todos los agente"
> Si hay alguna accion que no se puede reprentar con icono pones el texto
> Usa para todo el mismo esquema de iconos y colores.

+ Los facts personalizados los estás mezclando usando como raiz el nombre del script, luego en segundo level el nombre del script normalizado (minusculas , sustituyendo espacios por guines bajos , etc) y a partir de entonces pone todo el objeto generado a partir del json, los 2 primero niveles esos no son necesarios, ya el json viene formateado e ideado para poner su primer nivel de objeto en el primer nivel de los facts.
+ Tambien veo que los facts OS y Cpu aparecen con el simbolo ‼️ y ell sufijo [Built-In] no se porqué pero bajo las directrices anteriores no deberían.
+ Los Facts, al menos el primer nivel quiero que esté ordenado alfabeticamente, y los de tipo "container" primeros y despues los de tipo valor , vamos el mismo orden que pone el explorador de windows.
+ Si es posible a la izquierde de los botones de acciones de los facts poner un sencillo buscador para buscar valores o container que coincidan: Si es uno o varios container, se muestra el container con todos sus padres, y tambien todos sus hijos, si es un valor se muestra el valor con todos sus padres.

+ En los facts built-in :
> Del Agente , incluye el tamaño del archivo pswm.exe y el hash
> Hay uno que se llama Total y veo que dentro indica la ram total, lo suyo seria llamarlo memory o ram al primer nivel del objeto
> Agrega un fact con el System Uptime, que muestre la hora/fecha de inicio, y el tiempo que lleva ecendido en dias, horas, minutos y segundos
+ Me gustaría , para los facts personalizados, ponerles al nodo del primer nivel, un tooltip o equivalente, que indique el Nombre del Script que lo generó, y la fecha de ultima ejecución.
+ En los "Scripts Runs" me gustaría saber el tamaño de la salida de cada uno, de ambos tipos, en unidad Bytes (human readable) y luego en el colapsabe de IterationID tambien mostrar el total.
+ Tambien en los "Scripts Runs" para el enlace de "Recargar" , "Ver"/"Ocultar" usa los iconos reprenstativos de cada accion.
+ Aquellos facts que lleven mas de X días sin actualizar/reportarse, quiero que el color del nodo primer nivel cambie a color gris oscuro
> Para determinar la cantidad de dias, quiero que añadas una configuración que determine esos días en la configuracion en sistema
+ En todos los sitios donde se esté representando una ubicacion/localizacion hazlo usando mismo formato con badge que usamos en la ficha de edicion en los Despliegues de tipo location, revisa todo , pero entre otro te puedo decir estos:
> En la ficha de información del agente, es muy similar pero la chincheta está mal ubicada
> En la Vista Generl de gestion de Todos los agentes en la columna "Ubicacion" , en este caso deja tambien la de Organización a parte
> En Tokens de Registro en la columan "Org / Ubicación" y tambien en el popup de "Edicion de Token"
+ En el formulario de edicion de un Despliegue muestras los badges con los scripts del mismo, recuerda pornerle a esos badges el icono del tipo de script (fact o action)

+ En el formulario de Edicion de Token la organización y ubicacion no se está representando bien, el caso existente tiene asignado la organizacion ubicacion "🏢 pHiSoft > SJplace > 📍 Casa" y lo que se muestra es "🏢 pHiSoft > 📍 📍 Casa"
+ En el popup de selecion de script en Despliegues llamado "Agregar Script" , quiero que los Scripts que aparecen ahí vayan acompañado de su icono segun el tipo de script (action o fact)
+ En "Script Runs" en los tamaños de de la salida de los script, en aquellos que son de tipo facts, es cierto que en esta seccion se muestra el texto al estilo siguiente :
Fact Generado: Obtener Servicios
Claves: services
> Esto está bien, pero el tamaño que hay que registrar es el tamaño real de la salida del script.


----


- Estoy viendo la forma en la que funciona en background el fujo de chocolatey implementado y vamos a hacer algunos cambios.
> Veo que siempre que se aplique un despliegue en una máquina ejecuta los choco install, choco upgrade y choco uninstall independientemente si el paquete existe o no. Vamos por partes.
> Lo primero de todo es que el servidor le entregue al agente una version saneada de las acciones que debe hacer en chocolatey, esto implica primero las opciones del perfil. Si a un agente le afectan 2 o mas perfiles, pues hay que mezclar las opciones de ambos, es decir lo que no tena uno y si el otro, en el caso de opciones que si tengan definidas mas de 1 perfil, se seleccionará por precedencia del tipo del despliegue asociado, teniendo prioridad en este orden por el tipo de despliegue, de mayor a menor
- Agentes
- Localizaciones
- Organizaciones
- Todos
Fíjate que no he puesto grupos, ya que quiero añadir una restriccion los despliegues de tipo grupos no podrábn llevar asociado un Perfil de Chocolatey, los unicos que pueden asociar un perfil son los indicados.
Solo podrá exisitir un Despliegue de Chocolatey de Tipo TODOS
Solo podrá Exisitir un Despliegue por cada Organización, y cada Localización , o sea una organización no puede estar en mas de 2 despliegues, y una localizacion tampoco
Y en los tipo Agentes, un agente seleccionado en un despliegue no podrá asociarse a otro a menos que se quite uno.
Los Despliegues de chocolatey de tipo grupos pueden gestionar paquetes y y sus opciones/parametros
Cuando un paquete de choco entra en conflicto se seleccionará por precedencia del tipo del despliegue, teniendo prioridad por este ordenm, de mayor a menor
- Agentes
- Grupos
- Localizaciones
- Organizaciones
- Todos

Con todo esto ya podemos dar un catalogo de las opciones de perfil de chocolatey y los paquetes que vamos a gestionar.

Antes de nada en las opciones de paquetes ademas de las que tenemos quiero que añadas una casilla checkbox para determinar si el paquete debe estar o no pineado.

Primero recopilas la informacion actual de todo:
- Paquetes instalados y la version instalada (choco list -r)
- Paquetes pineados y la version pineada (choco pin -r)
- Sources del chocolatey (choco sources -r)
- Opciones de configuracion del chocolatey (choco config -r)
- Features de chocolatey (choco features -r) -> hay que agregar a la interfaz de Perfiles de chocolatey para agergar features
Y todo esto lo preservas para usarlo en adelante.

Primero ajustas los sources, pero comparando los que tiene el perfil, si es que tiene, con los actuales, y si diferen, pues los ponemos tal cual indica el perfil.

Luego procederemos con los features solo comparando y aplicando solo los cambios, y lo mismo con los config

Aún así no quiero que siempre ejecutes cada comando relativo a cada paquete

Ahora procedes con el proceso de desinstalación, mirando los que tienes instalados y sabiendo los que debes desintalar, procedes a desintalar unicamente los que coincidan o sea aquellos que están instalados, no quiero que ejecutes el comando de desinstalación para un paquete que no está instalado, debes tener en cuenta que si el paquete está pineado debes despinearlo primero.

Ahora procedes con los install, que básicamente es todos aquellos que no están instalados los instalas, no es necesario volver a lanzar el comando de instalacion. Fijate aquí que puedes pinearlo si tiene el check directamente en la instalación.

Ahora la fase de pineado, siguiedo la misma estrategia solo sobre los paquetes gestionados, pinea o despinea los que proceda segun cada paquete

Ahora viene la fase de Updates que dependerá de varios casos.
Primero vamos a definir los mosos de actualización:
Deshabilitado: no hacemos updates de nada.
Solo paquetes gestionados: Esto solo actualiza los paquetes gestionados y que no estén pineados
Actualizar Todos los paquetes: Esto actualiza todos los paquetes instaladados y que no estén pineados.

El proceso es el siguiente hay que revisar cuando fue la ultima vez que se hizo el proceso de actualización y si han pasado la cantida de días indicada en la frecuencia procedemos al flujo de actualización, sino no lo hacemos.

El flujo de actualización no se basará nunca en ejecutar un choco upgrade all, lo haremos paquete por paquete. 
Primero determinamos que paquetes son actualizables con choco outdated -r y lo preservas en memoria.
Luego dependiedo del modo de Actualización ("Solo paquetes gestionados" o "Actualizar todos los paquetes") descartamos o no los paquetes que NO son gestionados, luego descartamos los que están pineados.

Y luego eso si uno a uno ejecutamo un choco upgrade del paquete.


----


Para todo esto en los despliegues , en los paquetes la accion "upgrade" no es necesaria ya que viene determinada si el paquete está pineado o no y de la politica de Actualización del perfil.

Para los despliegues de chocolatey no quiero la posibilidad de "Ejecutar una sola vez"

Quiero tambien que en los "Scripts Runs" dentro dela iteración añadamos un evento en lugar de ser un script sea "Paquetede de choco" y que muestre las acciones llevadas a cabo y el resultado de las mismas.

En los facts de cad agenntees importante tener un Fact con Chocolatey que es built inque tenga los siguientes hijos:
installed=[true|false] ; Indica si choco está insatlado
exe=<indica la ruta absoluta del choco.exe>
version=<indica la version del choco.exe a partir del fileversion>
sources= aqui un objeto por cada uno de los sources y cada uno con sus propiedades clave valor
features= bajo este todos los features tipo clave valor
lastUpdate=<aqui la fecha de la ultima vez que se lanzo un proceso de update>
profile=
    name=<nombre del perfil que estamos aplicando>
    description=<descripcion del perfil que está aplicando>
    UpdateMode=<El modo de actualización elegido en el perfil>
    UpdateFrecuencyDays=<la frecuencia en días de actualizaciones>
    Chocolatey_Policy=<la política de chocolatey elegida>


Luego en la pestaña se mostrarán todos paquetes de Chocoaltey instalados, gestionados o no, Para ellos los agruparemos mediante comprimibles los que son gestionado y los que no.
Debemos tener el nombre del paquete la version instalada y si está pineado o no, para ambos
Luego para los no gestionados añadir la columna "Version disponible"
Y para los gestionados ademas debemos añadir una columna que sea info, y si hacemos click sobre la misma podemos ver en un popup tipo viñeta los parámetros designados para ese paquete

Actualmente no se permite editar los "Despliegue de choco" y quiero que sea editable, a excepcion del tipo


---

Sigue igual , no se instaló el paquete, ni se aplica las features

FYI:
- Existe un Perfil de chocolatey llamado "General" , entre otras cosa indico  que usePackageRepositoryOptimizations no esté habilitado
- Luego existe un desoligue de Choclatey llamado "Básicos" de tipo location, tiene el perfil asignado "General" y tiene que se instale 2 paquetes el rufus y el tcping

Bien pues no se ha aplicado la feture ni se ha instalado el tcping; el rufus ya estaba instalado


----

Ok, bien funciona.

Ahora vamos a corregir el fact de chocolate que está built-in ya que lo que estas mostrando no es nada de lo que te pedí, lo que te pedí para el fact chocolatey es estos datos

installed=[true|false] ; Indica si choco.exe está instalado
exe=<indica la ruta absoluta del choco.exe>
version=<indica la version del choco.exe a partir del fileversion>
sources= aqui un objeto por cada uno de los sources y cada uno con sus propiedades clave valor
features= bajo este todos los features tipo clave valor
lastUpdate=<aqui la fecha de la ultima vez que se lanzo un proceso de update>
profile=
    name=<nombre del perfil que estamos aplicando>
    description=<descripcion del perfil que está aplicando>
    UpdateMode=<El modo de actualización elegido en el perfil>
    UpdateFrecuencyDays=<la frecuencia en días de actualizaciones>
    Chocolatey_Policy=<la política de chocolatey elegida>

    


+ Por defecto cuando instalamos para que sea desatendido usamos el parametro -y , quiero que tambien usemos el --no-progress a fin de reducir ruido en los logs de salida, y si es posible añadir en el log de salida que se reporta al servidor toda la linea de comandos utilizada.
+ El comando "choco outdated -r" estoy viendo que lo ejecutas con cada iteracion, este comando hace consultas a los servidores de chocolatey lo que implica trafico, y si hacemos muchas peticiones nos podrían banear la IP, es por ello que quiero que limites la ejecución de este comando una vez cada 16 horás máximo, cuando lo ejecutes guarda el resultado en algun sitio accesible, para que durante las próximas 16 horas cuando estés iterando no lo ejecutes, sino recuperes el ultimo resultado. Esto es cierto que puede demorar actualizaciones de versiones hasta 16 horas, pero lo damos por aceptable.
+ Igualmente añade al pswm una action que se llame reset_timers_lock , que lo que haga es eliminar la fecha y hora de ultima vez que se ejecuto el procedimiento de actualizaciones y tambien eliminar ese resultado guardado de "choco outdated -r" , lo cual forzaría a ejecutar en la proxima iteración el "choco outdated -r" y el procedimiento de actualizar. Incluye informacion detallada, de onde estaba guardado, las fechas de inicio y las fechas de fin de cada uno
+ En los facts de forma genernal aquellos clave valor, en el que valor están vacíos lo estás mostrando con el icono de una carpeta, para esos casos pon un icono mas propicio
+ En los facts elimina el Built-In Total ya que tenemos el Memoria y el Memoria renombralo a RAM
+ Dentro de algunos facts tienes en primer nivel el nombre del fact y luego en el segundo lo vuelves a repetir, por ejemplo Chocolatey -> Chocolatey , tambien lo haces con Disks (Disks -> disks) y tambien con Uptime
+ En la pestaña Chocolatey arriba del todo, quiero poder ver que Perfil es el que está aplicando al agente, así como los "Despliegues de Chocolatey"
+ En la misma pestaña en los paquetes de chocolatey gestionados, en el popup de Info, podríamos mostrar que "Despliegues de chocolatey" es el que lo gestiona
+ En los "Despliegues de chocolatey" quiero poder editar los paquetes.
+ En el formulario de "Despliegue de Chocolatey" en los de tipo location quiero que muestres las localizaciones igual que en el formulario de "Despliegues de Powershell", con el bugdet formato pildora con toda la informacion dentro por ejemplo "🏢 pHiSoft > SJPlace > 📍 Casa"
+ En la vista de listado de "Despliegues de Chocolatey" en la columna objetivo , quiero que muestres todos los objetivos en forma de budgets

+ En la vista "Despliegues de Chocolatey" el orden por defecto es de arriba abajo según el tipo:
> Todos
> Organizacion
> Localizacion
> Grupos
> Agentes
+ En la ficha de Agentes, en los Facts el Fact Built-In que se llama Total, lo renombramos a RAM
+ En la ficha de Agentes, en la pestaña chocolatey:
> Para determinar el Perfil de chocolatey Activo, perimeo debemos determinar el "Despliegue de Chocolatey" con mas peso entre todo los que aplique a este agente.
> Entonces en "Despliegues Chocolatey activos" debes mostrar todos los que afectan a este agente.
> Luego se determina cual es del mayor precedencia para determinar el "Perfil de Chocolatey Activo", para este caso unicamente evaluamos los "Despliegues de Chocolate Activos" que no son de tipo Grupo, y que tengan asociado/elegido un Perfil de Chocolatey y la precedencia o el peso es este, segun el tipo de mayor a menor "Agentes > Localizaciones > Organizaciones > Todos", una vez determinado el de mayor peso o precedencia, en el badge correspondiente en "Despliegues Chocolatey Activos" lo marcamos con una icono de estrella ⭐.
> Para los paquetes gestionados, usamos una estrategia parecida, primero elaboramos un listado de todos los paquetes relacionados con todos los "Despliegues de Chocolatey Activos" que afecten al gente. Si hay un paquete repetido, se utiliza el de mayor precedencia o peso segun el tipo del "Despliegue Choco Activos" de mayor a menor ( Aqui si entran los grupos ) "Agentes > Grupos > Organizaciones > Todos" . Ten en cuetna esto ya que en el icono info de los paquetes gestionados en el popup que muestra info extendida del mismo, debes indicar el "Despliege de Chocolatey Activo" Seleccionado.
+ En el formulario de edición de un "Despliegue de Chocolatey" , en los de tipo Organizacion, en los badges que se muestran las organizaciones elegidas, añade al badge el emoji 🏢
+ A los "Perfiles de chocolatey","Despliegues de choco","Scripts de Powershell", "Despligues","Grupos","Etquetas",etc ... ponerle el incono de accion y la implementación correpondiente para "Clonar", repetando el esquema de iconos y colores actual en cada caso.
+ Al pswm al comando uninstall_service añadimos el parametro --remove-files para que tambien elimine los archivos .exe de la ruta donde están instalados, tras eliminar el servicio.
> En el texto de salida cuando ejecutamos pswm.exe sin prametros que muestra "psWinModel Reborn Agent - CLI v0.1.0-mvp" usa la version real, leyendola del fileinfo del mismo y tambien cuando ejecutamos pwsm.exe version

+ En la pestaña "Chocolatey" de Agente, en la parte de Paquetes de Choclatey, en Gestionados , no es necesario que el agente itere para saber cuales son los gestionados.
> Una vez que los sepas ponlos todos, incluso los que son uninstall,  y tambien los que no están instalados.
> Los que pongas en la parte de Gestionados, quitalos de la parte "No Gestionados" si están
> Los que sean gestionados de accion install, pero si aún no sabemos que está instalado, a la izquierda del nombre le ponemos un emoji que refleje el estado. Hacemos lo mismo con la version, y el fijado.
> Si se da el caso de que tiene una version fijada en el despliege pero la que reconocemos instalada es diferente, le ponemos al lado un emoji y al hacer click sobre ese emoji, se despliega un popup tipo viñeta indicando que en la siguiente iteracion se instalará la version deseada.
> Con lo del caso pineado haremos lo mismo que con la version
> Y con el estado install/uninstall haremos lo mismo
+ Para "pswm.exe iterate" si le pasamos el parametro --log-extended-info , para que se registre en el log cada una de las ejecuciones que hagamos de powershell.exe o de choco.exe con sus parametros y linea de comando
+ En la consola web en alguna sitio que te dejaré que lo ubique y lo nombre, quiero añadir una característica que tiene un cajón de texto para añadir un bloque de texto que es el script que se encargará de instalar chocolatey en la maquina del agente si no lo tuviera instalado.
>  El script por defecto es el siguiente:
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
+ Visto lo anterior en pswm cuando se ejcuta iterate, si detecta que NO está instalado el chocolatey (choco.exe) solicitará al servidor el script para instalarlo, y procederá instalarlo.
> Una vez que se ha instalado el chocolatey, es necesario refrescar las variables de entorno para que reconozca que en la variable PATH ya existe la ruta del choco. Igualmente en pswm, cuando var a buscar choco.exe si no lo encuentras por los metodo que están actualmente implementados, puede probar a ver si lo encuentras en la ruta por defecto "$($env:ProgramData)\chocolatey\bin\choco.exe"
+ En la vista "Despliegues de Choco" en la columna "Paquetes" poner junto al nombre los siguientes emojis:
> ➕ Si es para instalar (a la izquierda del nombre)
> ❌ Si es para desinstalar (a la izquierda del nombre)
> ⚙️ Si lleva parámetros (a la derecha del nombre)
> #️⃣ Si tiene indicada una version específica (a la derecha del nombre)
> 📌 Si esta fijado (pin) (a la derecha del nombre)
> A partir de 3 paquetes Colapsas todos los paquetes de ese despliegue en un comprimible
+ Tambien quiero que NO sea obligatorio poner al menos un paquete de choco en los despliegues, se puede crear o editar sin necesidad de indicar algn paquetde de choco.
+ En el Dashboard aparecen todas las cards a 0

+ Cuando a un paquete de chocolatey se le asigna una version, hay que marcar de forma obligatoria el check "Fijar (pin)" ya que una version específica implica pineado
+ En "Eventos Chocolatey Recientes" preservar unicametne los que coincidan con las 3 ultimas iteraciones de agente. Ademas. que sea comprimible igual que "Gestionados" y "No gestionados"
+ En la columna "Fijado" a los que están pineados usa el mismo budget que en la de "Gestionados" -> 📌 PIN
+ En Gestionados ordenalos por "Accion" y luego por "Paquete"
+ A las pestañas "Información","Facts","Scripts Runs","Chocolatey" adjuntales el icono representativo de cada uno.
> Al de Información pon el tipico icono de información
> A Facts usa el mismo icono que usamos para los Scripts Powershell de tipo fact
> Scripts Runs ya tiene el icono mismo icono que usas para definir la seccion Paquetes en el formulario de edicion de "Despliegues Chocolatey", que es basicamente un cubo.
> Además me gustaría renombrar las pestañas "Scripts Runs" por iteraciones, y "Chocolatey" por Packages
+ En las "Versiones de Agente" en el listado de "Versiones almacenadas" ponme casillas multi checks para hacer seleccion multiple y poder eliminar varios de una sola vez

+ Al final de la iteracion vuelve a generar la fase de facts, tanto los buit-in y los scripts tipo facts, a fin de que si algun script o accion ha cambiado algo quede reflejado en los facts.
+ Cuando vinculamos e instalamos mediante gui añade una casilla para poder rellenar una anotación que será puesta en la casilla "Anotación" del agente.
+ Cuando un equipo aparece en cola de aprobación tambien es necesario tener los datos de las direcciones mac de los adaptadores, conectados y tambien si puede ser la Marca y Modelo del dipositivo. Esta información hay que mostrarla en la cola de Registros
+ Para Tokens de registros, si se crea un Token de un solo uso, y con una fecha de caducidad de máximo 15 días, el tipo de token debe ser un codigo de letras de la A a la Z y Numeros del 0 al 9 , de seis 8 caracteres de longitud, separados por un guion medio (al final queda una logitud de 9 digitos) sin usar caracteres ambiguos, como la O y el 0 l y 1 , I o l, etc . Esto son codigos cortos de un solo uso, estos codigos no deben poder cambiarse los usos máximos ni la fecha de caducidad.
+ En "Tokens de Registro" añade el botón de eliminar para aquellos que estén caducados o revocados
+ Para la cola de registro tambien añade boton de eliminar para aquellos que hayan sido rechazados, o tambien los que han sidos aprobado pero hace mas de 15 días. En esta añade tambien checkboxes para poder hacer una seleccion multiple y poder eliminar varios de una sola vez, aqui tambien tenemos que tener en cuenta los criterios anteriores,  ni siquiera permitir seleccionar esos.

+ Vamos a hacer el despliegue inicial en produccion del servidor y la web-console
> Para ello vamos a utilizar un LXC que tengo bajo mi infraestructura de proxmox.
> La ip del LXC es 192.168.200.242
> Está basado en debian 12
> Antes de hacer el despliege vamos a configurar primero el accso ssh con clave ssh, para que puedas interactuar con el propio LXC con el comando ssh
> Luego tendras que instalar y configurar git , con acceso por token o ssh, aqui me vas guiando.
> Quiero que el despliegue lo hagas bajo la ruta /root/pswinmodel
> Recuerda que tienes que instalar todo lo necesario
> Luego publicaremos tanto el server como el web-console usando cloudflared tunnel con mi propio dominio
> Una vez hecho todo, guarda como está todo montado en LXC, y tambien los datos y metodo de acceso para futuros despliegues, en un documento dentro de /docs
> No hagas transferencias dela app o de scripts de la misma con scp, lo que haces es crearlos, subirlos con git push y descargarlos con git pull en el LXC.
# Despliegue realizado el 08/03/2026. SSH por clave OK. Node 20 + PM2 + cloudflared instalados.
# API en :3000, web-console en :3001 accesibles desde LAN. Cloudflared instalado, tunnel pendiente de dominio.
# Documentación en docs/despliegue-lxc.md (repo servidor). Acceso: ssh pswinmodel-lxc

+ Auditoría de Seguridad Zero-Day
>Examina este código fuente crítico. Simula un ataque de inyección complejo e identifica fallos en la lógica de negocio. Proporciona los parches y las pruebas de regresión asociadas.
# Completada: SEC-01..SEC-10 parcheados en src/index.js, src/middleware/auth.js, src/routes/{agents,deployments,facts,scripts,settings}.js. Commit cc48488. Desplegado en produccion OK.
+ Generación de Documentación Técnica
>Recorre todo el código y genera una documentación técnica completa (50k palabras) en formato Markdown, incluyendo diagramas Mermaid de flujos de datos.
# Completada: docs/documentacion-tecnica.md (1678 líneas, 18 capítulos, 15+ diagramas Mermaid) + docs/openapi.yaml (3001 líneas, OpenAPI 3.0). Commit cc3d510.
+ Generación de Suite de Pruebas
>Redacta una suite completa de pruebas unitarias y de integración que cubra el 100% de los casos de uso de este módulo, incluyendo casos límite y edge cases.
# Completada: 197 tests (18 unit + 179 integration) — tests/unit.test.js + tests/integration.test.js + tests/helpers.js. Se corrigió bug de orden de rutas en deployments.js. Commit cc3d510.

+ Estoy intentaando arrancar la consola web en local y me sale un error
PS C:\MyRepos\psWinModel-Reborn-Server\web-console> npm run dev

> web-console@0.0.1 dev
> vite dev

error when starting dev server:
Error [ERR_MODULE_NOT_FOUND]: Cannot find package '@sveltejs/adapter-node' imported from C:\MyRepos\psWinModel-Reborn-Server\web-console\svelte.config.js   
    at Object.getPackageJSONURL (node:internal/modules/package_json_reader:316:9)
    at packageResolve (node:internal/modules/esm/resolve:768:81)
    at moduleResolve (node:internal/modules/esm/resolve:858:18)
    at defaultResolve (node:internal/modules/esm/resolve:990:11)
    at #cachedDefaultResolve (node:internal/modules/esm/loader:757:20)
    at ModuleLoader.resolve (node:internal/modules/esm/loader:734:38)
    at ModuleLoader.getModuleJobForImport (node:internal/modules/esm/loader:317:38)
    at #link (node:internal/modules/esm/module_job:208:49)
# Solucionado: ejecutar npm install en web-console/. El paquete @sveltejs/adapter-node estaba en devDependencies pero no instalado.
+ Al pswm tanto al reg_init_check como al reg_token le añadimos el parametro --install el cual quiere decir que si se ha registrado bien, aunque esté esperando por aprobacion, instale automaticamente los servicios, si no están instalados.
# Implementado: --install detectado via raw cmdline (funciona compilado). En reg_init_check se instala el servicio antes del polling. En reg_token se instala tras registro exitoso.
+ Igualmente en "pswm install", y tambien en psem reg_init o reg_token con parametro --install una vez que se ha registrado e instaldo el servicio, pone el servicio en inicio automatico, y lo inicia.
# Implementado: Enable-ServiceAutostart() llamado tras instalar. pswm install ahora usa StartupType Automatic y arranca el servicio automaticamente.
+ Revisa "pswm unistall_service --remove-files" porque lo he ejecutado y no ha eliminado los archivos
PS C:\MyRepos\psWinModel-Reborn-Agent\build> .\pswm.exe uninstall_service --remove-files
[INFO] Desinstalando servicio...
[OK] Servicio 'pswm-reborn' eliminado correctamente.

Nota: Los archivos en C:\Program Files\pswm-reborn NO se han eliminado.
Para eliminarlos manualmente: Remove-Item -Recurse -Force 'C:\Program Files\pswm-reborn'
PS C:\MyRepos\psWinModel-Reborn-Agent\build> .\pswm.exe uninstall_service --remove-files
PS C:\MyRepos\psWinModel-Reborn-Agent\build> Remove-Item -Recurse -Force 'C:\Program Files\pswm-reborn'
# Corregido: $script:RemoveFiles detectado via raw cmdline (igual que --log-extended-info). Ahora elimina el directorio completo con Remove-Item -Recurse -Force. La nota 'NO eliminados' solo aparece cuando NO se pasa --remove-files.
+ En la seccion "Cola de aprobación" en el mismo SideMenu, quiero aparezca un indicador como un contador de notificaciones tipico de android, el que se parece un boliche rojo con un numero dentro, siempre que hayan equipos en cola esperando. Si "Agentes" está colapsed y no se "Cola de aprobación" en casos como este lo despliegas automáticamente.
# Implementado: badge rojo con contador junto a 'Cola de Aprobación' en ambos bloques del menu. Polling cada 60s. Auto-expand de 'Agentes' cuando hay pendientes. Archivo: web-console src/routes/(app)/+layout.svelte

+ A pswm reg_init_check si le añadimos--install , no vamos a iterar hasta que sea aprobado o rechazado el equipo, lo que hace es tras que se hayan generados las claves y se haya guardado el queue Id en el config, procedemo a instalar el servicio, y ya luego el propio servicio llamará pswm iterate, con algunos cambios que quiero hacer.
# Implementado: cuando --install esta activo, reg_init_check instala el servicio y sale (Exit-Cmd 0). No hace polling. El servicio llamara iterate periodicamente.
+ A pswm reg_init_check mientras está status pending, hace una comprobación cada 5 segundos, y vamos a cambiar ese comportamiento.
> Las primeras 3 iteraciones siguen con un intervalo de 5 segundos, luego las siguientes 20 iteraciones cada 30 segundos, y desde esas en adelante, cada 60 segundos (1 minuto)
# Implementado: intervalos adaptativos en la logica de polling de reg_init_check (sin --install). 5s/30s/60s.
+ Con esto cada vez que pswm iterate se lance, debe comprobar que el agente no esá en Queued, si esta queued, entonces, el propio pswm iterate lanza un pswm reg_init_check ya que si no es aprobado en la consola po podrá iterar.
# Implementado: al inicio de Invoke-Iterate se comprueba queue_id sin agent_id. Si pending -> inicia polling inline con intervalos adaptativos (5s/30s/60s) hasta aprobacion o rechazo, y luego continua la iteracion normalmente. Si rechazado, sale con error.

+ Ahora quiero estandarizar el popup que utilizamos para "Seleccionar Organición y Ubicación" , para usarlo en todas las partes que sea necesario. Vamos a partir primero iterando sobre el que utilizamos para "Asignar" Ubicacion en el formulario de "Editar Agente", quiero que lo mejores, que sea mas intuitivo y ofrezca mejor experiencia de usuario, además usa los emojis propicios dentro de la interfaz como lo son 🏢 y 📍, si quieres puedes crear 3 variantes, para probarlas, pon por ahora un botón "Asignar" para cada variante. Despues cuando elijamos eliminamos los botones tambien.
# Implementado: LocationPickerModal.svelte creado con 3 variantes (A: panel dividido con búsqueda+TreeNode, B: cascada por pasos con tarjetas org→lista ubicaciones, C: búsqueda unificada con pills breadcrumb). Integrado en edit/+page.svelte con 3 botones "Variante A/B/C". Limpiadas variables e imports no usados (orgModalOpen, expandedNodes, orgLoading, toggleNode, buildTree, selectLocationFromTree, import TreeNode). Archivo: web-console/src/lib/LocationPickerModal.svelte

+ Me gusta la variante A, Elimina las variantes B y C y sus botones. Luego usa la variante seleccionada, en todos lo sitios donde se use un "Selector de Ubicación", ahora mismo te puedo decir lo que se, pero seguro que hay alguno mas, son:
> En Cola de aprobación en popup que se muestra cuando aprobamos un agente
> En "Crear Token de registro"
> En despliegues de Scripts de powershell tipo location. (Formulario de nuevo y edicion)
> En despluiegues de choco tipo location (Formulario de nuevo y edicion)
> Revisa por si hay alguno mas...
> En todos usar el Selector de Ubicacion de Variante A
> Documenta donde veas oportuno, para que si en el futuro tienes que implementar otro selector de Ubicacion uses el mismo.
+ Cuando usamos el botón Clonar, no quiero que lo clone directamente, es decir que cree el registo, sino que abra el formulario de nuevo con los datos prerellenados igual del original que vamos a clonar.

+ En la vista "Gestion de Agentes" en Org / Ubicación tenemos que susar tambien el "Selector de Ubicación" que hemos elegido anteriormente.
+ Quiero tambien estandarizar el badge que usamos para mostrar una ubicacion, ya seleccionada.
> Por ejemplo el badge que utilizamos para representar una ubicacion que  usamos en el campo "Ubicación" en los "Detalles del Agente" , es la que mas me gusta, así que lo llamaremos el "badge de ubicacion predeterminado". Debemos usarla en todos los sitios que estamos representando una ubicacion, asi lo que tengo en mente son:
> "Gestion de Agentes" , aqui tenemos 2 columnas una llamada Organización y otra Ubicación, podemos prescindir de la columna Organización y usar unicamente la columna Ubicación, con el "badge de ubicación predeterminado"
> cuando estamos editando un agente en "Editar Agente", tambien debemos usar este badge
> En "Crear token de Registro"
> En Despliegues de Powershell, tanto de tipo Localizaciones, como tipo Organizaciones (tanto en el formulario de creación o de edición)
> En Despliegues de Chocom, tanto de tipo Localizaciones, como tipo Organizaciones (tanto en el formulario de creación o de edición)
> Tambien en las vistas principal de "Despliegues Choco" en el listado en la columna "Objetivo" cuando es tipo Organizaciones, o Localizaciones
> Revisa a ver si hay algun sitio mas donde representamos localizaciones y usa ese badge
+ El Listado de "Despliegues" de powershell, quita la columa "Single Run" y pon "Objetivo" igual que en el listado de "Despliegues Choco"
> En La columna los scripts, tiene un badge que representa a cada script con su icono representativo, pon el icono a la izquierda del nombre del script.
> Arriba el buscador de despliegues tiene un desplegable para elegir ubicaciones, vamos a usar el mismo que usamos en "Todos los agentes" > ""Gestion de Agentes", con el popup para seleccionar una ubicacion, usando el popup de "Selector de Ubicación" que hemos elegido.
+ Cuando creamos un "Token de Registro" ya sea el Estándar o el "Código Corto" cuando seleccionamos una fecha pon por defecto la hora 23:59 si no está indicada o sea si está "--:--".
+ Tambien me gustaría estandarizar "Selector de Grupo" y un "Selector de Agentes".
> 5 variantes de cada uno en la url /selectores_test para probar los que me sugieres y luego elegimos uno de cada, o iteramos para hacer el definitivo.
> Ambos popup tienen que tener la posibilidad de recargar desde el mismo popup, por si se por ejemplo se ha creado un agente nuevo mientras está abierto, tambien para grupos, no pongas un enlaces de texto, sino un icono representativo para ello.
> Para el popup de Selector de Agentes , ademas de buscar por nombre tambien tenemos que tener la posiblidad de filtrar por ubicación usando el "Selector de Ubicaciones" definido en la documentación.
+ En la vista de "Todos los agentes" > ""Gestion de Agentes" , agrega la columna "Version Agente"
+ Para los usuarios crea todo el sistema para inmplementar MFA por QR compatible con Google Authenticator.
> Como por ahora no tenemos soporte par email, para recuperar contraseña, crea un script que seráunicamente de acceso desde la consola del servidor por comando para eliminar el MFA de un usuario, en este caso tambien es imperativo poner una contraseña nueva, que la genere el mismo script de 12 caracteres, solo letras y numero mayusculas y minusculas, sin usar caracteres ambiguos.
+ En "Versiones del Agente", quiero tener la posibilidad de seleccionar uno de las versiones del agente, para poder descargarla desde la url /agent a la que se podrá acceder unicamente para tal menester para descargar esa version
> En /agent aparecerá una web con un botón para descargar el pswm.exe indicando tambien la version y los hashes, si pulsas el botón lleva a la descarga que estará en /agent/pswm.exe (esta url tambien puede ser utilizada para descargarlo directamente desde scripts externos)
> Si NO hay version seleccionada para descargar pulicamente no estará disponible el enlace /agent/pswm.exe
> La version publicada por este método no tene que coincidir con la version publicada para descargar en upgrades o mandatory desde pwsm_updater.exe
> El enlace /agent/pswm.exe lo ofrece la app de api server, no la de la web-console

+ cuando seleccionamos una ubicacion en Gestion de Agentes, hay que buscar por los agentes de esa ubicaciony de todas las que estén (sean hijos) de esa ubicacion.

+ En "Desplieges" de powershell en la columna Objetivo, en los que son de tipo location o organizacion, hay que usar el "badge de ubicación predeterminado"
+ En los despliegues de tipo organizaciones, tenemos que estandarizar tambien el popup de seleccion de Organizacion, podemos basarlo en "Selector de Ubicaciones" , pero permitiendo unicamente la seleccion de "Organizaciones", incluye tambien 5 variaste para el "Selector de Organizaciones" en /selectores_test
+ No implementaste esto que te dije antes, "Cuando creamos un "Token de Registro" ya sea el Estándar o el "Código Corto" cuando seleccionamos una fecha pon por defecto la hora 23:59 si no está indicada o sea si está "--:--""
> si quieres en el selector de fecha, que solo sea fecha, no hace falta indicar la hora, eso si , almacenamos la fecha pero la hora siempre las 23:59
+ Lo que implementamos para la descarga pública sin autenticar del agente, en la parte de la web-console cuando vas /agent muestra la interfaz con el boton de descarga y demás datos, que redirecciona a la url /agent/pswm.exe del servidor
> En el servidor /agent dará error 404 ,  pero /agent/pswm.exe desacarga directamente la version pública del mismo
> En el web-console /agent mostrará la UI con el botón demás datos para descargar el agente y el botón redireccionará a /agent/pswm.exe del servidor.
+ Para todas la variantes de "Selectores de Agente", cuando quiero filtrar por ubicacion:
> Tengo que poder seleccionar unicamente la Organización si quiero
> Si selecciono una organización o una ubicacion cuaddo filtre por ubicacion, quiere decir que están incluidos los agentes de esa ubiaciones y los agentes de todos los hijos de esa ubicacion.
+ Documenta como se hace un reseteo del mfa con el script creado a tal fin.
+ Cuando itento configurar mi MFA en la web me sale unicamente la palabra "internal" en un recuadro y en la consola sale esto:
[nodemon] starting `node src/index.js`
[WARN] No JWT secret configured. Using insecure default — ONLY acceptable in development.
Server listening on port 3000
Could not migrate old update settings: oldVersion is not defined
[MFA] setup error: TypeError: Cannot read properties of undefined (reading 'generateSecret')
    at C:\MyRepos\psWinModel-Reborn-Server\src\routes\mfa.js:34:34
    at Layer.handle [as handle_request] (C:\MyRepos\psWinModel-Reborn-Server\node_modules\express\lib\router\layer.js:95:5)   
    at next (C:\MyRepos\psWinModel-Reborn-Server\node_modules\express\lib\router\route.js:149:13)
    at authMiddleware (C:\MyRepos\psWinModel-Reborn-Server\src\middleware\auth.js:62:5)

+ De selectores_test :
> El "Selector de Grupo" predeterminado será la variante E
> El "Selector de Agente" predeterminado será la variante B , pero recuerda que en la columna Ubicación tenemos que usar el "badge de ubicacion predeterminado" que elegimos anteriormente.
> El "Selector de Orgnizacion" predeterminado será la variante E
> Busca en todo el proyecto donde se usa Selectores de "Grupo","Agentes" y/o "Organizaciones" y cambialos por los predeterminados que acabamos de definir
> Documenta los "Selectores" prederminados que hemos seleccionado para cada cosa.
+ Documenta tambien si no lo esta, cual es el "badge de ubicacion predeterminado" elegido anteriormante y el "Selector de Ubicaciones" si no no lo están ya.
+ Elimina el acceso a /selectores_test una vez esté todo implementado y documentado.

+ Te falto usar los nuevos selectores de "Grupo", "Organzaciones" , "Agentes" en :
> Los despliegues de Powershell de cada tipo, tanto en el formulario de Creacion como el de edicion.
> Los despliegues de Choco de cada tipo, tanto en el formulario de Creacion como el de edicion.
> En el botón Acciones de "Gestion de Agentes" -> "Asignar Grupo"
> Haz una busqueda un poco mas exaustiva a ver si alguno de los selectores predeterminados no se está usando en algún sitio del codigo donde tiene cabida y debería usarse.
+ En la edicion de angente "Editar Agente", tiene una seccion para seleccionar los grupos a los que pertenece, y es una lista con todos los grupos y un checkbox para cada uno, esto no es muy comodo de usar cuando haya muchos grupos. Quiero que uses Badges con los grupos a los que está asignado el agente, y cada badge puede ser elimnado con el boton X que tendrá cada uno, luego en la misma zona un botón o badge de accion que diga seleccionar grupo o agregar a grupo, y usamos el "Selector de Grupos" predeterminado para añadirlo a esos grupos.

+ En el "Selector de Agentes" predeterminado, en el popup la columna ubicación debe mostrar el "badge de ubicación predeterminado" con toda la ruta completa, ahora mismo solo estas mostrando la Organización y la localizacion final, no muestra las intermedias, el badge debe indicar la ruta completa.
+ en la "Gestion de Grupos" en el botón "Gestionar Agente" debemos usar el "Selector de Agentes" predeterminado.

+ En los popups del "Selector de Grupo" , aparece un texto indicando que Variante es, esto ya no aplica era solo para el momento de test, elimina ese texto en todos lo sitios que se use.
+ En los popups del "Selector de Agente" , aparece un texto indicando que Variante es, esto ya no aplica era solo para el momento de test, elimina ese texto en todos lo sitios que se use.
+ En los popups del "Selector de Grupo" , aparece un texto indicando que Variante es, esto ya no aplica era solo para el momento de test, elimina ese texto en todos lo sitios que se use.
+ Cuando estamos crando un nuevo despliegue de powershell, y selecciono "Localizaciones" , cuando le doy al botón "Agregar Localización" no pasa nada, y debería mostrar el "Selector de Ubicacion" predeterminado. Cuando edito un despliegue de este tipo si aparece el "Selector de Ubicacion" correcto.

+ El pswm.ps1 tiene hardcodeado en la funcion Get-ServerUrl la url por defecto http://localhost:3000 , bien, quiero que si en el mismo directorio de build.ps1 existe un .json que tenga esa opcion con una url, compile pswm con la url del .json hardcodeada en pswm.exe
+ En la gestion de usuarios me gustaría ver que sesiones "abiertas" tiene cada usuario, con IP de orgigen de cada sesion y poder cerrarlas todas o granularmente.
+ En los despliegue de chocolatey, en los paquetes quiero agregar una nueva accion, que no se como llamarla, pero básicamente es que en paquete que hayan sido instalados , bien manualmente por el usuario, o por cualquier otro metodo, entonces pasa a ser gestionado, ajustando la version especifica si la tiene, usando los parametros indicados para actualziar si lo tiene, fijarlo si está establecido, y entrar en las politicas de Actualizaciones del perfil.
+ Quiero que se guarde un registro de todas las veces que se ha descargado el pswm.exe con el enlacde de descarga pública, registrando fecha y hora ip remota, y la version pswm.exe
> Ponlo dentro de "Versiones de Agente" pero en una pestaña nueva, limita el regitro a los ultimos 200 mas recientes, el resto eliminalos de la BDD.
+ A las organizaciones vamos a ponerle una opción para poder subirle un logotipo.
+ En la "Gestión de Agentes" en la pestaña Packages de un agente, en la parte de "Paquetes Chocolate" Gestionados, hay que agregar tambien la columna "Actualización disponible" igual que en los "No gestionados"
+ En /agent de la web-console quiero que muestre la version correcta, te pongo la peticion que implementamos anteriormente par que sepas lo que hablo:
> "En las versiones de agente, cuando lo subo , no me preserva los 0 iniciales de cada segmento, por ejemplo la version 2026.03.10.02244 aparece como 2026.3.10.2244 y al menos en el ultimo segmento de la version, si tiene un cero delante me gustaría que apareciera, y ya que en los otros vamos a eliminar los ceros iniciales en la web tambien lo hacemos en local."

+ En /agent de la web-console muestras debanjo el texto "También puedes descargar directamente desde:
https://pswm-server.phiro.es/agent/pswm.exe" , pues quiero que junto a la casilla de la url ponga un icono tipico para copiar la url al portapapeles

+ Los logos de fondo de las organizaciones los pones de fondo centrados en la card, rellenando todo lo vertical, y respentando la proporcion , sin deformarlo, y como marca de agua apenas se ve, ponlo si con transparencia, pero qu se vea ahora está muy translucido.
+ Quiero pasarle un parametro a pswm iterate para que si este parametro está, muestre en foreground las ventanas de los procesos de choco.exe , así podemos ir viendo que sucede y si se atasca de alguna forma
+ Cuando en una iteracion se necesita instalar el propio chocolatey, tambien hay que registralo en la iteración , usemos un icono diferentes al de los "Paquetes de choco", los "Scripts Actions", y los "Scripts Facts"
+ Me gustaría que las iteraciones muestren un icono mientras están iterando, y otro cuando ya han iterado (esto directametne arriba junto con el iteration ID)
> Tambien una vez finalizado registrar el tiempo que duró en formato ( #h #m #seg)
> Si empieza una iteración y supuestamente hay otra anterior que ha terminado, marcamos esa anterior con icono que represente que la iteracion fue abortada o terminada abruptamente.
+ Lo que implementamos de las sesiones activas de los usuarios y que puedan cerrarlas selectivamente, quiero que también cada usuario tenga las suyas propias disponible en "Mi Perfil"

+ En el "pswm help" documenta el parametro '--show-choco-window'

+ Si es posible y no muy complicado, cuando se autoactualice el agente pswm.exe, quiero que apareza en la iteracion en la ficha del Agente.
+ En la documentacion en un archivo .md genera el un bloque de código de powershell para instalar de forma desatendida pswm.exe con token
> Debe contener 3 variables una para el token , otra con la url de la descarga del pswm.exe y otra con la url del pswm-server.
> Usa la misma estrategia que usa chocolatey para instalar su software invocando a Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
> La idea es que descargue el pswm.exe y lo instale u lo vincule usando token.
+ Con lo que sabemos del punto anterior, al generar el token de registro debe mostrar el bloque de código para instalar pswm.exe usando el token generado.
> Tambien aparecerá cuando pulsamos sobre el icono de info junto a los tokens.
+ En los tokens cambia el icono de copiar token que está actualmente por el otro mas característico que somo dos cuadrados/rectángulos sobrepuestos. Y que cuando lo pulse apareza algun texto parecido a los toast notifications de android para saber que se ha copiado.
+ En la vista de Packages en los detalles de un Agente, en la seccion de Paquetes Chocolate Gestionados, los que son de tipo "adopt" aparecen con "✅" aunque no están instalados, si no estan instalados ponles otro icono para diferenciarlo, pero que no sea ⌛ ni ⏳, y además esos que no están instalados quiero que aparezan a la punta abajo del listado de los gestionados,  justo antes de los uninstall, cuando se vayan instalando iran moviendose arriba junto con los que están install.
+ En esa Vista de Packages Tenemos el "PERFIL CHOCOLATATEY ACTIVO" y "DESPLIEGUES CHOCOLATEY ACTIVOS" y debajo de cada uno los badges que representa a cada uno de los que aplica al agente, pues cuando hagamos click en el agente quiero que se abra la vista de "Depliegues" de powershell o "Despliegues Choco" con el campo de búsqueda del cuadro de texto de , rellenado con el id:<id del despliege>.
> Que lo abra en una pestaña nueva
> Para que esto funcione debes hacer cambios en el buscado para que si hacemos una búsqueda que empiece por id: muestre unicamente el despliegue que coresponda
> Tambien haz que se abra si pulsamos en el badge de despliegue que está dentro del popup que aparece al pulsar sobre el icono de info de cada paquete gestionado.
+ En todos los contenedores que mostramos codigo de salida de los comandos quiero que tengan arriba a la derecha un icono para abrirlo en forma de popup mas ampliado para poder ver mas cantidad de texto
> Recuerda que este popup debe tener el botón cerrar, pero tambien quiero que tenga el boton descargar para descargar el contenido como un .txt
> Tambien ponle el botón copiar contenido para copiarlo al portapapeles.
> Recuerda hacerlo tanto en las Iteraciones, como en los "Eventos Chocolatey Recientes"
+ En la vista "Paquetes de Chocolatey" cambia el boton recargar que es estilo texto, por uno con un icono que represente esa accion.
> Haz lo mismo con el botón "Ver salida/ocultar" que está en "Eventos Chocolatey recientes"
+ Reordena la configuración usando pestañas para cada seccion, agrupalos como quieras.
+ Para las "Versiones de Agente" ahora quiero añadir un canal de Beta:
> Para ello debemos añadir un setting para elegir que grupo contiene los agentes acogidos al canal beta.
> Luego hay que añadir toda la lógica para que los agentes en ese grupo reciban las actualiazaciones del canal beta
> Las versiones almacenadas serán comunes tanto a la version beta, como la version estable.
> El modo de publicación para cada canal es independeinte, es decir en cada uno se podrá configurar de formas diferentes.
> Genera toda la lógica, server-side, para esto no es necesario, hacer cambios en el pswm


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

+ Respecto al badge de la version BETA, tengo un caso que quiero que manejes, la "Version Beta Publicada" es la 2026.3.13.02081 pero en el agente se ve así 2026.03.13.02081 , ten cuidao con lo que tocas porque ya tuvimos una incidencia a la hora de actualizar el agente por eso mismo porque el endopint la gesiona de una forma y el agente pswm de otra.
# Implementado: añadida función normalizeVersionForComparison() en $lib/index.ts que elimina los ceros iniciales de cada segmento solo para comparación (no afecta al display ni al almacenamiento). La condición del badge BETA en agents/+page.svelte y agents/[id]/+page.svelte ahora usa esta normalización: normalizeVersionForComparison(agentVersion) === normalizeVersionForComparison(betaPublishedVersion). Así "2026.03.13.02081" y "2026.3.13.02081" se comparan correctamente.

+ Lo de "Marcar como visto X equipos nuevos" no termina de funcionar, ya que en el PC que uso para mi trabajo me apareció el boliche azul, con 1 equipo nuevo, lo marqué como visto y en ese equipo no me ha vuelto a salir, pero me he cambiado a mi PC personal, he abierto la consola y acaba de aparece el boliche azul con 1 equipo nuevo, y no , no es uno nuevo es el mismo que me salió en el equipo del trabajo. Tambien mas tarde conecté con mi dispositivo móvil , y segun lo abrí me salió el boliche azul con el tontador total de agentes registrados. Revisa que no se esté usando local storage para esto, ya que el valor de confianza es el registro "token_agents_seen_at" de la tabla "users"
# Corregido: se eliminó todo uso de localStorage para el timestamp de visto. La fuente única de verdad es ahora BDD (token_agents_seen_at en tabla users). Bug raíz: el frontend accedía a me?.token_agents_seen_at pero el endpoint /api/users/me devuelve { user: {...} }, por lo que debía ser me?.user?.token_agents_seen_at — el valor BDD nunca se leía correctamente.
+ En la configuración del servidor quiero 2 opciones individuales, ambas dentro al misma pestaña (crea una nueva), que sean para activar o desactivar globalmente la posibilidad de que los agentes se enrolen por cola de espera o por token, esto no impide generar tokens, ni aprobar los equipos que ya estuvieran en espera, solo que no admitiría enrolamientos nuevo por cualquiera de los métodos mientra la opcion esté deshabilitada. Recuerda quiero 2 opciones:
# Implementado: nueva pestaña "Enrolamiento" en Configuración del Servidor con 2 switches (enrollment_queue_enabled, enrollment_token_enabled). Los endpoints POST /api/agents/queue y POST /api/agents/register/token verifican la setting correspondiente y devuelven 403 si está deshabilitado. Los switches guardan automáticamente al cambialros.
> Permitir enrolamiento por cola de espera
> Permitir enrolamiento por uso de token
> Ambas en lugar de usar un checkbox usa un switch
+ Tambien con el sitema de updates hemos definido la frecuencia de actualizacion en dias para los modos "Actualiza todos los paquetes" y "Solo paquets gestionados", pero creo que esta frecuencia de actualización no debería limitarse a intentar actualizar en esa frecuencia los paquetes, sino en limitar el uso del comando "choco outdated -r" desde las iteraciones a esa frecuencia, pero intentar actualizar todos los paquetes actualizables, segun la información en choco_outdated_cache.json
> Con esto limitamos el uso de "choco outdated -r" por el tiempo indicado en la frecuencia. Si la "Frecuencia de actualización" no es 1 o mayor que 1, entonces lo interpretamos como 12 horas.
> En cada iteración comprobamos las versiones actuales de los paquetes respecto a las almacenadas en "choco_outdated_cache.json" para los paquetes que existan, si alguno tiene una version nueva intenta actualizarlo, si el paquete no está en "choco_outdated_cache.json" quiere decir que está a la ultima version, por lo que es necesario hacer nada.
> Recuerda que segun el "Modo de actualización" que le aplique al equipo, es "Deshabilitado", no voy hacer nunca ninguna actualización pero si ejecuto el "choco outdated -r" en la frecuencia establecida, y reflejo en la web console que hay actualizaciones disponibles para los paquetes que corresponda, si el modo es "Solo paquetes gestionados" intenta actualizar paquete por paquete de aquellos que están siendo gestionados y tengan una version nueva disponible,y si el modo es "Actualizar todos los paquetes", actualiza tambien paquete por paquete, de TODOS los paquetes instalados y que tengan version nueva disponible, no uses el comando "choco upgrade all", lo hacer paquete por paquete, primero haces todos los paquetes gestionados y despues los no gestionados.
> Ten en cuenta que los paquetes pineados NO se actualizan, por lo que ni lo intentes, pero seguimos reflejando si tiene una version nueva disponible.
+ Se está dando el caso que termuina una iteración durante la cual se han actualizado algunos paquetes de chocolatey, pero en la consola siguen apareciendo como que tiene "Actualización disponible". Quiero que antes de terminar la iteración agreges una fase mas que sea para enviar esta info actualizada al server.
+ En la vista de todos los agentes, en la columna Version, ya mostramos si es la version BETA, bien esto lo dejamos igual, pero vamos a añadir alguna mejora:
> Si la version coincide con la version publicada en la rama estable, lo dejamos tal cual, es decir no ponemos nada.
> Si la version es inferior a la version estable le ponemos un icono con una flecha roja apuntando hacia abajo.
> Si la version es superior a la version estable le ponemos un icono con una flecha azul apuntando hacia arriba
> Si en "Versiones de Agente" no hemos seleccionado ninguna version como version estable "Estado =  Publicada" entonces no ponemos ningna de las flechas.
+ Cuando usamos el popup de "Seleccionar Agente" en listado bajo el nombre del agente (pc) quiero que apareza igual que en la vista todos los agentes el owner y la anotacion si lo tienen designado, y que la búsqueda tambien tenga en cuenta esos valores.
> Tambien en el selector en lugar de usar la columna "Version" usamos la columna "Ultimo Contacto"
> Y la columna Estado del selector usamos los mismo valores que usamos en la columna estado de la vista "Todos los agentes" , a cada uno el que corresponda. En consecuencia, en el dropdown que aparece junto a la casilla de buscar, debemos introducir los valores unicos de los diferentes estados.
+ En "Versiones de Agente" en "Versioens almacenadas" ordenalas de version mayo a menor por la columna version
+ Tambien podemos poner en "Versiones almacenadas" los controles para ordenar ascente o descente por columna igual que en la vista "Todos los agentes"
+ Revisa el boliche azul porque estoy borrando la casilla token_agent_seen_at de mi usaurio y solo me aparece en el boliche el numero 1, deberían aparece el numero de agentes enrolados despues de esa fecha y como no hay fecha debería ser el total de agents
# No era bug: si solo hay 1 agente con registered_via='token', muestra 1 correctamente. Al borrar token_agents_seen_at muestra el total de agentes registrados por token.
+ Dentro de "Configuracion del Servidor" en "DEV - LAB" el setting "Forzar el boliche azul de nuevos agentes" ya no tiene sentido que sea un switch lo suyo es que sea un botón que borre el valor de la casilla token_agent_seen_at de mi usuario
# Implementado: switch reemplazado por botón "Resetear boliche azul" que llama PUT /api/users/me/preferences con token_agents_seen_at vacío. Eliminada toda referencia a devLabForceBadge del layout y settings.
