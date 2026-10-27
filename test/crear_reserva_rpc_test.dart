import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';

void main() {
  test('los errores de crear_reserva se muestran sin el prefijo técnico', () {
    expect(
      SupabaseReservationRepository.reservationErrorMessage(
        'RESERVA_PLAZO_VENCIDO: las reservas para hoy cierran a las 09:00.',
      ),
      'las reservas para hoy cierran a las 09:00.',
    );
    expect(
      SupabaseReservationRepository.reservationErrorMessage('Otro error'),
      'Otro error',
    );
  });

  test(
    'en modo local createReservation devuelve la reserva guardada',
    () async {
      final repo = SupabaseReservationRepository()..clearTestReservations();
      final reservation = Reservation(
        id: 'local-1',
        userId: 'demo-prueba-2',
        userName: 'Empleado Prueba 2',
        storedPickupCode: 'ABCD-1234',
        dishName: 'Almuerzo del día',
        date: DateTime(2030, 3, 6),
        type: 'diaria',
        status: 'confirmada',
        createdAt: DateTime(2030, 3, 5),
      );

      final saved = await repo.createReservation(reservation);

      expect(saved.id, 'local-1');
      expect(saved.pickupCode, 'ABCD-1234');
      expect(
        (await repo.getAllReservationsForDate(DateTime(2030, 3, 6))).single.id,
        'local-1',
      );
    },
  );
}
