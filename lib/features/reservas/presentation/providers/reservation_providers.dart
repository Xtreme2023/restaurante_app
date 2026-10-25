import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:uuid/uuid.dart';

/// Proveedor del repositorio de reservas
final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return SupabaseReservationRepository();
});

/// Proveedor de la instancia del caso de uso de políticas
final reservationPolicyUseCaseProvider = Provider<ReservationPolicy>((ref) {
  return ReservationPolicy();
});

/// Notifier para la fecha seleccionada en el calendario
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  @override
  set state(DateTime value) => super.state = value;

  void selectDate(DateTime date) {
    state = date;
  }
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

/// Notifier para la hora actual del sistema
class CurrentTimeNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  @override
  set state(DateTime value) => super.state = value;

  void setTime(DateTime time) {
    state = time;
  }
}

final currentTimeProvider = NotifierProvider<CurrentTimeNotifier, DateTime>(
  CurrentTimeNotifier.new,
);

/// Lista de feriados cargados desde Supabase / locales
final holidaysProvider = FutureProvider<List<Holiday>>((ref) async {
  final repo = ref.watch(reservationRepositoryProvider);
  return repo.getHolidays();
});

/// Estado consolidado de la política para la fecha actualmente seleccionada
class ReservationPolicyState {
  final bool canReserve;
  final String reserveReason;
  final bool canCancel;
  final String cancelReason;

  const ReservationPolicyState({
    required this.canReserve,
    required this.reserveReason,
    required this.canCancel,
    required this.cancelReason,
  });
}

