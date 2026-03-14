Ignora el contenido entero de este archivo, son anotaciones y cosas que haremos en el futuro por lo que no quiero que las tengasn en cuenta. Puedes parar de leerlo aqui.

---

- Si un paquete de choco entra en conflicto por estar en un "Despliegue de choco" de tipo Agentes, y un despliegue de choco de tipo "Grupo", tendrá preferencia el tipo grupo.
> Si aún así hay un paquete que para un agente entra en conflicto porque está en dos "Despliegues de Choco" tipo Grupo, vamos a implementar el OrderId para el despliegue de este tipo, que será numérico, y desde 0 hacia arriba, hasta el máximo que admita un tipo integer. A la hora de desempatar, el que tenga el numero menor será el elegido. Si aún así hay un empate, pues se elige el primero que se creó.

- Quiero ir preparando en un alarde transparencia, que se cree un TrayIcon en la bandeja de la barra de inicio, con un menú de opciones que por ahora será "Resincronizar" , que lanzaría un pswm iterate a demanda , mientras haya una iteracion en curso esta opcion estará deshabilitada (Greyedout) ,y "Salir" que lo que haces es cerrar el tray y parar el servicio, hasta que el equipo vuelva a ser reiniciado.
> Para todo esto si no lo tienes claro como sería mejor puedes consultarme.

- Implementar banderitas de paises de origen
- Settings del agente desde la consola