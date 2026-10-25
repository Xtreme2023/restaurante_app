import 'package:flutter/foundation.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/familiares/domain/family_policy.dart';
import 'package:restaurante_app/features/familiares/domain/family_repository.dart';
import 'package:restaurante_app/supabase/usuarios_service.dart';

class SupabaseFamilyRepository implements FamilyRepository {
  /// Datos de familiares precargados para pruebas y modo offline.
  /// Cada empleado puede tener hasta 3 familiares registrados.
  static final Map<String, List<Familiar>> _mockFamilyStore = {
    'demo-user-123': [
      const Familiar(
        id: 'fam-1',
        empleadoId: 'demo-user-123',
        ci: '8492011',
        nombres: 'Sofía',
        apellidos: 'Pérez',
        parentesco: 'Hija',
        activo: true,
      ),
      const Familiar(
        id: 'fam-2',
        empleadoId: 'demo-user-123',
        ci: '8492012',
        nombres: 'Mateo',
        apellidos: 'Pérez',
        parentesco: 'Hijo',
        activo: true,
      ),
      const Familiar(
        id: 'fam-3',
        empleadoId: 'demo-user-123',
        ci: '5938210',
        nombres: 'Carmen',
        apellidos: 'López',
        parentesco: 'Cónyuge',
        activo: true,
      ),
    ],
  };

  /// Limpia los familiares de prueba en memoria.
  static void clearMockFamilyStore([String? empleadoId]) {
    if (empleadoId != null) {
      _mockFamilyStore[empleadoId] = [];
    } else {
      _mockFamilyStore.clear();
      _mockFamilyStore['demo-user-123'] = [];
      _mockFamilyStore['demo-emp-002'] = [];
      _mockFamilyStore['demo-emp-003'] = [];
      _mockFamilyStore['demo-emp-004'] = [];
    }
  }

  /// Restablece los familiares de prueba iniciales para pruebas.
  static void resetMockFamilyStore() {
    _mockFamilyStore.clear();
    _mockFamilyStore['demo-user-123'] = [
      const Familiar(
        id: 'fam-1',
        empleadoId: 'demo-user-123',
        ci: '8492011',
        nombres: 'Sofía',
        apellidos: 'Pérez',
        parentesco: 'Hija',
        activo: true,
      ),
      const Familiar(
        id: 'fam-2',
        empleadoId: 'demo-user-123',
        ci: '8492012',
        nombres: 'Mateo',
        apellidos: 'Pérez',
        parentesco: 'Hijo',
        activo: true,
      ),
      const Familiar(
        id: 'fam-3',
        empleadoId: 'demo-user-123',
        ci: '5938210',
        nombres: 'Carmen',
        apellidos: 'López',
        parentesco: 'Cónyuge',
        activo: true,
      ),
    ];
  }

  @override
  Future<List<Familiar>> getFamilyMembers(String empleadoId) async {
    final client = SupabaseConfig.client;

    if (client == null) {
      return _getMockFamily(empleadoId);
    }

    try {
      final rawFamiliares =
          await UsuariosService.getFamiliaresByUsuario(empleadoId);
      if (rawFamiliares.isEmpty) {
        return [];
      }

      final list = rawFamiliares.map((f) {
        final persona = f['persona'] as Map<String, dynamic>?;
        return Familiar(
          id: (f['id_familiar'] ?? f['id'] ?? '').toString(),
          empleadoId: (f['id_usuario'] ?? empleadoId).toString(),
          ci: '',
          telefono: (persona?['telefono'] ?? f['telefono'] ?? '').toString(),
          nombres: (persona?['nombre'] ?? f['nombres'] ?? f['nombre'] ?? '')
              .toString(),
          apellidos:
              (persona?['apellidos'] ?? f['apellidos'] ?? '').toString(),
          parentesco: f['parentesco']?.toString() ?? 'Hijo',
          activo: f['activo'] != false,
        );
      }).toList();

      return FamilyPolicy.enforceLimit(list);
    } catch (e) {
      debugPrint(
        '⚠️ Error consultando familiares en Supabase ($e). Usando datos precargados.',
      );
      return _getMockFamily(empleadoId);
    }
  }

  @override
  Future<bool> canUseRestaurantService(
    String empleadoId,
    String familiarId,
  ) async {
    final members = await getFamilyMembers(empleadoId);
    return FamilyPolicy.isFamilyMemberAuthorized(
      familiarId: familiarId,
      employeeFamilyMembers: members,
    );
  }

  List<Familiar> _getMockFamily(String empleadoId) {
    if (_mockFamilyStore.containsKey(empleadoId)) {
      return FamilyPolicy.enforceLimit(_mockFamilyStore[empleadoId]!);
    }
    return [];
  }
}
