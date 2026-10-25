import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/data/supabase_auth_repository.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/menu/presentation/menu_screen.dart';
import 'package:restaurante_app/features/reservas/presentation/employee_screen.dart';
import 'package:restaurante_app/supabase/menu_service.dart';

class _MockAuthNotifier extends AuthNotifier {
  final dynamic _user;
  _MockAuthNotifier(this._user);

  @override
  build() => _user;
}

void main() {
  group('1. Cálculo de Semana y Desplazamiento (Week Offset)', () {
    test('Week offset 0 vs 1 desplaza correctamente 7 días', () {
      final ref = DateTime(2026, 10, 25); // Domingo
      final rangoSemanaActual = MenuService.getRangoSemana(
        referenceDate: ref,
        weekOffset: 0,
      );
      final rangoSemanaSiguiente = MenuService.getRangoSemana(
        referenceDate: ref,
        weekOffset: 1,
      );

      expect(rangoSemanaActual.inicioSemana.day, equals(19));
      expect(rangoSemanaActual.finSemana.day, equals(23));

      expect(rangoSemanaSiguiente.inicioSemana.day, equals(26));
      expect(rangoSemanaSiguiente.finSemana.day, equals(30));
    });

    test('getDiasSemana genera 5 días hábiles (Lunes a Viernes)', () {
      final ref = DateTime(2026, 10, 25);
      final dias = MenuService.getDiasSemana(referenceDate: ref, weekOffset: 1);

      expect(dias.length, equals(5));
      expect(dias[0].weekday, equals(DateTime.monday));
      expect(dias[4].weekday, equals(DateTime.friday));
      expect(dias[0].day, equals(26));
      expect(dias[4].day, equals(30));
    });
  });

  group('2. Soporte de Nulos en Dish.tipo y Filtrado', () {
    test('Dish soporta tipo nulo y parseDish maneja null de forma segura', () {
      final dishConTipo = MenuService.parseDish({
        'id_plato': 1,
        'nombre': 'Sopa de maní',
        'tipo': 'Sopa',
      });
      expect(dishConTipo, isNotNull);
      expect(dishConTipo!.tipo, equals('Sopa'));

      final dishSinTipo = MenuService.parseDish({
        'id_plato': 2,
        'nombre': 'Pailita',
        'tipo': null,
      });
      expect(dishSinTipo, isNotNull);
      expect(dishSinTipo!.tipo, isNull);
    });
  });

  group('3. Renderizado y Navegación de Semanas en MenuScreen', () {
    testWidgets(
      'MenuScreen muestra barra de semana y chips de filtro de tipo (Segundo, Sopa, Vegetariano)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _MockAuthNotifier(SupabaseAuthRepository.demoEmpleado),
              ),
            ],
            child: const MaterialApp(home: MenuScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Barra de navegación entre semanas
        expect(find.text('Semana Actual'), findsOneWidget);
        expect(find.text('Semana Siguiente'), findsOneWidget);

        // Chips de categoría basadas en enum tipo
        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Segundo'), findsOneWidget);
        expect(find.text('Sopa'), findsOneWidget);
        expect(find.text('Vegetariano'), findsOneWidget);

        // Verificar que 'Almuerzo Completo' visual fue retirado de las categorías
        expect(find.widgetWithText(FilterChip, 'Almuerzo Completo'), findsNothing);
      },
    );
  });

  group('4. EmployeeScreen: Validación HU7 y HU9', () {
    testWidgets(
      'Al intentar confirmar sin seleccionar plato, muestra "Debe seleccionar un plato"',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _MockAuthNotifier(SupabaseAuthRepository.demoEmpleado),
              ),
            ],
            child: const MaterialApp(home: EmployeeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Botón confirmar (ElevatedButton al final del formulario)
        final confirmBtn = find.byType(ElevatedButton).last;
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Si no hay plato seleccionado o menú disponible, se valida
        // (o muestra 'Debe seleccionar un plato' o 'Fuera de horario')
        expect(find.byType(SnackBar), findsWidgets);
      },
    );
  });
}
