import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

void main() {
  final date = DateTime(2030, 3, 4);
  final codeFormat = RegExp(r'^[0-9A-F]{4}-[0-9A-F]{4}$');

  group('Código de retiro aleatorio', () {
    test('tiene el formato XXXX-XXXX y no se repite', () {
      final codes = List.generate(
        2000,
        (_) => Reservation.generatePickupCode(),
      );

      expect(codes.every(codeFormat.hasMatch), isTrue);
      expect(codes.toSet().length, codes.length);
    });

    test('el QR usa el código guardado y no el formato predecible', () {
      final res = Reservation(
        id: 'r1',
        userId: 'u1',
        storedPickupCode: 'a3f9-0c7e',
        date: date,
        createdAt: date,
      );

      expect(res.pickupCode, 'A3F9-0C7E');
      expect(res.pickupCode, isNot(contains('EMP-')));
    });

    test('sin código guardado se mantiene el formato anterior', () {
      final res = Reservation(
        id: 'r1',
        userId: 'u1',
        date: date,
        createdAt: date,
      );
      expect(res.pickupCode, endsWith('_LUNES_2030-03-04'));
    });

    test('fromJson lee el código de ambas tablas y normaliza ACTIVA', () {
      final fromReservations = Reservation.fromJson({
        'id': '1',
        'user_id': 'u1',
        'reservation_date': '2030-03-04',
        'status': 'confirmada',
        'pickup_code': 'AAAA-1111',
      });
      final fromReservas = Reservation.fromJson({
        'id': '2',
        'empleado_id': 'u1',
        'fecha': '2030-03-04',
        'estado': 'ACTIVA',
        'codigo_retiro': 'BBBB-2222',
      });

      expect(fromReservations.pickupCode, 'AAAA-1111');
      expect(fromReservas.pickupCode, 'BBBB-2222');
      expect(fromReservas.isConfirmed, isTrue);
    });
  });

  test('cancelar la reserva del empleado no anula el QR del familiar', () {
    final employee = Reservation(
      id: 'r1',
      userId: 'u1',
      storedPickupCode: 'AAAA-1111',
      status: 'cancelada',
      date: date,
      createdAt: date,
    );
    final familiar = Reservation(
      id: 'r2',
      userId: 'u1',
      familiarId: 'f1',
      storedPickupCode: 'BBBB-2222',
      date: date,
      createdAt: date,
    );
    const policy = ReservationPolicy();

    expect(
      policy.resolvePickupCode([employee, familiar], 'AAAA-1111').status,
      PickupCodeStatus.cancelled,
    );
    expect(
      policy.resolvePickupCode([employee, familiar], 'bbbb-2222').isValid,
      isTrue,
    );
  });

  test('cada reserva conjunta recibe su propio código', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Espera la carga inicial del notifier antes de crear reservas.
    container.read(userReservationsProvider);
    await Future<void>.delayed(Duration.zero);

    final count = await container
        .read(userReservationsProvider.notifier)
        .createJointReservations(
          date: date,
          dishName: 'Almuerzo del día',
          reserveForEmployee: true,
          selectedFamiliarIds: const ['f1', 'f2'],
          familiarNames: const {'f1': 'Ana', 'f2': 'Luis'},
          pricePerPerson: 18.0,
        );

    final codes = container
        .read(userReservationsProvider)
        .where((r) => r.date == date)
        .map((r) => r.storedPickupCode)
        .whereType<String>()
        .toList();
    expect(count, 3);
    expect(codes.length, 3);
    expect(codes.toSet().length, 3);
    expect(codes.every(codeFormat.hasMatch), isTrue);
  });

  test('sin servidor, el canje por RPC cede a la validación local', () async {
    final repo = SupabaseReservationRepository();

    expect(await repo.redeemPickupCode('AAAA-1111'), isNull);
    expect(await repo.monthlyPlanPickupCode(date), isNull);
  });
}
