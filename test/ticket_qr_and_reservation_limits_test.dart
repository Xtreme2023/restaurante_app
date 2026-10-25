import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/features/reservas/presentation/my_reservations_screen.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

class MockReservationRepository implements ReservationRepository {
  List<Reservation> mockReservations = [];

  @override
  Future<List<Reservation>> getUserReservations(String userId) async {
    return mockReservations;
  }

  @override
  Future<List<Reservation>> getAllReservationsForDate(DateTime date) async {
    return mockReservations;
  }

  @override
  Future<void> createReservation(Reservation reservation) async {
    mockReservations.add(reservation);
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    mockReservations = mockReservations.map((r) {
      if (r.id == reservationId) {
        return r.copyWith(status: 'cancelada');
      }
      return r;
    }).toList();
  }

  @override
  Future<void> updateReservationStatus(String reservationId, String status) async {
    mockReservations = mockReservations.map((r) {
      if (r.id == reservationId) {
        return r.copyWith(status: status);
      }
      return r;
    }).toList();
  }

  @override
  Future<void> markReservationAsPickedUp(String reservationId, bool recogido) async {
    mockReservations = mockReservations.map((r) {
      if (r.id == reservationId) {
        return r.copyWith(recogido: recogido);
      }
      return r;
    }).toList();
  }

  @override
  Future<List<Reservation>> getUserReservationsForPeriod(
      String userId, DateTime startDate, DateTime endDate) async {
    return mockReservations.where((r) => r.userId == userId).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceForDate(DateTime date) async => [];

  @override
  Future<void> registerAttendance({
    required String userId,
    int? reservationId,
    required DateTime date,
    bool asistio = true,
    String? observacion,
  }) async {}

  @override
  Future<List<Holiday>> getHolidays() async => [];
}

void main() {
  group('1. Ver Ticket QR Code Format Tests', () {
    test('Calculates displayCode correctly without RangeError for single-digit or short IDs', () {
      final shortIds = ['1', '2', '8', '12', '12345'];
      for (final id in shortIds) {
        final cleanCode = id.toUpperCase().replaceAll('-', '');
        final displayCode = cleanCode.length >= 8
            ? cleanCode.substring(0, 8)
            : cleanCode.padLeft(8, '0');
        expect(displayCode.length, 8);
        expect(displayCode, id.padLeft(8, '0'));
      }
    });

    test('Calculates displayCode correctly for UUIDs and long IDs', () {
      const uuid = '869f0e77-98fc-1c14-9afb-4c760635c556';
      final cleanCode = uuid.toUpperCase().replaceAll('-', '');
      final displayCode = cleanCode.length >= 8
          ? cleanCode.substring(0, 8)
          : cleanCode.padLeft(8, '0');
      expect(displayCode, '869F0E77');
      expect(displayCode.length, 8);
    });

    testWidgets('Rendering MyReservationsScreen with short ID does not crash on Ver Ticket',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRepo = MockReservationRepository();
      final reservationWithShortId = Reservation(
        id: '1', // Short ID that previously caused RangeError (end): 8
        userId: 'test-user',
        userName: 'Juan Pérez',
        dishName: 'Silpancho Cochabambino',
        date: DateTime.now(),
        status: 'confirmada',
        price: 18.0,
        createdAt: DateTime.now(),
      );
      mockRepo.mockReservations = [reservationWithShortId];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reservationRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MyReservationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find "Ver Ticket" button
      final ticketBtn = find.text('Ver Ticket');
      expect(ticketBtn, findsOneWidget);

      await tester.tap(ticketBtn);
      await tester.pumpAndSettle();

      // Dialog should open with padded code #00000001
      expect(find.text('Ticket de Retiro'), findsOneWidget);
      expect(find.text('CÓDIGO: #00000001'), findsOneWidget);
      expect(find.text('Silpancho Cochabambino'), findsNWidgets(2));

      // Close dialog
      await tester.tap(find.text('Cerrar Ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Ticket de Retiro'), findsNothing);
    });
  });

