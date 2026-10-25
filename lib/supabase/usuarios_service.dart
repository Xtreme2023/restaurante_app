import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurante_app/supabase/supabase_client.dart';

/// Servicio centralizado para la gestión y obtención de usuarios.
/// REGLA ESTRICTA DE ARQUITECTURA:
/// - La obtención y consulta de datos de usuarios SIEMPRE se realiza a través de la VIEW `vista_usuarios`.
/// - NUNCA se consulta `public.usuario` directamente para lectura de usuarios.
/// - El registro de usuarios invoca `auth.signUp` con los metadatos requeridos por el trigger
///   en base de datos `on_auth_user_created` (función `handle_new_user()`).
class UsuariosService {
  static const String viewName = 'vista_usuarios';

  // ===========================================================================
  // 1. CONSULTAS DE LECTURA (EXCLUSIVAMENTE A TRAVÉS DE LA VIEW `vista_usuarios`)
  // ===========================================================================

  /// Obtiene todos los usuarios registrados en el sistema desde `vista_usuarios`.
  static Future<List<Map<String, dynamic>>> getUsuarios() async {
    final data = await supabase
        .from(viewName)
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Obtiene un usuario específico por su UUID (`id_usuario`) desde `vista_usuarios`.
  static Future<Map<String, dynamic>?> getUsuarioById(String idUsuario) async {
    final data = await supabase
        .from(viewName)
        .select()
        .eq('id_usuario', idUsuario)
        .maybeSingle();

    return data;
  }

  /// Obtiene un usuario específico por su correo institucional desde `vista_usuarios`.
  static Future<Map<String, dynamic>?> getUsuarioByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    final data = await supabase
        .from(viewName)
        .select()
        .eq('email', cleanEmail)
        .maybeSingle();

    return data;
  }

  /// Obtiene un usuario específico por su CI o código institucional desde `vista_usuarios`.
  static Future<Map<String, dynamic>?> getUsuarioByCi(String ciCodigo) async {
    final cleanCi = ciCodigo.trim();
    if (cleanCi.isEmpty) return null;

    final data = await supabase
        .from(viewName)
        .select()
        .eq('ci_codigo', cleanCi)
        .maybeSingle();

    return data;
  }

