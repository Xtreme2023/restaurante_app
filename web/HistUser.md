HU1-Login — Iniciar sesión en el sistema

-        Como usuario (Empleado, Encargado o Institución)

-        Quiero iniciar sesión con mi cuenta

-        Para acceder a las funciones que me corresponden según mi rol.

Criterios de aceptación:

-        Caso éxito: Dado que el usuario ingresa su cuenta correspondiente, cuando confirma, entonces el sistema le permite acceder.

-        Caso error: Dado que el usuario ingresa credenciales inválidas, cuando confirma(duda), entonces el sistema rechaza el acceso y muestra un mensaje de error.

- Caso restricción: Dado que el usuario no pertenezca a la institución, cuando intenta iniciar sesión, entonces el sistema rechaza el acceso.

HU2 — Administrar cuenta

-        Como usuario (Empleado, Encargado o Institución)

-        Quiero administrar mi cuenta (actualizar datos personales, cambiar contraseña, activar)

-        Para mantener mi información segura y personalizada según mis necesidades.

Criterios de aceptación:

-        Caso éxito: Dado que el usuario ingresa datos válidos, cuando guarda cambios, entonces el sistema actualiza su perfil correctamente.

-        Caso error: Dado que el usuario ingresa datos inválidos (ej. correo sin formato correcto espacios en blanco obligatorios), cuando confirma, entonces el sistema rechaza la acción y muestra un mensaje con el error para que éste lo corrija.

-        Caso contraseña: Dado que el usuario solicita cambiar su contraseña, cuando confirma, entonces el sistema actualiza la clave y envía notificación de seguridad

HU3 — Registro de nuevos integrantes

-        Como administrador del sistema

-        Quiero registrar nuevas cuentas de usuario asignándoles un rol (Empleado, Encargado, Institución)

-        Para que puedan acceder al sistema y usar las funciones correspondientes.

Criterios de aceptación:

-        Caso éxito: Dado que el administrador completa el formulario con datos válidos y rol asignado, cuando guarda, entonces la cuenta queda creada y el usuario puede iniciar sesión.

-        Caso error: Dado que el administrador intenta crear una cuenta sin rol, cuando la guarda, entonces el sistema rechaza la acción y solicita asignar un rol.
-     Caso duplicado: Dado que el administrador intenta registrar un usuario con CI ya
       existente, cuando guarda, entonces el sistema rechaza la acción.

HU4 — Dar de baja usuarios

-        Como administrador del sistema

-        Quiero desactivar cuentas de usuario que ya no pertenecen a la institución

-        Para impedir que accedan al sistema aunque tengan una cuenta Válida.

HU5 — Creación y Visualización del menú

-        Como empleado

-        Quiero visualizar el menú creado del día por el administrador con anticipación

-        Para decidir mi reserva con tiempo.

Criterios de aceptación:

-        Caso éxito: Dado que el sistema tiene cargado el menú de toda la semana, cuando llega la hora y fecha configurada, entonces el empleado puede visualizar el menú disponible.

-        Caso actualización: Dado que llega la hora configurada, cuando el reloj pasa dicha hora, entonces el sistema actualiza automáticamente el menú de la semana y el empleado puede consultarlo.

-        Caso error: Dado que el menú no está cargado, cuando el empleado intenta visualizarlo, entonces el sistema muestra un mensaje de “menú no disponible”.

-        Caso restricción: Dado que el menú solo puede visualizarse hasta cierta fecha y hora (ej. 08:30 Viernes), cuando el empleado intenta acceder después de esa fecha y hora, entonces el sistema bloquea la visualización y muestra un mensaje de “fuera de horario”.

HU6 — Preferencias de menú

-        Como empleado

-        Quiero marcar platos del menú como favoritos

-        Para que el sistema guarde mis preferencias y me sugiera opciones en futuras reservas.

Criterios de aceptación:

-        Caso éxito: Dado que el empleado selecciona un plato como favorito, cuando confirma, entonces el sistema guarda esa preferencia en su perfil.

-        Caso sugerencia: Dado que el empleado consulta el menú de otra fecha, cuando el sistema carga opciones, entonces muestra primero los platos marcados como favoritos.

-        Caso actualización: Dado que el empleado cambia sus preferencias, cuando elimina o agrega favoritos, entonces el sistema actualiza su perfil correctamente.

HU7 — Control de días de atención disponibles

-        Como empleado

-        Quiero visualizar los días en que el restaurante ofrece servicio

-        Para reservar únicamente en fechas válidas.

Criterios de aceptación:

-        Caso éxito: Dado que el calendario está configurado, cuando intenta reservar en día habilitado, entonces el sistema confirma.

-        Caso error: Dado que intenta reservar en día no habilitado, cuando solicita, entonces el sistema rechaza y muestra mensaje de disponibilidad.

-        Caso error: Dado que el dia es feriado por motivos desconocidos para el sistema o la planificación el sistema rechaza las reservas de ese día.
