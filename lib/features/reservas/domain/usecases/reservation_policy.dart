import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';

class PolicyCheckResult {
  final bool isAllowed;
  final String message;

  const PolicyCheckResult({required this.isAllowed, required this.message});

  static const PolicyCheckResult allowed = PolicyCheckResult(
    isAllowed: true,
    message: 'Operación permitida',
  );
}

enum PickupCodeStatus {
  valid,
  notFound,
  cancelled,
  alreadyDelivered,
  wrongDate,
  outsideHours,
}

extension PickupCodeStatusMessage on PickupCodeStatus {
  String get message {
    switch (this) {
      case PickupCodeStatus.valid:
        return 'Código válido';
      case PickupCodeStatus.notFound:
        return 'Código inválido o sin reserva para este día.';
      case PickupCodeStatus.cancelled:
        return 'La reserva de este código fue cancelada. El QR ya no es válido.';
      case PickupCodeStatus.alreadyDelivered:
        return 'Este almuerzo ya fue registrado como retirado.';
      case PickupCodeStatus.wrongDate:
        return 'Este código corresponde a otro día.';
      case PickupCodeStatus.outsideHours:
        return 'La entrega está habilitada únicamente de 12:00 a 14:00.';
    }
  }
}

/// Resultado de validar o canjear un código de retiro.
/// En el canje del servidor, [valid] significa que ya quedó entregado.
class PickupCodeResult {
  final PickupCodeStatus status;
  final Reservation? reservation;
  final String? reservationId;

  const PickupCodeResult(this.status, {this.reservation, this.reservationId});

  bool get isValid => status == PickupCodeStatus.valid;
  String get message => status.message;
}

class ReservationPolicy {
  static const int deliveryStartHour = 12;
  static const int deliveryEndHour = 14;

  /// Modo demostración: ignora los límites de horario (09:00 para reservar o
  /// cancelar el mismo día y 12:00–14:00 para entregar). Se mantienen las
  /// demás reglas: fechas pasadas, fines de semana, feriados y entrega solo
  /// el día de la reserva.
  final bool ignoreServiceHours;

  const ReservationPolicy({this.ignoreServiceHours = false});

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Verifica si una fecha seleccionada puede ser reservada según las políticas de la institución.
  PolicyCheckResult checkCanReserve(
    DateTime selectedDate,
    DateTime currentTime, {
    List<Holiday> holidays = const [],
  }) {
    final today = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final target = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    // Regla 1: No se puede reservar en días pasados
    if (target.isBefore(today)) {
      return const PolicyCheckResult(
        isAllowed: false,
        message: 'No es posible realizar reservas para fechas pasadas.',
      );
    }

    // Regla 2: Fin de semana (sábado y domingo sin servicio)
    if (_isWeekend(target)) {
      return const PolicyCheckResult(
        isAllowed: false,
        message: 'El restaurante no brinda servicio los fines de semana.',
      );
    }

    // Regla 3: Control de Feriados
    for (final holiday in holidays) {
      if (_isSameDay(holiday.date, target)) {
        return PolicyCheckResult(
          isAllowed: false,
          message: 'Día no hábil por feriado institucional: ${holiday.name}.',
        );
      }
    }

    // Regla 4: Bloqueo Horario para reservas del mismo día
    // Si es hoy, el límite estricto son las 9:00 AM (9:01 ya no es permitido)
    if (_isSameDay(target, today) && !ignoreServiceHours) {
      if (currentTime.hour > 9 ||
          (currentTime.hour == 9 && currentTime.minute > 0)) {
        return const PolicyCheckResult(
          isAllowed: false,
          message:
              'Las reservas para el almuerzo de hoy cerraron a las 9:00 AM.',
        );
      }
    }

    // Regla 5: Días futuros hábiles permitidos
    return PolicyCheckResult.allowed;
  }

  /// Verifica si una reserva existente puede cancelarse.
  PolicyCheckResult checkCanCancel(
    DateTime selectedDate,
    DateTime currentTime,
  ) {
    final today = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final target = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    // Regla 1: No se puede cancelar en fechas pasadas
    if (target.isBefore(today)) {
      return const PolicyCheckResult(
        isAllowed: false,
        message: 'No es posible cancelar una reserva de días pasados.',
      );
    }

    // Regla 2: Bloqueo Horario para cancelaciones del mismo día
    // Permitir cancelación solo antes de las 8:59 AM (a partir de las 9:00 AM ya no)
    if (_isSameDay(target, today) && !ignoreServiceHours) {
      if (currentTime.hour >= 9) {
        return const PolicyCheckResult(
          isAllowed: false,
          message:
              'El plazo de cancelación para hoy venció a las 8:59 AM (compras en curso).',
        );
      }
    }

    return PolicyCheckResult.allowed;
  }

  // Métodos simplificados booleanos para conveniencia
  bool canReserve(
    DateTime selectedDate,
    DateTime currentTime, {
    List<Holiday> holidays = const [],
  }) {
    return checkCanReserve(
      selectedDate,
      currentTime,
      holidays: holidays,
    ).isAllowed;
  }

  bool canCancel(DateTime selectedDate, DateTime currentTime) {
    return checkCanCancel(selectedDate, currentTime).isAllowed;
  }

  /// La entrega solo se registra el día de la reserva, durante el servicio.
  PolicyCheckResult checkCanDeliver(
    DateTime reservationDate,
    DateTime currentTime,
  ) {
    if (!_isSameDay(reservationDate, currentTime)) {
      return const PolicyCheckResult(
        isAllowed: false,
        message: 'La entrega solo puede registrarse el día del almuerzo.',
      );
    }

    if (ignoreServiceHours) return PolicyCheckResult.allowed;

    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    const startMinutes = deliveryStartHour * 60;
    const endMinutes = deliveryEndHour * 60;
    if (currentMinutes < startMinutes || currentMinutes >= endMinutes) {
      return const PolicyCheckResult(
        isAllowed: false,
        message: 'La entrega está habilitada únicamente de 12:00 a 14:00.',
      );
    }

    return PolicyCheckResult.allowed;
  }

  bool canDeliver(DateTime reservationDate, DateTime currentTime) {
    return checkCanDeliver(reservationDate, currentTime).isAllowed;
  }

  /// Valida un código de retiro (QR) contra las reservas del día.
  ///
  /// Solo una reserva 'confirmada' habilita el retiro: una reserva cancelada
  /// deja su QR sin efecto. Como el código se forma con empleado + fecha,
  /// varias reservas pueden compartirlo (familiares o una reserva rehecha),
  /// por eso se prioriza la que sigue confirmada. Es la validación local; con
  /// servidor el canje lo hace la RPC canjear_codigo_retiro.
  PickupCodeResult resolvePickupCode(
    List<Reservation> reservations,
    String code,
  ) {
    final normalizedCode = code.trim().toUpperCase();
    final matches = reservations
        .where((r) => r.pickupCode.toUpperCase() == normalizedCode)
        .toList();

    if (normalizedCode.isEmpty || matches.isEmpty) {
      return const PickupCodeResult(PickupCodeStatus.notFound);
    }
    for (final reservation in matches) {
      if (reservation.isConfirmed) {
        return PickupCodeResult(
          PickupCodeStatus.valid,
          reservation: reservation,
          reservationId: reservation.id,
        );
      }
    }
    if (matches.any((r) => r.isDelivered)) {
      return const PickupCodeResult(PickupCodeStatus.alreadyDelivered);
    }
    return const PickupCodeResult(PickupCodeStatus.cancelled);
  }
}
