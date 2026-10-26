import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type EmployeeRequest = {
  ci: string;
  employeeCode: string;
  nombres: string;
  apellidos: string;
  email: string;
  password: string;
  telefono: string;
  departamento: string;
  rol: string;
  hasMonthlyPlan: boolean;
  familiares: Array<{
    ci: string;
    nombres: string;
    apellidos: string;
    parentesco: string;
  }>;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "Método no permitido" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
    return json({ error: "Configuración de autenticación incompleta" }, 500);
  }

  const token = authorization.replace(/^Bearer\s+/i, "");
  const authClient = createClient(supabaseUrl, anonKey);
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: caller, error: callerError } = await authClient.auth.getUser(token);
  if (callerError || !caller.user) return json({ error: "Sesión no válida" }, 401);

  const { data: actor, error: actorError } = await adminClient
    .from("usuarios")
    .select("rol, activo")
    .eq("id", caller.user.id)
    .maybeSingle();
  const { data: profileActor } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", caller.user.id)
    .maybeSingle();
  const actorRole = actor?.rol?.toString().toUpperCase() ??
    profileActor?.role?.toString().toUpperCase();
  const isAdmin = !actorError &&
    (actor?.activo ?? true) &&
    ["ADMINISTRADOR", "ENCARGADO", "INSTITUCION", "ADMIN"].includes(actorRole ?? "");
  if (!isAdmin) {
    return json({ error: "Solo un administrador puede registrar empleados" }, 403);
  }

  let payload: EmployeeRequest;
  try {
    payload = await request.json() as EmployeeRequest;
  } catch {
    return json({ error: "Solicitud JSON inválida" }, 400);
  }

  const email = payload.email.trim().toLowerCase();
  const role = payload.rol.trim().toUpperCase();
  if (!["ADMIN", "ADMINISTRADOR", "COCINA", "ENCARGADO", "EMPLEADO"].includes(role)) {
    return json({ error: "Rol de usuario inválido" }, 400);
  }
  if (!email || payload.password.length < 6 || !payload.ci.trim() ||
      !/^EMP-\d{3}$/.test(payload.employeeCode.trim().toUpperCase())) {
    return json({ error: "Correo, contraseña, CI y código EMP-### son obligatorios" }, 400);
  }

  const { data: created, error: createError } =
    await adminClient.auth.admin.createUser({
      email,
      password: payload.password,
      email_confirm: true,
      user_metadata: {
        full_name: `${payload.nombres.trim()} ${payload.apellidos.trim()}`.trim(),
        role: role.toLowerCase(),
      },
    });
  if (createError || !created.user) {
    return json({ error: createError?.message ?? "No se pudo crear la cuenta" }, 409);
  }

  const userId = created.user.id;
  const { error: employeeError } = await adminClient.from("usuarios").insert({
    id: userId,
    ci: payload.ci.trim(),
    employee_code: payload.employeeCode.trim().toUpperCase(),
    nombres: payload.nombres.trim(),
    apellidos: payload.apellidos.trim(),
    email,
    telefono: payload.telefono.trim(),
    departamento: payload.departamento.trim(),
    rol: role,
    has_monthly_plan: payload.hasMonthlyPlan,
    activo: true,
  });

  if (employeeError) {
    await adminClient.auth.admin.deleteUser(userId);
    return json({ error: employeeError.message }, 409);
  }

  const familiares = (payload.familiares ?? []).slice(0, 3).map((family) => ({
    empleado_id: userId,
    ci: family.ci.trim(),
    nombres: family.nombres.trim(),
    apellidos: family.apellidos.trim(),
    parentesco: family.parentesco.trim(),
    activo: true,
  }));
  if (familiares.length > 0) {
    const { error: familyError } = await adminClient.from("familiares").insert(familiares);
    if (familyError) {
      await adminClient.from("familiares").delete().eq("empleado_id", userId);
      await adminClient.from("usuarios").delete().eq("id", userId);
      await adminClient.auth.admin.deleteUser(userId);
      return json({ error: familyError.message }, 409);
    }
  }

  return json({ id: userId, email, email_confirmed: true });
});
