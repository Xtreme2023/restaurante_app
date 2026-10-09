import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.REACT_APP_SUPABASE_URL;
const SUPABASE_KEY = process.env.REACT_APP_SUPABASE_API_KEY;

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

/**
 * Inicio de sesión usando la función nativa de supabase-js
 */
export async function loginWithEmail(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    throw error;
  }

  // Obtener perfil complementario desde la tabla public.usuario
  if (data?.user) {
    const { data: profile, error: profileErr } = await supabase
      .from('usuario')
      .select('*')
      .eq('id_usuario', data.user.id)
      .single();

    if (!profileErr && profile) {
      if (profile.activo === false) {
        await supabase.auth.signOut();
        throw new Error('Esta cuenta ha sido desactivada. Comuníquese con el administrador.');
      }
      return { user: data.user, profile, session: data.session };
    }
  }

  return { user: data?.user, profile: data?.user?.user_metadata, session: data?.session };
}

/**
 * Cerrar sesión
 */
export async function logout() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

/**
 * Listar usuarios registrados
 */
export async function fetchUsuarios() {
  const { data, error } = await supabase
    .from('usuario')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data || [];
}

/**
 * Registro de nuevos integrantes mediante Opción A:
 * Utiliza un cliente secundario aislado (persistSession: false) para registrar
 * la nueva cuenta vía auth.signUp sin alterar la sesión del Administrador logueado.
 * El Trigger configurado en Supabase crea automáticamente el registro en public.usuario.
 */
export async function createAdminUser(userData) {
  const { email, password, nombres, apellidos, ci_codigo, telefono, rol } = userData;

  // 1. Validación previa de unicidad
  const { data: existingCi } = await supabase
    .from('usuario')
    .select('id_usuario, ci_codigo')
    .eq('ci_codigo', ci_codigo.trim())
    .maybeSingle();

  if (existingCi) {
    throw new Error(`El número de C.I. "${ci_codigo}" ya se encuentra registrado en el sistema.`);
  }

  const { data: existingEmail } = await supabase
    .from('usuario')
    .select('id_usuario, email')
    .eq('email', email.trim().toLowerCase())
    .maybeSingle();

  if (existingEmail) {
    throw new Error(`El correo electrónico "${email}" ya está en uso.`);
  }

  const { data: existingPhone } = await supabase
    .from('usuario')
    .select('id_usuario, telefono')
    .eq('telefono', telefono.trim())
    .maybeSingle();

  if (existingPhone) {
    throw new Error(`El teléfono "${telefono}" ya se encuentra registrado.`);
  }

  // 2. Cliente aislado sin persistencia de sesión para que el Admin continúe logueado
  const tempAuthClient = createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  // 3. Registro con user_metadata para activar el trigger de public.usuario
  const { data, error } = await tempAuthClient.auth.signUp({
    email: email.trim().toLowerCase(),
    password,
    options: {
      data: {
        nombres: nombres.trim(),
        apellidos: apellidos.trim(),
        ci_codigo: ci_codigo.trim(),
        telefono: telefono.trim(),
        rol, // 'Administrador' | 'Empleado' | 'Institucion'
      },
    },
  });

  if (error) {
    throw new Error(error.message || 'Error al registrar el usuario en Supabase');
  }

  return data;
}

/**
 * Anular o reactivar acceso (HU4 - Dar de baja usuarios)
 */
export async function toggleUserStatus(id_usuario, nuevoEstado) {
  const { data, error } = await supabase
    .from('usuario')
    .update({ activo: nuevoEstado })
    .eq('id_usuario', id_usuario)
    .select();

  if (error) throw error;
  return data;
}

/**
 * Actualizar perfil de usuario (HU2 - Mi Cuenta)
 */
export async function updateUserProfile(id_usuario, updateData) {
  const { nombres, apellidos, telefono } = updateData;
  const { data, error } = await supabase
    .from('usuario')
    .update({
      nombres,
      apellidos,
      telefono,
    })
    .eq('id_usuario', id_usuario)
    .select();

  if (error) throw error;
  return data;
}

/**
 * Cambiar contraseña de la cuenta actual (HU2)
 */
export async function updatePassword(newPassword) {
  const { data, error } = await supabase.auth.updateUser({
    password: newPassword,
  });
  if (error) throw error;
  return data;
}

/**
 * Eliminar usuario permanentemente
 */
export async function deleteUserPermanently(id_usuario) {
  // Eliminar de public.usuario
  const { error } = await supabase.from('usuario').delete().eq('id_usuario', id_usuario);
  if (error) throw error;
}
