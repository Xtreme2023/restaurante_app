import 'package:flutter/foundation.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/pension/domain/pension_entity.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';

class SupabasePensionRepository {
  // Suscripción demo local para pruebas
  final List<MonthlyPensionSubscription> _inMemorySubscriptions = [
    MonthlyPensionSubscription(
      id: 'sub-oct-2026',
      userId: 'demo-user-123',
      year: 2026,
      month: 10,
      totalDays: 22,
      pricePerDay: 15.0, // Tarifa pensionado
      totalPrice: 330.0,
      status: 'Pensionado',
      createdAt: DateTime(2026, 9, 25),
    ),
  ];

  /// Obtiene la suscripción de pensión de un usuario o familiar para un mes/año
  Future<MonthlyPensionSubscription?> getSubscription(
    String userId,
    int year,
    int month, {
    String? familiarId,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return _inMemorySubscriptions
          .cast<MonthlyPensionSubscription?>()
          .firstWhere(
            (s) =>
                s != null &&
                s.year == year &&
                s.month == month &&
                s.status == 'Pensionado' &&
                (familiarId != null
                    ? s.familiarId == familiarId
                    : (s.familiarId == null &&
                        (s.userId == userId || userId == 'demo-user-123'))),
            orElse: () => null,
          );
    }

    // 1. Intento primario: Tabla oficial 'pension' en Supabase
    try {
      var query = client
          .from('pension')
          .select()
          .eq('year', year)
          .eq('mes', month);

      if (familiarId != null) {
        query = query.eq('id_familiar', familiarId);
      } else {
        query = query.eq('id_usuario', userId).isFilter('id_familiar', null);
      }

      final response = await query.maybeSingle();
      if (response != null) {
        return MonthlyPensionSubscription.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
    } catch (e) {
      debugPrint('ℹ️ Consulta en tabla pension: $e');
    }

    // 2. Fallback tabla legacy 'monthly_subscriptions' si existiera
    try {
      final response = await client
          .from('monthly_subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('year', year)
          .eq('month', month)
          .eq('status', 'activa')
          .maybeSingle();

      if (response != null) {
        return MonthlyPensionSubscription.fromJson(response);
      }
    } catch (_) {}

    // 3. Fallback en memoria local
    return _inMemorySubscriptions
        .cast<MonthlyPensionSubscription?>()
        .firstWhere(
          (s) =>
              s != null &&
              s.year == year &&
              s.month == month &&
              s.status == 'Pensionado' &&
              (familiarId != null
                  ? s.familiarId == familiarId
                  : (s.familiarId == null &&
                      (s.userId == userId || userId == 'demo-user-123'))),
          orElse: () => null,
        );
  }

  /// Suscribe a modalidad pensionado a un empleado o a su familiar (HU8 / HU9)
  Future<bool> subscribeMonthly({
    required String userId,
    String? familiarId,
    required int year,
    required int month,
    List<Holiday> holidays = const [],
    double pricePerDay = 15.0,
    DateTime? currentTime,
  }) async {
    // Regla de negocio HU8 / HU9: Solo se puede suscribir ANTES de iniciar el mes
    final now = currentTime ?? DateTime.now();
    final firstDayOfMonth = DateTime(year, month, 1);
    final today = DateTime(now.year, now.month, now.day);
    if (!today.isBefore(firstDayOfMonth)) {
      debugPrint('⛔ Rechazado: El mes $month/$year ya inició. No se puede modificar pensión.');
      return false;
    }

    final holidayDates = holidays.map((h) => h.date).toList();
    final businessDays = AppDateUtils.countBusinessDays(
      year,
      month,
      holidays: holidayDates,
    );
    final totalPrice = businessDays * pricePerDay;

    // Actualizar almacén local
    final newSub = MonthlyPensionSubscription(
      id: 'sub-$year-$month-${familiarId ?? userId}-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      familiarId: familiarId,
      year: year,
      month: month,
      totalDays: businessDays,
      pricePerDay: pricePerDay,
      totalPrice: totalPrice,
      status: 'Pensionado',
      createdAt: DateTime.now(),
    );

    _inMemorySubscriptions.removeWhere(
      (s) =>
          s.year == year &&
          s.month == month &&
          (familiarId != null
              ? s.familiarId == familiarId
              : (s.familiarId == null && s.userId == userId)),
    );
    _inMemorySubscriptions.add(newSub);

    final client = SupabaseConfig.client;
    if (client == null) return true;

    // 1. Guardar en tabla oficial 'pension' de Supabase
    try {
      var query = client
          .from('pension')
          .select('id_pension')
          .eq('year', year)
          .eq('mes', month);

      if (familiarId != null) {
        query = query.eq('id_familiar', familiarId);
      } else {
        query = query.eq('id_usuario', userId).isFilter('id_familiar', null);
      }

      final existing = await query.maybeSingle();

      if (existing != null && existing['id_pension'] != null) {
        await client
            .from('pension')
            .update({'modalidad': 'Pensionado'})
            .eq('id_pension', existing['id_pension']);
      } else {
        await client.from('pension').insert({
          'id_usuario': userId,
          'id_familiar': familiarId,
          'year': year,
          'mes': month,
          'modalidad': 'Pensionado',
        });
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Error al registrar pensión en Supabase: $e');
      return true; // Conservado en memoria local
    }
  }

  /// Cancela la suscripción a pensión (cambia a modalidad Regular) (HU8 / HU9)
  Future<bool> cancelMonthlySubscription(
    String subscriptionId,
    int year,
    int month,
    DateTime currentTime, {
    String? userId,
    String? familiarId,
  }) async {
    // Validación de regla de negocio HU8 / HU9
    final firstDayOfMonth = DateTime(year, month, 1);
    final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
    if (!today.isBefore(firstDayOfMonth)) {
      debugPrint('⛔ No se puede cancelar: el mes ya inició.');
      return false;
    }

    _inMemorySubscriptions.removeWhere(
      (s) =>
          s.id == subscriptionId ||
          (s.year == year &&
              s.month == month &&
              (familiarId != null
                  ? s.familiarId == familiarId
                  : (s.familiarId == null && s.userId == userId))),
    );

    final client = SupabaseConfig.client;
    if (client == null) return true;

    try {
      final numericId = int.tryParse(subscriptionId);
      if (numericId != null) {
        await client
            .from('pension')
            .update({'modalidad': 'Regular'})
            .eq('id_pension', numericId);
      } else {
        var query = client
            .from('pension')
            .update({'modalidad': 'Regular'})
            .eq('year', year)
            .eq('mes', month);

        if (familiarId != null) {
          query = query.eq('id_familiar', familiarId);
        } else if (userId != null) {
          query = query.eq('id_usuario', userId).isFilter('id_familiar', null);
        }
        await query;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ Error al cancelar pensión en Supabase: $e');
      return true;
    }
  }

  /// Verifica si un comensal (empleado o familiar) tiene pensión activa en una fecha
  Future<bool> isPensioner({
    required String userId,
    String? familiarId,
    required DateTime date,
  }) async {
    final sub = await getSubscription(
      userId,
      date.year,
      date.month,
      familiarId: familiarId,
    );
    return sub != null && sub.isActive;
  }

  /// Obtiene de forma agrupada el estado de pensión del empleado y sus familiares
  /// Retorna un mapa: `null` -> si el empleado es pensionado, `familiarId` -> si ese familiar es pensionado.
  Future<Map<String?, bool>> getPensionStatusForComensales({
    required String userId,
    required List<String> familiarIds,
    required int year,
    required int month,
  }) async {
    final Map<String?, bool> result = {
      null: false,
      for (final famId in familiarIds) famId: false,
    };

    final client = SupabaseConfig.client;
    if (client == null) {
      for (final sub in _inMemorySubscriptions) {
        if (sub.year == year && sub.month == month && sub.isActive) {
          if (sub.familiarId == null && (sub.userId == userId || userId == 'demo-user-123')) {
            result[null] = true;
          } else if (sub.familiarId != null && result.containsKey(sub.familiarId)) {
            result[sub.familiarId] = true;
          }
        }
      }
      return result;
    }

    try {
      final response = await client
          .from('pension')
          .select('id_familiar, modalidad')
          .eq('id_usuario', userId)
          .eq('year', year)
          .eq('mes', month)
          .eq('modalidad', 'Pensionado');

      final List<dynamic> data = response as List<dynamic>;
      for (final row in data) {
        final famId = row['id_familiar']?.toString();
        if (famId == null) {
          result[null] = true;
        } else {
          result[famId] = true;
        }
      }
      return result;
    } catch (e) {
      debugPrint('ℹ️ Error al obtener estado de pensión agrupado: $e');
      for (final sub in _inMemorySubscriptions) {
        if (sub.year == year && sub.month == month && sub.isActive) {
          if (sub.familiarId == null && sub.userId == userId) {
            result[null] = true;
          } else if (sub.familiarId != null && result.containsKey(sub.familiarId)) {
            result[sub.familiarId] = true;
          }
        }
      }
      return result;
    }
  }
}
