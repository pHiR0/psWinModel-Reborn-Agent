** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

No tienes que modificar el contenido, nada mas que para marcarlo como hecho, si quieres puedes añadir algo bajo el punto que corresponda, comentarios que empiecen por # 

---

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