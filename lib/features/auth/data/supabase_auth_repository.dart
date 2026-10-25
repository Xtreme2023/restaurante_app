import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/supabase/usuarios_service.dart';

class SupabaseAuthRepository {
  UserProfile? _localSession;

  bool get hasActiveSession {
    final client = SupabaseConfig.client;
    return client == null
        ? _localSession != null
        : client.auth.currentSession != null;
  }

  Future<void> createPasswordResetRequest({
    required String email,
    String? message,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw Exception(
        'Supabase no está disponible para registrar la solicitud.',
      );
    }
    await client.from('password_reset_requests').insert({
      'email': email.trim().toLowerCase(),
      'message': message?.trim().isEmpty == true ? null : message?.trim(),
    });
  }

  static final UserProfile demoEmpleado = UserProfile(
    id: 'demo-user-123',
    email: 'juan.empleado@institucion.gob.bo',
    fullName: 'Juan Pérez',
    role: 'empleado',
    department: 'Finanzas y Contabilidad',
    isPensioner: true,
    monthlyExpense: 308.0,
  );

  static final UserProfile demoAdmin = UserProfile(
    id: 'demo-admin-789',
    email: 'admin.rrhh@institucion.gob.bo',
    fullName: 'Lic. Mariana Gómez',
    role: 'admin',
    department: 'Dirección de Recursos Humanos',
    isPensioner: false,
    monthlyExpense: 0.0,
  );

  static final UserProfile demoCocina = UserProfile(
    id: 'demo-chef-456',
    email: 'carlos.chef@restaurante.com',
    fullName: 'Chef Carlos Mendoza',
    role: 'cocina',
    department: 'Cocina & Restaurante',
    isPensioner: false,
    monthlyExpense: 0.0,
  );

  // Aliases para compatibilidad hacia atrás
  static UserProfile get demoInstitucion => demoAdmin;
  static UserProfile get demoEncargado => demoCocina;

