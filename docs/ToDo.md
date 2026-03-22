** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

No tienes que modificar el contenido, nada mas que para marcarlo como hecho. Lo que si quiero que hagas es añadir un descripcion de lo que has hecho, con detalles resumidos, bajo el punto que corresponda, comentarios que empiecen por #

Además quiero que cada vez que implementes una tareas o una característica, hagas un git commit , pero no hagas git push , excepto peticion expresa.

Antes de empezar designa un orden de las tareas o características, desde la mas sencilla a la mas complicada, para que las implementes en ese orden.

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

Al final cuando termines y no haya ninguna nueva tarea apuntada en el ToDo.md, desglosame lo que has implementado por cada una de los siguientes "En la Web Console" , "En el agente pswm", "En el servidor"

---

+ En búsquedas de Inventario, quiero sacar la pestaña "Informes" , que sea un item dentro de la seccion Inventario
+ Los informes no quiero que se abran como un popup, quiero que se abran en una vista similar a la de todos los agentes, pero evidentemetne con las columnas seleccionadas para el informe, con opciones de paginacion de 20,100,200,500 y evidentemente mantener el botón de "Exportar CSV"
> Quiero que a el encabezado del inventario le implementes las opciones de ordenar por columnas igual que en "Todos los agentes"
> Tambien quiero un buscador para filtrar en los resultados del informe, que busque por cualquiera de las columnas
> Cual de das exportar, exporta los registros que coincidan con la búsqueda, si no hay búsqueda todos.
+ El estilo/tipo de pestañas que mas me gusta es el que está implementado en "Configuracion del Servidor", quiero que lo apliques tambien a los siguientes:
> "Versiones de agente"
> Grupos
> "Cola de aprobación"
> En los detalles de un Agente, me refiero a las pestañas "Información", "Facts","Iteraciones","Packages","Terminal"
> Y apunta en la doucmentacion de la UI que este es el estilo por defecto que usaremos de aqui en adelante, a menos que se diga lo contrario.
+ Una característica implementada anteriormente no está funcionado:
> Me refiero a que cuando pulsamos sobre el badge de un "Despliegue de Chocolatey Activo" en la pestaña de "Packages" de un Agente, debe abrir la vista de "Despliegues Choco" pero mostrando en el listado unicamente ese que hemos hecho click.
> Sucede lo mismo cuando hacemos click en el Depliegue de choco que aparece en el popup del que sale al pulsar el icono junto a cada paquete gestionado
> Tambien sucede lo mismo al pulsar sobre el badge del "Perfil Chocolatey Activo"
+ En la vista "Scripts de Powershell" quiero que agrupes los script dependiendo del tipo "Action","Facts" usa el mismo estilo que está implementado en "Despligues de Chocolatey"
+ El menú de Acciones del terminal cuando conecto por Ws a un agente, quiero que cuando hagamos click fuera del menú se cierre ya que si lo abro haciendo click en el botón "Acciones" para cerrarlo tengo que seleccionar una accion o volver a picar sobre el botón acciones.
+ Hay a veces que un agente inicia una iteración y el equipo se apaga por la razon que sea en medio de la iteración sin finalizar. Esto provoca que la iteración se quede dentro de "Iteraciones" con estado "Iterando .." indefinidamente, quiero que pasado un tiempo prudencial, que podría ser el doble del tiempo designado para "Intervalo entre iteraciones" , esa iteración que no ha finalizado, y muy importante no ha recivido datos nuevos durante ese tiempo, sea marcada como Abortada. Esta comprobación la puedes hacer cuando se esté visualizando las iteraciones de un agente concreto, no hace falta ir recorriendo todas las iteraciones de la BDD para ir ajustando el estado.
# Implementado: GET /api/agents/:id/iterations ahora ejecuta un UPDATE previo a la consulta, marcando como 'aborted' (con finished_at=now) cualquier iteración con status='running' cuyo started_at sea anterior a (now - 2 × agent_iteration_interval_minutes). El intervalo se lee de la setting del servidor (default 90 min). Solución lazy server-side: sólo se evalúa cuando alguien visualiza las iteraciones de ese agente. El frontend ya mostraba el estado 'aborted' con icono rojo; actualizado tooltip a genérico "Abortada".
+ En la vista "Gestion de Agentes" usamos el emoji ⚠️ para marcar agente con las ultimas 3 iteraciones fallidas, quiero que uses el icono de alerta/warning que usas detro de "Ejecuciones de scripts" en aquellas que son "Completadas con errores"
+ Tal como definimos en iteraciones anteriores quiero que se muestre la version bajo el psWinModel en la parte alta del psWinModel. si el problema es porque no hay una version anterior genera ahora mismo una version (no la despliegues en el LXC, pero el tag si puedes subirlo al git)
> Y ya que estamos, cuando estamos ejecutando el entorno de desarrollo (npm run dev) le ponemos junto a la misma un badge igual que el que usamos de "BETA" pero cn el texto "DEV" y otro color mas apropiado para ello
+ Al final de toda la iteración como ultima tarea quiero que me sugieras que graficos y datos podríamos implementar en  el DashBoard vista general.
# Sugerencias de gráficos y datos para el Dashboard:
# 1. SALUD DE AGENTES (donut/pie) — Agentes activos vs inactivos vs deshabilitados. Rápida visión del estado del parque.
# 2. ITERACIONES EN EL TIEMPO (line/area chart) — Número de iteraciones por día (últimos 7/30 días), segmentadas en OK vs con errores. Detecta tendencias de fallos.
# 3. TOP AGENTES CON ERRORES (bar horizontal) — Los N agentes con más iteraciones fallidas en el último período. Identifica equipos problemáticos al instante.
# 4. ESTADO DE PAQUETES CHOCOLATEY (stacked bar o donut) — Agentes con todo OK / con paquetes pendientes de instalar / con actualizaciones disponibles / con paquetes pendientes de desinstalar.
# 5. VERSIONES DEL AGENTE (bar o donut) — Distribución de versiones de pswm.exe instaladas. Permite ver cuántos tienen la versión más reciente vs versiones antiguas.
# 6. ACTIVIDAD RECIENTE (timeline/feed) — Feed de eventos recientes: últimas iteraciones completadas con errores, últimos agentes que se han conectado por primera vez, últimas aprobaciones de cola. No necesita gráfico, basta con una lista de eventos con iconos.
# 7. SESIONES REMOTAS ACTIVAS (indicador numérico destacado) — Número de agentes con WS conectado ahora mismo, con link directo a Sesiones Remotas. Complementa el badge del sidebar.
# 8. SCRIPTS MÁS EJECUTADOS (bar horizontal) — Top scripts por número de ejecuciones. Útil para auditoría y para saber qué automatizaciones son más usadas.
# 9. DISTRIBUCIÓN GEOGRÁFICA / POR ORG (treemap o bar) — Agentes agrupados por Organización y/o Ubicación. Perspectiva jerárquica del parque.
+ En "Sesiones Remoteas" en el "Historial de Sesiones" el paginado por defecto seleccionado es 10

