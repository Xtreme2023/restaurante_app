import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:restaurante_app/features/admin/domain/admin_employee_entity.dart';
import 'package:restaurante_app/features/familiares/data/supabase_family_repository.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/familiares/domain/family_policy.dart';
import 'package:restaurante_app/supabase/usuarios_service.dart';

class SupabaseAdminRepository {
  bool lastCreatedUserRequiresEmailConfirmation = false;

  String _databaseParentesco(String parentesco) {
    return UsuariosService.normalizeParentesco(parentesco);
  }

  // Almacén en memoria de empleados y sus familiares asociados para demo y modo local
  final List<AdminEmployee> _employees = [
    AdminEmployee(
      id: 'demo-user-123',
      ci: '4839201',
      nombres: 'Juan',
      apellidos: 'Pérez Mendoza',
      email: 'juan.empleado@institucion.gob.bo',
      telefono: '70612345',
      departamento: 'Finanzas y Contabilidad',
      rol: 'EMPLEADO',
      hasMonthlyPlan: true,
      creadoEn: DateTime.now().subtract(const Duration(days: 90)),
      familiares: const [
        Familiar(
          id: 'fam-1',
          empleadoId: 'demo-user-123',
          ci: '8492011',
          nombres: 'Sofía',
          apellidos: 'Pérez',
          parentesco: 'Hija',
          activo: true,
        ),
        Familiar(
          id: 'fam-2',
          empleadoId: 'demo-user-123',
          ci: '8492012',
          nombres: 'Mateo',
          apellidos: 'Pérez',
          parentesco: 'Hijo',
          activo: true,
        ),
        Familiar(
          id: 'fam-3',
          empleadoId: 'demo-user-123',
          ci: '5938210',
          nombres: 'Carmen',
          apellidos: 'López',
          parentesco: 'Cónyuge',
          activo: true,
        ),
      ],
    ),
    AdminEmployee(
      id: 'demo-emp-002',
      ci: '6192843',
      nombres: 'Roberto',
      apellidos: 'Flores Vargas',
      email: 'roberto.flores@institucion.gob.bo',
      telefono: '71598234',
      departamento: 'Tecnología e Informática',
      rol: 'EMPLEADO',
      hasMonthlyPlan: false, // Tarifa particular 18 Bs
      creadoEn: DateTime.now().subtract(const Duration(days: 60)),
      familiares: const [
        Familiar(
          id: 'fam-4',
          empleadoId: 'demo-emp-002',
          ci: '9128374',
          nombres: 'Elena',
          apellidos: 'Flores',
          parentesco: 'Hija',
          activo: true,
        ),
      ],
    ),
    AdminEmployee(
      id: 'demo-emp-003',
      ci: '5201948',
      nombres: 'Claudia',
      apellidos: 'Gutiérrez Rojas',
      email: 'claudia.gutierrez@institucion.gob.bo',
      telefono: '72034918',
      departamento: 'Recursos Humanos',
      rol: 'EMPLEADO',
      hasMonthlyPlan: true, // Plan Mensual 15 Bs
      creadoEn: DateTime.now().subtract(const Duration(days: 45)),
      familiares: const [
        Familiar(
          id: 'fam-5',
          empleadoId: 'demo-emp-003',
          ci: '7391028',
          nombres: 'David',
          apellidos: 'Montaño',
          parentesco: 'Cónyuge',
          activo: true,
        ),
        Familiar(
          id: 'fam-6',
          empleadoId: 'demo-emp-003',
          ci: '8392019',
          nombres: 'Camila',
          apellidos: 'Montaño',
          parentesco: 'Hija',
          activo: true,
        ),
      ],
    ),
    AdminEmployee(
      id: 'demo-emp-004',
      ci: '3928104',
      nombres: 'Gonzalo',
      apellidos: 'Mamani Quispe',
      email: 'gonzalo.mamani@institucion.gob.bo',
      telefono: '76829104',
      departamento: 'Dirección Ejecutiva',
      rol: 'EMPLEADO',
      hasMonthlyPlan: false, // Tarifa particular 18 Bs
      creadoEn: DateTime.now().subtract(const Duration(days: 30)),
      familiares: const [],
    ),
  ];

