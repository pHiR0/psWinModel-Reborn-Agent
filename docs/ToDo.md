** TODO **

Este archivo recoge diferentes mejoras y correcciones que hay que realizar. Cada linea que comienza por un guión (-) es algo que hay que implementar, una vez que esté implementado hay que cambiar el guion al inicio por un simbolo mas (+) que indica que ya está implementado. Funciona como un checklist. Las lineas que empiezan por mayor que (>) se escribe a continuación de una implementación e incluse informacion ampliada y otras instrucciones para la implementación.

Una vez que hayas leído este archivo, muestra un listado rápido/simplificado de las tareas que vas a implementar.

Las Líneas que empiecen por # debes ignorarlas

IMPORTANTE: No te olvides de marcar en este archivo va inmplementación realizada com el símbolo +

Antes de terminar la iteración vuelve a releer el archivo a ver si hay nuevas mejoras o correcciones e implementalas, segun los criterios indicados anteriormente.

No tienes que modificar el contenido, nada mas que para marcarlo como hecho, si quieres puedes añadir algo bajo el punto que corresponda, comentarios que empiecen por # 

---

- Por defecto cuando instalamos para que sea desatendio usamos el parametro -y , quiero que tambien usemos el --no-progress a fin de reducir ruido en los logs de salida.
- El comando choco outdated -r estoy viendo que lo ejecutas con cada iteracion, este comando hace consultas a los servidores de chocolatey lo que implica trafico, y si hacemos muchas peticiones nos podrían banear la IP, es por ello que quiero que limites la ejecución de este comando una vez cada 16 horás máximo, cuando lo ejecutes guarda el resultado en algun sitio accesible, para que durante las próximas 16 horas cuando estés iterando no lo ejecutes, sino recuperes el ultimo resultado. Esto es cierto que puede demorar actualizaciones de versiones hasta 16 horas, pero lo damos por aceptable.
- Igualmente añade al pswm una action que se llame reset_timers_lock , que lo que haga es eliminar la fecha y hora de ultima vez que se ejecuto el procedimiento de actualizaciones y tambien eliminar ese resultado guardado de choco outdated -r , lo cual forzaría a ejecutar en la proxima iteración el choco outdated -r y el procedimiento de actualizar. Incluye informacion detallada, de onde estaba guardado, las fechas de inicio y las fechas de fin de cada uno
- En los facts de forma genernal aquellos clave valor, en el que valor está vacío lo estás mostrando con el icono de una carpeta, para esos casos ponel un icono mas propicio
- En los facts elimina el Built-In Total ya que tenemos el Memoria y el Memoria renombralo a RAM
- Dentro de algunos facts tienes en primer nivel el nombre del fat y luego en el segundo lo vuelves a repetir, por ejemplo Chocolatey -> Chocolatey , tambien lo haces con Disks (Disks -> disks) y tambien con Uptime
- En la pestaña Chocolatey arriba del todo podríamos ver que Perfil es el que está aplicando al agente
- En la misma pestaña en los paquetes de chocolatey gestionados, en el popup de Info, podríamos mostrar que "Despliegues de chocolatey" es el que lo gestiona
- En los "Despliegues de chocolatey" quiero poder editar los paquetes.
- En el formulario de "Despliegue de Chocolatey" en los de tipo location quiero que muestres las localizaciones igual que en el formulario de "Despliegues de Powershell", con el bugdet formato pildora con toda la informacion dentro por ejemplo "🏢 pHiSoft > SJPlace > 📍 Casa"
- En la visa de listado de "Despliegues de Chocolatey" en la columna objetivo , quiero que muestres todos los objetivos en forma de budgets