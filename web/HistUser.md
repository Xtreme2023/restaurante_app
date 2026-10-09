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
