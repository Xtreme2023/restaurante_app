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
