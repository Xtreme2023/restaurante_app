import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';

abstract class ReservationRepository {
  Future<List<Reservation>> getUserReservations(String userId);
  Future<List<Reservation>> getAllReservationsForDate(DateTime date);
  Future<void> createReservation(Reservation reservation);
  Future<void> cancelReservation(String reservationId);
  Future<void> updateReservationStatus(String reservationId, String status);
  Future<List<Holiday>> getHolidays();
}

abstract interface class ReservationQuantityRepository {
  Future<void> updateReservationQuantity(String reservationId, int quantity);
}
