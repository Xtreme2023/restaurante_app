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
