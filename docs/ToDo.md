** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

---

- Agrega al agente el comando svc, que lo que hace es llamar periodicamente al comando pswm.exe en su mismo directorio:
> Primero detecta que está ejecutando con privilegios de admin, sino sale
> Tiene que tener parametrizado cada cuanto tiempo lo va lanzar, podemos emppezar por 90 minutos.
> Pero según arranca lo lanza una vez y espera que termine, el tiempo de iteración es desde que termina.
> Tambien hay que parametrizar internamente con que parametros vamos a llamar a pswm.exe ;por ahor lo llamar con los parametros "check_status"
- Agrega al agente un comando llamado install , que lo que hace es:
> Primero detecta si se está ejecutando como un .exe o sea está compilado, si no, solo muestra un mensaje indicando que solo está disponible para la versión compilada.
> La ruta de instalacion será "$($env:ProgramFiles)\pswm-reborn\pswm.exe" creando las carpeta si no existen.
> Copia el pswm.exe en esa ruta; este es el agente principal y es el que lleva a cabo las acciones sobre el equipo
> Crea otra copia que se llamará pswm_svc.exe ; esta será la copia que se ejecute como servicio, que luego llamará periodicamente al pswm.exe con su parametro correcto para que itere
> Y otra copia que se llamara pswm_updater.exe ; esta será la copia que se encargue de gestionar las actualizaciones del propio ejecutable, en todas sus variantes de copias.
> Luego quiero que instales como servicio el pswm_svc.exe para que se ejecute con el parametro svc, hazlo con el cmdlet new-service. Agregale todo lo necesario para que pueda soportar trabajar como un servicio de windows. De entrada el startupType que sea manual.
- En consecuencia agrega el comando uninstall_service.
