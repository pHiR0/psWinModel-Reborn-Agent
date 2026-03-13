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

- Quiero que cuando edito o creo una Organización no lo haga en la misma página inline,  ya que siguen apareciendo el resto de organzaciones y no es buena experiencia de usuario. Quiero una página dedicada la edicion/creación de la organición, incluso cuando estoy clonando
> Esto tambien pasa con "Scripts de PowerShell", "Grupos", "Despliegues", "Perfiles de Chocolatey", "Despliegues de Chocolatey", "Usuarios", y quizás algun sitio mas, evitemos este comportamiento de forma general
> Solucionalos todos
- Cuando hay agentes en cola de espera para ser aprobados muestras un boliche rojo con la cantidad de ellos, quiero tambien que cuando se enrolen nuevos agentes de forma automática con token , muestre un boliche igual pero en color azul en "Todos los Agente"
> Mientras esté el boliche los agentes en la vista "Gestion de Agentes" se verán con un emoji junto al nombre que indique que son nuevas incorporaciones
> El criterio para marcarlo como visto y quitar el boliche azul te dejo que lo sugieras y lo implementes, ademas despues de implementarlo, dime 4 alternativas.