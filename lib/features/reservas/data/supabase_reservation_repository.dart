import 'package:flutter/foundation.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';

class SupabaseReservationRepository
    implements
        ReservationRepository,
        ReservationQuantityRepository,
        PickupCodeRepository {
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
        tickets: profile.$1
            ? await _monthlyTickets(client, userId: userId)
            : const {},
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
          tickets: profile.$1
              ? await _monthlyTickets(client, userId: userId)
              : const {},
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
    Map<String, Map<String, dynamic>> tickets = const {},
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
      final id = _monthlyId(userId, day.toIso8601String().substring(0, 10));
      generated.add(
        Reservation(
          id: id,
          userId: userId,
          userName: userName,
          storedEmployeeCode: employeeCode,
          storedPickupCode: tickets[id]?['codigo_retiro']?.toString(),
          beneficiaryName: userName,
          date: day,
          type: 'pension',
          status:
              tickets[id]?['estado']?.toString() ??
              _monthlyStatuses[id] ??
              'confirmada',
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
        final tickets = await _monthlyTickets(client, dateStr: dateStr);
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
            .map((user) {
              final id = _monthlyId(user['id'].toString(), dateStr);
              return Reservation(
                id: id,
                userId: user['id'].toString(),
                userName: '${user['nombres'] ?? ''} ${user['apellidos'] ?? ''}'
                    .trim(),
                beneficiaryName:
                    '${user['nombres'] ?? ''} ${user['apellidos'] ?? ''}'
                        .trim(),
                storedEmployeeCode: user['employee_code']?.toString(),
                storedPickupCode: tickets[id]?['codigo_retiro']?.toString(),
                dishName: 'Almuerzo del día',
                date: date,
                type: 'pension',
                status:
                    tickets[id]?['estado']?.toString() ??
                    _monthlyStatuses[id] ??
                    'confirmada',
                price: 15.0,
                quantity: _monthlyQuantities[id] ?? 1,
                notes: 'Plan Mensual',
                createdAt: date,
              );
            })
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
  Future<Reservation> createReservation(Reservation reservation) async {
    final client = SupabaseConfig.client;
    if (client != null && _isUuid(reservation.userId)) {
      final saved = await _createReservationOnServer(client, reservation);
      if (saved != null) {
        _inMemoryReservations
          ..removeWhere((r) => r.id == reservation.id || r.id == saved.id)
          ..add(saved);
        return saved;
      }
    }

    // Almacenar en memoria primero para reactividad inmediata
    final existingIdx = _inMemoryReservations.indexWhere(
      (r) => r.id == reservation.id,
    );
    if (existingIdx != -1) {
      _inMemoryReservations[existingIdx] = reservation;
    } else {
      _inMemoryReservations.add(reservation);
    }

    if (client == null) {
      return reservation;
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
        if (reservation.storedPickupCode != null)
          'pickup_code': reservation.storedPickupCode,
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

      await _insertWithPickupCode(
        client,
        'reservations',
        payload,
        'pickup_code',
      );
    } catch (e1) {
      // 2. Fallback de compatibilidad: Por si aún no se corrió la migración de nuevas columnas
      try {
        final payloadFallback = {
          'id': reservation.id,
          'user_id': reservation.userId,
          'employee_code': reservation.storedEmployeeCode,
          if (reservation.storedPickupCode != null)
            'pickup_code': reservation.storedPickupCode,
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
        await _insertWithPickupCode(
          client,
          'reservations',
          payloadFallback,
          'pickup_code',
        );
      } catch (e2) {
        // 3. Fallback hacia tabla alternativa 'reservas'
        try {
          final payloadReservas = {
            'empleado_id': reservation.userId,
            'employee_code': reservation.storedEmployeeCode,
            if (reservation.storedPickupCode != null)
              'codigo_retiro': reservation.storedPickupCode,
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
          await _insertWithPickupCode(
            client,
            'reservas',
            payloadReservas,
            'codigo_retiro',
          );
        } catch (e3) {
          debugPrint(
            '⚠️ Error al guardar reserva en Supabase ($e1, $e2, $e3).',
          );
          // Una reserva real que no llegó al servidor no debe mostrarse: su
          // QR no existiría en la base y cocina lo rechazaría como inválido.
          if (_isUuid(reservation.userId)) {
            _inMemoryReservations.removeWhere((r) => r.id == reservation.id);
            throw Exception(
              'No se pudo guardar la reserva en el servidor: $e3',
            );
          }
        }
      }
    }
    return reservation;
  }

  /// Crea la reserva con la RPC crear_reserva y devuelve la fila guardada con
  /// el código de retiro generado por la base. Devuelve null si la RPC aún no
  /// existe (migración pendiente) para usar el insert directo.
  Future<Reservation?> _createReservationOnServer(
    dynamic client,
    Reservation reservation,
  ) async {
    final dynamic response;
    try {
      response = await client.rpc(
        'crear_reserva',
        params: {
          'p_fecha': reservation.date.toIso8601String().substring(0, 10),
          'p_familiar_id': int.tryParse(reservation.familiarId ?? ''),
          'p_dish_name': reservation.dishName,
          'p_entrada_nombre': reservation.entradaNombre,
          'p_plato_principal': reservation.platoPrincipal,
          'p_sopa_nombre': reservation.sopaNombre,
          'p_es_almuerzo_completo': reservation.isAlmuerzoCompleto,
          'p_menu_category': reservation.menuCategory.wireValue,
          'p_cantidad': reservation.quantity,
          'p_notas': reservation.notes,
        },
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        debugPrint('ℹ️ RPC crear_reserva no disponible: ${e.message}');
        return null;
      }
      throw Exception(reservationErrorMessage(e.message));
    }

    final data = Map<String, dynamic>.from(response as Map);
    return reservation.copyWith(
      id: data['id'].toString(),
      storedPickupCode: data['codigo_retiro']?.toString(),
      status: 'confirmada',
      price: (data['precio'] as num?)?.toDouble() ?? reservation.price,
    );
  }

  /// Quita el prefijo técnico (RESERVA_DUPLICADA: ...) de los errores de la
  /// RPC crear_reserva para mostrar solo el mensaje.
  static String reservationErrorMessage(String raw) =>
      raw.replaceFirst(RegExp(r'^[A-Z_]+:\s*'), '');

  /// Inserta la reserva y, si la migración de códigos de retiro aún no se
  /// aplicó, reintenta sin esa columna para no perder la reserva.
  Future<void> _insertWithPickupCode(
    dynamic client,
    String table,
    Map<String, dynamic> payload,
    String codeColumn,
  ) async {
    try {
      await client.from(table).insert(payload);
    } catch (e) {
      if (!payload.containsKey(codeColumn) ||
          !e.toString().contains(codeColumn)) {
        rethrow;
      }
      debugPrint(
        'ℹ️ Falta la columna $codeColumn en $table. Ejecuta '
        'supabase/migrations/20261026_pickup_codes_rpc.sql.',
      );
      await client.from(table).insert(Map.of(payload)..remove(codeColumn));
    }
  }

  static String _monthlyId(String userId, String dateStr) =>
      'monthly-$userId-$dateStr';

  /// Separa `monthly-<uuid>-<yyyy-mm-dd>` en (empleado, fecha).
  static (String, String)? _parseMonthlyId(String id) {
    if (!id.startsWith('monthly-') || id.length < 'monthly-'.length + 12) {
      return null;
    }
    final dateStr = id.substring(id.length - 10);
    final userId = id.substring('monthly-'.length, id.length - 11);
    return (userId, dateStr);
  }

  /// Tickets persistidos del Plan Mensual (código y estado) por id sintético.
  Future<Map<String, Map<String, dynamic>>> _monthlyTickets(
    dynamic client, {
    String? userId,
    String? dateStr,
  }) async {
    try {
      var query = client
          .from('tickets_plan_mensual')
          .select('empleado_id, fecha, codigo_retiro, estado');
      if (userId != null) query = query.eq('empleado_id', userId);
      if (dateStr != null) query = query.eq('fecha', dateStr);
      final rows = await query as List<dynamic>;
      return {
        for (final row in rows)
          _monthlyId(row['empleado_id'].toString(), row['fecha'].toString()):
              Map<String, dynamic>.from(row as Map),
      };
    } catch (e) {
      debugPrint('ℹ️ No se pudieron cargar tickets del Plan Mensual: $e');
      return {};
    }
  }

  @override
  Future<PickupCodeResult?> redeemPickupCode(
    String code, {
    bool ignoreServiceHours = false,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) return null;

    final dynamic response;
    try {
      response = await client.rpc(
        'canjear_codigo_retiro',
        params: {'p_codigo': code, 'p_ignorar_horario': ignoreServiceHours},
      );
    } on PostgrestException catch (e) {
      // PGRST202: la RPC no existe (migración pendiente) → validación local.
      if (e.code == 'PGRST202') {
        debugPrint('ℹ️ RPC canjear_codigo_retiro no disponible: ${e.message}');
        return null;
      }
      rethrow;
    }

    final data = Map<String, dynamic>.from(response as Map);
    final reservationId = data['id']?.toString();
    final status = switch (data['resultado']?.toString()) {
      'entregada' => PickupCodeStatus.valid,
      'cancelada' => PickupCodeStatus.cancelled,
      'ya_entregada' => PickupCodeStatus.alreadyDelivered,
      'otra_fecha' => PickupCodeStatus.wrongDate,
      'fuera_de_horario' => PickupCodeStatus.outsideHours,
      _ => PickupCodeStatus.notFound,
    };
    return PickupCodeResult(status, reservationId: reservationId);
  }

  @override
  Future<String?> monthlyPlanPickupCode(DateTime date) async {
    final client = SupabaseConfig.client;
    if (client == null) return null;
    try {
      final rows = await client.rpc(
        'obtener_ticket_plan_mensual',
        params: {'p_fecha': date.toIso8601String().substring(0, 10)},
      );
      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;
      return (list.first as Map)['codigo_retiro']?.toString();
    } catch (e) {
      debugPrint('ℹ️ No se pudo obtener el ticket del Plan Mensual: $e');
      return null;
    }
  }

  @override
  Future<bool> isTestAccount(String userId) async {
    final client = SupabaseConfig.client;
    if (client == null || !_isUuid(userId)) return true;
    try {
      return await client.rpc('es_cuenta_prueba') == true;
    } catch (e) {
      debugPrint('ℹ️ No se pudo consultar si es cuenta de prueba: $e');
      return false;
    }
  }

  @override
  Future<int> regenerateWeekTickets(String userId, DateTime date) async {
    final monday = DateTime(date.year, date.month, date.day - date.weekday + 1);
    final friday = monday.add(const Duration(days: 4));
    final client = SupabaseConfig.client;
    if (client != null && _isUuid(userId)) {
      final count = await client.rpc(
        'regenerar_tickets_semana',
        params: {'p_fecha': monday.toIso8601String().substring(0, 10)},
      );
      _monthlyStatuses.removeWhere(
        (id, _) => id.startsWith('monthly-$userId-'),
      );
      return (count as num).toInt();
    }

    // Modo local: se reactivan las reservas en memoria de la semana.
    var count = 0;
    for (var i = 0; i < _inMemoryReservations.length; i++) {
      final r = _inMemoryReservations[i];
      final day = DateTime(r.date.year, r.date.month, r.date.day);
      if (r.userId != userId || day.isBefore(monday) || day.isAfter(friday)) {
        continue;
      }
      _inMemoryReservations[i] = r.copyWith(
        status: 'confirmada',
        storedPickupCode: Reservation.generatePickupCode(),
      );
      count++;
    }
    _monthlyStatuses.removeWhere((id, _) => id.startsWith('monthly-$userId-'));
    return count;
  }

  bool _isUuid(String? value) {
    if (value == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    final monthly = _parseMonthlyId(reservationId);
    final client = SupabaseConfig.client;

    // Primero el servidor: si rechaza (plazo vencido, sin conexión), el error
    // se propaga y la reserva sigue confirmada en la app.
    if (client != null) {
      if (monthly != null) {
        await client.rpc(
          'cancelar_ticket_plan_mensual',
          params: {'p_fecha': monthly.$2},
        );
      } else {
        try {
          await client
              .from('reservations')
              .update({'status': 'cancelada'})
              .eq('id', reservationId);
        } catch (e1) {
          if (e1.toString().contains('PLAZO_CANCELACION_VENCIDO')) rethrow;
          try {
            await client
                .from('reservas')
                .update({'estado': 'CANCELADA'})
                .eq('id', reservationId);
          } catch (e2) {
            debugPrint('⚠️ Error al cancelar reserva en Supabase: $e1, $e2');
            rethrow;
          }
        }
      }
    }

    final index = _inMemoryReservations.indexWhere(
      (r) => r.id == reservationId,
    );
    if (index != -1) {
      _inMemoryReservations[index] = _inMemoryReservations[index].copyWith(
        status: 'cancelada',
      );
    }
    if (monthly != null) _monthlyStatuses[reservationId] = 'cancelada';
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

    final monthly = _parseMonthlyId(reservationId);
    if (monthly != null) {
      try {
        await client.from('tickets_plan_mensual').upsert({
          'empleado_id': monthly.$1,
          'fecha': monthly.$2,
          'estado': status,
        }, onConflict: 'empleado_id,fecha');
      } catch (e) {
        debugPrint('⚠️ Error al guardar ticket del Plan Mensual: $e');
      }
      return;
    }

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
