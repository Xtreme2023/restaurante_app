# Documentación del Esquema de Base de Datos - Supabase

Este documento describe la arquitectura de base de datos en Supabase para el sistema de gestión del comedor institucional y reservas.

## Conexión con Supabase
- **URL**: `https://qnieqczrdyxyhpepjduj.supabase.co`
- **Anon Key**: `sb_publishable_s7ww56WzXyW76KlH-cqvfQ_SgdpLsX7`

### Cuentas de prueba y perfiles

El inicio de sesión remoto usa Supabase Auth. Para que una cuenta de prueba
guarde y lea datos reales:

1. Activa `Authentication > Providers > Email` en Supabase.
2. Crea la cuenta en `Authentication > Users` (por ejemplo,
   `cocina2@uab.edu.bo`) y confirma el correo.
3. Usa el UUID de esa cuenta como `id` en `public.usuarios` o
   `public.profiles`; el correo debe coincidir.
4. Define el rol como `COCINA` en `usuarios.rol` o `cocina` en `profiles.role`.

Para cuentas Auth que ya existían antes de instalar los perfiles, ejecuta
`supabase/migrations/20261023_sync_auth_test_users.sql`. El script no crea
cuentas ni contraseñas: copia las cuentas existentes de `auth.users` a
`public.profiles`, por lo que después serán visibles para la aplicación.

Las cuentas nuevas se registran con `signUp`, quedan pendientes de confirmación
si el proveedor Email exige confirmación y reciben un correo de Supabase. La
aplicación solo permite el acceso después de que el usuario confirme su correo.

Si aparece `over_email_send_rate_limit` o HTTP 429 al registrar empleados,
Supabase limitó temporalmente el envío de correos de confirmación. Espera unos
minutos y reintenta; para uso continuo configura un proveedor SMTP propio en
`Authentication > SMTP Settings`. El intento rechazado no guarda el empleado.

### Registro administrativo sin límite de correos

El formulario de administración usa la Edge Function
`supabase/functions/create-employee/index.ts`. Debes desplegarla desde la raíz
del proyecto:

```bash
supabase functions deploy create-employee
```

La función usa `SUPABASE_SERVICE_ROLE_KEY` solo en el servidor, crea la cuenta
confirmada y guarda el empleado y sus familiares sin enviar un correo de
confirmación por cada alta. La contraseña inicial debe entregarse al empleado
por un canal seguro y luego puede cambiarla desde su perfil. Nunca pongas la
clave `service_role` dentro de Flutter.

La política de `public.familiares` permite insertar, actualizar y eliminar
únicamente a un administrador autenticado. Los empleados solo pueden leer sus
familiares asociados para hacer reservas; no pueden registrarlos ni
modificarlos.

La aplicación primero busca el perfil por el UUID de Auth y luego por correo en
ambas tablas. Si no encuentra un perfil, muestra un error en lugar de crear un
usuario local, para evitar que reservas y permisos queden desconectados de
Supabase.

Ejemplo para completar el perfil de una cuenta ya creada en Auth:

```sql
INSERT INTO public.profiles (id, email, full_name, role)
SELECT id, email, 'Cocina 2', 'cocina'
FROM auth.users
WHERE lower(email) = 'cocina2@uab.edu.bo'
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role;
```

---

## Tarifas Fijas del Sistema
1. **15 Bs** para comensales bajo **Plan Mensual** (empleado o familiar asociado).
2. **18 Bs** para comensales particulares / sin plan mensual registrado.

---

## Esquema DDL de Tablas Principales