  /// Obtiene únicamente los usuarios con rol 'Empleado' desde `vista_usuarios`.
  static Future<List<Map<String, dynamic>>> getEmpleados({bool soloActivos = false}) async {
    var query = supabase
        .from(viewName)
        .select()
        .eq('rol', 'Empleado');

    if (soloActivos) {
      query = query.eq('activo', true);
    }

    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ===========================================================================
  // 2. REGISTRO DE USUARIOS (TRIGGER DE AUTH `on_auth_user_created`)
  // ===========================================================================

  /// Registra un nuevo usuario aprovechando el trigger en Supabase `on_auth_user_created`.
  /// El trigger `handle_new_user()` lee `raw_user_meta_data` e inserta automáticamente
  /// en `public.persona` y `public.usuario`.
  ///
  /// Se utiliza un cliente aislado para evitar modificar la sesión del Administrador logueado.
  static Future<AuthResponse> registerUser({
    required String email,
    required String password,
    required String nombre,
    required String apellidos,
    required String ciCodigo,
    required String telefono,
    required String rol, // 'Empleado' | 'Administrador' | 'Institucion'
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCi = ciCodigo.trim();
    final cleanNombre = nombre.trim();
    final cleanApellidos = apellidos.trim();
    final cleanTelefono = telefono.trim();

    // Normalizar rol según enum de Supabase ('Empleado', 'Administrador', 'Institucion')
    String normalizedRol = 'Empleado';
    final lowerRol = rol.toLowerCase();
    if (lowerRol.contains('admin')) {
      normalizedRol = 'Administrador';
    } else if (lowerRol.contains('institucion')) {
      normalizedRol = 'Institucion';
    } else if (lowerRol.contains('cocina') || lowerRol.contains('encargado')) {
      normalizedRol = 'Empleado';
    }

    // A. Validación previa de unicidad consultando la VIEW `vista_usuarios`
    if (cleanCi.isNotEmpty) {
      final existingCi = await getUsuarioByCi(cleanCi);
      if (existingCi != null) {
        throw Exception('El número de C.I. "$cleanCi" ya se encuentra registrado en el sistema.');
      }
    }

    final existingEmail = await getUsuarioByEmail(cleanEmail);
    if (existingEmail != null) {
      throw Exception('El correo electrónico "$cleanEmail" ya está en uso.');
    }

    if (cleanTelefono.isNotEmpty) {
      final existingPhone = await supabase
          .from(viewName)
          .select('id_usuario, telefono')
          .eq('telefono', cleanTelefono)
          .maybeSingle();

      if (existingPhone != null) {
        throw Exception('El teléfono "$cleanTelefono" ya se encuentra registrado.');
      }
    }

    // B. Cliente temporal aislado para no alterar la sesión del Administrador
    final tempClient = SupabaseClient(
      supabaseUrl,
      supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );

    final finalPassword = password.trim().isNotEmpty ? password.trim() : '123456';

    // C. Registro en Supabase Auth. El trigger `on_auth_user_created` se encarga de crear
    // los registros correspondientes en `persona` y `usuario`.
    final response = await tempClient.auth.signUp(
      email: cleanEmail,
      password: finalPassword,
      data: {
        'nombre': cleanNombre,
        'nombres': cleanNombre,
        'apellidos': cleanApellidos,
        'ci_codigo': cleanCi,
        'telefono': cleanTelefono,
        'rol': normalizedRol,
      },
    );

    if (response.user == null) {
      throw Exception('No se pudo completar el registro del usuario en Supabase Auth.');
    }

    return response;
  }

  // ===========================================================================
  // 3. ACTUALIZACIONES Y ESTADO DE ACCESO
  // ===========================================================================

  /// Anula o reactiva el acceso de un usuario modificando el campo `activo` en `public.usuario`.
  static Future<dynamic> toggleUserStatus(String idUsuario, bool nuevoEstado) async {
    final data = await supabase
        .from('usuario')
        .update({'activo': nuevoEstado})
        .eq('id_usuario', idUsuario)
        .select();

    return data;
  }

  /// Actualiza los datos personales (nombre, apellidos, telefono) en la tabla `persona`
  /// y opcionalmente el `ci_codigo` en la tabla `usuario`.
  static Future<dynamic> updateUserProfile({
    required String idUsuario,
    required String nombre,
    required String apellidos,
    String? telefono,
    String? ciCodigo,
  }) async {
    final cleanNombre = nombre.trim();
    final cleanApellidos = apellidos.trim();
    final cleanTelefono = telefono?.trim();

    // Obtener id_persona asociado
    final userRow = await supabase
        .from('usuario')
        .select('id_persona')
        .eq('id_usuario', idUsuario)
        .maybeSingle();

    final personaId = userRow?['id_persona'] ?? idUsuario;

    final data = await supabase
        .from('persona')
        .update({
          'nombre': cleanNombre,
          'apellidos': cleanApellidos,
          'telefono': cleanTelefono != null && cleanTelefono.isNotEmpty ? cleanTelefono : null,
        })
        .eq('id_persona', personaId)
        .select();

    if (ciCodigo != null && ciCodigo.trim().isNotEmpty) {
      await supabase
          .from('usuario')
          .update({'ci_codigo': ciCodigo.trim()})
          .eq('id_usuario', idUsuario);
    }

    return data;
  }

  /// Elimina un usuario de la base de datos (cascada hacia usuario/persona).
  static Future<void> deleteUser(String idUsuario) async {
    // 1. Eliminar familiares asociados si existen
    await supabase.from('familiar').delete().eq('id_usuario', idUsuario);

    // 2. Eliminar de la tabla usuario
    await supabase.from('usuario').delete().eq('id_usuario', idUsuario);

    // 3. Eliminar de la tabla persona
    await supabase.from('persona').delete().eq('id_persona', idUsuario);
  }

  // ===========================================================================
  // 4. GESTIÓN DE FAMILIARES ASOCIADOS AL USUARIO
  // ===========================================================================

  /// Lista los familiares asociados a un usuario empleado.
  static Future<List<Map<String, dynamic>>> getFamiliaresByUsuario(String idUsuario) async {
    try {
      final data = await supabase
          .from('familiar')
          .select('''
            *,
            persona:id_persona (
              id_persona,
              nombre,
              apellidos,
              telefono
            )
          ''')
          .eq('id_usuario', idUsuario);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('ℹ️ Fallback consulta familiares sin relación anidada: $e');
      final fData = await supabase
          .from('familiar')
          .select()
          .eq('id_usuario', idUsuario);

      if (fData.isEmpty) return [];

      final personaIds = fData
          .map((f) => f['id_persona'])
          .where((id) => id != null)
          .toList();

      if (personaIds.isEmpty) return List<Map<String, dynamic>>.from(fData);

      final personasData = await supabase
          .from('persona')
          .select()
          .inFilter('id_persona', personaIds);

      final personasList = List<Map<String, dynamic>>.from(personasData);

      return fData.map<Map<String, dynamic>>((f) {
        final matched = personasList.firstWhere(
          (p) => p['id_persona'] == f['id_persona'],
          orElse: () => <String, dynamic>{},
        );
        return {
          ...f,
          'persona': matched.isNotEmpty ? matched : null,
        };
      }).toList();
    }
  }

  /// Normaliza el parentesco para que coincida exactamente con el enum de Supabase (Esposo, Esposa, Hijo, Hija)
  static String normalizeParentesco(String parentesco) {
    switch (parentesco.trim().toLowerCase()) {
      case 'esposo':
        return 'Esposo';
      case 'esposa':
      case 'cónyuge':
      case 'conyuge':
        return 'Esposa';
      case 'hija':
        return 'Hija';
      case 'hijo':
      default:
        return 'Hijo';
    }
  }

  /// Registra un nuevo familiar vinculado a un empleado.
  static Future<Map<String, dynamic>> createFamiliar({
    required String idUsuario,
    required String parentesco,
    required String nombre,
    required String apellidos,
    String? telefono,
  }) async {
    final cleanParentesco = normalizeParentesco(parentesco);

    // 1. Insertar en tabla persona
    final personaData = await supabase
        .from('persona')
        .insert({
          'nombre': nombre.trim(),
          'apellidos': apellidos.trim(),
          'telefono': telefono != null && telefono.trim().isNotEmpty ? telefono.trim() : null,
        })
        .select()
        .single();

    final idPersona = personaData['id_persona'];

    // 2. Vincular en tabla familiar
    try {
      final familiarData = await supabase
          .from('familiar')
          .insert({
            'id_persona': idPersona,
            'id_usuario': idUsuario,
            'parentesco': cleanParentesco,
          })
          .select()
          .single();

      return {
        ...familiarData,
        'persona': personaData,
      };
    } catch (err) {
      await supabase.from('persona').delete().eq('id_persona', idPersona);
      rethrow;
    }
  }

  /// Actualiza los datos de un familiar y/o su persona asociada.
  static Future<void> updateFamiliar({
    required String idFamiliar,
    String? parentesco,
    String? nombre,
    String? apellidos,
    String? telefono,
  }) async {
    final client = supabase;
    final fam = await client
        .from('familiar')
        .select('id_persona')
        .eq('id_familiar', idFamiliar)
        .maybeSingle();

    if (parentesco != null && parentesco.isNotEmpty) {
      final cleanParentesco = normalizeParentesco(parentesco);
      await client
          .from('familiar')
          .update({'parentesco': cleanParentesco})
          .eq('id_familiar', idFamiliar);
    }

    final idPersona = fam?['id_persona'];
    if (idPersona != null) {
      final updates = <String, dynamic>{};
      if (nombre != null && nombre.isNotEmpty) updates['nombre'] = nombre.trim();
      if (apellidos != null && apellidos.isNotEmpty) updates['apellidos'] = apellidos.trim();
      if (telefono != null) updates['telefono'] = telefono.trim();
      if (updates.isNotEmpty) {
        await client.from('persona').update(updates).eq('id_persona', idPersona);
      }
    }
  }

  /// Elimina un familiar y su registro en la tabla persona.
  /// Acepta el ID del familiar (`id_familiar`) o el `id_persona`.
  static Future<void> deleteFamiliar(String idFamiliarOrPersona, [String? idUsuario]) async {
    final client = supabase;
    // Si viene idUsuario, intentar primero por (id_persona, id_usuario)
    if (idUsuario != null) {
      try {
        await client
            .from('familiar')
            .delete()
            .eq('id_persona', idFamiliarOrPersona)
            .eq('id_usuario', idUsuario);
        await client.from('persona').delete().eq('id_persona', idFamiliarOrPersona);
        return;
      } catch (_) {}
    }

    // Intentar buscar por id_familiar
    try {
      final fam = await client
          .from('familiar')
          .select('id_persona')
          .eq('id_familiar', idFamiliarOrPersona)
          .maybeSingle();

      await client.from('familiar').delete().eq('id_familiar', idFamiliarOrPersona);

      final idPersona = fam?['id_persona'];
      if (idPersona != null) {
        await client.from('persona').delete().eq('id_persona', idPersona);
      }
    } catch (_) {
      // Fallback: eliminar directamente por id_persona
      await client.from('familiar').delete().eq('id_persona', idFamiliarOrPersona);
      await client.from('persona').delete().eq('id_persona', idFamiliarOrPersona);
    }
  }
}
