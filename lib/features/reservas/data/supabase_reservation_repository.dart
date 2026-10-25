import 'package:flutter/foundation.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';

class SupabaseReservationRepository implements ReservationRepository {
  // Almacén en memoria para respaldo y funcionamiento sin conexión / demo
  final List<Map<String, dynamic>> _inMemoryAttendance = [];
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
      return _inMemoryReservations
          .where(
            (r) =>
                r.userId == userId ||
                userId == 'demo-user-123' ||
                userId.isEmpty,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    if (!_isUuid(userId)) {
      return _inMemoryReservations
          .where(
            (r) =>
                r.userId == userId ||
                userId == 'demo-user-123' ||
                userId.isEmpty,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }

    try {
      // 0. Intento con vista_reservas_completas
      final viewResponse = await client
          .from('vista_reservas_completas')
          .select()
          .eq('id_usuario', userId)
          .order('fecha', ascending: false);

      final List<dynamic> viewData = viewResponse as List<dynamic>;
      if (viewData.isNotEmpty) {
        return viewData.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return Reservation.fromJson(map);
        }).toList();
      }
    } catch (eView) {
      debugPrint('ℹ️ Consulta en vista_reservas_completas: $eView');
    }

    try {
      // 1. Intento primario: Tabla oficial 'reserva' con relación de familiar y persona
      final response = await client
          .from('reserva')
          .select('*, familiar(id_familiar, parentesco, persona(nombre, apellidos))')
          .eq('id_usuario', userId)
          .order('fecha', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return Reservation.fromJson(map);
        }).toList();
      }
    } catch (eRes) {
      debugPrint('ℹ️ Consulta en tabla reserva oficial: $eRes');
    }

    try {
      final response = await client
          .from('reservations')
          .select('*, dishes(name)')
          .eq('user_id', userId)
          .order('reservation_date', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map['dishes'] != null && map['dishes']['name'] != null) {
          map['dish_name'] = map['dishes']['name'];
        }
        if (map['dish_name'] != null &&
            !map['dish_name'].toString().contains('Almuerzo Completo') &&
            map['plato_principal'] != null) {
          map['dish_name'] =
              'Almuerzo Completo (${map['plato_principal']} + ${map['sopa_nombre'] ?? "Sopa de Maní Tradicional"})';
        }
        return Reservation.fromJson(map);
      }).toList();
    } catch (e1) {
      try {
        final response = await client
            .from('reservas')
            .select()
            .eq('empleado_id', userId)
            .order('fecha', ascending: false);
        final List<dynamic> data = response as List<dynamic>;
        return data
            .map(
              (item) =>
                  Reservation.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
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

  @override
  Future<List<Reservation>> getUserReservationsForPeriod(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final client = SupabaseConfig.client;
    if (client == null || !_isUuid(userId)) {
      return _inMemoryReservations
          .where((r) =>
              (r.userId == userId ||
                  userId.isEmpty ||
                  userId == 'demo-user-123') &&
              !r.date.isBefore(startDay) &&
              !r.date.isAfter(endDay) &&
              r.status.toLowerCase() != 'cancelada')
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }

    final startStr =
        "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')} 00:00:00";
    final endStr =
        "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')} 23:59:59";

    try {
      final response = await client
          .from('vista_reservas_completas')
          .select()
          .eq('id_usuario', userId)
          .neq('estado', 'CANCELADA')
          .gte('fecha', startStr)
          .lte('fecha', endStr)
          .order('fecha', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) {
        return Reservation.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
    } catch (e) {
      debugPrint('ℹ️ Error al obtener reservas por período en vista: $e');
      final all = await getUserReservations(userId);
      return all
          .where((r) =>
              !r.date.isBefore(startDay) &&
              !r.date.isAfter(endDay) &&
              r.status.toLowerCase() != 'cancelada')
          .toList();
    }
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

    // 0. Intentar consultar 'vista_reservas_completas'
    try {
      final startStr = "$dateStr 00:00:00";
      final endStr = "$dateStr 23:59:59";
      final response = await client
          .from('vista_reservas_completas')
          .select()
          .gte('fecha', startStr)
          .lte('fecha', endStr)
          .order('id_reserva', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return Reservation.fromJson(map);
        }).toList();
      }
    } catch (eView) {
      debugPrint(
        'ℹ️ Fallback 0: No se pudo consultar vista_reservas_completas: $eView',
      );
    }

    // 1. Intentar consultar 'reservations' con joins de platos y perfiles
    try {
      final response = await client
          .from('reservations')
          .select('*, dishes(name), profiles(full_name)')
          .eq('reservation_date', dateStr);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['dishes'] != null && map['dishes']['name'] != null) {
            map['dish_name'] = map['dishes']['name'];
          }
          if (map['profiles'] != null && map['profiles']['full_name'] != null) {
            map['user_name'] = map['profiles']['full_name'];
          }
          return Reservation.fromJson(map);
        }).toList();
      }
    } catch (e1) {
      debugPrint('ℹ️ Fallback 1: reservations ($e1)');
    }

    // 2. Intentar consultar 'reservations' sin relaciones
    try {
      final response = await client
          .from('reservations')
          .select()
          .eq('reservation_date', dateStr);
      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data
            .map(
              (item) =>
                  Reservation.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      }
    } catch (e2) {
      debugPrint('ℹ️ Fallback 2: reservations ($e2)');
    }

    // 3. Intentar consultar tabla 'reservas' (esquema DDL principal)
    try {
      final response =
          await client.from('reservas').select().eq('fecha', dateStr);
      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data
            .map(
              (item) =>
                  Reservation.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      }
    } catch (e3) {
      debugPrint('⚠️ Error al consultar reservas en Supabase ($e3).');
    }

    return _inMemoryReservations
        .where((r) => AppDateUtils.isSameDay(r.date, date))
        .toList();
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
              ? 'Almuerzo Completo (${reservation.entradaNombre ?? "Ensalada Fresca del Día"} + ${reservation.sopaNombre ?? "Sopa del día"} + ${reservation.platoPrincipal ?? "Segundo"})'
              : (reservation.platoPrincipal ?? 'Plato del Día'));

    // 1. Intento primario: Inserción directa en tabla real de Supabase 'reserva'
    try {
      final payloadReservaReal = {
        if (_isUuid(reservation.userId)) 'id_usuario': reservation.userId,
        if (_isUuid(reservation.familiarId)) 'id_familiar': reservation.familiarId,
        'fecha': reservation.date.toUtc().toIso8601String(),
        'costo_aplicado': reservation.price,
        'estado': reservation.status.toUpperCase(),
        'es_pension': reservation.price <= 15.0,
        'origen': reservation.familiarId != null ? 'FAMILIAR' : 'EMPLEADO',
      };
      await client.from('reserva').insert(payloadReservaReal);
      return;
    } catch (eReal) {
      debugPrint('ℹ️ Inserción en tabla reserva falló ($eReal). Intentando tablas fallback...');
    }

    try {
      // 2. Fallback: Columnas extendidas en Supabase
      final payload = {
        'id': reservation.id,
        'user_id': reservation.userId,
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
        if (reservation.notes != null) 'notes': reservation.notes,
      };

      await client.from('reservations').insert(payload);
    } catch (e1) {
      try {
        final payloadFallback = {
          'id': reservation.id,
          'user_id': reservation.userId,
          if (_isUuid(reservation.dishId)) 'dish_id': reservation.dishId,
          'reservation_date': dateStr,
          'type': reservation.type,
          'status': reservation.status,
          if (reservation.familiarId != null)
            'familiar_id': reservation.familiarId,
          'beneficiary_name': reservation.displayName,
          'price': reservation.price,
          'notes': [
            if (reservation.notes != null && reservation.notes!.isNotEmpty)
              reservation.notes,
            'Categoría: ${reservation.menuCategory.label}',
            'Combo: $comboDishName',
          ].join(' | '),
        };
        await client.from('reservations').insert(payloadFallback);
      } catch (e2) {
        debugPrint('⚠️ Error guardando en fallback ($e1, $e2). Guardado en memoria.');
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
      final numericId = int.tryParse(reservationId);
      if (numericId != null) {
        await client
            .from('reserva')
            .update({'estado': 'CANCELADA'})
            .eq('id_reserva', numericId);
      } else {
        await client
            .from('reserva')
            .update({'estado': 'CANCELADA'})
            .eq('id_reserva', reservationId);
      }
    } catch (eRes) {
      debugPrint('ℹ️ Error actualizando estado CANCELADA en tabla reserva: $eRes');
    }

    try {
      await client
          .from('reservations')
          .update({'status': 'cancelada'})
          .eq('id', reservationId);
    } catch (_) {}
  }

  @override
  Future<void> updateReservationStatus(
    String reservationId,
    String status,
  ) async {
    final index = _inMemoryReservations.indexWhere(
      (r) => r.id == reservationId,
    );
    if (index != -1) {
      _inMemoryReservations[index] = _inMemoryReservations[index].copyWith(
        status: status,
      );
    }

    final client = SupabaseConfig.client;
    if (client == null) return;

    try {
      final numericId = int.tryParse(reservationId);
      if (numericId != null) {
        await client.from('reserva').update({'estado': status.toUpperCase()}).eq('id_reserva', numericId);
      } else {
        await client.from('reserva').update({'estado': status.toUpperCase()}).eq('id', reservationId);
      }
    } catch (_) {}

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
  Future<void> markReservationAsPickedUp(
    String reservationId,
    bool recogido,
  ) async {
    final index = _inMemoryReservations.indexWhere(
      (r) => r.id == reservationId,
    );
    if (index != -1) {
      _inMemoryReservations[index] = _inMemoryReservations[index].copyWith(
        recogido: recogido,
        status: recogido ? 'entregada' : _inMemoryReservations[index].status,
      );
    }

    final client = SupabaseConfig.client;
    if (client == null) return;

    final numericId = int.tryParse(reservationId);
    final payload = {
      'recogido': recogido,
      if (recogido) 'estado': 'ENTREGADA',
    };

    try {
      if (numericId != null) {
        await client
            .from('reserva')
            .update(payload)
            .eq('id_reserva', numericId);
      } else {
        await client
            .from('reserva')
            .update(payload)
            .eq('id_reserva', reservationId);
      }
    } catch (e) {
      debugPrint('ℹ️ Error actualizando recogido en reserva: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceForDate(DateTime date) async {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final client = SupabaseConfig.client;
    if (client == null) {
      return _inMemoryAttendance
          .where((a) => a['fecha'] == dateStr)
          .toList();
    }

    try {
      final response = await client
          .from('asistencia')
          .select()
          .eq('fecha', dateStr);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('ℹ️ Error al consultar asistencia: $e');
      return _inMemoryAttendance
          .where((a) => a['fecha'] == dateStr)
          .toList();
    }
  }

  @override
  Future<void> registerAttendance({
    required String userId,
    int? reservationId,
    required DateTime date,
    bool asistio = true,
    String? observacion,
  }) async {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final record = {
      'id_usuario': userId,
      if (reservationId != null) 'id_reserva': reservationId,
      'fecha': dateStr,
      'hora_marcado': timeStr,
      'asistio': asistio,
      if (observacion != null) 'observacion': observacion,
      'creado_en': now.toUtc().toIso8601String(),
    };

    _inMemoryAttendance.removeWhere(
      (a) => a['id_usuario'] == userId && a['fecha'] == dateStr,
    );
    _inMemoryAttendance.add(record);

    final client = SupabaseConfig.client;
    if (client == null) return;

    try {
      await client.from('asistencia').insert(record);
    } catch (e) {
      debugPrint('ℹ️ Error al registrar asistencia en Supabase: $e');
    }
  }

  @override
  Future<List<Holiday>> getHolidays() async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return Holiday.defaultHolidays;
    }

    try {
      final List<Holiday> list = [];

      // 1. Consultar excepcion_calendario (HU6)
      try {
        final exRes = await client.from('excepcion_calendario').select();
        if (exRes.isNotEmpty) {
          for (final row in exRes) {
            final fStr = row['fecha']?.toString();
            if (fStr != null && fStr.isNotEmpty) {
              final dt = DateTime.tryParse(fStr);
              if (dt != null) {
                list.add(
                  Holiday(
                    id: row['id_excepcion']?.toString() ?? 'ex-${list.length}',
                    date: dt,
                    name:
                        row['motivo']?.toString() ?? 'Excepción de calendario',
                    description: 'Día no habilitado en calendario',
                  ),
                );
              }
            }
          }
        }
      } catch (eEx) {
        debugPrint('ℹ️ No se pudo cargar excepcion_calendario: $eEx');
      }

      // 2. Consultar tabla holidays si existiera
      try {
        final response = await client.from('holidays').select();
        final List<dynamic> data = response as List<dynamic>;
        if (data.isNotEmpty) {
          list.addAll(
            data.map((item) => Holiday.fromJson(item as Map<String, dynamic>)),
          );
        }
      } catch (_) {}

      // Si no hay datos, incluir los feriados por defecto
      if (list.isEmpty) {
        return Holiday.defaultHolidays;
      }
      return list;
    } catch (e) {
      debugPrint('⚠️ Error al obtener feriados desde Supabase: $e');
      return Holiday.defaultHolidays;
    }
  }
}