```sql
-- 1. Usuarios y Empleados
CREATE TABLE public.usuarios (  
  id uuid NOT NULL,  
  ci text NOT NULL UNIQUE,  
  nombres text NOT NULL CHECK (btrim(nombres) <> ''::text),  
  apellidos text NOT NULL CHECK (btrim(apellidos) <> ''::text),  
  email text NOT NULL UNIQUE CHECK (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text),  
  employee_code text UNIQUE,
  telefono text,  
  departamento text NOT NULL DEFAULT 'Administración General',
  has_monthly_plan boolean NOT NULL DEFAULT true,
  rol USER-DEFINED NOT NULL DEFAULT 'EMPLEADO'::rol_usuario,  
  activo boolean NOT NULL DEFAULT true,  
  creado_en timestamp with time zone NOT NULL DEFAULT now(),  
  CONSTRAINT usuarios_pkey PRIMARY KEY (id),  
  -- El padrón puede contener empleados sin cuenta de acceso en auth.users.
);  

-- 2. Familiares asociados a un Empleado (Hasta 3 familiares por empleado)
CREATE TABLE public.familiares (  
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,  
  empleado_id uuid NOT NULL,  
  ci text NOT NULL,  
  nombres text NOT NULL CHECK (btrim(nombres) <> ''::text),  
  apellidos text NOT NULL CHECK (btrim(apellidos) <> ''::text),  
  parentesco USER-DEFINED NOT NULL,  
  activo boolean NOT NULL DEFAULT true,  
  creado_en timestamp with time zone NOT NULL DEFAULT now(),  
  CONSTRAINT familiares_pkey PRIMARY KEY (id),  
  CONSTRAINT familiares_empleado_id_fkey FOREIGN KEY (empleado_id) REFERENCES public.usuarios(id)  
);  

-- 3. Catálogo de Gastronomía Boliviana
CREATE TABLE public.platos_catalogo (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  nombre text NOT NULL UNIQUE CHECK (btrim(nombre) <> ''),
  descripcion text,
  categoria text NOT NULL DEFAULT 'Segundo', -- Entrada, Sopa, Segundo, Vegetariano, Especial, Postre
  region text,                               -- Cochabamba, Santa Cruz, La Paz, Tarija, Chuquisaca, etc.
  precio numeric NOT NULL DEFAULT 18.00 CHECK (precio >= 0),
  imagen_url text,
  activo boolean NOT NULL DEFAULT true,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT platos_catalogo_pkey PRIMARY KEY (id)
);

-- 4. Menú Semanal (Planificado por Cocina)
CREATE TABLE public.menu_semanal (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  fecha date NOT NULL,
  dia_semana text NOT NULL, -- 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'
  plato_catalogo_id bigint NOT NULL,
  tipo_plato text NOT NULL DEFAULT 'Segundo',
  estado text NOT NULL DEFAULT 'borrador' CHECK (estado IN ('borrador', 'publicado')),
  creado_por uuid,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT menu_semanal_pkey PRIMARY KEY (id),
  CONSTRAINT menu_semanal_plato_catalogo_id_fkey FOREIGN KEY (plato_catalogo_id) REFERENCES public.platos_catalogo(id) ON DELETE CASCADE,
  CONSTRAINT menu_semanal_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id)
);

-- 5. Suscripciones / Membresías a Plan Mensual
CREATE TABLE public.suscripciones (  
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,  
  empleado_id uuid NOT NULL,  
  mes date NOT NULL CHECK (mes = date_trunc('month'::text, mes::timestamp with time zone)::date),  
  modalidad USER-DEFINED NOT NULL,  
  vegetariano boolean NOT NULL DEFAULT false,  
  activo boolean NOT NULL DEFAULT true,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),  
  CONSTRAINT suscripciones_pkey PRIMARY KEY (id),  
  CONSTRAINT suscripciones_empleado_id_fkey FOREIGN KEY (empleado_id) REFERENCES public.usuarios(id)  
);  

-- 6. Reservas de Almuerzo del día (Empleado o Familiar)
CREATE TABLE public.reservas (  
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,  
  empleado_id uuid NOT NULL,  
  familiar_id bigint,  
  employee_code text,
  fecha date NOT NULL,  
  dish_name text,
  entrada_nombre text,
  ensalada_nombre text,
  plato_principal text,
  sopa_nombre text,
  es_almuerzo_completo boolean NOT NULL DEFAULT true,
  menu_category text NOT NULL DEFAULT 'almuerzo_completo'
    CHECK (menu_category IN ('almuerzo_completo', 'menu_vegetariano', 'plato_especial')),
  estado USER-DEFINED NOT NULL DEFAULT 'ACTIVA'::estado_reserva,  
  tipo_tarifa text NOT NULL DEFAULT 'PARTICULAR' CHECK (tipo_tarifa IN ('PLAN_MENSUAL', 'PARTICULAR')),  
  precio numeric NOT NULL DEFAULT 18.00 CHECK (precio >= 0),  
  cantidad integer NOT NULL DEFAULT 1 CHECK (cantidad > 0),
  vegetariano boolean NOT NULL DEFAULT false,  
  notas text,  
  creado_en timestamp with time zone NOT NULL DEFAULT now(),  
  cancelado_en timestamp with time zone,  
  CONSTRAINT reservas_pkey PRIMARY KEY (id),  
  CONSTRAINT reservas_empleado_id_fkey FOREIGN KEY (empleado_id) REFERENCES public.usuarios(id),  
  CONSTRAINT reservas_familiar_id_fkey FOREIGN KEY (familiar_id) REFERENCES public.familiares(id)  
);  

-- 7. Tarifas y Acuerdos
CREATE TABLE public.tarifas (  
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,  
  tipo USER-DEFINED NOT NULL,  
  consumidor USER-DEFINED NOT NULL,  
  precio numeric NOT NULL CHECK (precio >= 0::numeric),  
  vigente_desde date NOT NULL,  
  vigente_hasta date,  
  CONSTRAINT tarifas_pkey PRIMARY KEY (id)  
);  

-- 8. Calendario institucional y feriados
CREATE TABLE public.calendario (  
  fecha date NOT NULL,  
  habilitado boolean NOT NULL,  
  motivo text,  
  CONSTRAINT calendario_pkey PRIMARY KEY (fecha)  
);  
```

