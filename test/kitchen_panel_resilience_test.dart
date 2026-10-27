import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/admin/presentation/kitchen_panel.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

/// Mock que simula fallas de red / Supabase para probar la resiliencia
class FailingReservationRepository implements ReservationRepository {
  @override
  Future<List<Reservation>> getAllReservationsForDate(DateTime date) async {
    throw Exception('Error simulado de conexión / esquema PostgREST');
  }

  @override
  Future<List<Reservation>> getUserReservations(String userId) async {
    throw Exception('Error simulado al obtener reservas de usuario');
  }

  @override
  Future<Reservation> createReservation(Reservation reservation) async {
    throw Exception('Error simulado al crear reserva');
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    throw Exception('Error simulado al cancelar reserva');
  }

  @override
  Future<void> updateReservationStatus(
    String reservationId,
    String status,
  ) async {
    throw Exception('Error simulado al actualizar estado');
  }

  @override
  Future<List<Holiday>> getHolidays() async {
    return Holiday.defaultHolidays;
  }
}

void main() {
  group('Resiliencia y Pruebas Unitarias de SupabaseReservationRepository', () {
    test(
      'getAllReservationsForDate no arroja excepción y retorna lista para hoy',
      () async {
        final repo = SupabaseReservationRepository();
        final today = DateTime.now();
        final reservations = await repo.getAllReservationsForDate(today);

        expect(reservations, isA<List<Reservation>>());
        expect(reservations.isNotEmpty, isTrue);
        expect(reservations.first.dishName, isNotEmpty);
      },
    );

    test(
      'getUserReservations no arroja excepción ante ID no UUID ni conexión',
      () async {
        final repo = SupabaseReservationRepository();
        final reservations = await repo.getUserReservations('demo-user-123');

        expect(reservations, isA<List<Reservation>>());
        expect(reservations.isNotEmpty, isTrue);
      },
    );

    test(
      'updateReservationStatus actualiza el estado a entregada en memoria',
      () async {
        final repo = SupabaseReservationRepository();
        final today = DateTime.now();
        final reservations = await repo.getAllReservationsForDate(today);
        final first = reservations.first;

        await repo.updateReservationStatus(first.id, 'entregada');
        final updatedList = await repo.getAllReservationsForDate(today);
        final updated = updatedList.firstWhere((r) => r.id == first.id);

        expect(updated.status, equals('entregada'));
      },
    );
  });

  group('Pruebas de Widgets y Resiliencia de KitchenPanel', () {
    testWidgets(
      'KitchenPanel carga sin colgarse y muestra métricas y pedidos',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Scaffold(body: KitchenPanel())),
          ),
        );

        // Primer frame en loading
        await tester.pump();
        // Esperar resolución de microtareas y llamadas asíncronas
        await tester.pumpAndSettle();

        // Debe mostrar el título y tabs
        expect(
          find.text('Métricas de producción y menú semanal boliviano'),
          findsOneWidget,
        );
        expect(find.text('Resumen & Totales'), findsOneWidget);
        expect(find.text('Menú Semanal'), findsOneWidget);

        // Debe mostrar las métricas cargadas sin spinner infinito
        expect(find.text('Total Pedidos'), findsOneWidget);
        expect(find.text('Pendientes'), findsOneWidget);
        expect(find.text('Entregados'), findsOneWidget);

        // Debe haber pedidos en pantalla
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'Resiliencia: KitchenPanel ante fallo de Supabase/Backend NO se cuelga',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reservationRepositoryProvider.overrideWithValue(
                FailingReservationRepository(),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: KitchenPanel())),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // Verifica que no se quedó colgado en loading infinito
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text('Métricas de producción y menú semanal boliviano'),
          findsOneWidget,
        );
        expect(find.text('Total Pedidos'), findsOneWidget);
      },
    );

    testWidgets(
      'KitchenPanel Tab Menú Semanal renderiza sin desbordamientos de layout',
      (tester) async {
        tester.view.physicalSize = const Size(
          400,
          900,
        ); // Pantalla móvil angosta
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Scaffold(body: KitchenPanel())),
          ),
        );

        await tester.pumpAndSettle();

        // Cambiar a la pestaña "Menú Semanal"
        await tester.tap(find.text('Menú Semanal'));
        await tester.pumpAndSettle();

        // Debe mostrar la vista de planificación sin excepciones de RenderFlex
        expect(find.text('Publicar Menú'), findsOneWidget);
        expect(find.text('Silpancho Cochabambino'), findsWidgets);
      },
    );
  });
}
