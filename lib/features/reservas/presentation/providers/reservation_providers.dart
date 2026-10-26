import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/reservas/data/supabase_reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
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
      final repo = ref.read(reservationRepositoryProvider);
      final currentUser = ref.read(authProvider);
      final finalDishName =
          dishName ??
          (platoPrincipal != null && sopaNombre != null
              ? 'Almuerzo del día (${entradaNombre ?? "Ensalada Fresca del Día"} + $sopaNombre + $platoPrincipal)'
              : 'Almuerzo del día');

      final newRes = Reservation(
        id: const Uuid().v4(),
        userId: userId,
        storedEmployeeCode: currentUser?.employeeCode,
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
    required Map<String, String> familiarNames,
    required double pricePerPerson,
    String? notes,
    String userName = 'Empleado',
    String userId = 'demo-user-123',
  }) async {
    int count = 0;
    final repo = ref.read(reservationRepositoryProvider);
    final currentUser = ref.read(authProvider);
    final List<Reservation> createdList = [];

    final finalDishName = dishName.isNotEmpty
        ? dishName
        : (platoPrincipal != null && sopaNombre != null
              ? 'Almuerzo del día (${entradaNombre ?? "Ensalada Fresca del Día"} + $sopaNombre + $platoPrincipal)'
              : 'Almuerzo del día');

    if (reserveForEmployee) {
      final res = Reservation(
        id: const Uuid().v4(),
        userId: userId,
        storedEmployeeCode: currentUser?.employeeCode,
        userName: userName,
        beneficiaryName: userName,
        dishName: finalDishName,
        entradaNombre: entradaNombre,
        platoPrincipal: platoPrincipal,
        sopaNombre: sopaNombre,
        isAlmuerzoCompleto: isAlmuerzoCompleto,
        menuCategory: menuCategory,
        date: date,
        type: pricePerPerson == 15.0 ? 'pension' : 'diaria',
        status: 'confirmada',
        price: pricePerPerson,
        notes: notes,
        createdAt: DateTime.now(),
      );
      await repo.createReservation(res);
      createdList.add(res);
      count++;
    }

    for (final famId in selectedFamiliarIds) {
      final famName = familiarNames[famId] ?? 'Familiar';
      final res = Reservation(
        id: const Uuid().v4(),
        userId: userId,
        storedEmployeeCode: currentUser?.employeeCode,
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
        type: pricePerPerson == 15.0 ? 'pension' : 'diaria',
        status: 'confirmada',
        price: pricePerPerson,
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
      return false;
    }
  }

  Future<bool> updateQuantity(String reservationId, int quantity) async {
    try {
      final repo = ref.read(reservationRepositoryProvider);
      if (repo is! ReservationQuantityRepository) {
        throw StateError('El repositorio no permite editar cantidades.');
      }
      final quantityRepo = repo as ReservationQuantityRepository;
      await quantityRepo.updateReservationQuantity(reservationId, quantity);
      state = state
          .map(
            (r) => r.id == reservationId ? r.copyWith(quantity: quantity) : r,
          )
          .toList();
      return true;
    } catch (e) {
      debugPrint('⚠️ Error actualizando cantidad de almuerzos: $e');
      return false;
    }
  }
}

/// Proveedor de las reservas del usuario
final userReservationsProvider =
    NotifierProvider<UserReservationsNotifier, List<Reservation>>(
      UserReservationsNotifier.new,
    );