---

## Políticas de Seguridad (RLS) y Acceso Público

Para que la aplicación pueda cargar el menú y las imágenes directamente desde Supabase con la clave pública (`anon`), ejecuta el script:
`supabase/migrations/20261020_grant_public_menu_and_images.sql` en el SQL Editor de Supabase:
- Otorga permisos `GRANT SELECT` a `anon` y `authenticated` en el esquema público.
- Habilita las políticas RLS de lectura pública para `platos`, `menu_dias`, `menu_dia_platos`, `platos_catalogo` y `menu_semanal`.
- Ejecuta `NOTIFY pgrst, 'reload schema'` para que PostgREST actualice su caché y no devuelva el error `42501 permission denied`.

Para permitir que el administrador registre empleados desde la aplicación,
ejecuta la migración
`supabase/migrations/20261018_admin_employee_rls.sql` en el SQL Editor de
Supabase. Esta migración habilita las operaciones administrativas sobre
`usuarios` y `familiares` y elimina la dependencia de `usuarios.id` respecto
de `auth.users(id)`.

Para habilitar la persistencia del combo **Almuerzo del día** (Plato Principal + Sopa Boliviana), ejecuta la migración:
`supabase/migrations/20261023_almuerzo_completo_combo.sql` en el SQL Editor de Supabase:
- Agrega las columnas `dish_name`, `plato_principal`, `sopa_nombre` y `es_almuerzo_completo` a las tablas `reservations` y `reservas`.
- Asegura la existencia de las sopas tradicionales de la gastronomía boliviana en `platos_catalogo`.
- Ejecuta `NOTIFY pgrst, 'reload schema'` para refrescar la API de Supabase.

Si el registro de familiares falla con `invalid input value for enum
parentesco`, ejecuta `supabase/migrations/20261023_fix_parentesco_type.sql`.
La migración conserva los valores existentes y cambia la columna a texto para
que no dependa de un enum distinto entre ambientes.

1. **`platos_catalogo`**:
   - Lectura pública para cualquier usuario institucional autenticado.
   - Creación, actualización y desactivación restringida a roles `ADMIN` y `COCINA`.
2. **`menu_semanal`**:
   - Los empleados solo tienen acceso de lectura si el estado es `'publicado'`.
   - El personal de `COCINA` y `ADMIN` pueden consultar y modificar en estado `'borrador'` y publicar el menú.
3. **`reservas`**:
   - Cada empleado puede ver, registrar y cancelar sus propias reservas y las de sus familiares vinculados.
   - La cocina y los administradores tienen acceso global para auditar y marcar entregas.

---

## Códigos de retiro (QR) y canje en el servidor

Ejecuta `supabase/migrations/20261026_pickup_codes_rpc.sql` en el SQL Editor:
- Agrega `reservations.pickup_code` y `reservas.codigo_retiro` (únicos, con
  código aleatorio por defecto) y completa las filas existentes.
- Crea `tickets_plan_mensual` para los almuerzos diarios del Plan Mensual.
- RPC `canjear_codigo_retiro(p_codigo, p_ignorar_horario)`: solo
  administradores; devuelve `entregada`, `cancelada`, `ya_entregada`,
  `otra_fecha`, `fuera_de_horario` o `no_encontrado`.
- RPC `obtener_ticket_plan_mensual(p_fecha)` y
  `cancelar_ticket_plan_mensual(p_fecha)` para el empleado con Plan Mensual.
- La hora de servicio se evalúa en `America/La_Paz`.

## Recursos Multimedia del Menú (`platos`)

Para vincular las imágenes estáticas locales a los platos del menú institucional, ejecuta el script `supabase/migrations/update_imagenes_platos.sql` en el SQL Editor de Supabase:
- Agrega la columna `imagen_path TEXT` a la tabla `public.platos`.
- Actualiza los 11 platos precargados (IDs del 1 al 11) asignando los nombres de archivo (`01_silpancho.jpg` hasta `11_tortilla_de_verduras.jpg`).
- Los archivos de imagen se encuentran empaquetados en `assets/images/` y registrados en `pubspec.yaml`.

## Platos Preestablecidos de Gastronomía Boliviana
- Silpancho Cochabambino
- Pique Macho Especial
- Majadito Cruceño con Huevo y Plátano
- Sopa de Maní Tradicional
- Falso Conejo
- Saice Tarijeño
- Chairo Paceño
- Picante Mixto
- Mondongo Chuquisaqueño
- Trucha del Titicaca al Limón
- Ají de Papalisa
- Pastel de Fideo Tradicional