-- =====================================================================
-- Script único para el SQL Editor de Supabase: códigos QR de retiro,
-- plazo de cancelación y modo de prueba. Es idempotente: se puede volver
-- a ejecutar sin romper nada.
--
-- Incluye, en orden: columnas faltantes de reservas, 20261025, 20261026,
-- 20261027 y 20261028. Al final hay consultas de diagnóstico.
--
-- ANTES DE EJECUTAR: cambia el filtro del paso 0.2 por el correo del
-- empleado de prueba.
-- =====================================================================

-- 0.1 Columnas y estados que la app envía al guardar en public.reservas.
DO $$
BEGIN
  IF to_regclass('public.reservas') IS NOT NULL THEN
    ALTER TABLE public.reservas
      ADD COLUMN IF NOT EXISTS tipo_tarifa TEXT NOT NULL DEFAULT 'PARTICULAR',
      ADD COLUMN IF NOT EXISTS precio NUMERIC NOT NULL DEFAULT 18.00,
      ADD COLUMN IF NOT EXISTS notas TEXT,
      ADD COLUMN IF NOT EXISTS employee_code TEXT;
  END IF;
  IF to_regtype('public.estado_reserva') IS NOT NULL THEN
    EXECUTE 'ALTER TYPE public.estado_reserva ADD VALUE IF NOT EXISTS ''CONFIRMADA''';
  END IF;
END $$;

-- ===================== 20261025_reservation_pickup_quantity.sql =====================
-- Permite que un empleado con plan mensual ajuste los almuerzos de su reserva
-- y que cocina pueda identificar el ticket diario sin exponer el UUID interno.
DO $$
BEGIN
  IF to_regclass('public.reservations') IS NOT NULL THEN
    ALTER TABLE public.reservations
      ADD COLUMN IF NOT EXISTS quantity INT NOT NULL DEFAULT 1
        CHECK (quantity > 0);
  END IF;

  IF to_regclass('public.reservas') IS NOT NULL THEN
    ALTER TABLE public.reservas
      ADD COLUMN IF NOT EXISTS cantidad INT NOT NULL DEFAULT 1
        CHECK (cantidad > 0);
  END IF;
END $$;

-- ===================== 20261026_pickup_codes_rpc.sql =====================
-- Códigos de retiro (QR) únicos por reserva, validados en el servidor.
--
-- Antes el QR era EMP-042_MARTES_2026-10-27: predecible y compartido entre el
-- empleado y sus familiares. Ahora cada reserva tiene un código aleatorio
-- (ej. A3F9-0C7E) y el canje se hace con la RPC canjear_codigo_retiro, que
-- verifica estado, fecha y horario de forma atómica.
--
-- Las reservas del Plan Mensual no se guardaban (se generaban en la app); se
-- agrega tickets_plan_mensual para darles código y estado persistentes.

-- 1. Generador de códigos: 8 caracteres hexadecimales en mayúsculas.
CREATE OR REPLACE FUNCTION public.generar_codigo_retiro()
RETURNS text
LANGUAGE sql
VOLATILE
AS $$
  SELECT upper(
    substr(md5(gen_random_uuid()::text), 1, 4) || '-' ||
    substr(md5(gen_random_uuid()::text), 1, 4)
  );
$$;

-- 2. Estados usados por la app en el enum de la tabla reservas.
DO $$
BEGIN
  IF to_regtype('public.estado_reserva') IS NOT NULL THEN
    EXECUTE 'ALTER TYPE public.estado_reserva ADD VALUE IF NOT EXISTS ''CANCELADA''';
    EXECUTE 'ALTER TYPE public.estado_reserva ADD VALUE IF NOT EXISTS ''ENTREGADA''';
  END IF;
END $$;

