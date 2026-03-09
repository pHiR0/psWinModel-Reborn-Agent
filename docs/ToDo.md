** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

No tienes que modificar el contenido, nada mas que para marcarlo como hecho, si quieres puedes añadir algo bajo el punto que corresponda, comentarios que empiecen por # 

---

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