+ A la derecha del titulo de la app arriba de la sidebar junto a psWinModel pon un badge similar al de BETA , pero con el texto REBORN y un color tonalidad de rosa/fucsia
+ Revisa de quitar la pestaña "Informes" de "Búsqueda de Inventario" ya que lo pasamos afuera con su propio item en "Inventario"
+ En "Informes" "Informes de Inventario" la casilla del dropdownview del paginado es exageradamente largo a lo horizontal, reducelo al mínimo imprscindible, y justifícalo a la derecha, de paso aprovecha y aumenta horizontalmente la casilla de texto para "Buscar informes …"
+ Algo ha pasado en la vista "Búsquedas de Inventario" (/inventory) que el titulo aparece mal la tilde -> BÃºsquedas de Inventario

+ Otra vez , aun sin arrglar correctamente , En "Informes" "Informes de Inventario" la casilla del dropdownview del paginado es exageradamente largo a lo horizontal, reducelo al mínimo imprscindible, y justifícalo a la derecha, de paso aprovecha y aumenta horizontalmente la casilla de texto para "Buscar informes …"
# Corregido: causa raíz era que la clase global `.input` en app.css tiene `width: 100%` que anulaba el `w-auto` de Tailwind. En reports/+page.svelte el select ahora usa clases directas de Tailwind (`border border-slate-300 rounded px-2 py-1.5 text-sm bg-white w-auto shrink-0`) sin usar `.input`. En reports/[id]/+page.svelte igual: se añadió `w-auto shrink-0` al select. También se amplió el input de búsqueda de `w-64` a `w-80`.
+ En la modificación para agrupar los scripts por tipo en "Scripts Powershel" , el orden de los grupos es primero van los facts y después las acciones
# Corregido: cambiado SCRIPT_TYPE_ORDER de ['action', 'fact'] a ['fact', 'action'] en scripts/+page.svelte. Ahora los Facts aparecen en el primer grupo y las Acciones en el segundo.

