** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

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