-- 3. Columna de código en las tablas de reservas existentes.
DO $$
BEGIN
  IF to_regclass('public.reservations') IS NOT NULL THEN
    ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS pickup_code TEXT;
    UPDATE public.reservations
      SET pickup_code = public.generar_codigo_retiro()
      WHERE pickup_code IS NULL OR btrim(pickup_code) = '';
    ALTER TABLE public.reservations
      ALTER COLUMN pickup_code SET DEFAULT public.generar_codigo_retiro(),
      ALTER COLUMN pickup_code SET NOT NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS reservations_pickup_code_key
      ON public.reservations(pickup_code);
  END IF;

  IF to_regclass('public.reservas') IS NOT NULL THEN
    ALTER TABLE public.reservas ADD COLUMN IF NOT EXISTS codigo_retiro TEXT;
    UPDATE public.reservas
      SET codigo_retiro = public.generar_codigo_retiro()
      WHERE codigo_retiro IS NULL OR btrim(codigo_retiro) = '';
    ALTER TABLE public.reservas
      ALTER COLUMN codigo_retiro SET DEFAULT public.generar_codigo_retiro(),
      ALTER COLUMN codigo_retiro SET NOT NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS reservas_codigo_retiro_key
      ON public.reservas(codigo_retiro);
  END IF;
END $$;

-- 4. Tickets diarios del Plan Mensual.
CREATE TABLE IF NOT EXISTS public.tickets_plan_mensual (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empleado_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  fecha DATE NOT NULL,
  codigo_retiro TEXT NOT NULL UNIQUE DEFAULT public.generar_codigo_retiro(),
  estado TEXT NOT NULL DEFAULT 'confirmada'
    CHECK (estado IN ('confirmada', 'cancelada', 'entregada')),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tickets_plan_mensual_empleado_fecha_key UNIQUE (empleado_id, fecha)
);

ALTER TABLE public.tickets_plan_mensual ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Empleado ve sus tickets del plan" ON public.tickets_plan_mensual;
CREATE POLICY "Empleado ve sus tickets del plan" ON public.tickets_plan_mensual
  FOR SELECT TO authenticated
  USING (empleado_id = auth.uid() OR public.is_admin_actor());

-- Los empleados no escriben directamente: usan las RPC de abajo.
DROP POLICY IF EXISTS "Administración gestiona tickets del plan" ON public.tickets_plan_mensual;
CREATE POLICY "Administración gestiona tickets del plan" ON public.tickets_plan_mensual
  FOR ALL TO authenticated
  USING (public.is_admin_actor())
  WITH CHECK (public.is_admin_actor());

GRANT SELECT, INSERT, UPDATE ON public.tickets_plan_mensual TO authenticated;

-- 5. RPC: el empleado obtiene (o crea) su ticket del Plan Mensual del día.
CREATE OR REPLACE FUNCTION public.obtener_ticket_plan_mensual(p_fecha DATE)
RETURNS TABLE (codigo_retiro TEXT, estado TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id = v_uid AND u.has_monthly_plan = true AND u.activo = true
  ) THEN
    RAISE EXCEPTION 'El usuario no tiene Plan Mensual activo.'
      USING ERRCODE = '42501';
  END IF;
  IF extract(isodow FROM p_fecha) > 5 THEN
    RAISE EXCEPTION 'No hay servicio los fines de semana.';
  END IF;

  INSERT INTO public.tickets_plan_mensual (empleado_id, fecha)
  VALUES (v_uid, p_fecha)
  ON CONFLICT ON CONSTRAINT tickets_plan_mensual_empleado_fecha_key DO NOTHING;

  RETURN QUERY
    SELECT t.codigo_retiro, t.estado
    FROM public.tickets_plan_mensual t
    WHERE t.empleado_id = v_uid AND t.fecha = p_fecha;
END;
$$;

