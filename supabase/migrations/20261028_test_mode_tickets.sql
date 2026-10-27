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
