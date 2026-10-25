import { createClient } from "@supabase/supabase-js";

// Soporta tanto VITE_SUPABASE_URL como VITE_APP_SUPABASE_URL y REACT_APP_SUPABASE_URL
export const supabaseUrl = (
  import.meta.env.VITE_SUPABASE_URL ||
  ""
).trim();

export const supabaseAnonKey = (
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  ""
).trim();

if (!supabaseUrl || !supabaseAnonKey) {
  console.error(
   "Estamos teniendo problemas con la conexión a nuestros servidores."
  );
}

// Fallback seguro para evitar 'Uncaught Error: supabaseUrl is required' si faltan variables en el build
export const supabase = createClient(
  supabaseUrl || "https://placeholder.supabase.co",
  supabaseAnonKey || "placeholder-anon-key",
  {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  }
);

// Re-exporta los métodos y funciones para que supabase.js sea el punto central
export * from "./supabaseClient";