/// Proveedor que evalúa reactivamente si la fecha seleccionada puede ser reservada o cancelada
final reservationPolicyProvider = Provider<ReservationPolicyState>((ref) {
  final policyUseCase = ref.watch(reservationPolicyUseCaseProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final currentTime = ref.watch(currentTimeProvider);
  final holidaysAsync = ref.watch(holidaysProvider);

  final holidays = holidaysAsync.value ?? Holiday.defaultHolidays;

  final reserveCheck = policyUseCase.checkCanReserve(
    selectedDate,
    currentTime,
    holidays: holidays,
  );

  final cancelCheck = policyUseCase.checkCanCancel(selectedDate, currentTime);

  return ReservationPolicyState(
    canReserve: reserveCheck.isAllowed,
    reserveReason: reserveCheck.message,
    canCancel: cancelCheck.isAllowed,
    cancelReason: cancelCheck.message,
  );
});

/// Notifier para la gestión reactiva de las reservas del usuario
class UserReservationsNotifier extends Notifier<List<Reservation>> {
  @override
  List<Reservation> build() {
    final user = ref.watch(authProvider);
    Future.microtask(() => loadReservations(userId: user?.id ?? ''));
    return [];
  }

  Future<void> loadReservations({String userId = ''}) async {
    try {
      final repo = ref.read(reservationRepositoryProvider);
      final list = await repo.getUserReservations(userId);
      state = list;
    } catch (e) {
      debugPrint('⚠️ Error cargando reservas del usuario: $e');
    }
  }

  Future<bool> createReservation({
    required DateTime date,
    String? dishId,
    String? dishName,
    String? entradaNombre,
    String? platoPrincipal,
    String? sopaNombre,
    bool isAlmuerzoCompleto = true,
    ReservationMenuCategory menuCategory =
        ReservationMenuCategory.almuerzoCompleto,
    String? familiarId,
    String? beneficiaryName,
    String? notes,
    String type = 'diaria',
    double price = 18.0,
    String userName = 'Empleado',
    String userId = 'demo-user-123',
  }) async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      if (targetDate.isBefore(todayDate)) {
        debugPrint('⛔ No se permite reservar para una fecha pasada.');
        return false;
      }
      if (AppDateUtils.isSameDay(targetDate, todayDate) &&
          (now.hour > 9 || (now.hour == 9 && now.minute > 0))) {
        debugPrint('⛔ Solo se puede reservar hasta las 9:00 AM del día de la reserva.');
        return false;
      }

      // Validar: Máximo una reserva activa por persona / familiar por día
      final alreadyReserved = state.any((r) =>
          AppDateUtils.isSameDay(r.date, date) &&
          r.status.toLowerCase() != 'cancelada' &&
          (familiarId != null
              ? r.familiarId == familiarId
              : (!r.isForFamiliar && r.familiarId == null)));

      if (alreadyReserved) {
        debugPrint('⛔ Ya existe una reserva activa para este comensal en esta fecha.');
        return false;
      }

      final repo = ref.read(reservationRepositoryProvider);
      final finalDishName =
          dishName ??
          (platoPrincipal != null && sopaNombre != null
              ? 'Almuerzo Completo (${entradaNombre ?? "Ensalada Fresca del Día"} + $sopaNombre + $platoPrincipal)'
              : 'Almuerzo Completo del Día');

      final newRes = Reservation(
        id: const Uuid().v4(),
        userId: userId,
        userName: userName,
        familiarId: familiarId,
        beneficiaryName: beneficiaryName ?? userName,
        dishId: dishId,
        dishName: finalDishName,
        entradaNombre: entradaNombre,
        platoPrincipal: platoPrincipal,
        sopaNombre: sopaNombre,
        isAlmuerzoCompleto: isAlmuerzoCompleto,
        menuCategory: menuCategory,
        date: date,
        type: type,
        status: 'confirmada',
        price: price,
        notes: notes,
        createdAt: DateTime.now(),
      );

      await repo.createReservation(newRes);
      state = [newRes, ...state];
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<int> createJointReservations({
    required DateTime date,
    required String dishName,
    String? entradaNombre,
    String? platoPrincipal,
    String? sopaNombre,
    bool isAlmuerzoCompleto = true,
    ReservationMenuCategory menuCategory =
        ReservationMenuCategory.almuerzoCompleto,
    required bool reserveForEmployee,
    required List<String> selectedFamiliarIds,
    Map<String, String> familiarNames = const {},
    required double pricePerPerson,
    Map<String?, double>? individualPrices,
    String? notes,
    String userName = 'Empleado',
    String userId = 'demo-user-123',
  }) async {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    if (targetDate.isBefore(todayDate)) {
      debugPrint('⛔ No se permite reservar para una fecha pasada.');
      return 0;
    }
    if (AppDateUtils.isSameDay(targetDate, todayDate) &&
        (now.hour > 9 || (now.hour == 9 && now.minute > 0))) {
      debugPrint('⛔ Solo se puede reservar hasta las 9:00 AM del día de la reserva.');
      return 0;
    }

    int count = 0;
    final repo = ref.read(reservationRepositoryProvider);
    final List<Reservation> createdList = [];

    final finalDishName = dishName.isNotEmpty
        ? dishName
        : (platoPrincipal != null && sopaNombre != null
              ? 'Almuerzo Completo (${entradaNombre ?? "Ensalada Fresca del Día"} + $sopaNombre + $platoPrincipal)'
              : 'Almuerzo Completo del Día');

    final empAlreadyReserved = state.any((r) =>
        AppDateUtils.isSameDay(r.date, date) &&
        r.status.toLowerCase() != 'cancelada' &&
        !r.isForFamiliar &&
        r.familiarId == null);

    if (reserveForEmployee && !empAlreadyReserved) {
      final empPrice = individualPrices != null
          ? (individualPrices[null] ?? pricePerPerson)
          : pricePerPerson;
      final res = Reservation(
        id: const Uuid().v4(),
        userId: userId,
        userName: userName,
        beneficiaryName: userName,
        dishName: finalDishName,
        entradaNombre: entradaNombre,
        platoPrincipal: platoPrincipal,
        sopaNombre: sopaNombre,
        isAlmuerzoCompleto: isAlmuerzoCompleto,
        menuCategory: menuCategory,
        date: date,
        type: empPrice == 15.0 ? 'pension' : 'diaria',
        status: 'confirmada',
        price: empPrice,
        notes: notes,
        createdAt: DateTime.now(),
      );
      await repo.createReservation(res);
      createdList.add(res);
      count++;
    }

    for (final famId in selectedFamiliarIds) {
      final famAlreadyReserved = state.any((r) =>
          AppDateUtils.isSameDay(r.date, date) &&
          r.status.toLowerCase() != 'cancelada' &&
          r.familiarId == famId);

      if (famAlreadyReserved) continue;

      final famName = familiarNames[famId] ?? 'Familiar';
      final famPrice = individualPrices != null
          ? (individualPrices[famId] ?? pricePerPerson)
          : pricePerPerson;
      final res = Reservation(
        id: const Uuid().v4(),
        userId: userId,
        userName: userName,
        familiarId: famId,
        beneficiaryName: famName,
        dishName: finalDishName,
        entradaNombre: entradaNombre,
        platoPrincipal: platoPrincipal,
        sopaNombre: sopaNombre,
        isAlmuerzoCompleto: isAlmuerzoCompleto,
        menuCategory: menuCategory,
        date: date,
        type: famPrice == 15.0 ? 'pension' : 'diaria',
        status: 'confirmada',
        price: famPrice,
        notes: notes,
        createdAt: DateTime.now(),
      );
      await repo.createReservation(res);
      createdList.add(res);
      count++;
    }

    state = [...createdList, ...state];
    return count;
  }

  Future<bool> cancelReservation(String reservationId) async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final targetRes = state.where((r) => r.id == reservationId).firstOrNull;
      if (targetRes != null) {
        final targetDate = DateTime(
          targetRes.date.year,
          targetRes.date.month,
          targetRes.date.day,
        );
        if (targetDate.isBefore(todayDate)) {
          debugPrint('⛔ No se puede cancelar una reserva de días pasados.');
          return false;
        }
        if (AppDateUtils.isSameDay(targetDate, todayDate) &&
            (now.hour > 9 || (now.hour == 9 && now.minute > 0))) {
          debugPrint(
            '⛔ Solo se puede cancelar antes de las 9:00 AM del día de la reserva.',
          );
          return false;
        }
      }

      final repo = ref.read(reservationRepositoryProvider);
      await repo.cancelReservation(reservationId);
      state = state.map((r) {
        if (r.id == reservationId) {
          return r.copyWith(status: 'cancelada');
        }
        return r;
      }).toList();
      return true;
    } catch (e) {
      debugPrint('⚠️ Error al cancelar reserva: $e');
      return false;
    }
  }
}

/// Proveedor de las reservas del usuario
final userReservationsProvider =
    NotifierProvider<UserReservationsNotifier, List<Reservation>>(
      UserReservationsNotifier.new,
    );
