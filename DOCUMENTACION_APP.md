# Restaurante App - Resumen funcional y reglas de negocio

## 1. Objetivo de la aplicación

Aplicación Flutter para administrar el comedor institucional, publicar el menú
boliviano, registrar reservas de almuerzo, gestionar empleados y familiares,
controlar la entrega de pedidos y administrar la modalidad de consumo.

La aplicación utiliza Flutter, Riverpod y Supabase. Cuando Supabase no está
disponible, existen datos y sesiones de demostración para continuar con el
desarrollo visual y las pruebas locales.

## 2. Inicio de la aplicación y navegación por roles

El punto de entrada es [`lib/main.dart`](lib/main.dart).

Al iniciar:

1. Se inicializa Supabase.
2. Se consulta el usuario actual mediante `authProvider`.
3. Se selecciona la pantalla principal según el rol:

| Rol | Shell o pantalla principal |
|---|---|
| Sin sesión | [`LoginScreen`](lib/features/auth/presentation/login_screen.dart) |
| Empleado | [`MainLayout`](lib/core/layout/main_layout.dart) |
| Administrador o institución | [`AdminShell`](lib/core/layout/admin_shell.dart) |

Ya no existe una pantalla propia para cocina/encargado: sus funciones están en
la pestaña **Cocina** del Panel Administrador. Un perfil heredado con rol
`cocina` o `encargado` ingresa como empleado.

El modelo de usuario se encuentra en
[`UserProfile`](lib/features/auth/domain/user_profile.dart). Los perfiles
remotos aceptan los campos `has_monthly_plan`, `hasMonthlyPlan`,
`is_pensioner` e `isPensioner`.

## 3. Pantallas del empleado

La navegación del empleado está definida en
[`MainLayout`](lib/core/layout/main_layout.dart) y contiene cinco secciones:

### Menú

Archivo: [`menu_screen.dart`](lib/features/menu/presentation/menu_screen.dart)

- Muestra el menú del día.
- Presenta almuerzos completos, platos especiales, vegetarianos y postre.
- El resumen de menú diario es desplegable.
- Muestra el usuario activo en el encabezado.
- Muestra imágenes, descripción y categoría de cada plato.
- Permite actualizar el menú y cerrar sesión.
- Permite ir directamente a Reservas desde un almuerzo.

### Reservas

Archivo: [`employee_screen.dart`](lib/features/reservas/presentation/employee_screen.dart)

- Muestra el nombre, correo y código del usuario activo.
- Permite seleccionar fecha y categoría de menú.
- Permite seleccionar:
  - Almuerzo del día.
  - Menú vegetariano.
  - Plato especial.
- El almuerzo completo incluye entrada/ensalada, sopa y segundo.
- Permite reservar para el empleado y para familiares.
- Tiene modo de reserva individual y conjunta.
- Muestra el resumen de comensales y el costo total.
- Permite agregar notas a la reserva.

### Calendario

Archivo: [`calendar_screen.dart`](lib/features/reservas/presentation/calendar_screen.dart)

- Permite consultar fechas disponibles.
- Permite seleccionar beneficiario: empleado o familiar.
- Permite seleccionar categoría de plato.
- Usa las reglas de reserva y feriados.

### Tickets

Archivo: [`my_reservations_screen.dart`](lib/features/reservas/presentation/my_reservations_screen.dart)

- Separa reservas próximas e históricas.
- Muestra estado, modalidad, precio y beneficiario.
- Permite cancelar cuando la política lo autoriza.
- Muestra el código de retiro asociado a la reserva.

### Perfil

Archivo: [`profile_screen.dart`](lib/features/auth/presentation/profile_screen.dart)

- Muestra los datos del usuario.
- Permite actualizar la contraseña.
- Muestra la modalidad mensual o diaria.
- Permite cerrar sesión.

## 4. Pantallas administrativas

### Panel administrador

Archivo: [`admin_screen.dart`](lib/features/admin/presentation/admin_screen.dart)

Incluye pestañas para:

1. **Empleados y familiares**
   - Listar empleados.
   - Buscar empleados.
   - Ver familiares asociados.
   - Registrar empleados.
   - Activar o desactivar el Plan Mensual.
   - Visualizar tarifa aplicable.

2. **Membresías**
   - Filtrar empleados con Plan Mensual.
   - Filtrar empleados con modalidad diaria.
   - Consultar cantidades y tarifas.

3. **Cocina** (ver sección siguiente)

4. **Auditoría**
   - Mostrar indicadores institucionales y distribución de consumo.

5. **Solicitudes**
   - Consultar solicitudes de reinicio de contraseña.
   - Atender solicitudes desde el panel.

Las pestañas usan desplazamiento horizontal para evitar que los títulos se
corten en pantallas pequeñas.

### Pestaña Cocina (dentro del Panel Administrador)