-- 6. RPC: el empleado cancela su almuerzo del Plan Mensual de un día.
CREATE OR REPLACE FUNCTION public.cancelar_ticket_plan_mensual(p_fecha DATE)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_hoy DATE := (now() AT TIME ZONE 'America/La_Paz')::date;
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id = v_uid AND u.has_monthly_plan = true
  ) THEN
    RAISE EXCEPTION 'El usuario no tiene Plan Mensual.' USING ERRCODE = '42501';
  END IF;
  IF p_fecha < v_hoy THEN
    RAISE EXCEPTION 'No se pueden cancelar almuerzos de fechas pasadas.';
  END IF;

  INSERT INTO public.tickets_plan_mensual AS t (empleado_id, fecha, estado)
  VALUES (v_uid, p_fecha, 'cancelada')
  ON CONFLICT ON CONSTRAINT tickets_plan_mensual_empleado_fecha_key
  DO UPDATE SET estado = 'cancelada', actualizado_en = now()
  WHERE t.estado = 'confirmada';
END;
$$;

-- 7. RPC: administración canjea un código de retiro.
--    p_ignorar_horario solo lo usa el modo demostración del administrador.
CREATE OR REPLACE FUNCTION public.canjear_codigo_retiro(
  p_codigo TEXT,
  p_ignorar_horario BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_codigo TEXT := upper(btrim(coalesce(p_codigo, '')));
  v_ahora TIMESTAMP := now() AT TIME ZONE 'America/La_Paz';
  v_tabla TEXT;
  v_id TEXT;
  v_fecha DATE;
  v_estado TEXT;
BEGIN
  IF NOT public.is_admin_actor() THEN
    RAISE EXCEPTION 'Solo administración puede registrar retiros.'
      USING ERRCODE = '42501';
  END IF;
  IF v_codigo = '' THEN
    RETURN jsonb_build_object('resultado', 'no_encontrado');
  END IF;

  IF to_regclass('public.reservations') IS NOT NULL THEN
    EXECUTE 'SELECT id::text, reservation_date, lower(status::text)
             FROM public.reservations WHERE pickup_code = $1 FOR UPDATE'
      INTO v_id, v_fecha, v_estado USING v_codigo;
    IF v_id IS NOT NULL THEN v_tabla := 'reservations'; END IF;
  END IF;

  IF v_tabla IS NULL AND to_regclass('public.reservas') IS NOT NULL THEN
    EXECUTE 'SELECT id::text, fecha, lower(estado::text)
             FROM public.reservas WHERE codigo_retiro = $1 FOR UPDATE'
      INTO v_id, v_fecha, v_estado USING v_codigo;
    IF v_id IS NOT NULL THEN v_tabla := 'reservas'; END IF;
  END IF;

  IF v_tabla IS NULL THEN
    SELECT t.id::text, t.fecha, t.estado INTO v_id, v_fecha, v_estado
    FROM public.tickets_plan_mensual t
    WHERE t.codigo_retiro = v_codigo
    FOR UPDATE;
    IF v_id IS NOT NULL THEN v_tabla := 'tickets_plan_mensual'; END IF;
  END IF;

  IF v_tabla IS NULL THEN
    RETURN jsonb_build_object('resultado', 'no_encontrado');
  ELSIF v_estado = 'cancelada' THEN
    RETURN jsonb_build_object('resultado', 'cancelada', 'id', v_id);
  ELSIF v_estado = 'entregada' THEN
    RETURN jsonb_build_object('resultado', 'ya_entregada', 'id', v_id);
  ELSIF v_fecha <> v_ahora::date THEN
    RETURN jsonb_build_object('resultado', 'otra_fecha', 'id', v_id);
  ELSIF NOT p_ignorar_horario
    AND (v_ahora::time < TIME '12:00' OR v_ahora::time >= TIME '14:00') THEN
    RETURN jsonb_build_object('resultado', 'fuera_de_horario', 'id', v_id);
  END IF;

  IF v_tabla = 'reservations' THEN
    EXECUTE 'UPDATE public.reservations SET status = ''entregada'' WHERE id::text = $1'
      USING v_id;
  ELSIF v_tabla = 'reservas' THEN
    EXECUTE 'UPDATE public.reservas SET estado = ''ENTREGADA'' WHERE id::text = $1'
      USING v_id;
  ELSE
    UPDATE public.tickets_plan_mensual
      SET estado = 'entregada', actualizado_en = now()
      WHERE id::text = v_id;
  END IF;

  RETURN jsonb_build_object('resultado', 'entregada', 'id', v_id, 'tabla', v_tabla);
END;
$$;

REVOKE ALL ON FUNCTION public.obtener_ticket_plan_mensual(DATE) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancelar_ticket_plan_mensual(DATE) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.canjear_codigo_retiro(TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obtener_ticket_plan_mensual(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_ticket_plan_mensual(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.canjear_codigo_retiro(TEXT, BOOLEAN) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ===================== 20261027_cancel_deadline.sql =====================
-- Plazo de cancelación validado en el servidor (hora de Bolivia).
--
-- La app valida el plazo con la hora del teléfono, que el usuario puede
-- cambiar. Este trigger aplica la misma regla en la base de datos:
--   * no se cancelan reservas de fechas pasadas;
--   * el mismo día, la cancelación cierra a las 09:00 (8:59 es el último
--     minuto permitido).
-- Administración queda exenta, y también los scripts sin sesión (SQL Editor).
-- El mensaje empieza con PLAZO_CANCELACION_VENCIDO para que la app lo reconozca.

-- Hora oficial del servicio. Centralizada para poder fijarla en pruebas.
CREATE OR REPLACE FUNCTION public.ahora_la_paz()
RETURNS TIMESTAMP
LANGUAGE sql
STABLE
AS $$ SELECT now() AT TIME ZONE 'America/La_Paz' $$;

CREATE OR REPLACE FUNCTION public.validar_plazo_cancelacion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ahora TIMESTAMP := public.ahora_la_paz();
  v_nuevo JSONB := to_jsonb(NEW);
  v_viejo JSONB := to_jsonb(OLD);
  v_fecha DATE := coalesce(v_nuevo ->> 'reservation_date', v_nuevo ->> 'fecha')::date;
  v_estado_nuevo TEXT := lower(coalesce(v_nuevo ->> 'status', v_nuevo ->> 'estado'));
  v_estado_viejo TEXT := lower(coalesce(v_viejo ->> 'status', v_viejo ->> 'estado'));
BEGIN
  IF v_estado_nuevo IS DISTINCT FROM 'cancelada'
    OR v_estado_viejo = 'cancelada'
    OR auth.uid() IS NULL
    OR public.is_admin_actor() THEN
    RETURN NEW;
  END IF;

  IF v_fecha < v_ahora::date THEN
    RAISE EXCEPTION 'PLAZO_CANCELACION_VENCIDO: no se pueden cancelar reservas de fechas pasadas.';
  END IF;
  IF v_fecha = v_ahora::date AND v_ahora::time >= TIME '09:00' THEN
    RAISE EXCEPTION 'PLAZO_CANCELACION_VENCIDO: el plazo para cancelar hoy venció a las 8:59.';
  END IF;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.reservations') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS reservations_plazo_cancelacion ON public.reservations;
    CREATE TRIGGER reservations_plazo_cancelacion
      BEFORE UPDATE ON public.reservations
      FOR EACH ROW EXECUTE FUNCTION public.validar_plazo_cancelacion();
  END IF;

  IF to_regclass('public.reservas') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS reservas_plazo_cancelacion ON public.reservas;
    CREATE TRIGGER reservas_plazo_cancelacion
      BEFORE UPDATE ON public.reservas
      FOR EACH ROW EXECUTE FUNCTION public.validar_plazo_cancelacion();
  END IF;
END $$;

-- El Plan Mensual se cancela por RPC: se le agrega el mismo plazo.
CREATE OR REPLACE FUNCTION public.cancelar_ticket_plan_mensual(p_fecha DATE)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_ahora TIMESTAMP := public.ahora_la_paz();
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.usuarios u
    WHERE u.id = v_uid AND u.has_monthly_plan = true
  ) THEN
    RAISE EXCEPTION 'El usuario no tiene Plan Mensual.' USING ERRCODE = '42501';
  END IF;
  IF p_fecha < v_ahora::date THEN
    RAISE EXCEPTION 'PLAZO_CANCELACION_VENCIDO: no se pueden cancelar almuerzos de fechas pasadas.';
  END IF;
  IF p_fecha = v_ahora::date AND v_ahora::time >= TIME '09:00' THEN
    RAISE EXCEPTION 'PLAZO_CANCELACION_VENCIDO: el plazo para cancelar hoy venció a las 8:59.';
  END IF;

  INSERT INTO public.tickets_plan_mensual AS t (empleado_id, fecha, estado)
  VALUES (v_uid, p_fecha, 'cancelada')
  ON CONFLICT ON CONSTRAINT tickets_plan_mensual_empleado_fecha_key
  DO UPDATE SET estado = 'cancelada', actualizado_en = now()
  WHERE t.estado = 'confirmada';
END;
$$;

REVOKE ALL ON FUNCTION public.cancelar_ticket_plan_mensual(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancelar_ticket_plan_mensual(DATE) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ===================== 20261028_test_mode_tickets.sql =====================
-- Modo de prueba para tickets de retiro (QR).
--
-- Requiere 20261026_pickup_codes_rpc.sql y 20261027_cancel_deadline.sql.
--
-- * usuarios.es_cuenta_prueba marca las cuentas de prueba (ej. "Empleado
--   Prueba 2"). Solo administración la cambia:
--     UPDATE public.usuarios SET es_cuenta_prueba = true WHERE email = '...';
-- * regenerar_tickets_semana: deja confirmados, con códigos nuevos, los
--   tickets de lunes a viernes de la semana indicada. Solo para cuentas de
--   prueba (o administración actuando sobre una cuenta de prueba), para que
--   un empleado real no pueda reactivar almuerzos ya retirados.
-- * canjear_codigo_retiro: en modo demostración (p_ignorar_horario) un ticket
--   de una cuenta de prueba se acepta aunque sea de otro día de la semana.

-- 1. Marca de cuenta de prueba.
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS es_cuenta_prueba BOOLEAN NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.es_cuenta_prueba(p_usuario UUID DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce((
    SELECT u.es_cuenta_prueba FROM public.usuarios u
    WHERE u.id = coalesce(p_usuario, auth.uid())
  ), false);
$$;

-- Un empleado no puede marcarse a sí mismo como cuenta de prueba.
CREATE OR REPLACE FUNCTION public.proteger_es_cuenta_prueba()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.es_cuenta_prueba IS DISTINCT FROM
       (CASE WHEN TG_OP = 'INSERT' THEN false ELSE OLD.es_cuenta_prueba END)
    AND auth.uid() IS NOT NULL
    AND NOT public.is_admin_actor() THEN
    RAISE EXCEPTION 'Solo administración puede marcar cuentas de prueba.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS usuarios_proteger_es_cuenta_prueba ON public.usuarios;
CREATE TRIGGER usuarios_proteger_es_cuenta_prueba
  BEFORE INSERT OR UPDATE ON public.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.proteger_es_cuenta_prueba();

-- 2. RPC: regenerar los tickets de la semana de una cuenta de prueba.
--    Devuelve cuántos tickets quedaron confirmados con código nuevo.
CREATE OR REPLACE FUNCTION public.regenerar_tickets_semana(
  p_fecha DATE DEFAULT NULL,
  p_empleado UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_empleado UUID := coalesce(p_empleado, auth.uid());
  v_lunes DATE;
  v_viernes DATE;
  v_total INTEGER := 0;
  v_filas INTEGER;
  v_plan BOOLEAN;
BEGIN
  IF v_empleado IS NULL THEN
    RAISE EXCEPTION 'Sesión requerida.' USING ERRCODE = '42501';
  END IF;
  IF v_empleado IS DISTINCT FROM auth.uid() AND NOT public.is_admin_actor() THEN
    RAISE EXCEPTION 'Solo administración puede regenerar tickets de otro empleado.'
      USING ERRCODE = '42501';
  END IF;
  IF NOT public.es_cuenta_prueba(v_empleado) THEN
    RAISE EXCEPTION 'CUENTA_NO_ES_DE_PRUEBA: solo las cuentas de prueba pueden regenerar tickets.'
      USING ERRCODE = '42501';
  END IF;

  v_lunes := date_trunc('week', coalesce(p_fecha, public.ahora_la_paz()::date))::date;
  v_viernes := v_lunes + 4;

  -- Plan Mensual: un ticket por día hábil.
  SELECT coalesce(u.has_monthly_plan, false) INTO v_plan
  FROM public.usuarios u WHERE u.id = v_empleado;
  IF v_plan THEN
    INSERT INTO public.tickets_plan_mensual AS t (empleado_id, fecha)
    SELECT v_empleado, d::date
    FROM generate_series(v_lunes, v_viernes, INTERVAL '1 day') AS d
    ON CONFLICT ON CONSTRAINT tickets_plan_mensual_empleado_fecha_key
    DO UPDATE SET estado = 'confirmada',
                  codigo_retiro = public.generar_codigo_retiro(),
                  actualizado_en = now();
    GET DIAGNOSTICS v_filas = ROW_COUNT;
    v_total := v_total + v_filas;
  END IF;

  -- Reservas diarias ya hechas en la semana.
  IF to_regclass('public.reservations') IS NOT NULL THEN
    EXECUTE 'UPDATE public.reservations
             SET status = ''confirmada'', pickup_code = public.generar_codigo_retiro()
             WHERE user_id = $1 AND reservation_date BETWEEN $2 AND $3'
      USING v_empleado, v_lunes, v_viernes;
    GET DIAGNOSTICS v_filas = ROW_COUNT;
    v_total := v_total + v_filas;
  END IF;

  IF to_regclass('public.reservas') IS NOT NULL THEN
    EXECUTE 'UPDATE public.reservas
             SET estado = ''ACTIVA'', codigo_retiro = public.generar_codigo_retiro()
             WHERE empleado_id = $1 AND fecha BETWEEN $2 AND $3'
      USING v_empleado, v_lunes, v_viernes;
    GET DIAGNOSTICS v_filas = ROW_COUNT;
    v_total := v_total + v_filas;
  END IF;

  RETURN v_total;
END;
$$;

-- 3. RPC de canje: igual que 20261026, pero en modo demostración acepta
--    tickets de cuentas de prueba de otro día.
CREATE OR REPLACE FUNCTION public.canjear_codigo_retiro(
  p_codigo TEXT,
  p_ignorar_horario BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_codigo TEXT := upper(btrim(coalesce(p_codigo, '')));
  v_ahora TIMESTAMP := public.ahora_la_paz();
  v_tabla TEXT;
  v_id TEXT;
  v_fecha DATE;
  v_estado TEXT;
  v_empleado UUID;
BEGIN
  IF NOT public.is_admin_actor() THEN
    RAISE EXCEPTION 'Solo administración puede registrar retiros.'
      USING ERRCODE = '42501';
  END IF;
  IF v_codigo = '' THEN
    RETURN jsonb_build_object('resultado', 'no_encontrado');
  END IF;

  IF to_regclass('public.reservations') IS NOT NULL THEN
    EXECUTE 'SELECT id::text, reservation_date, lower(status::text), user_id
             FROM public.reservations WHERE pickup_code = $1 FOR UPDATE'
      INTO v_id, v_fecha, v_estado, v_empleado USING v_codigo;
    IF v_id IS NOT NULL THEN v_tabla := 'reservations'; END IF;
  END IF;

  IF v_tabla IS NULL AND to_regclass('public.reservas') IS NOT NULL THEN
    EXECUTE 'SELECT id::text, fecha, lower(estado::text), empleado_id
             FROM public.reservas WHERE codigo_retiro = $1 FOR UPDATE'
      INTO v_id, v_fecha, v_estado, v_empleado USING v_codigo;
    IF v_id IS NOT NULL THEN v_tabla := 'reservas'; END IF;
  END IF;

  IF v_tabla IS NULL THEN
    SELECT t.id::text, t.fecha, t.estado, t.empleado_id
      INTO v_id, v_fecha, v_estado, v_empleado
    FROM public.tickets_plan_mensual t
    WHERE t.codigo_retiro = v_codigo
    FOR UPDATE;
    IF v_id IS NOT NULL THEN v_tabla := 'tickets_plan_mensual'; END IF;
  END IF;

  IF v_tabla IS NULL THEN
    RETURN jsonb_build_object('resultado', 'no_encontrado');
  ELSIF v_estado = 'cancelada' THEN
    RETURN jsonb_build_object('resultado', 'cancelada', 'id', v_id);
  ELSIF v_estado = 'entregada' THEN
    RETURN jsonb_build_object('resultado', 'ya_entregada', 'id', v_id);
  ELSIF v_fecha <> v_ahora::date
    AND NOT (p_ignorar_horario AND public.es_cuenta_prueba(v_empleado)) THEN
    RETURN jsonb_build_object('resultado', 'otra_fecha', 'id', v_id);
  ELSIF NOT p_ignorar_horario
    AND (v_ahora::time < TIME '12:00' OR v_ahora::time >= TIME '14:00') THEN
    RETURN jsonb_build_object('resultado', 'fuera_de_horario', 'id', v_id);
  END IF;

  IF v_tabla = 'reservations' THEN
    EXECUTE 'UPDATE public.reservations SET status = ''entregada'' WHERE id::text = $1'
      USING v_id;
  ELSIF v_tabla = 'reservas' THEN
    EXECUTE 'UPDATE public.reservas SET estado = ''ENTREGADA'' WHERE id::text = $1'
      USING v_id;
  ELSE
    UPDATE public.tickets_plan_mensual
      SET estado = 'entregada', actualizado_en = now()
      WHERE id::text = v_id;
  END IF;

  RETURN jsonb_build_object('resultado', 'entregada', 'id', v_id, 'tabla', v_tabla);
END;
$$;

REVOKE ALL ON FUNCTION public.es_cuenta_prueba(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.regenerar_tickets_semana(DATE, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.canjear_codigo_retiro(TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.es_cuenta_prueba(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.regenerar_tickets_semana(DATE, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.canjear_codigo_retiro(TEXT, BOOLEAN) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- 0.2 Marcar al empleado de prueba (cambia el correo).
UPDATE public.usuarios
SET es_cuenta_prueba = true
WHERE email = 'empleado2@uab.edu.bo';

-- ===================== Diagnóstico =====================
-- Debe mostrar es_cuenta_prueba = true, activo = true y su código EMP-xxx.
SELECT id, nombres, apellidos, email, employee_code, rol,
       has_monthly_plan, activo, es_cuenta_prueba
FROM public.usuarios
WHERE es_cuenta_prueba OR nombres ILIKE '%prueba%' OR email ILIKE '%prueba%';

-- Reservas y tickets de esta semana de las cuentas de prueba. Si sale vacío
-- después de reservar desde la app, el guardado está fallando (ver políticas).
SELECT 'reservas' AS origen, r.fecha, r.estado::text, r.codigo_retiro
FROM public.reservas r
JOIN public.usuarios u ON u.id = r.empleado_id AND u.es_cuenta_prueba
WHERE r.fecha >= date_trunc('week', current_date)::date
UNION ALL
SELECT 'plan_mensual', t.fecha, t.estado, t.codigo_retiro
FROM public.tickets_plan_mensual t
JOIN public.usuarios u ON u.id = t.empleado_id AND u.es_cuenta_prueba
WHERE t.fecha >= date_trunc('week', current_date)::date
ORDER BY 2;

-- Políticas RLS de reservas: debe haber una de INSERT para el empleado.
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'reservas';
