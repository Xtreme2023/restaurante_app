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

/// Modo demostración: permite reservar y entregar fuera de horario.
/// Solo el administrador lo activa; no se guarda y se apaga al reiniciar.
class DemoModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) => state = enabled;
}

final demoModeProvider = NotifierProvider<DemoModeNotifier, bool>(
  DemoModeNotifier.new,
);

/// Si el usuario actual es una cuenta de prueba (usuarios.es_cuenta_prueba).
/// Habilita en su pantalla el botón para regenerar los tickets de la semana.
final testAccountProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authProvider);
  final repo = ref.watch(reservationRepositoryProvider);
  if (user == null || repo is! PickupCodeRepository) return false;
  return (repo as PickupCodeRepository).isTestAccount(user.id);
});

/// Proveedor de la instancia del caso de uso de políticas
final reservationPolicyUseCaseProvider = Provider<ReservationPolicy>((ref) {
  return ReservationPolicy(ignoreServiceHours: ref.watch(demoModeProvider));
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

/// Reloj real del sistema. Las acciones con plazo (cancelar) lo consultan en
/// el momento de ejecutarse; las pruebas pueden sobrescribirlo.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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
  // Cambios locales hechos mientras una carga estaba en curso. Al terminar la
  // carga se aplican sobre la lista recibida para no perderlos ni duplicarlos.
  int _loadsInFlight = 0;
  final Map<String, Reservation> _changedDuringLoad = {};

  /// Motivo del último fallo de [createReservation], para mostrarlo al usuario.
  String? lastError;

  @override
  List<Reservation> build() {
    final user = ref.watch(authProvider);
    Future.microtask(() => loadReservations(userId: user?.id ?? ''));
    return [];
  }

  Future<void> loadReservations({String userId = ''}) async {
    _loadsInFlight++;
    try {
      final repo = ref.read(reservationRepositoryProvider);
      final list = await repo.getUserReservations(userId);
      state = _mergeById(list, _changedDuringLoad.values);
    } catch (e) {
      debugPrint('⚠️ Error cargando reservas del usuario: $e');
    } finally {
      _loadsInFlight--;
      if (_loadsInFlight == 0) _changedDuringLoad.clear();
    }
  }

  /// Reemplaza por id las reservas de [base] que cambiaron y antepone las
  /// nuevas. Una misma reserva nunca aparece dos veces.
  static List<Reservation> _mergeById(
    List<Reservation> base,
    Iterable<Reservation> changed,
  ) {
    final changedById = {for (final r in changed) r.id: r};
    final baseIds = {for (final r in base) r.id};
    return [
      ...changedById.values.where((r) => !baseIds.contains(r.id)),
      for (final r in base) changedById[r.id] ?? r,
    ];
  }

  void _applyLocalChanges(Iterable<Reservation> changed) {
    if (_loadsInFlight > 0) {
      for (final r in changed) {
        _changedDuringLoad[r.id] = r;
      }
    }
    state = _mergeById(state, changed);
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
        storedPickupCode: Reservation.generatePickupCode(),
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

      final saved = await repo.createReservation(newRes);
      _applyLocalChanges([saved]);
      lastError = null;
      return true;
    } catch (e) {
      debugPrint('⚠️ No se pudo crear la reserva: $e');
      lastError = e.toString().replaceFirst('Exception: ', '');
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
        storedPickupCode: Reservation.generatePickupCode(),
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
      createdList.add(await repo.createReservation(res));
      count++;
    }

    for (final famId in selectedFamiliarIds) {
      final famName = familiarNames[famId] ?? 'Familiar';
      final res = Reservation(
        id: const Uuid().v4(),
        userId: userId,
        storedEmployeeCode: currentUser?.employeeCode,
        storedPickupCode: Reservation.generatePickupCode(),
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
      createdList.add(await repo.createReservation(res));
      count++;
    }

    _applyLocalChanges(createdList);
    return count;
  }

  /// Cancela una reserva validando el plazo con la hora real del momento en
  /// que se ejecuta, no con la hora en que se abrió la pantalla: si se abrió a
  /// las 8:57 y se confirma a las 9:03, se rechaza.
  Future<PolicyCheckResult> cancelReservation(String reservationId) async {
    final reservation = state.where((r) => r.id == reservationId).firstOrNull;
    if (reservation == null) {
      return const PolicyCheckResult(
        isAllowed: false,
        message: 'No se encontró la reserva. Actualiza la lista.',
      );
    }
    if (!reservation.isConfirmed) {
      return const PolicyCheckResult(
        isAllowed: false,
        message: 'Solo se pueden cancelar reservas confirmadas.',
      );
    }

    final now = ref.read(clockProvider)();
    final check = ref
        .read(reservationPolicyUseCaseProvider)
        .checkCanCancel(reservation.date, now);
    if (!check.isAllowed) {
      // Actualiza la hora de la UI para que el botón refleje el bloqueo.
      ref.read(currentTimeProvider.notifier).setTime(now);
      return check;
    }

    try {
      final repo = ref.read(reservationRepositoryProvider);
      await repo.cancelReservation(reservationId);
      _applyLocalChanges([reservation.copyWith(status: 'cancelada')]);
      return PolicyCheckResult.allowed;
    } catch (e) {
      debugPrint('⚠️ Error al cancelar la reserva: $e');
      return PolicyCheckResult(
        isAllowed: false,
        message: e.toString().contains('PLAZO_CANCELACION_VENCIDO')
            ? 'El plazo de cancelación para hoy venció a las 8:59 AM.'
            : 'No se pudo cancelar la reserva. Intenta nuevamente.',
      );
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
      _applyLocalChanges(
        state
            .where((r) => r.id == reservationId)
            .map((r) => r.copyWith(quantity: quantity)),
      );
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
