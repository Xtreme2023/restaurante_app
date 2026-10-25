import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/admin/data/supabase_admin_repository.dart';
import 'package:restaurante_app/features/admin/presentation/admin_screen.dart';
import 'package:restaurante_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:restaurante_app/features/auth/data/supabase_auth_repository.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/features/auth/presentation/login_screen.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/data/supabase_family_repository.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/presentation/employee_screen.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';
import 'package:restaurante_app/main.dart';

class _StaticAuthNotifier extends AuthNotifier {
  final UserProfile? _user;
  _StaticAuthNotifier(this._user);

  @override
  UserProfile? build() => _user;
}

void main() {
  group('1. Corrección: Registro de Nuevos Usuarios (Módulo Administrador)', () {
    setUp(() {
      SupabaseFamilyRepository.resetMockFamilyStore();
    });

    test('Persistencia y validación de usuarios en repositorio y provider', () async {
      final adminRepo = SupabaseAdminRepository();
      final container = ProviderContainer(
        overrides: [
          adminRepositoryProvider.overrideWithValue(adminRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(adminEmployeesProvider.notifier);

      // 1. Registro exitoso de empleado con familiares
      final ok = await notifier.createEmployee(
        ci: '88442211',
        nombres: 'Carlos Andrés',
        apellidos: 'Vargas Mercado',
        email: 'carlos.vargas@institucion.gob.bo',
        password: 'Password123!',
        telefono: '72233445',
        departamento: 'Recursos Humanos',
        hasMonthlyPlan: true,
        initialFamiliares: [
          {
            'nombres': 'Elena',
            'apellidos': 'Vargas',
            'ci': '993311',
            'parentesco': 'Hija',
          },
        ],
      );

      expect(ok, isTrue);
      final state = container.read(adminEmployeesProvider);
      expect(state.employees.any((e) => e.ci == '88442211'), isTrue);
      expect(state.employees.first.email, equals('carlos.vargas@institucion.gob.bo'));
      expect(state.employees.first.familiares.length, equals(1));
      expect(state.error, isNull);

      // 2. Rechazo de duplicado de CI
      final okDupCi = await notifier.createEmployee(
        ci: '88442211',
        nombres: 'Otro',
        apellidos: 'Usuario',
        email: 'otro.usuario@institucion.gob.bo',
        password: 'Password123!',
        telefono: '71122334',
        departamento: 'Tecnología',
        hasMonthlyPlan: false,
      );

      expect(okDupCi, isFalse);
      expect(container.read(adminEmployeesProvider).error, contains('cédula de identidad'));

      // 3. Rechazo de duplicado de Email
      final okDupEmail = await notifier.createEmployee(
        ci: '77665544',
        nombres: 'Otro',
        apellidos: 'Usuario',
        email: 'carlos.vargas@institucion.gob.bo',
        password: 'Password123!',
        telefono: '71122334',
        departamento: 'Tecnología',
        hasMonthlyPlan: false,
      );

      expect(okDupEmail, isFalse);
      expect(container.read(adminEmployeesProvider).error, contains('correo institucional'));
    });

    testWidgets('Formulario Admin: Valida, persiste y muestra confirmación visible', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final adminRepo = SupabaseAdminRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _StaticAuthNotifier(SupabaseAuthRepository.demoAdmin),
            ),
            adminRepositoryProvider.overrideWithValue(adminRepo),
          ],
          child: const MaterialApp(
            home: AdminScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir modal de nuevo empleado
      final addBtn = find.text('Registrar Empleado');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Registrar Nuevo Empleado'), findsOneWidget);

      // Ingresar datos completos
      await tester.enterText(find.widgetWithText(TextField, 'Nombres'), 'Alejandro');
      await tester.enterText(find.widgetWithText(TextField, 'Apellidos'), 'Guzmán');
      await tester.enterText(find.widgetWithText(TextField, 'Cédula de Identidad (CI)'), '65432199');
      await tester.enterText(find.widgetWithText(TextField, 'Teléfono'), '79988776');
      await tester.enterText(find.widgetWithText(TextField, 'Correo Institucional'), 'alejandro.guzman@institucion.gob.bo');

      // Presionar Guardar Empleado
      final saveBtn = find.widgetWithText(ElevatedButton, 'Registrar y Asociar Familiares');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // El modal debe haberse cerrado y mostrar mensaje de éxito
      expect(find.text('Registrar Nuevo Empleado'), findsNothing);
      expect(find.textContaining('Empleado registrado con éxito'), findsOneWidget);
      expect(find.text('Alejandro Guzmán'), findsWidgets);
    });
  });

  group('2. Implementación: Botón de Logout en la Pantalla de Empleado y Menú', () {
    testWidgets('Logout desde MenuScreen (tab 0) redirige a LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(SupabaseAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider.notifier).setDemoUser(SupabaseAuthRepository.demoEmpleado);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RestauranteApp(),
        ),
      );
      await tester.pumpAndSettle();

      // El empleado aterriza en Menú del Día (tab 0)
      expect(find.text('Menú del Día'), findsOneWidget);

      // El botón de logout debe estar accesible en el AppBar de Menú
      final logoutBtn = find.byTooltip('Cerrar Sesión');
      expect(logoutBtn, findsOneWidget);

      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Diálogo de confirmación
      expect(find.text('¿Estás seguro de que deseas cerrar sesión y salir del sistema de forma segura?'), findsOneWidget);

      // Confirmar
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Cerrar Sesión');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Debe limpiar sesión y redirigir a LoginScreen
      expect(container.read(authProvider), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('3. Menú Dinámico y Platos Reales por Tipo (HU7, HU8, HU9)', () {
    testWidgets('EmployeeScreen muestra platos reales y permite filtrar por tipo de plato', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _StaticAuthNotifier(SupabaseAuthRepository.demoEmpleado),
            ),
          ],
          child: const MaterialApp(
            home: EmployeeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar chips de tipo
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Segundo'), findsOneWidget);
      expect(find.text('Sopa'), findsOneWidget);
      expect(find.text('Vegetariano'), findsOneWidget);

      // Verificar selector de semanas
      expect(find.text('Semana Actual'), findsOneWidget);
      expect(find.text('Semana Siguiente'), findsOneWidget);
    });

    test('Creación de reservas con datos estructurados para cada categoría', () async {
      final resRepo = SupabaseReservationRepository();
      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(resRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      final now = DateTime.now();
      final date1 = now.add(const Duration(days: 1));
      final date2 = now.add(const Duration(days: 2));
      final date3 = now.add(const Duration(days: 3));

      // 1. Reserva Almuerzo Completo
      await notifier.createReservation(
        date: date1,
        dishName: 'Reserva Test Silpancho + Sopa',
        platoPrincipal: 'Silpancho Cochabambino',
        sopaNombre: 'Sopa de Maní Tradicional',
        isAlmuerzoCompleto: true,
        price: 15.0,
      );

      // 2. Reserva Menú Vegetariano
      await notifier.createReservation(
        date: date2,
        dishName: 'Reserva Test Vegetariano',
        platoPrincipal: 'Quinua Real',
        sopaNombre: null,
        isAlmuerzoCompleto: false,
        price: 15.0,
      );

      // 3. Reserva Plato Especial
      await notifier.createReservation(
        date: date3,
        dishName: 'Reserva Test Plato Especial Único',
        platoPrincipal: 'Pique Macho Especial',
        sopaNombre: null,
        isAlmuerzoCompleto: false,
        price: 15.0,
      );

      final reservations = await resRepo.getUserReservations('demo-user-123');

      final resAlmuerzo = reservations.firstWhere(
        (r) => r.dishName == 'Reserva Test Silpancho + Sopa',
      );
      expect(resAlmuerzo.sopaNombre, equals('Sopa de Maní Tradicional'));
      expect(resAlmuerzo.platoPrincipal, equals('Silpancho Cochabambino'));
      expect(resAlmuerzo.isAlmuerzoCompleto, isTrue);

      final resVeg = reservations.firstWhere((r) => r.dishName == 'Reserva Test Vegetariano');
      expect(resVeg.isAlmuerzoCompleto, isFalse);
      expect(resVeg.sopaNombre, isNull);

      final resEsp = reservations.firstWhere((r) => r.dishName == 'Reserva Test Plato Especial Único');
      expect(resEsp.isAlmuerzoCompleto, isFalse);
      expect(resEsp.sopaNombre, isNull);
    });
  });
}