  Future<List<Map<String, dynamic>>> getPasswordResetRequests() async {
    final client = SupabaseConfig.client;
    if (client == null) return const [];
    try {
      final response = await client
          .from('password_reset_requests')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      // Retornar lista vacía si la tabla no existe en Supabase (evita 404 en la app)
      return const [];
    }
  }

  Future<void> updatePasswordResetRequest({
    required String id,
    String newPassword = '123456',
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw Exception('Supabase no está disponible.');
    }
    await client.rpc(
      'attend_password_reset_request',
      params: {'p_request_id': id, 'p_new_password': newPassword},
    );
  }

  /// Obtiene la lista completa de empleados con sus familiares consultando la VIEW `vista_usuarios`
  Future<List<AdminEmployee>> getEmployees() async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return List.unmodifiable(_employees);
    }

    try {
      final data = await UsuariosService.getUsuarios();
      if (data.isEmpty) {
        return const [];
      }

      Set<String> pensionedUserIds = {};
      Set<String> pensionedFamiliarIds = {};
      try {
        final pensionRes = await client
            .from('pension')
            .select('id_usuario, id_familiar, modalidad')
            .eq('modalidad', 'Pensionado');
        for (final row in (pensionRes as List<dynamic>)) {
          final uId = row['id_usuario']?.toString();
          final fId = row['id_familiar']?.toString();
          if (fId != null && fId.isNotEmpty) {
            pensionedFamiliarIds.add(fId);
          } else if (uId != null && uId.isNotEmpty) {
            pensionedUserIds.add(uId);
          }
        }
      } catch (e) {
        debugPrint('ℹ️ No se pudo cargar estado de pensiones: $e');
      }

      final List<AdminEmployee> employees = [];
      for (final item in data) {
        final idUsuario = (item['id_usuario'] ?? item['id'] ?? '').toString();

        List<Familiar> familiares = [];
        try {
          final rawFamiliares = await UsuariosService.getFamiliaresByUsuario(
            idUsuario,
          );
          familiares = rawFamiliares.map((f) {
            final persona = f['persona'] as Map<String, dynamic>?;
            final famId = (f['id_familiar'] ?? f['id'] ?? '').toString();
            return Familiar(
              id: famId,
              empleadoId: idUsuario,
              ci: '',
              telefono: (persona?['telefono'] ?? f['telefono'] ?? '')
                  .toString(),
              nombres: (persona?['nombre'] ?? f['nombres'] ?? f['nombre'] ?? '')
                  .toString(),
              apellidos: (persona?['apellidos'] ?? f['apellidos'] ?? '')
                  .toString(),
              parentesco: f['parentesco']?.toString() ?? 'Hijo',
              activo: f['activo'] != false,
              hasMonthlyPlan: pensionedFamiliarIds.contains(famId),
            );
          }).toList();
        } catch (_) {}

        final emp = AdminEmployee.fromJson(item, familiares: familiares);
        employees.add(emp.copyWith(
          hasMonthlyPlan:
              pensionedUserIds.contains(idUsuario) || emp.hasMonthlyPlan,
        ));
      }
      return employees;
    } catch (e) {
      debugPrint('⚠️ Error obteniendo empleados desde vista_usuarios: $e');
      throw Exception(
        'No se pudo cargar el padrón de empleados desde la vista vista_usuarios. '
        'Detalle: $e',
      );
    }
  }

  /// Registra un nuevo empleado junto a sus familiares iniciales
  Future<AdminEmployee> createEmployee({
    required String ci,
    required String nombres,
    required String apellidos,
    required String email,
    String password = '123456',
    required String telefono,
    required String departamento,
    required bool hasMonthlyPlan,
    List<Map<String, String>> initialFamiliares = const [],
  }) async {
    // Validación de duplicados en la lista local antes de persistir
    final trimmedCi = ci.trim();
    final trimmedEmail = email.trim().toLowerCase();
    lastCreatedUserRequiresEmailConfirmation = false;

    if (_employees.any((e) => e.ci.trim() == trimmedCi)) {
      throw Exception(
        'El usuario ya está registrado con la cédula de identidad (CI) $trimmedCi.',
      );
    }
    if (_employees.any((e) => e.email.trim().toLowerCase() == trimmedEmail)) {
      throw Exception(
        'El usuario ya está registrado con el correo institucional $trimmedEmail.',
      );
    }

    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres.');
    }

    var newId = const Uuid().v4();
    final List<Familiar> addedFamiliares = [];

    // Limitar familiares iniciales al máximo legal de 3
    final limitedList = initialFamiliares.take(
      FamilyPolicy.maxFamilyMembersPerEmployee,
    );
    int famIndex = 1;
    for (final famData in limitedList) {
      if ((famData['nombres'] ?? '').trim().isNotEmpty) {
        addedFamiliares.add(
          Familiar(
            id: 'fam-$newId-${famIndex++}',
            empleadoId: newId,
            ci: '',
            telefono: famData['telefono'] ?? famData['ci'] ?? '',
            nombres: famData['nombres'] ?? '',
            apellidos: famData['apellidos'] ?? apellidos,
            parentesco: famData['parentesco'] ?? 'Familiar',
            activo: true,
          ),
        );
      }
    }

    var newEmployee = AdminEmployee(
      id: newId,
      ci: trimmedCi,
      nombres: nombres.trim(),
      apellidos: apellidos.trim(),
      email: trimmedEmail,
      telefono: telefono.trim(),
      departamento: departamento.trim(),
      rol: 'EMPLEADO',
      hasMonthlyPlan: hasMonthlyPlan,
      activo: true,
      creadoEn: DateTime.now(),
      familiares: addedFamiliares,
    );

    final client = SupabaseConfig.client;
    if (client == null || !SupabaseConfig.isInitialized) {
      _employees.insert(0, newEmployee);
      return newEmployee;
    }
    if (client.auth.currentUser == null) {
      throw Exception(
        'Debes iniciar sesión con una cuenta administrativa de Supabase '
        'para guardar empleados.',
      );
    }

    try {
      // 1. Registro usando UsuariosService con auth.signUp y trigger on_auth_user_created
      final cleanPassword = password.trim().isNotEmpty
          ? password.trim()
          : '123456';
      final authResponse = await UsuariosService.registerUser(
        email: trimmedEmail,
        password: cleanPassword,
        nombre: nombres,
        apellidos: apellidos,
        ciCodigo: trimmedCi,
        telefono: telefono,
        rol: 'Empleado',
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('No se pudo registrar la cuenta en Supabase Auth.');
      }
      newId = user.id;
      lastCreatedUserRequiresEmailConfirmation = false;

      // 2. Registrar familiares asociados si fueron definidos
      for (final family in addedFamiliares) {
        try {
          await UsuariosService.createFamiliar(
            idUsuario: newId,
            parentesco: _databaseParentesco(family.parentesco),
            nombre: family.nombres,
            apellidos: family.apellidos,
            telefono: family.telefono,
          );
        } catch (fErr) {
          debugPrint('Aviso: no se pudo registrar familiar: $fErr');
        }
      }

      newEmployee = newEmployee.copyWith(
        id: newId,
        familiares: newEmployee.familiares
            .map((familiar) => familiar.copyWith(empleadoId: newId))
            .toList(),
      );
    } catch (e) {
      debugPrint(
        '⚠️ Error registrando empleado con trigger on_auth_user_created: $e',
      );
      rethrow;
    }

    _employees.insert(0, newEmployee);
    return newEmployee;
  }

  /// Actualiza los datos de un empleado utilizando UsuariosService
  Future<void> updateEmployee(AdminEmployee updated) async {
    final index = _employees.indexWhere((e) => e.id == updated.id);
    if (index != -1) {
      _employees[index] = updated;
    }

    final client = SupabaseConfig.client;
    if (client != null && SupabaseConfig.isInitialized) {
      try {
        await UsuariosService.updateUserProfile(
          idUsuario: updated.id,
          nombre: updated.nombres,
          apellidos: updated.apellidos,
          telefono: updated.telefono,
          ciCodigo: updated.ci,
        );
      } catch (e) {
        debugPrint('⚠️ Error actualizando empleado en UsuariosService: $e');
      }
    }
  }

  /// Borra los datos y registros de prueba correspondientes a
  /// 'empleado', 'administrador' y 'cocina' tanto en memoria como en Supabase.
  Future<Map<String, dynamic>> clearTestData() async {
    // 1. Limpieza en memoria local
    _employees.removeWhere(
      (e) =>
          e.id.startsWith('demo-') ||
          e.email.toLowerCase().contains('empleado') ||
          e.email.toLowerCase().contains('admin') ||
          e.email.toLowerCase().contains('chef') ||
          e.email.toLowerCase().contains('cocina'),
    );

    // Limpieza de familiares en memoria
    SupabaseFamilyRepository.clearMockFamilyStore();

    // 2. Si Supabase está conectado, borrar registros de prueba de BD
    final client = SupabaseConfig.client;
    if (client != null && SupabaseConfig.isInitialized) {
      try {
        await client.rpc('limpiar_datos_prueba');
      } catch (e) {
        debugPrint(
          'ℹ️ RPC limpiar_datos_prueba no disponible, borrado seguro: $e',
        );
        final testIds = [
          'demo-user-123',
          'demo-admin-789',
          'demo-chef-456',
          'demo-emp-002',
          'demo-emp-003',
          'demo-emp-004',
        ];

        for (final uid in testIds) {
          try {
            await UsuariosService.deleteUser(uid);
          } catch (_) {}
          try {
            await client.from('reservas').delete().eq('empleado_id', uid);
          } catch (_) {}
          try {
            await client.from('reservations').delete().eq('user_id', uid);
          } catch (_) {}
        }
      }
    }

    return {
      'success': true,
      'message':
          'Registros de prueba de empleado, administrador y cocina borrados con éxito.',
    };
  }

  /// Elimina un empleado mediante UsuariosService
  Future<void> deleteEmployee(String employeeId) async {
    final client = SupabaseConfig.client;
    if (client == null || !SupabaseConfig.isInitialized) {
      _employees.removeWhere((e) => e.id == employeeId);
      return;
    }

    try {
      await UsuariosService.deleteUser(employeeId);
      _employees.removeWhere((e) => e.id == employeeId);
    } catch (e) {
      debugPrint('⚠️ Error al eliminar empleado: $e');
      throw Exception(
        'No se pudo eliminar el empleado en Supabase. '
        'Detalle: $e',
      );
    }
  }

  /// Agrega un familiar a un empleado respetando el límite de 3
  Future<bool> addFamiliar(String employeeId, Familiar familiar) async {
    final empIndex = _employees.indexWhere((e) => e.id == employeeId);
    if (empIndex == -1) return false;

    final currentEmp = _employees[empIndex];
    if (currentEmp.familiares.length >=
        FamilyPolicy.maxFamilyMembersPerEmployee) {
      return false; // Cupo máximo alcanzado
    }

    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        await UsuariosService.createFamiliar(
          idUsuario: employeeId,
          parentesco: _databaseParentesco(familiar.parentesco),
          nombre: familiar.nombres,
          apellidos: familiar.apellidos,
          telefono: familiar.telefono,
        );
      } catch (e) {
        debugPrint('⚠️ Error insertando familiar en Supabase: $e');
        throw Exception('No se pudo guardar el familiar en Supabase: $e');
      }
    }

    _employees[empIndex] = currentEmp.copyWith(
      familiares: [...currentEmp.familiares, familiar],
    );
    return true;
  }

  /// Elimina un familiar asociado
  Future<void> deleteFamiliar(String employeeId, String familiarId) async {
    final empIndex = _employees.indexWhere((e) => e.id == employeeId);
    if (empIndex != -1) {
      final currentEmp = _employees[empIndex];
      final updatedFamiliares = currentEmp.familiares
          .where((f) => f.id != familiarId)
          .toList();
      _employees[empIndex] = currentEmp.copyWith(familiares: updatedFamiliares);
    }

    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        await UsuariosService.deleteFamiliar(familiarId);
      } catch (e) {
        debugPrint('⚠️ Error eliminando familiar en Supabase: $e');
      }
    }
  }

  Future<void> updateFamiliar(String employeeId, Familiar familiar) async {
    final empIndex = _employees.indexWhere((e) => e.id == employeeId);
    if (empIndex == -1) {
      throw Exception('No se encontró el empleado.');
    }

    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        await UsuariosService.updateFamiliar(
          idFamiliar: familiar.id,
          parentesco: _databaseParentesco(familiar.parentesco),
          nombre: familiar.nombres,
          apellidos: familiar.apellidos,
          telefono: familiar.telefono,
        );
      } catch (e) {
        debugPrint('⚠️ Error actualizando familiar en Supabase: $e');
        throw Exception('No se pudo actualizar el familiar en Supabase: $e');
      }
    }

    final currentEmp = _employees[empIndex];
    _employees[empIndex] = currentEmp.copyWith(
      familiares: currentEmp.familiares
          .map((current) => current.id == familiar.id ? familiar : current)
          .toList(),
    );
  }

  /// Alterna o activa el plan mensual (tarifa Bs. 15 vs Bs. 18) para empleado o familiar
  Future<void> toggleMonthlyPlan(
    String employeeId,
    bool hasPlan, {
    String? familiarId,
  }) async {
    final empIndex = _employees.indexWhere((e) => e.id == employeeId);
    if (empIndex != -1) {
      final currentEmp = _employees[empIndex];
      if (familiarId != null) {
        final updatedFams = currentEmp.familiares.map((f) {
          if (f.id == familiarId) {
            return f.copyWith(hasMonthlyPlan: hasPlan);
          }
          return f;
        }).toList();
        _employees[empIndex] = currentEmp.copyWith(familiares: updatedFams);
      } else {
        _employees[empIndex] = currentEmp.copyWith(
          hasMonthlyPlan: hasPlan,
        );
      }
    }

    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        final now = DateTime.now();
        final modalidad = hasPlan ? 'Pensionado' : 'Regular';
        if (familiarId != null) {
          final existing = await client
              .from('pension')
              .select('id_pension')
              .eq('id_familiar', familiarId)
              .maybeSingle();

          if (existing != null && existing['id_pension'] != null) {
            await client
                .from('pension')
                .update({'modalidad': modalidad})
                .eq('id_pension', existing['id_pension']);
          } else if (hasPlan) {
            await client.from('pension').insert({
              'id_usuario': employeeId,
              'id_familiar': familiarId,
              'year': now.year,
              'mes': now.month,
              'modalidad': 'Pensionado',
            });
          }
        } else {
          final existing = await client
              .from('pension')
              .select('id_pension')
              .eq('id_usuario', employeeId)
              .isFilter('id_familiar', null)
              .maybeSingle();

          if (existing != null && existing['id_pension'] != null) {
            await client
                .from('pension')
                .update({'modalidad': modalidad})
                .eq('id_pension', existing['id_pension']);
          } else if (hasPlan) {
            await client.from('pension').insert({
              'id_usuario': employeeId,
              'id_familiar': null,
              'year': now.year,
              'mes': now.month,
              'modalidad': 'Pensionado',
            });
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error actualizando plan mensual en Supabase: $e');
      }
    }
  }
}
