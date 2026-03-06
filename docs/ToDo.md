** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

No tienes que modificar el contenido, nada mas que para marcarlo como hecho, si quieres puedes añadir algo bajo el punto que corresponda, comentarios que empiecen por # 

---

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