Archivo: [`kitchen_panel.dart`](lib/features/admin/presentation/kitchen_panel.dart)

Widget `KitchenPanel`, embebido como pestaña de `AdminScreen`. Tiene sus
propias subpestañas:

1. **Resumen y totales**
   - Total de pedidos.
   - Pedidos pendientes.
   - Pedidos entregados.
   - Cobro total.
   - Distribución por plato y empleado.

2. **Plan mensual**
   - Reservas de empleados con Plan Mensual.
   - Precio normalizado de Bs. 15.

3. **Empleados regulares**
   - Reservas sin Plan Mensual.
   - Precio normalizado de Bs. 18.

4. **Menú semanal**
   - Planificación de platos por día.
   - Publicación del menú para los empleados.

5. **Calendario**
   - Consulta de reservas por fecha.

También permite verificar códigos de retiro mediante texto, lector USB o cámara.

### Bloqueo de inicio de sesión

Regla en [`login_attempt_policy.dart`](lib/features/auth/domain/login_attempt_policy.dart).

- Después de 3 intentos fallidos con el mismo correo, el login se bloquea.
- Se muestra el mensaje: "Ponte en contacto con el administrador".
- Antes del bloqueo se indican los intentos restantes.
- Un ingreso correcto reinicia el contador.
- Solo cuentan credenciales incorrectas, no errores de configuración.
- El contador vive en memoria de la app: se reinicia al cerrarla.

## 5. Reglas de tarifas

Las tarifas están centralizadas en
[`UserProfile`](lib/features/auth/domain/user_profile.dart):

```dart
UserProfile.monthlyMealPrice // Bs. 15
UserProfile.dailyMealPrice   // Bs. 18
```

La propiedad `mealPrice` calcula el valor:

| Condición | Tarifa |
|---|---:|
| Empleado o familiar bajo Plan Mensual | Bs. 15 |
| Empleado o familiar sin Plan Mensual | Bs. 18 |

La pantalla del menú, la pantalla de reservas y cocina deben usar esta regla.
No se debe tomar `combo.precio` como tarifa final del usuario, porque ese
valor representa el precio base del plato o de datos antiguos.

## 6. Reglas de reservas

Las reglas se encuentran en
[`reservation_policy.dart`](lib/features/reservas/domain/usecases/reservation_policy.dart).

### Crear una reserva

- No se permiten fechas pasadas.
- No hay servicio sábado ni domingo.
- No se permiten feriados institucionales.
- Para reservar el mismo día, el límite es las 09:00.
- A las 09:00 todavía se permite reservar.
- Desde las 09:01 la reserva del mismo día queda cerrada.

### Cancelar una reserva

- No se pueden cancelar reservas de fechas pasadas.
- Para el mismo día, la cancelación solo es posible antes de las 09:00.
- Desde las 09:00 la cancelación queda bloqueada.
- El plazo se valida con la hora real **al confirmar** la cancelación
  (`clockProvider`), no con la hora en que se abrió la pantalla: abierta a
  las 8:57 y confirmada a las 9:03 se rechaza.
- En Supabase, el trigger `validar_plazo_cancelacion` y la RPC
  `cancelar_ticket_plan_mensual` aplican la misma regla en hora de Bolivia
  (`supabase/migrations/20261027_cancel_deadline.sql`), aunque se cambie la
  hora del teléfono. Administración está exenta.

### Entrega

- Solo se puede registrar el día de la reserva.
- El horario de entrega es de 12:00 a 14:00.
- Fuera de ese horario la entrega se rechaza.
- Cada reserva tiene un código de retiro aleatorio y único (ej. `A3F9-0C7E`),
  también para cada familiar. Se genera en la app al reservar y se guarda en
  `reservations.pickup_code` / `reservas.codigo_retiro`.
- El Plan Mensual usa `tickets_plan_mensual`: el código se crea al abrir el
  ticket (RPC `obtener_ticket_plan_mensual`) y se cancela con
  `cancelar_ticket_plan_mensual`.
- Cocina canjea con la RPC `canjear_codigo_retiro`: solo administradores,
  valida estado, fecha y horario y marca la entrega en una sola operación.
  Sin servidor, se valida localmente con `ReservationPolicy.resolvePickupCode`.
- Requiere ejecutar `supabase/migrations/20261026_pickup_codes_rpc.sql`.
- Solo una reserva `confirmada` habilita el QR. Al cancelarla, el QR queda
  anulado: el empleado ya no puede abrir el ticket ("QR anulado") y cocina
  rechaza el código (`ReservationPolicy.resolvePickupCode`).
- Al verificar un QR, cocina vuelve a consultar las reservas del día para
  detectar cancelaciones recientes.

### Modo demostración

- Solo el administrador lo activa, con el ícono de matraz del Panel
  Administrador y una confirmación previa.
