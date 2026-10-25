import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurante_app/supabase/usuarios_service.dart';

export 'package:restaurante_app/supabase/usuarios_service.dart';
export 'package:restaurante_app/supabase/menu_service.dart';

/// Fallback credentials matching the project configuration (.env)
const String kDefaultSupabaseUrl = 'https://vzcrkhjqdsnxizhyjjjk.supabase.co';
const String kDefaultSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6Y3JraGpxZHNueGl6aHlqamprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0NzgwNjQsImV4cCI6MjEwNzA1NDA2NH0.1CspDh3s9fLpn9cSU--xYlEYa4q6JEGjEySoWkT3yR8';

/// Getter global para acceder a la instancia del cliente en cualquier parte del proyecto
SupabaseClient get supabase => Supabase.instance.client;

/// Obtiene la URL configurada de Supabase
String get supabaseUrl {
  if (dotenv.isInitialized) {
    final envUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    if (envUrl.isNotEmpty) return envUrl;
  }
  return kDefaultSupabaseUrl;
}

/// Obtiene la clave anónima configurada de Supabase
String get supabaseAnonKey {
  if (dotenv.isInitialized) {
    final envKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();
    if (envKey.isNotEmpty) return envKey;
  }
  return kDefaultSupabaseAnonKey;
}

/// Inicialización centralizada con carga de variables y fallback seguro
Future<void> initSupabase() async {
  try {
    // Si ya está inicializado, no relanzar
    Supabase.instance.client;
    debugPrint('ℹ️ Supabase ya se encontraba inicializado.');
    return;
  } catch (_) {
    // Continúa con la inicialización
  }

  final url = supabaseUrl;
  final anonKey = supabaseAnonKey;

  if (!dotenv.isInitialized || dotenv.env['SUPABASE_URL'] == null) {
    debugPrint(
      'Aviso: dotenv no cargado o sin SUPABASE_URL. '
      'Utilizando configuración segura predeterminada.',
    );
  }

  // Supabase.initialize en Flutter incluye persistencia en almacenamiento seguro
  // y auto-refresh de tokens por defecto.
  await Supabase.initialize(
    url: url,
    publishableKey: anonKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
      authFlowType: AuthFlowType.pkce,
    ),
  );
  debugPrint('✅ Supabase inicializado exitosamente.');
}

// =============================================================================
// FUNCIONES DE AUTENTICACIÓN Y USUARIOS (Delegadas a UsuariosService / vista_usuarios)
// =============================================================================

/// Inicio de sesión usando la función nativa de Supabase Auth
/// y verificación del perfil y estado activo en la vista `vista_usuarios`.
Future<Map<String, dynamic>> loginWithEmail(
  String email,
  String password,
) async {
  final res = await supabase.auth.signInWithPassword(
    email: email.trim(),
    password: password,
  );

  final user = res.user;
  if (user == null) {
    throw const AuthException('No se pudo autenticar al usuario.');
  }

  // Obtener perfil complementario desde la vista vista_usuarios
  final profile = await UsuariosService.getUsuarioById(user.id);
  if (profile != null) {
    if (profile['activo'] == false) {
      await supabase.auth.signOut();
      throw Exception(
        'Esta cuenta ha sido desactivada. Comuníquese con el administrador.',
      );
    }
    return {'user': user, 'profile': profile, 'session': res.session};
  }

  return {
    'user': user,
    'profile': user.userMetadata ?? <String, dynamic>{},
    'session': res.session,
  };
}

/// Cerrar sesión en Supabase
Future<void> logout() async {
  await supabase.auth.signOut();
}

/// Listar usuarios registrados desde la vista `vista_usuarios`
Future<List<Map<String, dynamic>>> fetchUsuarios() =>
    UsuariosService.getUsuarios();

/// Obtener un usuario específico desde la vista `vista_usuarios` por su `id_usuario`
Future<Map<String, dynamic>?> fetchUsuario(String idUsuario) =>
    UsuariosService.getUsuarioById(idUsuario);

/// Obtener un usuario específico desde la vista `vista_usuarios` por su correo electrónico
Future<Map<String, dynamic>?> fetchUsuarioByEmail(String email) =>
    UsuariosService.getUsuarioByEmail(email);

/// Registro de nuevos integrantes usando el trigger en Auth `on_auth_user_created`
Future<AuthResponse> createAdminUser(Map<String, dynamic> userData) {
  return UsuariosService.registerUser(
    email: (userData['email'] ?? '').toString(),
    password: (userData['password'] ?? '').toString(),
    nombre: (userData['nombre'] ?? userData['nombres'] ?? '').toString(),
    apellidos: (userData['apellidos'] ?? '').toString(),
    ciCodigo: (userData['ci_codigo'] ?? userData['ci'] ?? '').toString(),
    telefono: (userData['telefono'] ?? '').toString(),
    rol: (userData['rol'] ?? 'Empleado').toString(),
  );
}

