** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

No tienes que modificar el contenido, mas que para marcarlo como hecho, si quieres puedes añadir algo bajo el punto que corresponda comentarios que empiecen por # 

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

- En la webconsole , en la "Cola de Aprobación de Agentes" quiero que cambies la estructura, "Cola de Aprobación de Agentes" y "Tokens" , separados en Tabs.
> Para ambos añade paginación de 20 items, pero que permita seleccionar en un desplegable otras paginaciones de 50,100, y 200
- Tambien quiero que se puedan editar los Tokens, para:
> Aumentar los usos
> Cambiar la caducidad
> Cambiar la ubicacion
> Cambiar la descripcion
> El resto igual
- En Configuración tambien quiero que lo reordenes usando tabs.