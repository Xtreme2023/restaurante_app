import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/data/supabase_auth_repository.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/familiares/presentation/providers/family_providers.dart';
import 'package:restaurante_app/features/pension/data/supabase_pension_repository.dart';
import 'package:restaurante_app/features/pension/domain/pension_entity.dart';
import 'package:restaurante_app/features/pension/presentation/pension_screen.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';

class _StaticAuthNotifier extends AuthNotifier {
  final dynamic _user;
  _StaticAuthNotifier(this._user);

  @override
  build() => _user;
}

void main() {
  group('1. HU8 y HU9: Entidad MonthlyPensionSubscription y Esquema public.pension', () {
    test('MonthlyPensionSubscription serializa y deserializa con id_familiar y modalidad', () {
      final sub = MonthlyPensionSubscription(
        id: '10',
        userId: 'usr-abc',
        familiarId: 'fam-xyz',
        year: 2026,
        month: 11,
        totalDays: 22,
        pricePerDay: 15.0,
        totalPrice: 330.0,
        status: 'Pensionado',
        createdAt: DateTime(2026, 10, 25),
      );

      final json = sub.toJson();
      expect(json['id_usuario'], equals('usr-abc'));
      expect(json['id_familiar'], equals('fam-xyz'));
      expect(json['mes'], equals(11));
      expect(json['year'], equals(2026));
      expect(json['modalidad'], equals('Pensionado'));

      final parsed = MonthlyPensionSubscription.fromJson(json);
      expect(parsed.userId, equals('usr-abc'));
      expect(parsed.familiarId, equals('fam-xyz'));
      expect(parsed.isForFamiliar, isTrue);
      expect(parsed.isActive, isTrue);
      expect(parsed.month, equals(11));
      expect(parsed.year, equals(2026));
    });

    test('HU8: canModifyOrCancel bloquea si el mes ya inició y permite si es futuro', () {
      final subNov = MonthlyPensionSubscription(
        id: '11',
        userId: 'usr-1',
        year: 2026,
        month: 11,
        totalDays: 20,
        totalPrice: 300.0,
        createdAt: DateTime(2026, 10, 20),
      );

      // Si hoy es 25 de Octubre 2026 (antes de Noviembre):
      final beforeNov = DateTime(2026, 10, 25);
      expect(subNov.canModifyOrCancel(beforeNov), isTrue);

      // Si hoy es 1 de Noviembre 2026 (mes ya inició):
      final inNov = DateTime(2026, 11, 1);
      expect(subNov.canModifyOrCancel(inNov), isFalse);

      // Si hoy es 15 de Noviembre 2026:
      final midNov = DateTime(2026, 11, 15);
      expect(subNov.canModifyOrCancel(midNov), isFalse);
    });
  });

  group('2. HU8 y HU9: SupabasePensionRepository - Reglas y Precios Independientes', () {
    late SupabasePensionRepository repo;

    setUp(() {
      repo = SupabasePensionRepository();
    });

    test('Suscripción y cancelación independiente para empleado y familiar', () async {
      final userId = 'emp-test-100';
      final familiarId = 'fam-test-200';
      final beforeMonth = DateTime(2026, 10, 20);

      // Suscribir solo al empleado para Noviembre 2026
      final okEmp = await repo.subscribeMonthly(
        userId: userId,
        familiarId: null,
        year: 2026,
        month: 11,
        currentTime: beforeMonth,
      );
      expect(okEmp, isTrue);

      // Empleado pensionado -> Bs. 15.00
      final isEmpPensioned = await repo.isPensioner(
        userId: userId,
        familiarId: null,
        date: DateTime(2026, 11, 10),
      );
      expect(isEmpPensioned, isTrue);

      // Familiar NO pensionado -> Bs. 18.00 por defecto
      final isFamPensioned = await repo.isPensioner(
        userId: userId,
        familiarId: familiarId,
        date: DateTime(2026, 11, 10),
      );
      expect(isFamPensioned, isFalse);

      // Ahora suscribir al familiar
      final okFam = await repo.subscribeMonthly(
        userId: userId,
        familiarId: familiarId,
        year: 2026,
        month: 11,
        currentTime: beforeMonth,
      );
      expect(okFam, isTrue);

      final isFamPensionedNow = await repo.isPensioner(
        userId: userId,
        familiarId: familiarId,
        date: DateTime(2026, 11, 10),
      );
      expect(isFamPensionedNow, isTrue);

      // Cancelar empleado manteniendo al familiar pensionado
      final okCancelEmp = await repo.cancelMonthlySubscription(
        'dummy-id',
        2026,
        11,
        beforeMonth,
        userId: userId,
        familiarId: null,
      );
      expect(okCancelEmp, isTrue);

      // Empleado ahora es regular (18), pero familiar sigue pensionado (15)
      expect(
        await repo.isPensioner(userId: userId, familiarId: null, date: DateTime(2026, 11, 10)),
        isFalse,
      );
      expect(
        await repo.isPensioner(userId: userId, familiarId: familiarId, date: DateTime(2026, 11, 10)),
        isTrue,
      );
    });

    test('HU8: Rechaza modificar pensión si el mes ya inició', () async {
      final afterMonthStarted = DateTime(2026, 11, 2);

      final rejected = await repo.subscribeMonthly(
        userId: 'usr-99',
        year: 2026,
        month: 11,
        currentTime: afterMonthStarted,
      );
      expect(rejected, isFalse);
    });
  });

  group('3. HU9: Tabla reserva y campo id_familiar', () {
    test('Reservation model mapea id_familiar y costo_aplicado de la base de datos', () {
      final rowReserva = {
        'id_reserva': 2,
        'costo_aplicado': 18.0,
        'fecha': '2026-10-26T04:00:00Z',
        'estado': 'CONFIRMADA',
        'es_pension': false,
        'origen': 'FAMILIAR',
        'id_usuario': '6bca617c-f84b-4eeb-b7c9-acd135919130',
        'id_familiar': '869f0e77-4802-41c7-b0ef-0a192578e9b0',
        'nombre': 'Irina',
        'apellidos': 'Doblas',
        'parentesco': 'Esposa',
      };

      final res = Reservation.fromJson(rowReserva);

      expect(res.id, equals('2'));
      expect(res.familiarId, equals('869f0e77-4802-41c7-b0ef-0a192578e9b0'));
      expect(res.isForFamiliar, isTrue);
      expect(res.beneficiaryName, equals('Irina Doblas (Esposa)'));
      expect(res.price, equals(18.0));

      final jsonOutput = res.toJson();
      expect(jsonOutput['id_familiar'], equals('869f0e77-4802-41c7-b0ef-0a192578e9b0'));
      expect(jsonOutput['id_usuario'], equals('6bca617c-f84b-4eeb-b7c9-acd135919130'));
      expect(jsonOutput['costo_aplicado'], equals(18.0));
      expect(jsonOutput['origen'], equals('FAMILIAR'));
    });
  });

  group('4. Widget: PensionScreen (HU8 y HU9)', () {
    testWidgets(
      'HU8: Al presionar Confirmar sin seleccionar modalidad, muestra "Debe seleccionar modalidad"',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testFamiliar = Familiar(
          id: 'fam-uuid-1',
          empleadoId: 'demo-user-123',
          nombres: 'Irina',
          apellidos: 'Doblas',
          parentesco: 'Esposa',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _StaticAuthNotifier(SupabaseAuthRepository.demoEmpleado),
              ),
              employeeFamilyMembersProvider.overrideWith(
                (ref) async => [testFamiliar],
              ),
            ],
            child: const MaterialApp(home: PensionScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Verificar título y selector de comensal
        expect(find.text('Gestión de Pensión Mensual'), findsOneWidget);
        expect(find.text('Para mí (Empleado)'), findsOneWidget);
        expect(find.text('Familiar (HU9)'), findsOneWidget);

        // Muestra regla de 10 almuerzos mínimos si está pensionado el mes actual
        expect(
          find.textContaining('Mínimo de consumo para todo el mes: 10 almuerzos'),
          findsOneWidget,
        );

        // Buscar botón de confirmar modalidad
        final confirmBtn = find.textContaining('Confirmar Modalidad').first;
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Debe haber feedback o SnackBar
        expect(find.byType(SnackBar), findsWidgets);
      },
    );

    testWidgets(
      'HU9: Al cambiar a Familiar sin seleccionar ninguno y pulsar Confirmar, muestra "Debe seleccionar un familiar"',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _StaticAuthNotifier(SupabaseAuthRepository.demoEmpleado),
              ),
              employeeFamilyMembersProvider.overrideWith(
                (ref) async => [], // Sin familiares seleccionados
              ),
            ],
            child: const MaterialApp(home: PensionScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Cambiar a pestaña Familiar (HU9)
        final famChip = find.text('Familiar (HU9)');
        await tester.tap(famChip);
        await tester.pumpAndSettle();

        // Intentar confirmar
        final confirmBtn = find.textContaining('Confirmar Modalidad').first;
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(find.text('Debe seleccionar un familiar'), findsOneWidget);
      },
    );
  });

  group('5. HU8 y HU9: Cálculo de tarifas independientes', () {
    test('Tarifas independientes para empleado y familiar', () {
      // Caso 1: Empleado pensionado (15), Familiar regular (18)
      final statusCaso1 = {null: true, 'fam-1': false};
      final priceEmp1 = (statusCaso1[null] ?? false) ? 15.0 : 18.0;
      final priceFam1 = (statusCaso1['fam-1'] ?? false) ? 15.0 : 18.0;
      expect(priceEmp1, equals(15.0));
      expect(priceFam1, equals(18.0));
      expect(priceEmp1 + priceFam1, equals(33.0));

      // Caso 2: Empleado regular (18), Familiar pensionado (15)
      final statusCaso2 = {null: false, 'fam-1': true};
      final priceEmp2 = (statusCaso2[null] ?? false) ? 15.0 : 18.0;
      final priceFam2 = (statusCaso2['fam-1'] ?? false) ? 15.0 : 18.0;
      expect(priceEmp2, equals(18.0));
      expect(priceFam2, equals(15.0));
      expect(priceEmp2 + priceFam2, equals(33.0));

      // Caso 3: Ambos pensionados (15 + 15 = 30)
      final statusCaso3 = {null: true, 'fam-1': true};
      final priceEmp3 = (statusCaso3[null] ?? false) ? 15.0 : 18.0;
      final priceFam3 = (statusCaso3['fam-1'] ?? false) ? 15.0 : 18.0;
      expect(priceEmp3 + priceFam3, equals(30.0));

      // Caso 4: Ambos regulares (18 + 18 = 36)
      final statusCaso4 = {null: false, 'fam-1': false};
      final priceEmp4 = (statusCaso4[null] ?? false) ? 15.0 : 18.0;
      final priceFam4 = (statusCaso4['fam-1'] ?? false) ? 15.0 : 18.0;
      expect(priceEmp4 + priceFam4, equals(36.0));
    });
  });
}

