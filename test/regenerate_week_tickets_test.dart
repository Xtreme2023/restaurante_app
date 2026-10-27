import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';

void main() {
  // Miércoles: la semana va del lunes 4 al viernes 8 de marzo de 2030.
  final wednesday = DateTime(2030, 3, 6);

  Reservation reservation(String id, DateTime date, String status) =>
      Reservation(
        id: id,
        userId: 'demo-prueba-2',
        userName: 'Empleado Prueba 2',
        storedPickupCode: 'AAAA-0000',
        dishName: 'Almuerzo del día',
        date: date,
        type: 'diaria',
        status: status,
        createdAt: date,
      );

  test('en modo local las cuentas demo son cuentas de prueba', () async {
    final repo = SupabaseReservationRepository();
    expect(await repo.isTestAccount('demo-prueba-2'), isTrue);
  });

  test('regenera solo los tickets de la semana con códigos nuevos', () async {
    final repo = SupabaseReservationRepository()..clearTestReservations();
    await repo.createReservation(
      reservation('lunes', DateTime(2030, 3, 4), 'entregada'),
    );
    await repo.createReservation(
      reservation('viernes', DateTime(2030, 3, 8), 'cancelada'),
    );
    await repo.createReservation(
      reservation('otra-semana', DateTime(2030, 3, 11), 'entregada'),
    );

    final count = await repo.regenerateWeekTickets('demo-prueba-2', wednesday);
    expect(count, 2);

    final monday = (await repo.getAllReservationsForDate(
      DateTime(2030, 3, 4),
    )).single;
    final friday = (await repo.getAllReservationsForDate(
      DateTime(2030, 3, 8),
    )).single;
    final nextWeek = (await repo.getAllReservationsForDate(
      DateTime(2030, 3, 11),
    )).single;

    expect(monday.status, 'confirmada');
    expect(friday.status, 'confirmada');
    expect(monday.pickupCode, isNot('AAAA-0000'));
    expect(monday.pickupCode, matches(RegExp(r'^[0-9A-F]{4}-[0-9A-F]{4}$')));
    expect(nextWeek.status, 'entregada');

    // El QR nuevo se canjea; el anterior ya no existe.
    const policy = ReservationPolicy(ignoreServiceHours: true);
    expect(
      policy.resolvePickupCode([monday], monday.pickupCode).isValid,
      isTrue,
    );
    expect(
      policy.resolvePickupCode([monday], 'AAAA-0000').status,
      PickupCodeStatus.notFound,
    );
  });
}
