import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/data/supabase_auth_repository.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/main.dart';

class TestAuthNotifier extends AuthNotifier {
  final UserProfile? initialUser;
  TestAuthNotifier([this.initialUser]);

  @override
  UserProfile? build() => initialUser;
}

void main() {
  group('Auth Roles & Navigation Logic', () {
    test(
      'Roles de UserProfile: Identifica correctamente empleado, admin y cocina',
      () {
        const empleado = UserProfile(
          id: '1',
          email: 'juan@institucion.gob.bo',
          fullName: 'Juan Pérez',
          role: 'empleado',
        );
        expect(empleado.isEmpleado, isTrue);
        expect(empleado.isAdmin, isFalse);
        expect(empleado.isCocina, isFalse);
        expect(empleado.roleDisplay, equals('Empleado Institucional'));

        const admin = UserProfile(
          id: '2',
          email: 'admin@institucion.gob.bo',
          fullName: 'Mariana Gómez',
          role: 'admin',
        );
        expect(admin.isAdmin, isTrue);
        expect(admin.isEmpleado, isFalse);
        expect(admin.isCocina, isFalse);
        expect(admin.roleDisplay, equals('Administrador Institucional'));

        const cocina = UserProfile(
          id: '3',
          email: 'chef@restaurante.com',
          fullName: 'Carlos Mendoza',
          role: 'cocina',
        );
        expect(cocina.isCocina, isTrue);
        expect(cocina.isEmpleado, isFalse);
        expect(cocina.isAdmin, isFalse);
        expect(cocina.roleDisplay, equals('Empleado de Cocina'));
      },
    );

    test(
      'SupabaseAuthRepository: Identifica roles según el correo en modo demo',
      () async {
        final repo = SupabaseAuthRepository();

        final emp = await repo.signInWithEmailPassword(
          'maria.empleado@test.com',
          '123456',
        );
        expect(emp.isEmpleado, isTrue);

        final adm = await repo.signInWithEmailPassword(
          'admin.rrhh@test.com',
          '123456',
        );
        expect(adm.isAdmin, isTrue);

        final coc = await repo.signInWithEmailPassword(
          'cocina.turno@test.com',
          '123456',
        );
        // El rol cocina/encargado ya no tiene pantalla propia: sus funciones
        // están en el Panel Administrador.
        expect(coc.isCocina, isFalse);
        expect(coc.isEmpleado, isTrue);
      },
    );

    testWidgets(
      'LoginScreen: Solo muestra campos de correo y contraseña para el acceso',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => TestAuthNotifier(null)),
            ],
            child: const RestauranteApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Iniciar Sesión'), findsWidgets);
        expect(find.text('Correo electrónico'), findsOneWidget);
        expect(find.text('Contraseña'), findsOneWidget);
        expect(find.text('Ingresar al Sistema'), findsOneWidget);
        // No debe contener campos innecesarios de registro
        expect(find.text('Nombre Completo'), findsNothing);
        expect(find.text('Acceso Rápido por Rol (Pruebas):'), findsNothing);
        expect(find.text('1. Empleado'), findsNothing);
        expect(find.text('2. Admin'), findsNothing);
        expect(find.text('3. Cocina'), findsNothing);
      },
    );

    testWidgets(
      'Redirección Empleado: Lleva al menú y panel de reservas del empleado',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => TestAuthNotifier(SupabaseAuthRepository.demoEmpleado),
              ),
            ],
            child: const RestauranteApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Menú del Día'), findsOneWidget);
        expect(find.text('Calendario'), findsOneWidget);
        expect(find.text('Reservas'), findsOneWidget);
        expect(find.text('Perfil'), findsOneWidget);
      },
    );

    testWidgets('Redirección Admin: Lleva al Panel Administrador', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => TestAuthNotifier(SupabaseAuthRepository.demoAdmin),
            ),
          ],
          child: const RestauranteApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel Administrador'), findsOneWidget);
      expect(
        find.text('Gestión de personal, membresías, cocina y despacho'),
        findsOneWidget,
      );
      expect(find.text('Empleados & Familiares'), findsOneWidget);
      expect(find.text('Cocina'), findsOneWidget);
    });

    testWidgets('Admin: la pestaña Cocina muestra el panel de cocina', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => TestAuthNotifier(SupabaseAuthRepository.demoAdmin),
            ),
          ],
          child: const RestauranteApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cocina'));
      await tester.pumpAndSettle();

      expect(
        find.text('Métricas de producción y menú semanal boliviano'),
        findsOneWidget,
      );
      expect(find.text('Resumen & Totales'), findsOneWidget);
      expect(find.text('Total Pedidos'), findsOneWidget);
    });
  });
}