- Ignora los horarios: 09:00 para reservar o cancelar el mismo día y
  12:00–14:00 para entregar.
- Mantiene las demás reglas: fechas pasadas, fines de semana, feriados y
  entrega solo el día de la reserva.
- Muestra la cinta "DEMO" en todas las pantallas.
- No se guarda: se apaga al cerrar la app. Las acciones sí se guardan como
  reales, así que conviene usarlo con cuentas de prueba.

Las reservas se representan mediante
[`Reservation`](lib/features/reservas/domain/reservation_entity.dart) y se
guardan mediante [`ReservationRepository`](lib/features/reservas/domain/reservation_repository.dart).

## 7. Reglas del menú

Las reglas están en
[`daily_menu_policy.dart`](lib/features/menu/domain/daily_menu_policy.dart).

Un menú diario puede contener:

- Almuerzo completo: entrada, sopa y segundo.
- Una opción vegetariana.
- Una opción especial.
- Postre únicamente los jueves.

El menú semanal se administra con
[`weekly_menu_provider.dart`](lib/features/menu/presentation/providers/weekly_menu_provider.dart)
y los repositorios de menú ubicados en
[`lib/features/menu/data/`](lib/features/menu/data/).

## 8. Familiares

Las reglas están en
[`family_policy.dart`](lib/features/familiares/domain/family_policy.dart).

- Cada empleado puede tener hasta tres familiares activos.
- Solo se consideran familiares activos.
- Un familiar debe estar vinculado al empleado.
- Las reservas familiares se guardan con `familiar_id`.
- La reserva conjunta puede incluir al empleado y uno o más familiares.

Los proveedores están en
[`family_providers.dart`](lib/features/familiares/presentation/providers/family_providers.dart).

## 9. Persistencia y Supabase

La configuración está en [`supabase_config.dart`](lib/core/config/supabase_config.dart).

Los principales repositorios son:

- [`supabase_auth_repository.dart`](lib/features/auth/data/supabase_auth_repository.dart)
  - Autenticación.
  - Perfil del usuario.
  - Recuperación de contraseña.

- [`supabase_reservation_repository.dart`](lib/features/reservas/data/supabase_reservation_repository.dart)
  - Reservas.
  - Estados.
  - Códigos de retiro.
  - Feriados.

- [`supabase_admin_repository.dart`](lib/features/admin/data/supabase_admin_repository.dart)
  - Empleados.
  - Familiares.
  - Plan Mensual.
  - Solicitudes administrativas.

- [`supabase_menu_repository.dart`](lib/features/menu/data/supabase_menu_repository.dart)
  - Menú diario.
  - Catálogo de platos.
  - Favoritos.

La documentación del esquema se encuentra en [`lib/db.md`](lib/db.md) y
[`supabase_schema.sql`](supabase_schema.sql).

## 10. Pruebas

Las pruebas existentes están en [`test/`](test/).

### Pruebas funcionales de tarifas

La carpeta [`test/pruebas_funcion/`](test/pruebas_funcion/) contiene pruebas
para:

- Plan Mensual: Bs. 15.
- Modalidad diaria: Bs. 18.
- Conversión del perfil cargado desde Supabase.

Ejecutar solo esas pruebas:

```bash
flutter test test/pruebas_funcion
```

Ejecutar una prueba específica:

```bash
flutter test test/pruebas_funcion/prueba_1_tarifa_empleado_test.dart
```

Ejecutar toda la suite:

```bash
flutter test
```

## 11. Convenciones importantes para futuros cambios

1. Usar `authProvider` para obtener el usuario activo.
2. Usar `UserProfile.mealPrice` para calcular tarifas.
3. No duplicar los valores 15 y 18 en nuevas pantallas.
4. Usar `ReservationPolicy` para fechas, cancelaciones y entregas.
5. Usar `DailyMenuPolicy` para validar la estructura del menú.
6. Mantener los repositorios separados de las pantallas.
7. Agregar una prueba cuando cambie una regla de negocio.
8. Verificar pantallas pequeñas para evitar overflow en `Row`, `TabBar` y
   `ListTile`.

## 12. Flujo principal de uso

```text
Inicio de aplicación
        |
        v
Inicio de sesión
        |
        v
Carga de perfil y rol
        |
        +--> Empleado
        |       |
        |       +--> Consulta menú
        |       +--> Selecciona plato y fecha
        |       +--> Agrega familiares
        |       +--> Confirma reserva
        |       +--> Consulta ticket y código de retiro
        |
        +--> Administrador
                |
                +--> Gestiona empleados y membresías
                +--> Atiende solicitudes
                +--> Consulta auditoría
                +--> Cocina: consulta pedidos
                +--> Publica menú semanal
                +--> Registra entregas
                +--> Controla códigos de retiro
```
