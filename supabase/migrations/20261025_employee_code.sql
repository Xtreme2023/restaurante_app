ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS employee_code TEXT;

WITH numbered AS (
  SELECT id, row_number() OVER (ORDER BY creado_en, id) AS code_number
  FROM public.usuarios
  WHERE employee_code IS NULL OR btrim(employee_code) = ''
)
UPDATE public.usuarios AS usuarios
SET employee_code = 'EMP-' || lpad(numbered.code_number::text, 3, '0')
FROM numbered
WHERE usuarios.id = numbered.id;

CREATE UNIQUE INDEX IF NOT EXISTS usuarios_employee_code_key
  ON public.usuarios(employee_code)
  WHERE employee_code IS NOT NULL;

DO $$
BEGIN
  IF to_regclass('public.reservations') IS NOT NULL THEN
    ALTER TABLE public.reservations
      ADD COLUMN IF NOT EXISTS employee_code TEXT;
  END IF;

  IF to_regclass('public.reservas') IS NOT NULL THEN
    ALTER TABLE public.reservas
      ADD COLUMN IF NOT EXISTS employee_code TEXT;
  END IF;
END $$;