/// Anular o reactivar acceso (HU4 - Dar de baja usuarios)
Future<dynamic> toggleUserStatus(String idUsuario, bool nuevoEstado) =>
    UsuariosService.toggleUserStatus(idUsuario, nuevoEstado);

/// Actualizar perfil de usuario (HU2 - Mi Cuenta)
Future<dynamic> updateUserProfile(
  String idUsuario,
  Map<String, dynamic> updateData,
) {
  return UsuariosService.updateUserProfile(
    idUsuario: idUsuario,
    nombre: (updateData['nombre'] ?? updateData['nombres'] ?? '').toString(),
    apellidos: (updateData['apellidos'] ?? '').toString(),
    telefono: updateData['telefono']?.toString(),
  );
}

/// Cambiar contraseña de la cuenta actual (HU2)
Future<UserResponse> updatePassword(String newPassword) async {
  final data = await supabase.auth.updateUser(
    UserAttributes(password: newPassword),
  );
  return data;
}

/// Eliminar usuario permanentemente de la base de datos
Future<void> deleteUserPermanently(String idUsuario) =>
    UsuariosService.deleteUser(idUsuario);

// =============================================================================
// SECCIÓN FAMILIARES: familiar y persona
// =============================================================================

/// Listar familiares vinculados a un usuario empleado
Future<List<Map<String, dynamic>>> fetchFamiliaresByUsuario(String idUsuario) =>
    UsuariosService.getFamiliaresByUsuario(idUsuario);

/// Registrar un nuevo familiar para un usuario empleado
Future<Map<String, dynamic>> createFamiliar({
  required String idUsuario,
  required String parentesco,
  required String nombre,
  required String apellidos,
  String? telefono,
}) {
  return UsuariosService.createFamiliar(
    idUsuario: idUsuario,
    parentesco: parentesco,
    nombre: nombre,
    apellidos: apellidos,
    telefono: telefono,
  );
}

/// Eliminar un familiar
Future<void> deleteFamiliar(String idFamiliarOrPersona, [String? idUsuario]) =>
    UsuariosService.deleteFamiliar(idFamiliarOrPersona, idUsuario);

// =============================================================================
// SECCIÓN CALENDARIO: excepcion_calendario (Adaptado de web/src/lib/supabaseClient.js)
// =============================================================================

/// Listar todas las excepciones de calendario registradas
Future<List<Map<String, dynamic>>> fetchExcepcionesCalendario() async {
  final data = await supabase
      .from('excepcion_calendario')
      .select()
      .order('fecha', ascending: true);

  return List<Map<String, dynamic>>.from(data);
}

/// Registrar un nuevo día de excepción (no atención)
Future<dynamic> createExcepcionCalendario({
  required String fecha,
  required String motivo,
  String? idEncargado,
}) async {
  final existing = await supabase
      .from('excepcion_calendario')
      .select()
      .eq('fecha', fecha)
      .maybeSingle();

  if (existing != null) {
    throw Exception(
      'Ya existe un día de excepción registrado para la fecha $fecha.',
    );
  }

  final insertPayload = <String, dynamic>{
    'fecha': fecha,
    'motivo': motivo.trim(),
  };
  if (idEncargado != null) {
    insertPayload['id_encargado'] = idEncargado;
  }

  final data = await supabase
      .from('excepcion_calendario')
      .insert(insertPayload)
      .select();

  return data;
}

/// Eliminar un día de excepción
Future<void> deleteExcepcionCalendario(dynamic excepcionIdOrFecha) async {
  if (excepcionIdOrFecha is Map) {
    final idExcepcion =
        excepcionIdOrFecha['id_excepcion'] ?? excepcionIdOrFecha['id'];
    if (idExcepcion != null) {
      await supabase
          .from('excepcion_calendario')
          .delete()
          .eq('id_excepcion', idExcepcion);
      return;
    }
    final fecha = excepcionIdOrFecha['fecha'];
    if (fecha != null) {
      await supabase.from('excepcion_calendario').delete().eq('fecha', fecha);
      return;
    }
  }

  // Si es un número o UUID o fecha en String
  final str = excepcionIdOrFecha.toString();
  if (str.contains('-')) {
    // Parece una fecha YYYY-MM-DD
    await supabase.from('excepcion_calendario').delete().eq('fecha', str);
  } else {
    await supabase
        .from('excepcion_calendario')
        .delete()
        .eq('id_excepcion', excepcionIdOrFecha);
  }
}
