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
