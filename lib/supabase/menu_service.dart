import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurante_app/features/menu/data/dish_category_resolver.dart';
import 'package:restaurante_app/features/menu/domain/bolivian_dish_entity.dart';
import 'package:restaurante_app/features/menu/domain/menu_entity.dart';
import 'package:restaurante_app/supabase/supabase_client.dart';

/// Resultado detallado de la consulta del menú para una fecha específica (HU5 y HU6).
class MenuDiaResult {
  final String fecha;
  final int? idMenu;
  final bool isExcepcion;
  final String? motivoExcepcion;
  final bool isDisponible;
  final List<Dish> platos;

  const MenuDiaResult({
    required this.fecha,
    this.idMenu,
    this.isExcepcion = false,
    this.motivoExcepcion,
    this.isDisponible = false,
    this.platos = const [],
  });

  /// Indica si el restaurante está habilitado y el menú tiene platos para el día
  bool get tieneMenuValido => !isExcepcion && isDisponible && platos.isNotEmpty;
}

/// Servicio centralizado para la consulta y obtención de menús institucionales.
/// REGLAS DE ARQUITECTURA:
/// - Lectura de menús y platos a través de la VIEW `vista_menu_con_platos`.
/// - Filtrado estricto contra `excepcion_calendario` (campo `fecha`) para no mostrar
///   menú en días feriados o sin atención (HU6).
/// - Control riguroso de nulos y resolución de imágenes (Supabase Storage, CDN y assets locales).
class MenuService {
  static const String viewMenuConPlatos = 'vista_menu_con_platos';
  static const String tableExcepcionCalendario = 'excepcion_calendario';

