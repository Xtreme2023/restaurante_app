import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/admin/data/supabase_admin_repository.dart';
import 'package:restaurante_app/features/admin/domain/admin_employee_entity.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';

final adminRepositoryProvider = Provider<SupabaseAdminRepository>((ref) {
  return SupabaseAdminRepository();
});

/// Filtro de Membresías:
/// - 'todos'
/// - 'mensual' (Tarifa Bs. 15)
/// - 'diario'  (Tarifa Bs. 18 / sin plan)
enum MembershipFilter { todos, mensual, diario }

class MembershipFilterNotifier extends Notifier<MembershipFilter> {
  @override
  MembershipFilter build() => MembershipFilter.todos;

  @override
  set state(MembershipFilter value) => super.state = value;

  void setFilter(MembershipFilter filter) {
    state = filter;
  }
}

final membershipFilterProvider =
    NotifierProvider<MembershipFilterNotifier, MembershipFilter>(
      MembershipFilterNotifier.new,
    );

class AdminEmployeesState {
  final List<AdminEmployee> employees;
  final bool isLoading;
  final String? error;

  const AdminEmployeesState({
    required this.employees,
    this.isLoading = false,
    this.error,
  });

  int get totalEmployees => employees.length;
  int get monthlyPlanCount =>
      employees.where((e) => e.hasMonthlyPlan).length +
      employees.fold(
        0,
        (sum, e) => sum + e.familiares.where((f) => f.hasMonthlyPlan).length,
      );
  int get dailyPlanCount =>
      employees.where((e) => !e.hasMonthlyPlan).length +
      employees.fold(
        0,
        (sum, e) => sum + e.familiares.where((f) => !f.hasMonthlyPlan).length,
      );
  int get totalFamilyCount =>
      employees.fold(0, (prev, e) => prev + e.familiares.length);
  int get familyMonthlyPlanCount => employees.fold(
    0,
    (sum, e) => sum + e.familiares.where((f) => f.hasMonthlyPlan).length,
  );
}

class AdminEmployeesNotifier extends Notifier<AdminEmployeesState> {
  @override
  AdminEmployeesState build() {
    Future.microtask(() => loadEmployees());
    return const AdminEmployeesState(employees: [], isLoading: true);
  }

  Future<void> loadEmployees() async {
    state = AdminEmployeesState(employees: state.employees, isLoading: true);
    final repo = ref.read(adminRepositoryProvider);
    try {
      final list = await repo.getEmployees();
      state = AdminEmployeesState(employees: list, isLoading: false);
    } catch (e) {
      state = AdminEmployeesState(
        employees: state.employees,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> createEmployee({
    required String ci,
    required String nombres,
    required String apellidos,
    required String email,
    required String password,
    required String telefono,
    required String departamento,
    required bool hasMonthlyPlan,
    List<Map<String, String>> initialFamiliares = const [],
  }) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final newEmp = await repo.createEmployee(
        ci: ci,
        nombres: nombres,
        apellidos: apellidos,
        email: email,
        password: password,
        telefono: telefono,
        departamento: departamento,
        hasMonthlyPlan: hasMonthlyPlan,
        initialFamiliares: initialFamiliares,
      );
      state = AdminEmployeesState(
        employees: [newEmp, ...state.employees.where((e) => e.id != newEmp.id)],
        isLoading: false,
        error: null,
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      state = AdminEmployeesState(
        employees: state.employees,
        isLoading: false,
        error: cleanMsg,
      );
      return false;
    }
  }

  Future<bool> updateEmployee(AdminEmployee employee) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateEmployee(employee);
      state = AdminEmployeesState(
        employees: state.employees
            .map((e) => e.id == employee.id ? employee : e)
            .toList(),
        isLoading: false,
        error: null,
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      state = AdminEmployeesState(
        employees: state.employees,
        isLoading: false,
        error: cleanMsg,
      );
      return false;
    }
  }

  Future<bool> deleteEmployee(String employeeId) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.deleteEmployee(employeeId);
      state = AdminEmployeesState(
        employees: state.employees.where((e) => e.id != employeeId).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      state = AdminEmployeesState(
        employees: state.employees,
        isLoading: false,
        error: cleanMsg,
      );
      return false;
    }
  }

  Future<bool> clearTestData() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.clearTestData();
      await loadEmployees();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addFamiliarToEmployee({
    required String employeeId,
    String ci = '',
    String telefono = '',
    required String nombres,
    required String apellidos,
    required String parentesco,
  }) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final familiar = Familiar(
        id: 'fam-$employeeId-${DateTime.now().millisecondsSinceEpoch}',
        empleadoId: employeeId,
        ci: ci,
        telefono: telefono,
        nombres: nombres,
        apellidos: apellidos,
        parentesco: parentesco,
        activo: true,
      );

      final ok = await repo.addFamiliar(employeeId, familiar);
      if (ok) {
        await loadEmployees();
      }
      return ok;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteFamiliarFromEmployee(
    String employeeId,
    String familiarId,
  ) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.deleteFamiliar(employeeId, familiarId);
      await loadEmployees();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateFamiliarForEmployee({
    required String employeeId,
    required Familiar familiar,
  }) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateFamiliar(employeeId, familiar);
      await loadEmployees();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> toggleMonthlyPlan(
    String employeeId,
    bool hasPlan, {
    String? familiarId,
  }) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.toggleMonthlyPlan(employeeId, hasPlan, familiarId: familiarId);
    state = AdminEmployeesState(
      employees: state.employees.map((e) {
        if (e.id == employeeId) {
          if (familiarId != null) {
            final updatedFams = e.familiares.map((f) {
              if (f.id == familiarId) {
                return f.copyWith(hasMonthlyPlan: hasPlan);
              }
              return f;
            }).toList();
            return e.copyWith(familiares: updatedFams);
          } else {
            return e.copyWith(hasMonthlyPlan: hasPlan);
          }
        }
        return e;
      }).toList(),
      isLoading: false,
    );
  }
}

final adminEmployeesProvider =
    NotifierProvider<AdminEmployeesNotifier, AdminEmployeesState>(
      AdminEmployeesNotifier.new,
    );

/// Proveedor de lista filtrada según búsqueda y membresía
final filteredAdminEmployeesProvider = Provider<List<AdminEmployee>>((ref) {
  final state = ref.watch(adminEmployeesProvider);
  final filter = ref.watch(membershipFilterProvider);

  return state.employees.where((emp) {
    switch (filter) {
      case MembershipFilter.mensual:
        return emp.hasMonthlyPlan ||
            emp.familiares.any((f) => f.hasMonthlyPlan);
      case MembershipFilter.diario:
        return !emp.hasMonthlyPlan ||
            emp.familiares.any((f) => !f.hasMonthlyPlan);
      case MembershipFilter.todos:
        return true;
    }
  }).toList();
});
