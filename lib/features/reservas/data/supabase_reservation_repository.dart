import 'package:flutter/foundation.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';

class SupabaseReservationRepository
    implements ReservationRepository, ReservationQuantityRepository {
  final Map<String, int> _monthlyQuantities = {};
  final Map<String, String> _monthlyStatuses = {};
  // Almacén en memoria para respaldo y funcionamiento sin conexión / demo
  final List<Reservation> _inMemoryReservations = [
    Reservation(
      id: 'res-demo-today-1',
      userId: 'demo-user-123',
      userName: 'Juan Pérez (Empleado)',
      dishName: 'Silpancho Cochabambino',
      date: DateTime.now(),
      type: 'diaria',
      status: 'confirmada',
      notes: 'Sin locoto en la sarza',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Reservation(
      id: 'res-demo-today-2',
      userId: 'demo-emp-2',
      userName: 'María Quispe (Empleado)',
      dishName: 'Pique Macho Especial',
      date: DateTime.now(),
      type: 'diaria',
      status: 'confirmada',
      notes: 'Bien caliente por favor',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Reservation(
      id: 'res-demo-today-3',
      userId: 'demo-emp-3',
      userName: 'Carlos Mamani (Empleado)',
      dishName: 'Sopa de Maní Tradicional',
      date: DateTime.now(),
      type: 'diaria',
      status: 'entregada',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Reservation(
      id: 'res-demo-1',
      userId: 'demo-user-123',
      userName: 'Juan Pérez (Empleado)',
      dishName: 'Silpancho Cochabambino',
      date: DateTime.now().add(const Duration(days: 1)),
      type: 'diaria',
      status: 'confirmada',
      notes: 'Sin locoto en la sarza',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Reservation(
      id: 'res-demo-2',
      userId: 'demo-user-123',
      userName: 'Juan Pérez (Empleado)',
      dishName: 'Sopa de Maní Tradicional',
      date: DateTime.now().add(const Duration(days: 2)),
      type: 'diaria',
      status: 'confirmada',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Reservation(
      id: 'res-demo-3',
      userId: 'demo-user-123',
      userName: 'Juan Pérez (Empleado)',
      dishName: 'Pique Macho Especial',
      date: DateTime.now().subtract(const Duration(days: 2)),
      type: 'diaria',
      status: 'entregada',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  /// Limpia las reservas de prueba en memoria.
  void clearTestReservations() {
    _inMemoryReservations.removeWhere(
      (r) =>
          r.userId.startsWith('demo-') ||
          r.userName.toLowerCase().contains('empleado') ||
          r.userName.toLowerCase().contains('juan'),
    );
  }

  @override
  Future<List<Reservation>> getUserReservations(String userId) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      final reservations = _inMemoryReservations
          .where(
            (r) =>
                r.userId == userId ||
                userId == 'demo-user-123' ||
                userId.isEmpty,
          )
          .toList();
      return _withMonthlyPlanReservations(
        userId: userId,
        userName: reservations.isNotEmpty
            ? reservations.first.userName
            : 'Empleado',
        reservations: reservations,
        hasMonthlyPlan: userId == 'demo-user-123',
      );
    }
    if (!_isUuid(userId)) {
      final reservations = _inMemoryReservations
          .where(
            (r) =>
                r.userId == userId ||
                userId == 'demo-user-123' ||
                userId.isEmpty,
          )
          .toList();
      return _withMonthlyPlanReservations(
        userId: userId,
        userName: reservations.isNotEmpty
            ? reservations.first.userName
            : 'Empleado',
        reservations: reservations,
        hasMonthlyPlan: false,
      );
    }

    try {
      final response = await client
          .from('reservations')
          .select('*, dishes(name)')
          .eq('user_id', userId)
          .order('reservation_date', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final reservations = data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map['dishes'] != null && map['dishes']['name'] != null) {
          map['dish_name'] = map['dishes']['name'];
        }
        if (map['dish_name'] != null &&
            !map['dish_name'].toString().contains('Almuerzo Completo') &&
            map['plato_principal'] != null) {
          map['dish_name'] =
              'Almuerzo del día (${map['plato_principal']} + ${map['sopa_nombre'] ?? "Sopa de Maní Tradicional"})';
        }
        return Reservation.fromJson(map);
      }).toList();
      final profile = await _monthlyPlanProfile(client, userId);
      return _withMonthlyPlanReservations(
        userId: userId,
        userName: profile.$2.isNotEmpty
            ? profile.$2
            : reservations.isNotEmpty
            ? reservations.first.userName
            : 'Empleado',
        employeeCode: profile.$3,
        reservations: reservations,
        hasMonthlyPlan: profile.$1,
      );
    } catch (e1) {
      try {
        final response = await client
            .from('reservas')
            .select()
            .eq('empleado_id', userId)
            .order('fecha', ascending: false);
        final List<dynamic> data = response as List<dynamic>;
        final reservations = data
            .map(
              (item) =>
                  Reservation.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        final profile = await _monthlyPlanProfile(client, userId);
        return _withMonthlyPlanReservations(
          userId: userId,
          userName: reservations.isNotEmpty
              ? reservations.first.userName
              : 'Empleado',
          employeeCode: profile.$3,
          reservations: reservations,
          hasMonthlyPlan: profile.$1,
        );
      } catch (e2) {
        debugPrint(
          '⚠️ Error al consultar reservas del usuario en Supabase ($e1, $e2). Retornando memoria.',
        );
        return _inMemoryReservations
            .where((r) => r.userId == userId || userId == 'demo-user-123')
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      }
    }
  }

  Future<(bool, String, String)> _monthlyPlanProfile(
    dynamic client,
    String userId,
  ) async {
    try {
      final row = await client
          .from('usuarios')
          .select('nombres, apellidos, has_monthly_plan, employee_code')
          .eq('id', userId)
          .maybeSingle();
      if (row != null) {
        return (
          row['has_monthly_plan'] == true,
          '${row['nombres'] ?? ''} ${row['apellidos'] ?? ''}'.trim(),
          row['employee_code']?.toString() ?? '',
        );
      }
    } catch (e) {
      debugPrint('ℹ️ No se pudo consultar la modalidad del empleado: $e');
    }
    return (false, '', '');
  }

  List<Reservation> _withMonthlyPlanReservations({
    required String userId,
    required String userName,
    String employeeCode = '',
    required List<Reservation> reservations,
    required bool hasMonthlyPlan,
  }) {
    if (!hasMonthlyPlan || userId.isEmpty) {
      return reservations..sort((a, b) => b.date.compareTo(a.date));
    }

    final today = DateTime.now();
    final endOfMonth = DateTime(today.year, today.month + 1, 0);
    final existingDays = reservations
        .where((r) => r.status != 'cancelada')
        .map((r) => r.date)
        .toList();
    final generated = <Reservation>[];
    for (
      var day = DateTime(today.year, today.month, today.day);
      !day.isAfter(endOfMonth);
      day = day.add(const Duration(days: 1))
    ) {
      if (day.weekday > DateTime.friday ||
          existingDays.any((date) => AppDateUtils.isSameDay(date, day))) {
        continue;
      }
      generated.add(
        Reservation(
          id: 'monthly-$userId-${day.toIso8601String().substring(0, 10)}',
          userId: userId,
          userName: userName,
          storedEmployeeCode: employeeCode,
          beneficiaryName: userName,
          date: day,
          type: 'pension',
          status: 'confirmada',
          price: 15.0,
          notes: 'Plan Mensual',
          createdAt: day,
        ),
      );
    }
    return [...reservations, ...generated]
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<List<Reservation>> getAllReservationsForDate(DateTime date) async {
    final client = SupabaseConfig.client;
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    if (client == null) {
      return _inMemoryReservations
          .where((r) => AppDateUtils.isSameDay(r.date, date))
          .toList();
    }

    Future<List<Reservation>> withMonthlyPlanOrders(
      List<Reservation> reservations,
    ) async {
      if (date.weekday > DateTime.friday) {
        return _attachEmployeeData(reservations, client);
      }
      try {
        final monthlyResponse = await client
            .from('usuarios')
            .select(
              'id, nombres, apellidos, email, employee_code, rol, has_monthly_plan, activo',
            )
            .eq('has_monthly_plan', true);

        final existingUserIds = reservations
            .where((r) => r.familiarId == null)
            .map((r) => r.userId)
            .toSet();
        final monthlyOrders = (monthlyResponse as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .where((user) {
              if (user['activo'] == false) return false;

              // El enum puede llegar con distintas etiquetas según el
              // esquema; solo se excluyen roles administrativos y de cocina.
              final role = user['rol']?.toString().trim().toUpperCase() ?? '';
              return !{
                'ADMIN',
                'ADMINISTRADOR',
                'COCINA',
                'ENCARGADO',
                'INSTITUCION',
              }.contains(role);
            })
            .where((user) => !existingUserIds.contains(user['id'].toString()))
            .map(
              (user) => Reservation(
                id: 'monthly-${user['id']}-$dateStr',
                userId: user['id'].toString(),
                userName: '${user['nombres'] ?? ''} ${user['apellidos'] ?? ''}'
                    .trim(),
                beneficiaryName:
                    '${user['nombres'] ?? ''} ${user['apellidos'] ?? ''}'
                        .trim(),
                storedEmployeeCode: user['employee_code']?.toString(),
                dishName: 'Almuerzo del día',
                date: date,
                type: 'pension',
                status:
                    _monthlyStatuses['monthly-${user['id']}-$dateStr'] ??
                    'confirmada',
                price: 15.0,
                quantity:
                    _monthlyQuantities['monthly-${user['id']}-$dateStr'] ?? 1,
                notes: 'Plan Mensual',
                createdAt: date,
              ),
            )
            .toList();

        return _attachEmployeeData([...reservations, ...monthlyOrders], client);
      } catch (e) {
        debugPrint('ℹ️ No se pudieron cargar empleados con Plan Mensual: $e');
        return _attachEmployeeData(reservations, client);
      }
    }

    // 1. Intentar consultar 'reservations' con joins de platos y perfiles
    try {
      final response = await client
          .from('reservations')
          .select('*, dishes(name), profiles(full_name)')
          .eq('reservation_date', dateStr);

      final List<dynamic> data = response as List<dynamic>;
      final reservations = data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map['dishes'] != null && map['dishes']['name'] != null) {
          map['dish_name'] = map['dishes']['name'];
        }
        if (map['profiles'] != null && map['profiles']['full_name'] != null) {
          map['user_name'] = map['profiles']['full_name'];
        }
        return Reservation.fromJson(map);
      }).toList();
      return withMonthlyPlanOrders(reservations);
    } catch (e1) {
      debugPrint(
        'ℹ️ Fallback 1: No se pudo consultar reservations con relaciones ($e1). Probando sin relaciones.',
      );

      // 2. Intentar consultar 'reservations' sin relaciones
      try {
        final response = await client
            .from('reservations')
            .select()
            .eq('reservation_date', dateStr);
        final List<dynamic> data = response as List<dynamic>;
        final reservations = data
            .map(
              (item) =>
                  Reservation.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        return withMonthlyPlanOrders(reservations);
      } catch (e2) {
        debugPrint(
          'ℹ️ Fallback 2: No se pudo consultar tabla reservations ($e2). Probando tabla reservas.',
        );

        // 3. Intentar consultar tabla 'reservas' (esquema DDL principal)
        try {
          final response = await client
              .from('reservas')
              .select()
              .eq('fecha', dateStr);
          final List<dynamic> data = response as List<dynamic>;
          final reservations = data
              .map(
                (item) => Reservation.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
          return withMonthlyPlanOrders(reservations);
        } catch (e3) {
          debugPrint(
            '⚠️ Error al consultar reservas en Supabase ($e3). Retornando datos en memoria.',
          );
          return _inMemoryReservations
              .where((r) => AppDateUtils.isSameDay(r.date, date))
              .toList();
        }
      }
    }
  }

  Future<List<Reservation>> _attachEmployeeData(
    List<Reservation> reservations,
    dynamic client,
  ) async {
    final employeeIds = reservations
        .map((reservation) => reservation.userId)
        .where((id) => _isUuid(id))
        .toSet()
        .toList();
    if (employeeIds.isEmpty) return reservations;

    try {
      final response = await client
          .from('usuarios')
          .select('id, nombres, apellidos, employee_code')
          .inFilter('id', employeeIds);
      final employees = <String, Map<String, dynamic>>{
        for (final item in response as List<dynamic>)
          item['id'].toString(): Map<String, dynamic>.from(item as Map),
      };

      return reservations.map((reservation) {
        final employee = employees[reservation.userId];
        if (employee == null) return reservation;
        final fullName =
            '${employee['nombres'] ?? ''} ${employee['apellidos'] ?? ''}'
                .trim();
        return reservation.copyWith(
          userName: fullName.isEmpty ? reservation.userName : fullName,
          storedEmployeeCode:
              employee['employee_code']?.toString() ??
              reservation.storedEmployeeCode,
        );
      }).toList();
    } catch (e) {
      debugPrint('ℹ️ No se pudieron completar nombres de empleados: $e');
      return reservations;
    }
  }

  @override
  Future<void> createReservation(Reservation reservation) async {
    // Almacenar en memoria primero para reactividad inmediata
    final existingIdx = _inMemoryReservations.indexWhere(
      (r) => r.id == reservation.id,
    );
    if (existingIdx != -1) {
      _inMemoryReservations[existingIdx] = reservation;
    } else {
      _inMemoryReservations.add(reservation);
    }

    final client = SupabaseConfig.client;
    if (client == null) {
      return;
    }

    final dateStr =
        "${reservation.date.year.toString().padLeft(4, '0')}-${reservation.date.month.toString().padLeft(2, '0')}-${reservation.date.day.toString().padLeft(2, '0')}";

    // Nombre estructurado según categoría del menú
    final comboDishName = reservation.dishName.isNotEmpty
        ? reservation.dishName
        : (reservation.isAlmuerzoCompleto
              ? 'Almuerzo del día (${reservation.entradaNombre ?? "Ensalada Fresca del Día"} + ${reservation.sopaNombre ?? "Sopa del día"} + ${reservation.platoPrincipal ?? "Segundo"})'
              : (reservation.platoPrincipal ?? 'Plato del Día'));

    try {
      // 1. Intento primario con columnas dedicadas para Almuerzo Completo en Supabase
      final payload = {
        'id': reservation.id,
        'user_id': reservation.userId,
        'employee_code': reservation.storedEmployeeCode,
        if (_isUuid(reservation.dishId)) 'dish_id': reservation.dishId,
        'dish_name': comboDishName,
        'entrada_nombre': reservation.entradaNombre,
        'ensalada_nombre': reservation.entradaNombre,
        'plato_principal': reservation.platoPrincipal ?? reservation.dishName,
        'sopa_nombre': reservation.sopaNombre,
        'es_almuerzo_completo': reservation.isAlmuerzoCompleto,
        'menu_category': reservation.menuCategory.wireValue,
        'categoria_menu': reservation.menuCategory.label,
        'reservation_date': dateStr,
        'type': reservation.type,
        'status': reservation.status,
        if (reservation.familiarId != null)
          'familiar_id': reservation.familiarId,
        'beneficiary_name': reservation.displayName,
        'price': reservation.price,
        'quantity': reservation.quantity,
        if (reservation.notes != null) 'notes': reservation.notes,
      };

      await client.from('reservations').insert(payload);
    } catch (e1) {
      // 2. Fallback de compatibilidad: Por si aún no se corrió la migración de nuevas columnas
      try {
        final payloadFallback = {
          'id': reservation.id,
          'user_id': reservation.userId,
          'employee_code': reservation.storedEmployeeCode,
          if (_isUuid(reservation.dishId)) 'dish_id': reservation.dishId,
          'reservation_date': dateStr,
          'type': reservation.type,
          'status': reservation.status,
          if (reservation.familiarId != null)
            'familiar_id': reservation.familiarId,
          'beneficiary_name': reservation.displayName,
          'price': reservation.price,
          'quantity': reservation.quantity,
          'notes': [
            if (reservation.notes != null && reservation.notes!.isNotEmpty)
              reservation.notes,
            'Categoría: ${reservation.menuCategory.label}',
            'Combo: $comboDishName',
          ].join(' | '),
        };
        await client.from('reservations').insert(payloadFallback);
      } catch (e2) {
        // 3. Fallback hacia tabla alternativa 'reservas'
        try {
          final payloadReservas = {
            'empleado_id': reservation.userId,
            'employee_code': reservation.storedEmployeeCode,
            if (reservation.familiarId != null &&
                int.tryParse(reservation.familiarId!) != null)
              'familiar_id': int.tryParse(reservation.familiarId!),
            'fecha': dateStr,
            'estado': reservation.status.toUpperCase(),
            'tipo_tarifa': reservation.price <= 15
                ? 'PLAN_MENSUAL'
                : 'PARTICULAR',
            'precio': reservation.price,
            'cantidad': reservation.quantity,
            'notas': [
              if (reservation.notes != null && reservation.notes!.isNotEmpty)
                reservation.notes,
              'Categoría: ${reservation.menuCategory.label}',
              'Combo: $comboDishName',
            ].join(' | '),
          };
          await client.from('reservas').insert(payloadReservas);
        } catch (e3) {
          debugPrint(
            '⚠️ Error al guardar reserva en Supabase ($e1, $e2, $e3). Guardada en memoria.',
          );
        }
      }
    }
  }

  bool _isUuid(String? value) {
    if (value == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    final index = _inMemoryReservations.indexWhere(
      (r) => r.id == reservationId,
    );
    if (index != -1) {
      _inMemoryReservations[index] = _inMemoryReservations[index].copyWith(
        status: 'cancelada',
      );
    }

    final client = SupabaseConfig.client;
    if (client == null) return;

    try {
      await client
          .from('reservations')
          .update({'status': 'cancelada'})
          .eq('id', reservationId);
    } catch (e1) {
      try {
        await client
            .from('reservas')
            .update({'estado': 'CANCELADA'})
            .eq('id', reservationId);
      } catch (e2) {
        debugPrint('⚠️ Error al cancelar reserva en Supabase: $e1, $e2');
      }
    }
  }

  @override
  Future<void> updateReservationStatus(
    String reservationId,
    String status,
  ) async {
    final index = _inMemoryReservations.indexWhere(
      (r) => r.id == reservationId,
    );
    if (reservationId.startsWith('monthly-')) {
      _monthlyStatuses[reservationId] = status;
    }
    if (index != -1) {
      _inMemoryReservations[index] = _inMemoryReservations[index].copyWith(
        status: status,
      );
    }

    final client = SupabaseConfig.client;
    if (client == null) return;

    try {
      await client
          .from('reservations')
          .update({'status': status})
          .eq('id', reservationId);
    } catch (e1) {
      try {
        await client
            .from('reservas')
            .update({'estado': status.toUpperCase()})
            .eq('id', reservationId);
      } catch (e2) {
        debugPrint(
          '⚠️ Error al actualizar estado de reserva en Supabase: $e1, $e2',
        );
      }
    }
  }

  @override
  Future<void> updateReservationQuantity(
    String reservationId,
    int quantity,
  ) async {
    if (quantity < 1) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Debe ser mayor que cero.',
      );
    }

    final index = _inMemoryReservations.indexWhere(
      (r) => r.id == reservationId,
    );
    if (reservationId.startsWith('monthly-')) {
      _monthlyQuantities[reservationId] = quantity;
    }
    if (index != -1) {
      _inMemoryReservations[index] = _inMemoryReservations[index].copyWith(
        quantity: quantity,
      );
    }

    final client = SupabaseConfig.client;
    if (client == null || reservationId.startsWith('monthly-')) return;

    try {
      await client
          .from('reservations')
          .update({'quantity': quantity})
          .eq('id', reservationId);
    } catch (e1) {
      try {
        await client
            .from('reservas')
            .update({'cantidad': quantity})
            .eq('id', reservationId);
      } catch (e2) {
        debugPrint('⚠️ Error al actualizar cantidad de almuerzos: $e1, $e2');
        rethrow;
      }
    }
  }

  @override
  Future<List<Holiday>> getHolidays() async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return Holiday.defaultHolidays;
    }

    try {
      final response = await client.from('holidays').select();
      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return Holiday.defaultHolidays;
      }
      return data
          .map((item) => Holiday.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Error al obtener feriados desde Supabase: $e');
      return Holiday.defaultHolidays;
    }
  }
}
