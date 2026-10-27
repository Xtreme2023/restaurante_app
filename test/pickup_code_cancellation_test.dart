import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';

void main() {
  final policy = ReservationPolicy();
  final date = DateTime(2030, 3, 4);

  Reservation reservation(String id, String status, {String? familiarId}) {
    return Reservation(
      id: id,
      userId: 'empleado-qr-test',
      familiarId: familiarId,
      date: date,
      status: status,
      createdAt: date,
    );
  }

  group('ReservationPolicy.resolvePickupCode', () {
    test('una reserva confirmada habilita el QR', () {
      final res = reservation('r1', 'confirmada');
      final result = policy.resolvePickupCode([res], res.pickupCode);

      expect(result.isValid, isTrue);
      expect(result.reservation?.id, 'r1');
    });

    test('una reserva cancelada deja el QR sin efecto', () {
      final res = reservation('r1', 'cancelada');
      final result = policy.resolvePickupCode([res], res.pickupCode);

      expect(result.isValid, isFalse);
      expect(result.status, PickupCodeStatus.cancelled);
      expect(result.reservation, isNull);
    });

    test('una reserva entregada no se puede volver a retirar', () {
      final res = reservation('r1', 'entregada');
      final result = policy.resolvePickupCode([res], res.pickupCode);

      expect(result.status, PickupCodeStatus.alreadyDelivered);
    });

    test(
      'si el código se comparte, se usa la reserva que sigue confirmada',
      () {
        final cancelled = reservation('r1', 'cancelada');
        final familiar = reservation('r2', 'confirmada', familiarId: 'fam-1');
        expect(cancelled.pickupCode, familiar.pickupCode);

        final result = policy.resolvePickupCode([
          cancelled,
          familiar,
        ], cancelled.pickupCode);

        expect(result.isValid, isTrue);
        expect(result.reservation?.id, 'r2');
      },
    );

    test('código desconocido o vacío es inválido', () {
      final res = reservation('r1', 'confirmada');

      expect(
        policy.resolvePickupCode([res], 'EMP-999_LUNES_2030-03-04').status,
        PickupCodeStatus.notFound,
      );
      expect(
        policy.resolvePickupCode([res], '  ').status,
        PickupCodeStatus.notFound,
      );
    });
  });

  test(
    'Flujo completo: al cancelar la reserva, cocina rechaza su QR',
    () async {
      final repo = SupabaseReservationRepository();
      final res = reservation('qr-cancel-flow', 'confirmada');
      await repo.createReservation(res);

      var dayOrders = await repo.getAllReservationsForDate(date);
      expect(
        policy.resolvePickupCode(dayOrders, res.pickupCode).isValid,
        isTrue,
      );

      await repo.cancelReservation(res.id);

      dayOrders = await repo.getAllReservationsForDate(date);
      final result = policy.resolvePickupCode(dayOrders, res.pickupCode);
      expect(result.isValid, isFalse);
      expect(result.status, PickupCodeStatus.cancelled);
    },
  );
}
