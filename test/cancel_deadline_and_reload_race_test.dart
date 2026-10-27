import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';
import 'package:restaurante_app/features/reservas/presentation/my_reservations_screen.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

/// Repositorio en memoria cuya carga puede retenerse para forzar la carrera
/// entre la carga inicial y la creación de una reserva.
class GatedRepository implements ReservationRepository {
  final List<Reservation> rows;
  Completer<void>? gate;

  /// true: la carga lee los datos al terminar (incluye lo creado entre medio).
  /// false: la carga lee los datos al empezar (no incluye lo creado).
  bool snapshotAfterGate = true;

  /// Se ejecuta justo después de guardar una reserva (antes de que el
  /// notifier actualice su lista).
  Future<void> Function()? afterCreate;

  GatedRepository([List<Reservation>? initial]) : rows = [...?initial];

  @override
  Future<List<Reservation>> getUserReservations(String userId) async {
    final before = [...rows];
    if (gate != null) await gate!.future;
    return snapshotAfterGate ? [...rows] : before;
  }

  @override
  Future<Reservation> createReservation(Reservation reservation) async {
    rows.add(reservation);
    await afterCreate?.call();
    return reservation;
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    final i = rows.indexWhere((r) => r.id == reservationId);
    rows[i] = rows[i].copyWith(status: 'cancelada');
  }

  @override
  Future<List<Reservation>> getAllReservationsForDate(DateTime date) async =>
      rows;

  @override
  Future<void> updateReservationStatus(String id, String status) async {}

  @override
  Future<List<Holiday>> getHolidays() async => const [];
}

class FixedTimeNotifier extends CurrentTimeNotifier {
  final DateTime time;
  FixedTimeNotifier(this.time);

  @override
  DateTime build() => time;
}

void main() {
  // Martes 5 de marzo de 2030.
  final serviceDay = DateTime(2030, 3, 5);
  DateTime at(int h, int m) => DateTime(2030, 3, 5, h, m);

  Reservation todayReservation() => Reservation(
    id: 'res-hoy',
    userId: 'demo-user-123',
    userName: 'Juan',
    storedPickupCode: 'AAAA-1111',
    date: serviceDay,
    createdAt: serviceDay,
  );

  group('Plazo de cancelación con la hora real', () {
    late DateTime now;
    late GatedRepository repo;
    late ProviderContainer container;

    setUp(() async {
      repo = GatedRepository([todayReservation()]);
      container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => now),
          currentTimeProvider.overrideWith(() => FixedTimeNotifier(at(8, 57))),
        ],
      );
      container.read(userReservationsProvider);
      await Future<void>.delayed(Duration.zero);
    });
    tearDown(() => container.dispose());

    Reservation stored() => repo.rows.single;

    test('a las 8:57 se permite cancelar', () async {
      now = at(8, 57);
      final result = await container
          .read(userReservationsProvider.notifier)
          .cancelReservation('res-hoy');

      expect(result.isAllowed, isTrue);
      expect(stored().status, 'cancelada');
    });

    test(
      'pantalla abierta a las 8:57, confirmada a las 9:03: se rechaza',
      () async {
        // La pantalla se construyó a las 8:57 y muestra el botón habilitado.
        final policy = container.read(reservationPolicyUseCaseProvider);
        expect(
          policy.canCancel(serviceDay, container.read(currentTimeProvider)),
          isTrue,
        );

        now = at(9, 3);
        final result = await container
            .read(userReservationsProvider.notifier)
            .cancelReservation('res-hoy');

        expect(result.isAllowed, isFalse);
        expect(result.message, contains('8:59'));
        expect(stored().status, 'confirmada');
        expect(
          container.read(userReservationsProvider).single.status,
          'confirmada',
        );
        // La hora de la UI se actualiza para que el botón quede bloqueado.
        expect(container.read(currentTimeProvider), at(9, 3));
      },
    );

    test('a las 9:00 en punto ya no se permite', () async {
      now = at(9, 0);
      final result = await container
          .read(userReservationsProvider.notifier)
          .cancelReservation('res-hoy');
      expect(result.isAllowed, isFalse);
      expect(stored().status, 'confirmada');
    });

    test('una reserva ya cancelada no se vuelve a cancelar', () async {
      now = at(8, 0);
      final notifier = container.read(userReservationsProvider.notifier);
      expect((await notifier.cancelReservation('res-hoy')).isAllowed, isTrue);
      expect((await notifier.cancelReservation('res-hoy')).isAllowed, isFalse);
    });
  });

  testWidgets(
    'Tickets: abierta a las 8:57 y confirmada a las 9:03 muestra el bloqueo',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var now = at(8, 57);
      final repo = GatedRepository([todayReservation()]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reservationRepositoryProvider.overrideWithValue(repo),
            clockProvider.overrideWithValue(() => now),
            currentTimeProvider.overrideWith(
              () => FixedTimeNotifier(at(8, 57)),
            ),
          ],
          child: const MaterialApp(home: MyReservationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // A las 8:57 el botón está habilitado; el usuario lo pulsa...
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancelar'));
      await tester.pumpAndSettle();
      // ...y confirma recién a las 9:03.
      now = at(9, 3);
      await tester.tap(find.text('Sí, Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelación Bloqueada'), findsOneWidget);
      expect(find.text('Reserva cancelada con éxito.'), findsNothing);
      expect(repo.rows.single.status, 'confirmada');
    },
  );

  group('Carrera entre la carga inicial y la creación', () {
    late GatedRepository repo;
    late ProviderContainer container;

    setUp(() async {
      repo = GatedRepository()..gate = Completer<void>();
      container = ProviderContainer(
        overrides: [reservationRepositoryProvider.overrideWithValue(repo)],
      );
      // La carga inicial arranca y queda retenida.
      container.read(userReservationsProvider);
      await Future<void>.delayed(Duration.zero);
    });
    tearDown(() => container.dispose());

    Future<void> create() async {
      final ok = await container
          .read(userReservationsProvider.notifier)
          .createReservation(date: serviceDay, userName: 'Juan');
      expect(ok, isTrue);
    }

    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'la carga termina entre el guardado y la lista: no se duplica',
      () async {
        repo.afterCreate = () async {
          repo.gate!.complete();
          await settle();
        };
        await create();
        await settle();

        expect(container.read(userReservationsProvider).length, 1);
      },
    );

    test(
      'la carga trae datos viejos al final: la reserva no se pierde',
      () async {
        repo.snapshotAfterGate = false;
        await create();
        repo.gate!.complete();
        await settle();

        expect(container.read(userReservationsProvider).length, 1);
      },
    );

    test('una cancelación durante la carga no se revierte', () async {
      repo.gate!.complete();
      await settle();
      await create();
      final id = container.read(userReservationsProvider).single.id;

      // Nueva carga retenida que leyó la reserva aún confirmada.
      repo
        ..gate = Completer<void>()
        ..snapshotAfterGate = false;
      final reload = container
          .read(userReservationsProvider.notifier)
          .loadReservations(userId: 'demo-user-123');
      await container
          .read(userReservationsProvider.notifier)
          .cancelReservation(id);
      repo.gate!.complete();
      await reload;

      expect(
        container.read(userReservationsProvider).single.status,
        'cancelada',
      );
    });
  });
}
