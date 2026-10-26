-- ==============================================================================
-- BASE DE DATOS SUPABASE: RESTAURANTE INSTITUCIONAL
-- Copia y pega este script en el "SQL Editor" de tu panel de Supabase.
-- ==============================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLA DE PERFILES (Vinculada a auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    employee_code TEXT UNIQUE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'empleado' CHECK (role IN ('empleado', 'encargado', 'institucion')),
    department TEXT DEFAULT 'Administración Central',
    is_pensioner BOOLEAN DEFAULT false,
    monthly_expense NUMERIC(10, 2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. TABLA DE PLATOS DEL MENÚ
CREATE TABLE IF NOT EXISTS public.dishes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL DEFAULT 'Plato Fuerte' CHECK (category IN ('Plato Fuerte', 'Sopa', 'Vegetariano', 'Postre', 'Bebida', 'Entrada')),
    image_url TEXT,
    price NUMERIC(10, 2) NOT NULL DEFAULT 15.00,
    calories INT DEFAULT 600,
    is_favorite BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. TABLA DE FERIADOS INSTITUCIONALES
CREATE TABLE IF NOT EXISTS public.holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT
);

-- 5. TABLA DE RESERVAS
CREATE TABLE IF NOT EXISTS public.reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    employee_code TEXT,
    dish_id UUID REFERENCES public.dishes(id) ON DELETE SET NULL,
    dish_name TEXT,
    entrada_nombre TEXT,
    ensalada_nombre TEXT,
    plato_principal TEXT,
    sopa_nombre TEXT,
    es_almuerzo_completo BOOLEAN NOT NULL DEFAULT true,
    menu_category TEXT NOT NULL DEFAULT 'almuerzo_completo'
        CHECK (menu_category IN ('almuerzo_completo', 'menu_vegetariano', 'plato_especial')),
    reservation_date DATE NOT NULL,
    type TEXT NOT NULL DEFAULT 'diaria' CHECK (type IN ('diaria', 'pension')),
    status TEXT NOT NULL DEFAULT 'confirmada' CHECK (status IN ('confirmada', 'cancelada', 'entregada')),
    familiar_id TEXT,
    beneficiary_name TEXT NOT NULL DEFAULT 'Empleado',
    price NUMERIC(10, 2) NOT NULL DEFAULT 18.00,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. TABLA DE SUSCRIPCIONES MENSUALES (MODALIDAD PENSIONADO)
CREATE TABLE IF NOT EXISTS public.monthly_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    year INT NOT NULL,
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    total_days INT NOT NULL,
    price_per_day NUMERIC(10, 2) NOT NULL DEFAULT 14.00,
    total_price NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'activa' CHECK (status IN ('activa', 'cancelada', 'finalizada')),
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_user_monthly_subscription UNIQUE (user_id, year, month)
);

-- 7. ÍNDICES DE RENDIMIENTO
CREATE INDEX IF NOT EXISTS idx_reservations_date ON public.reservations(reservation_date);
CREATE INDEX IF NOT EXISTS idx_reservations_user ON public.reservations(user_id);
CREATE INDEX IF NOT EXISTS idx_holidays_date ON public.holidays(date);

-- 8. HABILITAR ROW LEVEL SECURITY (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_subscriptions ENABLE ROW LEVEL SECURITY;

-- 9. POLÍTICAS DE ACCESO (RLS POLICIES)

-- Dishes & Holidays: Lectura pública abierta (menú público)
CREATE POLICY "Lectura pública de menú" ON public.dishes
    FOR SELECT USING (true);

CREATE POLICY "Lectura pública de feriados" ON public.holidays
    FOR SELECT USING (true);

-- Perfiles: Cada usuario lee su perfil; encargados e instituciones leen todos
CREATE POLICY "Usuarios ven sus propios perfiles" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Usuarios actualizan su perfil" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Reservas:
CREATE POLICY "Usuarios ven sus propias reservas" ON public.reservations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Usuarios insertan sus reservas" ON public.reservations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios cancelan sus reservas" ON public.reservations
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Staff y administración gestionan reservas" ON public.reservations
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND (profiles.role IN ('encargado', 'institucion'))
        )
    );

-- Suscripciones Mensuales:
CREATE POLICY "Usuarios ven sus pensiones" ON public.monthly_subscriptions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Usuarios registran su pensión" ON public.monthly_subscriptions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios modifican su pensión antes de inicio" ON public.monthly_subscriptions
    FOR UPDATE USING (auth.uid() = user_id);

-- 10. TRIGGER PARA CREACIÓN AUTOMÁTICA DE PERFIL EN SIGNUP
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'full_name', 'Empleado'),
        COALESCE(new.raw_user_meta_data->>'role', 'empleado')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 11. DATOS INICIALES DE PRUEBA (SEED DATA)
INSERT INTO public.dishes (name, description, category, image_url, price, calories, is_favorite, is_available) VALUES
('Silpancho Cochabambino', 'Carne apanada sobre cama de arroz blanco y papas doradas con huevo estrellado y sarza fresca.', 'Plato Fuerte', 'https://images.unsplash.com/photo-1544025162-d76694265947?w=500', 18.00, 780, true, true),
('Sopa de Maní Tradicional', 'Sopa espesa y aromática a base de maní licuado, verduras selectas, carne tierna y fideos tostados.', 'Sopa', 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=500', 12.00, 520, true, true),
('Pique Macho Especial', 'Trozos de lomo de res saltados con salchichas, papas fritas crocantes, huevo duro, tomate y locoto.', 'Plato Fuerte', 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500', 22.00, 890, false, true),
('Plato Saludable Vegetariano', 'Quinua real perlada con verduras salteadas al wok, palta fresca y champiñones grillados.', 'Vegetariano', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500', 16.00, 460, false, true),
('Budín de Pan Casero', 'Tradicional budín horneado bañado en caramelo dorado con pasas de uva y un toque de canela.', 'Postre', 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=500', 7.00, 320, false, true)
ON CONFLICT DO NOTHING;

INSERT INTO public.holidays (date, name, description) VALUES
('2026-01-01', 'Año Nuevo', 'Feriado nacional'),
('2026-01-22', 'Día del Estado Plurinacional', 'Feriado nacional'),
('2026-02-16', 'Carnaval (Lunes)', 'Feriado nacional'),
('2026-02-17', 'Carnaval (Martes)', 'Feriado nacional'),
('2026-04-03', 'Viernes Santo', 'Feriado nacional'),
('2026-05-01', 'Día del Trabajo', 'Feriado nacional'),
('2026-06-04', 'Corpus Christi', 'Feriado nacional'),
('2026-08-06', 'Día de la Independencia', 'Feriado nacional patrio'),
('2026-11-02', 'Todos Santos', 'Feriado nacional'),
('2026-12-25', 'Navidad', 'Feriado nacional')
ON CONFLICT DO NOTHING;