  Future<UserProfile?> getCurrentUser() async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return _localSession;
    }

    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return _localSession;
      }

      final profile = await _loadRemoteProfile(
        client,
        userId: user.id,
        email: user.email,
      );
      if (profile != null) {
        return profile;
      }

      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: user.userMetadata?['full_name'] ?? 'Usuario',
        role: user.userMetadata?['role'] ?? 'empleado',
      );
    } catch (e) {
      debugPrint('⚠️ Error obteniendo usuario actual de Supabase: $e');
      return _localSession;
    }
  }

  Future<UserProfile> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    final client = SupabaseConfig.client;

    if (client == null) {
      // Modo demo / offline: login simulado según credenciales o dominio
      return _mockSignIn(email);
    }

    try {
      final authRes = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = authRes.user;
      if (user == null) {
        throw Exception('Supabase no devolvió el usuario autenticado.');
      }

      final profile = await _loadRemoteProfile(
        client,
        userId: user.id,
        email: user.email ?? email,
      );

      if (profile != null) {
        if (!profile.activo) {
          await client.auth.signOut();
          throw Exception(
            'Esta cuenta ha sido desactivada. Comuníquese con el administrador.',
          );
        }
        _localSession = profile;
        return profile;
      }

      // Si no existe fila en vista_usuarios, usar metadatos como respaldo
      final fallbackProfile = UserProfile(
        id: user.id,
        email: user.email ?? email,
        fullName: user.userMetadata?['nombre_completo'] ??
            user.userMetadata?['full_name'] ??
            'Usuario',
        role: user.userMetadata?['rol'] ??
            user.userMetadata?['role'] ??
            'empleado',
      );
      _localSession = fallbackProfile;
      return fallbackProfile;
    } on AuthRetryableFetchException catch (e) {
      debugPrint(
        '⚠️ Supabase Auth no está disponible ($e). Usando sesión local temporal.',
      );
      return _mockSignIn(email);
    } on AuthApiException catch (e) {
      debugPrint('⚠️ Falló login remoto en Supabase ($e).');
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Falló login remoto en Supabase ($e).');
      rethrow;
    }
  }

  Future<UserProfile?> _loadRemoteProfile(
    SupabaseClient client, {
    required String userId,
    required String? email,
  }) async {
    final normalizedEmail = email?.trim().toLowerCase();

    // 1. Consulta exclusiva a la vista vista_usuarios por id_usuario
    try {
      final vistaData = await UsuariosService.getUsuarioById(userId);
      if (vistaData != null) {
        return UserProfile.fromJson(vistaData);
      }
    } catch (e) {
      debugPrint('ℹ️ Error leyendo vista_usuarios por id_usuario: $e');
    }

    // 2. Consulta a vista_usuarios por email
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      try {
        final vistaData = await UsuariosService.getUsuarioByEmail(normalizedEmail);
        if (vistaData != null) {
          return UserProfile.fromJson(vistaData);
        }
      } catch (e) {
        debugPrint('ℹ️ Error leyendo vista_usuarios por email: $e');
      }
    }

    return null;
  }

  UserProfile _mockSignIn(String email) {
    final lower = email.toLowerCase();
    UserProfile prof;
    if (lower.contains('admin') || lower.contains('institucion')) {
      prof = demoAdmin.copyWith(
        email: email,
        fullName: 'Administrador ${email.split('@').first}',
      );
    } else if (lower.contains('cocina') ||
        lower.contains('chef') ||
        lower.contains('encargado')) {
      prof = demoCocina.copyWith(
        email: email,
        fullName: 'Cocinero ${email.split('@').first}',
      );
    } else {
      prof = demoEmpleado.copyWith(
        email: email,
        fullName: email.split('@').first.toUpperCase(),
      );
    }
    _localSession = prof;
    return prof;
  }

  Future<UserProfile> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      final profile = UserProfile(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        fullName: fullName,
        role: role,
      );
      _localSession = profile;
      return profile;
    }

    final parts = fullName.trim().split(' ');
    final firstName = parts.isNotEmpty ? parts.first : fullName.trim();
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : ' ';
    final normalizedRol = role.toLowerCase().contains('admin')
        ? 'Administrador'
        : role.toLowerCase().contains('institucion')
            ? 'Institucion'
            : 'Empleado';

    final res = await client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'nombre': firstName,
        'nombres': firstName,
        'apellidos': lastName,
        'ci_codigo': 'CI-${DateTime.now().millisecondsSinceEpoch}',
        'telefono': '70000000',
        'rol': normalizedRol,
      },
    );

    final user = res.user;
    if (user == null) {
      throw Exception('Error al registrar usuario');
    }

    final profile = UserProfile(
      id: user.id,
      email: email,
      fullName: fullName,
      role: role,
    );

    if (client.auth.currentSession != null) {
      _localSession = profile;
    }
    return profile;
  }

  Future<void> signOut() async {
    _localSession = null;
    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (e) {
        debugPrint('⚠️ Error cerrando sesión en Supabase: $e');
      }
    }
  }

  Future<void> updatePassword(String newPassword) async {
    final client = SupabaseConfig.client;
    if (client != null && client.auth.currentUser != null) {
      try {
        final res = await client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        if (res.user == null) {
          throw Exception(
            'No se pudo actualizar la contraseña en Supabase Auth.',
          );
        }
        debugPrint('✅ Contraseña actualizada en Supabase Auth.');
      } catch (e) {
        debugPrint('⚠️ Error actualizando contraseña en Supabase: $e');
        rethrow;
      }
    } else {
      // En modo local / demo: la contraseña se actualiza en memoria sin alterar sesión ni datos de BD
      debugPrint(
        'ℹ️ Contraseña actualizada en modo demo/local sin alterar datos de BD.',
      );
    }
  }

  void switchDemoUser(UserProfile demoUser) {
    _localSession = demoUser;
  }
}
