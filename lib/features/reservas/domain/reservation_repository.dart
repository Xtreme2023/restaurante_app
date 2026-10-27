import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';

abstract class ReservationRepository {
  Future<List<Reservation>> getUserReservations(String userId);
  Future<List<Reservation>> getAllReservationsForDate(DateTime date);
  /// Guarda la reserva y devuelve la versión guardada (con el id y el código
  /// de retiro asignados por el servidor, si lo hay).
  Future<Reservation> createReservation(Reservation reservation);
  Future<void> cancelReservation(String reservationId);
  Future<void> updateReservationStatus(String reservationId, String status);
  Future<List<Holiday>> getHolidays();
}

abstract interface class ReservationQuantityRepository {
  Future<void> updateReservationQuantity(String reservationId, int quantity);
}

/// Códigos de retiro validados en el servidor (RPC de Supabase).
/// Los métodos devuelven null cuando no hay servidor disponible; en ese caso
/// la app usa la validación local de [ReservationPolicy].
abstract interface class PickupCodeRepository {
  Future<PickupCodeResult?> redeemPickupCode(
    String code, {
    bool ignoreServiceHours = false,
  });

  /// Código del ticket del Plan Mensual del empleado actual para [date].
  Future<String?> monthlyPlanPickupCode(DateTime date);

  /// Si [userId] es una cuenta de prueba que puede regenerar sus tickets.
  /// En modo local (sin servidor) las cuentas demo siempre lo son.
  Future<bool> isTestAccount(String userId);

  /// Deja confirmados y con códigos nuevos los tickets de lunes a viernes de
  /// la semana de [date]. Devuelve cuántos tickets quedaron listos.
  Future<int> regenerateWeekTickets(String userId, DateTime date);
}
