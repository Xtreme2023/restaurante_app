-- Reservas creadas en el servidor.
--
-- Antes la app insertaba directo en public.reservas. Si el insert fallaba
-- (RLS, columnas o enums distintos), la reserva quedaba solo en el teléfono
-- con un QR que no existía en la base y cocina lo rechazaba como inválido.
-- Ahora la app llama a crear_reserva, que valida las reglas con la hora de
-- Bolivia, guarda la fila y devuelve el código de retiro generado por la base.
-- La app solo muestra el QR con ese código.
--
-- Requiere 20261026, 20261027 y 20261028.

-- 1. Columnas del detalle del plato que envía la app.
ALTER TABLE public.reservas
  ADD COLUMN IF NOT EXISTS dish_name TEXT,
  ADD COLUMN IF NOT EXISTS entrada_nombre TEXT,
  ADD COLUMN IF NOT EXISTS plato_principal TEXT,
  ADD COLUMN IF NOT EXISTS sopa_nombre TEXT,
  ADD COLUMN IF NOT EXISTS es_almuerzo_completo BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS menu_category TEXT NOT NULL DEFAULT 'almuerzo_completo',
  ADD COLUMN IF NOT EXISTS employee_code TEXT;

-- 2. RPC: el empleado crea una reserva (para sí o para un familiar suyo).
--    Errores con prefijo para que la app muestre un mensaje claro:
--    RESERVA_NO_PERMITIDA, RESERVA_FECHA_INVALIDA, RESERVA_PLAZO_VENCIDO,
--    RESERVA_DUPLICADA.
CREATE OR REPLACE FUNCTION public.crear_reserva(
  p_fecha DATE,
  p_familiar_id BIGINT DEFAULT NULL,
  p_dish_name TEXT DEFAULT NULL,
  p_entrada_nombre TEXT DEFAULT NULL,
  p_plato_principal TEXT DEFAULT NULL,
  p_sopa_nombre TEXT DEFAULT NULL,
  p_es_almuerzo_completo BOOLEAN DEFAULT true,
  p_menu_category TEXT DEFAULT 'almuerzo_completo',
  p_cantidad INTEGER DEFAULT 1,
  p_notas TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_ahora TIMESTAMP := public.ahora_la_paz();
  v_usuario public.usuarios%ROWTYPE;
  v_plan BOOLEAN;
  v_precio NUMERIC;
  v_id BIGINT;
  v_codigo TEXT;
BEGIN
  SELECT * INTO v_usuario FROM public.usuarios WHERE id = v_uid;
  IF v_uid IS NULL OR v_usuario.id IS NULL THEN
    RAISE EXCEPTION 'RESERVA_NO_PERMITIDA: tu cuenta no está registrada como empleado.'
      USING ERRCODE = '42501';
  END IF;
  IF v_usuario.activo IS FALSE THEN
    RAISE EXCEPTION 'RESERVA_NO_PERMITIDA: tu cuenta está inactiva.'
      USING ERRCODE = '42501';
  END IF;
  IF upper(v_usuario.rol::text) IN
       ('ADMIN', 'ADMINISTRADOR', 'COCINA', 'ENCARGADO', 'INSTITUCION') THEN
    RAISE EXCEPTION 'RESERVA_NO_PERMITIDA: solo los empleados pueden reservar.'
      USING ERRCODE = '42501';
  END IF;

  IF p_fecha IS NULL OR p_fecha < v_ahora::date THEN
    RAISE EXCEPTION 'RESERVA_FECHA_INVALIDA: no se puede reservar para fechas pasadas.';
  END IF;
  IF extract(isodow FROM p_fecha) > 5 THEN
    RAISE EXCEPTION 'RESERVA_FECHA_INVALIDA: no hay servicio los fines de semana.';
  END IF;
  IF p_fecha = v_ahora::date AND v_ahora::time >= TIME '09:00'
    AND NOT coalesce(v_usuario.es_cuenta_prueba, false) THEN
    RAISE EXCEPTION 'RESERVA_PLAZO_VENCIDO: las reservas para hoy cierran a las 09:00.';
  END IF;

  IF p_familiar_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.familiares f
    WHERE f.id = p_familiar_id AND f.empleado_id = v_uid
  ) THEN
    RAISE EXCEPTION 'RESERVA_NO_PERMITIDA: el familiar no está vinculado a tu cuenta.'
      USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.reservas r
    WHERE r.empleado_id = v_uid
      AND r.fecha = p_fecha
      AND r.familiar_id IS NOT DISTINCT FROM p_familiar_id
      AND lower(r.estado::text) <> 'cancelada'
  ) THEN
    RAISE EXCEPTION 'RESERVA_DUPLICADA: ya existe una reserva activa para ese día.';
  END IF;

  -- La tarifa la decide el servidor según la modalidad del empleado.
  v_plan := coalesce(v_usuario.has_monthly_plan, false);
  v_precio := CASE WHEN v_plan THEN 15.00 ELSE 18.00 END;

  INSERT INTO public.reservas (
    empleado_id, familiar_id, employee_code, fecha, estado, tipo_tarifa,
    precio, cantidad, notas, dish_name, entrada_nombre, plato_principal,
    sopa_nombre, es_almuerzo_completo, menu_category
  ) VALUES (
    v_uid, p_familiar_id, v_usuario.employee_code, p_fecha, 'ACTIVA',
    CASE WHEN v_plan THEN 'PLAN_MENSUAL' ELSE 'PARTICULAR' END,
    v_precio, greatest(coalesce(p_cantidad, 1), 1), p_notas, p_dish_name,
    p_entrada_nombre, p_plato_principal, p_sopa_nombre,
    coalesce(p_es_almuerzo_completo, true),
    coalesce(p_menu_category, 'almuerzo_completo')
  )
  RETURNING id, codigo_retiro INTO v_id, v_codigo;

  RETURN jsonb_build_object(
    'id', v_id,
    'codigo_retiro', v_codigo,
    'precio', v_precio,
    'estado', 'confirmada'
  );
END;
$$;

-- 3. Las RPC solo se ejecutan con sesión iniciada (Supabase da permiso a
--    anon por defecto).
REVOKE ALL ON FUNCTION public.crear_reserva(DATE, BIGINT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, INTEGER, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crear_reserva(DATE, BIGINT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT, INTEGER, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.canjear_codigo_retiro(TEXT, BOOLEAN) FROM anon;
REVOKE EXECUTE ON FUNCTION public.obtener_ticket_plan_mensual(DATE) FROM anon;
REVOKE EXECUTE ON FUNCTION public.cancelar_ticket_plan_mensual(DATE) FROM anon;
REVOKE EXECUTE ON FUNCTION public.regenerar_tickets_semana(DATE, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.es_cuenta_prueba(UUID) FROM anon;

NOTIFY pgrst, 'reload schema';
