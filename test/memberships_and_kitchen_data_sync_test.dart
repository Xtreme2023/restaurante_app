import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/admin/domain/admin_employee_entity.dart';
import 'package:restaurante_app/features/admin/presentation/admin_screen.dart';
import 'package:restaurante_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/menu/data/supabase_weekly_menu_repository.dart';
import 'package:restaurante_app/features/menu/domain/bolivian_dish_entity.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';

class MockAdminEmployeesNotifier extends AdminEmployeesNotifier {
  final List<AdminEmployee> initial;
  MockAdminEmployeesNotifier(this.initial);

  @override
  AdminEmployeesState build() {
    return AdminEmployeesState(employees: initial, isLoading: false);
  }

  @override
  Future<void> toggleMonthlyPlan(
    String employeeId,
    bool hasPlan, {
    String? familiarId,
  }) async {
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

class MockAuthNotifier extends AuthNotifier {
  final UserProfile? user;
  MockAuthNotifier(this.user);

  @override
  UserProfile? build() => user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Control de Membresías: Inclusión de Familiares con Pensión', () {
    testWidgets(
      'Membresías tab muestra familiares y su tarifa/switch correspondiente',
      (tester) async {
        final testEmployee = AdminEmployee(
          id: 'emp-101',
          ci: '1234567',
          nombres: 'Ruben',
          apellidos: 'Doblas',
          email: 'ruben@rest.com',
          hasMonthlyPlan: true,
          creadoEn: DateTime(2026, 1, 1),
          familiares: const [
            Familiar(
              id: 'fam-202',
              empleadoId: 'emp-101',
              nombres: 'Irina',
              apellidos: 'Doblas',
              parentesco: 'Esposa',
              hasMonthlyPlan: true, // Familiar con pensión
            ),
            Familiar(
              id: 'fam-203',
              empleadoId: 'emp-101',
              nombres: 'Leo',
              apellidos: 'Doblas',
              parentesco: 'Hijo',
              hasMonthlyPlan: false, // Familiar sin pensión
            ),
          ],
        );

        final adminUser = const UserProfile(
          id: 'admin-1',
          email: 'admin@rest.com',
          fullName: 'Administrador',
          role: 'Administrador',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => MockAuthNotifier(adminUser)),
              adminEmployeesProvider.overrideWith(
                () => MockAdminEmployeesNotifier([testEmployee]),
              ),
            ],
            child: const MaterialApp(home: AdminScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Navegar a la pestaña 'Membresías' (Tab 2)
        final membresiasTab = find.text('Membresías');
        expect(membresiasTab, findsOneWidget);
        await tester.tap(membresiasTab);
        await tester.pumpAndSettle();

        // Verificar que el empleado titular se muestra
        expect(find.text('Ruben Doblas'), findsWidgets);

        // Verificar que los familiares se muestran con su parentesco
        expect(find.text('Irina Doblas (Esposa)'), findsOneWidget);
        expect(find.text('Leo Doblas (Hijo)'), findsOneWidget);

        // Verificar tarifas
        expect(find.textContaining('Plan Mensual'), findsWidgets);
        expect(find.textContaining('Tarifa: Bs. 15.00 por plato (Plan Mensual)'), findsOneWidget);
        expect(find.textContaining('Tarifa: Bs. 18.00 por plato (Diario)'), findsOneWidget);

        // Verificar switches (1 del empleado + 2 de los familiares)
        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(3));
      },
    );
  });

  group('2. Órdenes de Cocina: No se inyectan comensales artificiales', () {
    test(
      'getAllReservationsForDate sólo retorna reservas reales para la fecha',
      () async {
        final repo = SupabaseReservationRepository();
        final targetDate = DateTime(2026, 10, 26);

        // Si no hay conexión o no hay filas, en memoria sólo retorna reservas que coinciden en fecha
        final orders = await repo.getAllReservationsForDate(targetDate);

        // Ninguna orden debe tener id empezando por 'monthly-' generado fiduciariamente
        final hasFictitiousMonthlyOrder = orders.any((o) => o.id.startsWith('monthly-'));
        expect(hasFictitiousMonthlyOrder, isFalse);

        for (final o in orders) {
          expect(o.date.year, equals(targetDate.year));
          expect(o.date.month, equals(targetDate.month));
          expect(o.date.day, equals(targetDate.day));
        }
      },
    );
  });

  group('3. Menú Semanal y Catálogo de Platos desde Base de Datos', () {
    test(
      'SupabaseWeeklyMenuRepository provee getCatalogoPlatos y getMenuSemanal',
      () async {
        final repo = SupabaseWeeklyMenuRepository();
        final catalogo = await repo.getCatalogoPlatos();
        expect(catalogo, isNotEmpty);

        // Cada plato del catálogo tiene ID y nombre válidos
        for (final p in catalogo) {
          expect(p.id, isPositive);
          expect(p.nombre, isNotEmpty);
          expect(p.categoria, isNotEmpty);
        }

        final startOfWeek = DateTime(2026, 10, 26);
        final menuSemanal = await repo.getMenuSemanal(startOfWeek);
        expect(menuSemanal, isA<List<MenuSemanalItem>>());
      },
    );
  });
}