  group('2. Restricción de 1 reserva por persona/familiar y por día', () {
    testWidgets('UserReservationsNotifier blocks duplicate reservation for the same employee on same date',
        (tester) async {
      final mockRepo = MockReservationRepository();
      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      final targetDate = DateTime.now().add(const Duration(days: 2));

      // First reservation for employee
      final success1 = await notifier.createReservation(
        date: targetDate,
        dishName: 'Plato A',
        userId: 'emp-1',
        userName: 'Carlos',
      );
      expect(success1, isTrue);

      // Second reservation for same employee on same date should be blocked
      final success2 = await notifier.createReservation(
        date: targetDate,
        dishName: 'Plato B',
        userId: 'emp-1',
        userName: 'Carlos',
      );
      expect(success2, isFalse, reason: 'Duplicate reservation on same date must be rejected');

      // But reservation for next day should succeed
      final nextDay = targetDate.add(const Duration(days: 1));
      final successNextDay = await notifier.createReservation(
        date: nextDay,
        dishName: 'Plato C',
        userId: 'emp-1',
        userName: 'Carlos',
      );
      expect(successNextDay, isTrue);
    });

    testWidgets('UserReservationsNotifier allows independent reservation for familiar but blocks duplicate familiar on same date',
        (tester) async {
      final mockRepo = MockReservationRepository();
      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      final targetDate = DateTime.now().add(const Duration(days: 2));

      // Employee reservation
      await notifier.createReservation(
        date: targetDate,
        dishName: 'Plato A',
        userId: 'emp-1',
        userName: 'Carlos',
      );

      // Familiar 1 reservation on same date -> ALLOWED (different comensal)
      final famSuccess1 = await notifier.createReservation(
        date: targetDate,
        dishName: 'Plato Familiar',
        userId: 'emp-1',
        userName: 'Carlos',
        familiarId: 'fam-101',
        beneficiaryName: 'Esposa María',
      );
      expect(famSuccess1, isTrue);

      // Duplicate reservation for Familiar 1 on same date -> BLOCKED
      final famDuplicate = await notifier.createReservation(
        date: targetDate,
        dishName: 'Otro Plato Familiar',
        userId: 'emp-1',
        userName: 'Carlos',
        familiarId: 'fam-101',
        beneficiaryName: 'Esposa María',
      );
      expect(famDuplicate, isFalse);

      // Reservation for Familiar 2 on same date -> ALLOWED
      final fam2Success = await notifier.createReservation(
        date: targetDate,
        dishName: 'Plato Hijo',
        userId: 'emp-1',
        userName: 'Carlos',
        familiarId: 'fam-102',
        beneficiaryName: 'Hijo Pedro',
      );
      expect(fam2Success, isTrue);
    });

    testWidgets('Cancelled reservation allows new booking for that person and date',
        (tester) async {
      final mockRepo = MockReservationRepository();
      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      final targetDate = DateTime.now().add(const Duration(days: 2));

      await notifier.createReservation(
        date: targetDate,
        dishName: 'Plato Inicial',
        userId: 'emp-1',
        userName: 'Carlos',
      );

      final existingRes = container.read(userReservationsProvider).first;

      // Cancel the reservation
      final cancelSuccess = await notifier.cancelReservation(existingRes.id);
      expect(cancelSuccess, isTrue);

      // Now booking again on same date should be allowed
      final newBooking = await notifier.createReservation(
        date: targetDate,
        dishName: 'Plato Reemplazo',
        userId: 'emp-1',
        userName: 'Carlos',
      );
      expect(newBooking, isTrue);
    });

    testWidgets('createJointReservations respects already reserved comensales',
        (tester) async {
      final mockRepo = MockReservationRepository();
      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      final targetDate = DateTime.now().add(const Duration(days: 3));

      // Employee already reserved
      await notifier.createReservation(
        date: targetDate,
        dishName: 'Plato Empleado Prev',
        userId: 'emp-1',
        userName: 'Carlos',
      );

      // Attempt joint reservation for employee + familiar 1 + familiar 2
      final count = await notifier.createJointReservations(
        date: targetDate,
        dishName: 'Almuerzo Conjunto',
        reserveForEmployee: true, // Should be skipped since employee is already reserved
        selectedFamiliarIds: ['fam-1', 'fam-2'],
        familiarNames: {'fam-1': 'Esposa', 'fam-2': 'Hijo'},
        pricePerPerson: 18.0,
      );

      // Only the 2 familiars should be created
      expect(count, 2);
    });
  });

