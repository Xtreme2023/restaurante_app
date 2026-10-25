import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';

abstract class ReservationRepository {
  Future<List<Reservation>> getUserReservations(String userId);
  Future<List<Reservation>> getUserReservationsForPeriod(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<Reservation>> getAllReservationsForDate(DateTime date);
  Future<void> createReservation(Reservation reservation);
  Future<void> cancelReservation(String reservationId);
  Future<void> updateReservationStatus(String reservationId, String status);
  Future<void> markReservationAsPickedUp(String reservationId, bool recogido);
  Future<List<Map<String, dynamic>>> getAttendanceForDate(DateTime date);
  Future<void> registerAttendance({
    required String userId,
    int? reservationId,
    required DateTime date,
    bool asistio = true,
    String? observacion,
  });
  Future<List<Holiday>> getHolidays();
}