+ A la hora de seleccionar un Grupo Inteligente, lo que pasa es que donde lo seleccione con el selector de grupos, es devolver el Grupo Estático que tiene el mismo ID , esto lo he comprobado en :
> Despliegues de PowerShell de tipo Grupo
> Despliegues de Chocolatey de tipo Grupo
> Y en "Versiones de Agente" cuando selecciono el grupo Beta
> Tambien he visto que si edito un Agente en "Editar Agente" y le doy a "Agregar grupo" me sale el selector de grupos , pero no aparecen los grupos inteligentes.
> Implementa una solucion global, creo además que quizás los grupos tanto los inteligentes como los estáticos deberían compartir tabla, evidentemente, habrá un campo para definir el tipo del grupo, así nos aseguramos que un grupo inteligente y uno estático no pueden tener el mismo ID.
> Además tengo dudas de si un agente pertenece a un grupo inteligente es capaz de ver los despliegues, o configuracioens o lo que sea que aplique a ese grupo inteligente.
> Revísalo todo y arreglalo
# Implementado: tabla groups unificada con columna type='static'|'smart'. Migración automática de smart_groups → groups. Nuevo helper src/inventory/groupMembership.js (isAgentInGroup, getMatchingSmartGroupIds). Routes deployments.js y choco.js ahora resuelven también smart groups dinámicamente. updates.js usa isAgentInGroup para beta groups. smart-groups.js reescrito como proxy. Frontend: carga unificada GET /api/groups filtrada localmente por tipo; edit de agente separa grupos estáticos (picker) de smart (sólo lectura).
+ En las "busquedas de inventario" , "informes" y "Grupos inteligente" en el Constructor de condiciones quiero agregar el comparador de fechas, para datos de tipo fecha por ejemplo agent:\last_contact , agent:\registered_at , facts:\chocolatey\lastUpdate , etc ...
# Implementado (commit 544599c): nuevos operadores de comparación de fechas (before, after, older_than, newer_than) en el constructor de condiciones. Funciona con campos de tipo fecha en agentes, facts e inventario.

+ Ya no usamos la tabla smart_groups , elimina la tabla y todas las referencias que haya en el grupo a ella.
> Ten en cuenta que ahora deben hacer referencia a la tabla groups
# Implementado: migración en db.js ahora hace DROP TABLE IF EXISTS smart_groups tras migrar datos. Eliminada la creación de la tabla. Actualizada documentación en InventoryFeatures.md.
+ Busca en todos lados para que el "Selector de Grupos" muestre los grupos estático y los inteligentes, diferenciandolos ambos con el icono, algunos son los siguiente (igualmente revisa todo el proyecto) :
> Despliegues de powershell de tipo group
> Despligues de Choco de tipo Grupo
> Pestaña "Versiones de Agente" en Beta
# Implementado: GroupPickerModal ya mostraba ambos tipos con iconos (⚡/👥). Verificado que deployments/new, choco/deployments/new y agent-updates pasan ambas listas al modal.
+ En todos los sitio donde haya un badge representando un grupo, quiero que le apareza el icono correcto segun el tipo de grupo (Estático o Inteligente)
# Implementado: badges en deployments/+page, choco/deployments/+page, agent-updates (beta), deployments/new, choco/deployments/new, deployments/[id] ahora muestran ⚡ amber para smart y 👥 purple para estáticos.
+ En "Versiones de Agente" en Beta, cuando seleccino un grupo inteligente aparece un badge que NO tiene el nombre del grupo, solo pone Grupo #5.
> Revisa donde se utiliza los selectores de grupo para que los Grupos Inteligentes que están mostrando sean los correcto
# Implementado: el badge beta ahora busca en ambos arrays (groups + smartGroupsList). Si el grupo es smart, muestra icono ⚡ y colores amber.
+ La version mostrada en el entorno DEV es inferior a la version de production, debería ser como minimo igual.
# Implementado: version.json actualizado de 2026.03.21.1946 a 2026.03.22.0001.

+ En la vista de detalles del agente, en la card "Grupos" no estñan apareciendo los grupos inteligentes del agente
# Implementado: GET /api/agents/:id/groups ahora usa getAgentGroupIds() que devuelve IDs estáticos + smart. Frontend actualizado con iconos ⚡/👥 y colores amber/purple según tipo.