  group('3. Bloqueo de reservas para fechas pasadas', () {
    testWidgets('createReservation rejects dates in the past', (tester) async {
      final mockRepo = MockReservationRepository();
      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final success = await notifier.createReservation(
        date: yesterday,
        dishName: 'Plato Ayer',
        userId: 'emp-1',
        userName: 'Carlos',
      );
      expect(success, isFalse, reason: 'Reservations for past dates must be blocked');
    });

    testWidgets('createJointReservations rejects dates in the past', (tester) async {
      final mockRepo = MockReservationRepository();
      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      final pastDate = DateTime.now().subtract(const Duration(days: 2));

      final count = await notifier.createJointReservations(
        date: pastDate,
        dishName: 'Plato Conjunto Pasado',
        reserveForEmployee: true,
        selectedFamiliarIds: ['fam-1'],
        pricePerPerson: 18.0,
      );
      expect(count, 0, reason: 'Joint reservations for past dates must return 0');
    });
  });

  group('4. Función Cancelar Reserva y Política de Horario (9:00 AM)', () {
    test('ReservationPolicy aplica corte a las 9:00 AM para reservas y cancelaciones del mismo día', () {
      final policy = ReservationPolicy();
      final weekday = DateTime(2026, 10, 28); // Miércoles
      final beforeCutoff = DateTime(weekday.year, weekday.month, weekday.day, 8, 30);
      final atCutoff = DateTime(weekday.year, weekday.month, weekday.day, 9, 0);
      final afterCutoff = DateTime(weekday.year, weekday.month, weekday.day, 9, 15);

      // Reservar en día hábil antes o a las 9:00 AM -> Permitido
      expect(policy.checkCanReserve(weekday, beforeCutoff).isAllowed, isTrue);
      expect(policy.checkCanReserve(weekday, atCutoff).isAllowed, isTrue);
      // Reservar en día hábil después de las 9:00 AM -> Bloqueado
      expect(policy.checkCanReserve(weekday, afterCutoff).isAllowed, isFalse);

      // Cancelar en día hábil antes de las 9:00 AM -> Permitido
      expect(policy.checkCanCancel(weekday, beforeCutoff).isAllowed, isTrue);
      // Cancelar en día hábil a partir de las 9:00 AM -> Bloqueado
      expect(policy.checkCanCancel(weekday, atCutoff).isAllowed, isFalse);
      expect(policy.checkCanCancel(weekday, afterCutoff).isAllowed, isFalse);

      // Días futuros -> Siempre permitidos
      final futureDate = weekday.add(const Duration(days: 1)); // Jueves 29
      expect(policy.checkCanCancel(futureDate, afterCutoff).isAllowed, isTrue);
      expect(policy.checkCanReserve(futureDate, afterCutoff).isAllowed, isTrue);
    });

    testWidgets('cancelReservation actualiza estado a cancelada y persiste', (tester) async {
      final mockRepo = MockReservationRepository();
      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      final futureDate = DateTime.now().add(const Duration(days: 3));

      await notifier.createReservation(
        date: futureDate,
        dishName: 'Plato Para Cancelar',
        userId: 'emp-1',
        userName: 'Carlos',
      );

      final res = container.read(userReservationsProvider).first;
      expect(res.status, 'confirmada');

      final success = await notifier.cancelReservation(res.id);
      expect(success, isTrue);

      final updatedRes = container.read(userReservationsProvider).first;
      expect(updatedRes.status, 'cancelada');
      expect(updatedRes.isCancelled, isTrue);

      // Verificar persistencia en el repositorio
      final repoList = await mockRepo.getUserReservations('emp-1');
      expect(repoList.first.status, 'cancelada');
    });

    testWidgets('cancelReservation bloquea cancelación de reservas pasadas', (tester) async {
      final mockRepo = MockReservationRepository();
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final pastRes = Reservation(
        id: 'past-res-1',
        userId: 'emp-1',
        userName: 'Carlos',
        dishName: 'Plato Pasado',
        date: pastDate,
        status: 'confirmada',
        price: 18.0,
        createdAt: pastDate,
      );
      mockRepo.mockReservations = [pastRes];

      final container = ProviderContainer(
        overrides: [
          reservationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userReservationsProvider.notifier);
      // Wait for initial load
      await container.read(userReservationsProvider.notifier).loadReservations(userId: 'emp-1');

      final success = await notifier.cancelReservation('past-res-1');
      expect(success, isFalse, reason: 'No se debe permitir cancelar reservas de fechas pasadas');
    });
  });
}