  /// Formatea un objeto [DateTime] a formato YYYY-MM-DD
  static String formatDate(DateTime dt) =>
      "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  /// Calcula el rango semanal de Lunes a Viernes según la fórmula solicitada:
  /// `final inicioSemana = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));`
  /// `final finSemana = inicioSemana.add(const Duration(days: 4)); // Lunes a Viernes`
  /// Con soporte para desplazamiento de semanas ([weekOffset]: 0 actual, 1 siguiente, -1 anterior).
  static ({DateTime inicioSemana, DateTime finSemana}) getRangoSemana({
    DateTime? referenceDate,
    int weekOffset = 0,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final cleanRef = DateTime(ref.year, ref.month, ref.day);
    var baseMonday = cleanRef.subtract(Duration(days: cleanRef.weekday - 1));
    if (weekOffset != 0) {
      baseMonday = baseMonday.add(Duration(days: 7 * weekOffset));
    }
    final finSemana = baseMonday.add(const Duration(days: 4));
    return (inicioSemana: baseMonday, finSemana: finSemana);
  }

  /// Retorna los 5 días hábiles de la semana (Lunes a Viernes) según el [weekOffset]
  static List<DateTime> getDiasSemana({
    DateTime? referenceDate,
    int weekOffset = 0,
  }) {
    final rango = getRangoSemana(
      referenceDate: referenceDate,
      weekOffset: weekOffset,
    );
    return List.generate(
      5,
      (index) => rango.inicioSemana.add(Duration(days: index)),
    );
  }

  /// Comprueba de forma segura si el cliente Supabase está inicializado
  static bool get _isSupabaseReady {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Consulta la tabla `excepcion_calendario` en un rango opcional de fechas
  static Future<List<Map<String, dynamic>>> getExcepcionesCalendario({
    String? fechaInicio,
    String? fechaFin,
  }) async {
    if (!_isSupabaseReady) return const [];
    try {
      var query = supabase.from(tableExcepcionCalendario).select();
      if (fechaInicio != null) {
        query = query.gte('fecha', fechaInicio);
      }
      if (fechaFin != null) {
        query = query.lte('fecha', fechaFin);
      }
      final res = await query.order('fecha', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('⚠️ Error obteniendo excepciones de calendario en MenuService: $e');
      return const [];
    }
  }

  /// Verifica si una fecha específica corresponde a un día no habilitado / feriado (HU6)
  static Future<Map<String, dynamic>?> checkExcepcion(DateTime date) async {
    if (!_isSupabaseReady) return null;
    try {
      final dateStr = formatDate(date);
      final res = await supabase
          .from(tableExcepcionCalendario)
          .select()
          .eq('fecha', dateStr)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('⚠️ Error al verificar excepcion de calendario para $date: $e');
      return null;
    }
  }

  /// Obtiene los menús de la semana laboral (Lunes a Viernes) desde `vista_menu_con_platos`.
  /// Si [filtrarExcepciones] es true, descarta los menús en días que coincidan
  /// con `excepcion_calendario` (HU6).
  static Future<List<Map<String, dynamic>>> getMenusSemana({
    DateTime? referenceDate,
    int weekOffset = 0,
    bool filtrarExcepciones = true,
  }) async {
    final rango = getRangoSemana(
      referenceDate: referenceDate,
      weekOffset: weekOffset,
    );
    final inicioStr = formatDate(rango.inicioSemana);
    final finStr = formatDate(rango.finSemana);

    if (!_isSupabaseReady) return const [];
    try {
      final data = await supabase
          .from(viewMenuConPlatos)
          .select()
          .gte('fecha', inicioStr)
          .lte('fecha', finStr)
          .order('fecha', ascending: true);

      final menus = List<Map<String, dynamic>>.from(data);
      if (!filtrarExcepciones) return menus;

      final excepciones = await getExcepcionesCalendario(
        fechaInicio: inicioStr,
        fechaFin: finStr,
      );
      final fechasExcepcion = excepciones
          .map((e) => e['fecha']?.toString())
          .whereType<String>()
          .toSet();

      return menus.where((m) {
        final f = m['fecha']?.toString();
        return f != null && !fechasExcepcion.contains(f);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Error al obtener menús semanales en MenuService: $e');
      return const [];
    }
  }

  /// Obtiene el menú de un día específico desde `vista_menu_con_platos` (por defecto hoy).
  /// Si el día está registrado en `excepcion_calendario`, retorna `isExcepcion: true`
  /// con el motivo correspondiente y lista vacía de platos (HU6).
  static Future<MenuDiaResult> getMenuPorFecha(DateTime date) async {
    final dateStr = formatDate(date);

    if (!_isSupabaseReady) {
      return MenuDiaResult(
        fecha: dateStr,
        isExcepcion: false,
        isDisponible: false,
        platos: const [],
      );
    }

    try {
      // 1. Verificar si la fecha está en excepcion_calendario (HU6)
      final excepcion = await checkExcepcion(date);
      if (excepcion != null) {
        final motivo = excepcion['motivo']?.toString() ?? 'Día de no atención';
        return MenuDiaResult(
          fecha: dateStr,
          isExcepcion: true,
          motivoExcepcion: motivo,
          isDisponible: false,
          platos: const [],
        );
      }

      // 2. Consultar vista_menu_con_platos
      final data = await supabase
          .from(viewMenuConPlatos)
          .select()
          .eq('fecha', dateStr)
          .maybeSingle();

      if (data == null) {
        return MenuDiaResult(
          fecha: dateStr,
          isExcepcion: false,
          isDisponible: false,
          platos: const [],
        );
      }

      final rawPlatos = data['platos'];
      final platos = parsePlatos(rawPlatos);
      final idMenu = data['id_menu'] is int
          ? data['id_menu'] as int
          : int.tryParse(data['id_menu']?.toString() ?? '');

      return MenuDiaResult(
        fecha: dateStr,
        idMenu: idMenu,
        isExcepcion: false,
        isDisponible: platos.isNotEmpty,
        platos: platos,
      );
    } catch (e) {
      debugPrint('⚠️ Error en getMenuPorFecha ($dateStr): $e');
      return MenuDiaResult(
        fecha: dateStr,
        isExcepcion: false,
        isDisponible: false,
        platos: const [],
      );
    }
  }

  /// Atajo para obtener la lista de platos para una fecha o hoy
  static Future<List<Dish>> getPlatosDelDia([DateTime? date]) async {
    final target = date ?? DateTime.now();
    final result = await getMenuPorFecha(target);
    return result.platos;
  }

  /// Parsea la lista dinámica de platos con control riguroso de nulos
  static List<Dish> parsePlatos(dynamic rawPlatos) {
    if (rawPlatos == null || rawPlatos is! List) return const [];

    final List<Dish> list = [];
    for (final item in rawPlatos) {
      if (item is Map<String, dynamic>) {
        final dish = parseDish(item);
        if (dish != null) list.add(dish);
      } else if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final dish = parseDish(map);
        if (dish != null) list.add(dish);
      }
    }
    return list;
  }

  /// Parsea un plato individual desde JSON de la vista
  static Dish? parseDish(Map<String, dynamic> json) {
    final idRaw = json['id_plato'] ?? json['id'];
    final nombreRaw = json['nombre'] ?? json['name'];
    final idStr = idRaw?.toString().trim() ?? '';
    final nombreStr = nombreRaw?.toString().trim() ?? '';

    if (idStr.isEmpty && nombreStr.isEmpty) return null;

    final descRaw = json['descripcion'] ?? json['description'];
    final imgRaw =
        json['imagen_url'] ?? json['image_url'] ?? json['imagen_path'];
    final tipoRaw = json['tipo'] ?? json['categoria'] ?? json['category'];

    final dishIdInt = int.tryParse(idStr);
    final resolvedImg = resolveDishImageUrl(
      imgRaw?.toString(),
      dishName: nombreStr,
      dishId: dishIdInt,
    );

    final category = resolveDishCategory(
      type: tipoRaw?.toString(),
      name: nombreStr,
    );

    final precioNum = json['precio'] ?? json['price'];
    final double precio = (precioNum is num)
        ? precioNum.toDouble()
        : (double.tryParse(precioNum?.toString() ?? '') ?? 18.0);

    final caloriasNum = json['calorias'] ?? json['calories'];
    final int calorias = (caloriasNum is num)
        ? caloriasNum.toInt()
        : (int.tryParse(caloriasNum?.toString() ?? '') ?? 650);

    final bool isFav =
        json['is_favorite'] == true || json['isFavorite'] == true;
    final bool isAvail =
        json['is_available'] != false && json['isAvailable'] != false;
    final rawTipo = json['tipo']?.toString().trim();
    final String? tipoEnum =
        (rawTipo != null && rawTipo.isNotEmpty) ? rawTipo : null;

    return Dish(
      id: idStr.isNotEmpty ? idStr : '0',
      name: nombreStr.isNotEmpty ? nombreStr : 'Plato del día',
      description: (descRaw != null && descRaw.toString().trim().isNotEmpty)
          ? descRaw.toString().trim()
          : 'Plato preparado y registrado en el menú institucional.',
      imageUrl: resolvedImg,
      category: category,
      tipo: tipoEnum,
      price: precio,
      calories: calorias,
      isFavorite: isFav,
      isAvailable: isAvail,
    );
  }
}
