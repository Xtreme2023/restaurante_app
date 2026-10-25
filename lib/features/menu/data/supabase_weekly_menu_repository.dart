import 'package:flutter/foundation.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/menu/domain/bolivian_dish_entity.dart';
import 'package:restaurante_app/features/menu/data/dish_image_resolver.dart';

class SupabaseWeeklyMenuRepository {
  // Catálogo base de platos típicos de la gastronomía boliviana
  static final List<PlatoCatalogo> defaultCatalogo = [
    const PlatoCatalogo(
      id: 1,
      nombre: 'Silpancho Cochabambino',
      descripcion:
          'Carne apanada tierna sobre cama de arroz y papas doradas, con huevo frito y sarza criolla',
      categoria: 'Segundo',
      region: 'Cochabamba',
      precio: 18.0,
      imagenUrl: 'assets/images/01_silpancho.jpg',
    ),
    const PlatoCatalogo(
      id: 2,
      nombre: 'Pique Macho Especial',
      descripcion:
          'Trozos de lomo de res, salchichas, papas fritas, huevo duro, cebolla, tomate y locoto',
      categoria: 'Segundo',
      region: 'Cochabamba',
      precio: 18.0,
      imagenUrl: 'assets/images/02_pique_macho.jpg',
    ),
    const PlatoCatalogo(
      id: 3,
      nombre: 'Majadito Cruceño',
      descripcion:
          'Arroz tostado con charque de res desmenuzado, plátano frito maduro y huevo criollo',
      categoria: 'Segundo',
      region: 'Santa Cruz',
      precio: 18.0,
      imagenUrl: 'assets/images/03_charque_kan.jpg',
    ),
    const PlatoCatalogo(
      id: 4,
      nombre: 'Sopa de Maní Tradicional',
      descripcion:
          'Sopa cremosa tradicional a base de maní molido, costilla de res, arvejas y papas al hilo',
      categoria: 'Sopa',
      region: 'Nacional',
      precio: 18.0,
      imagenUrl: 'assets/images/04_sopa_de_mani.jpg',
    ),
    const PlatoCatalogo(
      id: 5,
      nombre: 'Falso Conejo',
      descripcion:
          'Carne apanada en ají amarillo con arvejas jugosas, servido con arroz graneado y fideo',
      categoria: 'Segundo',
      region: 'La Paz',
      precio: 18.0,
      imagenUrl: 'assets/images/05_chicharron.jpg',
    ),
    const PlatoCatalogo(
      id: 6,
      nombre: 'Saice Tarijeño',
      descripcion:
          'Guiso tradicional de carne picada, ají colorado, arvejas, cebolla picada y chuchusmuti',
      categoria: 'Segundo',
      region: 'Tarija',
      precio: 18.0,
      imagenUrl: 'assets/images/06_fricase.jpg',
    ),
    const PlatoCatalogo(
      id: 7,
      nombre: 'Chairo Paceño',
      descripcion:
          'Sopa andina espesa con chuño picado, chalona, carne de res, trigo pelado y hierbabuena',
      categoria: 'Sopa',
      region: 'La Paz',
      precio: 18.0,
      imagenUrl: 'assets/images/08_crema_de_quinua.jpg',
    ),
    const PlatoCatalogo(
      id: 8,
      nombre: 'Picante Mixto',
      descripcion:
          'Combinación de pollo al ají amarillo y lengua de res en ají rojo con chuño phuti',
      categoria: 'Segundo',
      region: 'Cochabamba / Chuquisaca',
      precio: 18.0,
      imagenUrl: 'assets/images/09_locro_de_zapallo.jpg',
    ),
    const PlatoCatalogo(
      id: 9,
      nombre: 'Mondongo Chuquisaqueño',
      descripcion:
          'Carne de cerdo dorada en ají colorado acompañada de mote amarillo cocido y papas',
      categoria: 'Segundo',
      region: 'Chuquisaca',
      precio: 18.0,
      imagenUrl: 'assets/images/06_fricase.jpg',
    ),
    const PlatoCatalogo(
      id: 10,
      nombre: 'Trucha del Titicaca al Limón',
      descripcion:
          'Filete fresco de trucha a la plancha con limón, arroz blanco y papas a la francesa',
      categoria: 'Segundo',
      region: 'La Paz',
      precio: 18.0,
      imagenUrl: 'assets/images/11_tortilla_de_verduras.jpg',
    ),
    const PlatoCatalogo(
      id: 11,
      nombre: 'Pastel de Fideo Criollo',
      descripcion:
          'Pastel horneado de fideos con abundante queso chaqueño boliviano y huevo batido',
      categoria: 'Segundo',
      region: 'Nacional',
      precio: 18.0,
      imagenUrl: 'assets/images/10_aji_de_fideo_sin_carne.jpg',
    ),
    const PlatoCatalogo(
      id: 12,
      nombre: 'Ají de Papalisa',
      descripcion:
          'Guiso tradicional de papalisa en trozos con carne picada, ají colorado y cebollín',
      categoria: 'Segundo',
      region: 'Potosí / Cochabamba',
      precio: 18.0,
      imagenUrl: 'assets/images/07_milanesa_de_soya.jpg',
    ),
    const PlatoCatalogo(
      id: 13,
      nombre: 'Crema de Quinua Real',
      descripcion:
          'Sopa del día de quinua real con verduras frescas, queso criollo y cilantro.',
      categoria: 'Sopa',
      region: 'Potosí / Oruro',
      precio: 18.0,
      imagenUrl: 'assets/images/08_crema_de_quinua.jpg',
    ),
    const PlatoCatalogo(
      id: 14,
      nombre: 'Locro de Gallina Tradicional',
      descripcion: 'Sopa del día con gallina criolla, arroz graneado y yuca.',
      categoria: 'Sopa',
      region: 'Santa Cruz',
      precio: 18.0,
      imagenUrl: 'assets/images/09_locro_de_zapallo.jpg',
    ),
    const PlatoCatalogo(
      id: 15,
      nombre: 'Caldo de Costilla Criollo',
      descripcion:
          'Sopa del día de costilla de res, papas y verduras de la huerta.',
      categoria: 'Sopa',
      region: 'Nacional',
      precio: 18.0,
      imagenUrl: 'assets/images/04_sopa_de_mani.jpg',
    ),
    const PlatoCatalogo(
      id: 16,
      nombre: 'Ensalada Fresca del Día',
      descripcion:
          'Ensalada de hojas verdes, tomate, zanahoria y aderezo de la casa.',
      categoria: 'Entrada',
      region: 'Nacional',
      precio: 18.0,
      imagenUrl: 'assets/images/11_tortilla_de_verduras.jpg',
    ),
    const PlatoCatalogo(
      id: 17,
      nombre: 'Ensalada Rusa',
      descripcion: 'Papa, zanahoria, arvejas y mayonesa casera.',
      categoria: 'Entrada',
      region: 'Nacional',
      precio: 18.0,
      imagenUrl: 'assets/images/11_tortilla_de_verduras.jpg',
    ),
  ];

  // Almacén en memoria de menú semanal para respaldo y modo local
  final List<MenuSemanalItem> _inMemoryMenuSemanal = [];

  SupabaseWeeklyMenuRepository() {
    _initDefaultWeeklyMenu();
  }

  void _initDefaultWeeklyMenu() {
    final now = DateTime.now();
    // Encontrar el lunes de la semana actual
    final monday = now.subtract(Duration(days: now.weekday - 1));

    final defaultAssignments = [
      {'day': 0, 'dishId': 1, 'name': 'Lunes'}, // Silpancho
      {'day': 1, 'dishId': 4, 'name': 'Martes'}, // Sopa de Maní
      {'day': 2, 'dishId': 3, 'name': 'Miércoles'}, // Majadito
      {'day': 3, 'dishId': 2, 'name': 'Jueves'}, // Pique Macho
      {'day': 4, 'dishId': 5, 'name': 'Viernes'}, // Falso Conejo
    ];

    int autoId = 100;
    for (final assign in defaultAssignments) {
      final date = monday.add(Duration(days: assign['day'] as int));
      final dish = defaultCatalogo.firstWhere(
        (d) => d.id == assign['dishId'],
        orElse: () => defaultCatalogo.first,
      );

      _inMemoryMenuSemanal.add(
        MenuSemanalItem(
          id: autoId++,
          fecha: date,
          diaSemana: assign['name'] as String,
          platoCatalogoId: dish.id,
          platoNombre: dish.nombre,
          platoDescripcion: dish.descripcion,
          platoRegion: dish.region,
          tipoPlato: dish.categoria,
          estado: 'publicado',
          imagenUrl: dish.imagenUrl,
        ),
      );
    }

    const dailySoups = [4, 7, 13, 14, 15];
    for (var day = 0; day < dailySoups.length; day++) {
      final date = monday.add(Duration(days: day));
      final soup = defaultCatalogo.firstWhere((d) => d.id == dailySoups[day]);
      _inMemoryMenuSemanal.add(
        MenuSemanalItem(
          id: autoId++,
          fecha: date,
          diaSemana: ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'][day],
          platoCatalogoId: soup.id,
          platoNombre: soup.nombre,
          platoDescripcion: soup.descripcion,
          platoRegion: soup.region,
          tipoPlato: soup.categoria,
          estado: 'publicado',
          imagenUrl: soup.imagenUrl,
        ),
      );
    }

    const dailySalads = [16, 17, 16, 17, 16];
    for (var day = 0; day < dailySalads.length; day++) {
      final date = monday.add(Duration(days: day));
      final salad = defaultCatalogo.firstWhere((d) => d.id == dailySalads[day]);
      _inMemoryMenuSemanal.add(
        MenuSemanalItem(
          id: autoId++,
          fecha: date,
          diaSemana: ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'][day],
          platoCatalogoId: salad.id,
          platoNombre: salad.nombre,
          platoDescripcion: salad.descripcion,
          platoRegion: salad.region,
          tipoPlato: salad.categoria,
          estado: 'publicado',
          imagenUrl: salad.imagenUrl,
        ),
      );
    }
  }

  /// Obtiene la lista completa de platos preestablecidos de la gastronomía boliviana
  Future<List<PlatoCatalogo>> getCatalogoPlatos() async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return defaultCatalogo;
    }

    // 0. Consultar la tabla oficial 'plato' de Supabase
    try {
      final response = await client
          .from('plato')
          .select()
          .order('id_plato', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final rawImg =
              map['imagen_url'] ?? map['imagen_path'] ?? map['image_url'];
          final idVal = (map['id_plato'] ?? map['id'] as num?)?.toInt() ?? 0;
          final nameVal =
              map['nombre']?.toString() ?? map['name']?.toString() ?? 'Plato';
          final descVal = map['descripcion']?.toString() ?? '';
          final tipoVal = map['tipo']?.toString() ??
              map['categoria']?.toString() ??
              'Segundo';

          return PlatoCatalogo(
            id: idVal,
            nombre: nameVal,
            descripcion: descVal,
            categoria: tipoVal,
            region: map['region']?.toString() ?? 'Bolivia',
            precio: (map['precio'] as num?)?.toDouble() ?? 18.0,
            imagenUrl: resolveDatabaseDishImage(
              rawImg?.toString(),
              dishName: nameVal,
              dishId: idVal,
            ),
            activo: true,
          );
        }).toList();
      }
    } catch (ePlato) {
      debugPrint('ℹ️ Fallback 0 tabla plato: $ePlato');
    }

    // 1. Intentar consultar 'platos_catalogo'
    try {
      final response = await client
          .from('platos_catalogo')
          .select()
          .order('id', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((item) {
          final map = item as Map<String, dynamic>;
          final dish = PlatoCatalogo.fromJson(map);
          final rawImg =
              map['imagen_path'] ?? map['imagen_url'] ?? map['image_url'];
          return dish.copyWith(
            imagenUrl: resolveDatabaseDishImage(
              rawImg?.toString(),
              dishName: dish.nombre,
              dishId: dish.id,
            ),
          );
        }).toList();
      }
    } catch (_) {}

    // 2. Intentar consultar la tabla principal 'platos' de Supabase
    try {
      final response = await client
          .from('platos')
          .select()
          .order('id', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final rawImg =
              map['imagen_path'] ?? map['imagen_url'] ?? map['image_url'];
          final idVal = map['id'] is int
              ? map['id'] as int
              : int.tryParse(map['id']?.toString() ?? '0') ?? 0;
          final nameVal =
              map['nombre']?.toString() ?? map['name']?.toString() ?? 'Plato';
          final descVal =
              map['descripcion']?.toString() ?? 'Plato registrado en Supabase';
          final tipoVal =
              map['tipo']?.toString() ??
              map['categoria']?.toString() ??
              'Segundo';

          return PlatoCatalogo(
            id: idVal,
            nombre: nameVal,
            descripcion: descVal,
            categoria: tipoVal,
            region: map['region']?.toString() ?? 'Bolivia',
            precio: (map['precio'] as num?)?.toDouble() ?? 18.0,
            imagenUrl: resolveDatabaseDishImage(
              rawImg?.toString(),
              dishName: nameVal,
              dishId: idVal,
            ),
            activo:
                map['activo'] == true ||
                map['activo'] == 1 ||
                map['activo'] == null,
          );
        }).toList();
      }
    } catch (_) {}

    return defaultCatalogo;
  }

  /// Obtiene los platos configurados para la semana indicada
  Future<List<MenuSemanalItem>> getMenuSemanal(DateTime startOfWeek) async {
    final client = SupabaseConfig.client;
    final monday = startOfWeek.subtract(
      Duration(days: startOfWeek.weekday - 1),
    );
    final friday = monday.add(const Duration(days: 4));

    final mondayStr =
        "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
    final fridayStr =
        "${friday.year.toString().padLeft(4, '0')}-${friday.month.toString().padLeft(2, '0')}-${friday.day.toString().padLeft(2, '0')}";

    if (client == null) {
      return _inMemoryMenuSemanal.where((item) {
        final d = DateTime(item.fecha.year, item.fecha.month, item.fecha.day);
        final start = DateTime(monday.year, monday.month, monday.day);
        final end = DateTime(friday.year, friday.month, friday.day);
        return (d.isAfter(start.subtract(const Duration(days: 1))) &&
            d.isBefore(end.add(const Duration(days: 1))));
      }).toList();
    }

    // Nivel 0: Consultar la VIEW oficial 'vista_menu_con_platos' de Supabase
    try {
      final response = await client
          .from('vista_menu_con_platos')
          .select()
          .gte('fecha', mondayStr)
          .lte('fecha', fridayStr)
          .order('fecha', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        final List<MenuSemanalItem> itemsFromDb = [];
        int tempId = 1;

        for (final row in data) {
          final rowMap = Map<String, dynamic>.from(row as Map);
          final fechaParsed =
              DateTime.tryParse(rowMap['fecha']?.toString() ?? '') ??
              DateTime.now();
          final dayName = AppDateUtils.getDiaSemana(fechaParsed);
          final rawPlatos = rowMap['platos'];
          final List<dynamic> platosList =
              rawPlatos is List ? rawPlatos : [];

          for (final platoItem in platosList) {
            if (platoItem is Map) {
              final platoMap = Map<String, dynamic>.from(platoItem);
              final platoId =
                  (platoMap['id_plato'] ?? platoMap['id'] as num?)?.toInt() ??
                  0;
              final platoNom =
                  platoMap['nombre']?.toString() ?? 'Plato';
              final platoDesc =
                  platoMap['descripcion']?.toString() ?? '';
              final platoTipo =
                  platoMap['tipo']?.toString() ?? 'Segundo';
              final rawImg =
                  platoMap['imagen_url'] ?? platoMap['imagen_path'];

              itemsFromDb.add(
                MenuSemanalItem(
                  id: (platoMap['id_menuplato'] as num?)?.toInt() ?? tempId++,
                  fecha: fechaParsed,
                  diaSemana: dayName,
                  platoCatalogoId: platoId,
                  platoNombre: platoNom,
                  platoDescripcion: platoDesc,
                  platoRegion: 'Bolivia',
                  tipoPlato: platoTipo,
                  estado: 'publicado',
                  imagenUrl: resolveDatabaseDishImage(
                    rawImg?.toString(),
                    dishName: platoNom,
                    dishId: platoId,
                  ),
                ),
              );
            }
          }
        }

        if (itemsFromDb.isNotEmpty) {
          return itemsFromDb;
        }
      }
    } catch (eView) {
      debugPrint('ℹ️ Fallback 0 vista_menu_con_platos ($eView).');
    }

    // Nivel 1: Consultar 'menu_semanal' con join de 'platos_catalogo'
    try {
      final response = await client
          .from('menu_semanal')
          .select('*, platos_catalogo(*)')
          .gte('fecha', mondayStr)
          .lte('fecha', fridayStr)
          .order('fecha', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isNotEmpty) {
        return data.map((item) {
          final map = item as Map<String, dynamic>;
          final menuItem = MenuSemanalItem.fromJson(map);
          final catalog = map['platos_catalogo'];
          final catalogMap = catalog is Map ? catalog : null;
          final rawImg =
              map['imagen_path'] ??
              map['imagen_url'] ??
              map['image_url'] ??
              catalogMap?['imagen_path'] ??
              catalogMap?['imagen_url'] ??
              catalogMap?['image_url'];
          return menuItem.copyWith(
            imagenUrl: resolveDatabaseDishImage(
              rawImg?.toString(),
              dishName: menuItem.platoNombre,
              dishId: menuItem.platoCatalogoId,
            ),
          );
        }).toList();
      }
    } catch (e1) {
      debugPrint('ℹ️ Fallback 1 Supabase menu_semanal ($e1).');
    }

    // Nivel 2: Consultar 'menu_dias' con 'menu_dia_platos' y 'platos' (esquema relacional de Supabase)
    try {
      final menuDiasRes = await client
          .from('menu_dias')
          .select('id, fecha, menu_dia_platos(platos(*))')
          .gte('fecha', mondayStr)
          .lte('fecha', fridayStr)
          .order('fecha', ascending: true);

      final List<dynamic> daysData = menuDiasRes as List<dynamic>;
      if (daysData.isNotEmpty) {
        final List<MenuSemanalItem> itemsFromDb = [];
        int tempId = 1;

        for (final dayRow in daysData) {
          final fechaParsed =
              DateTime.tryParse(dayRow['fecha']?.toString() ?? '') ??
              DateTime.now();
          final dayName = AppDateUtils.getDiaSemana(fechaParsed);
          final relations = dayRow['menu_dia_platos'] as List<dynamic>? ?? [];

          for (final rel in relations) {
            final platoData = rel['platos'];
            if (platoData is Map<String, dynamic>) {
              final rawImg =
                  platoData['imagen_path'] ??
                  platoData['imagen_url'] ??
                  platoData['image_url'];
              final platoNom = platoData['nombre']?.toString() ?? 'Plato';
              final platoId = platoData['id'] is int
                  ? platoData['id'] as int
                  : int.tryParse(platoData['id']?.toString() ?? '0') ?? 0;

              itemsFromDb.add(
                MenuSemanalItem(
                  id: tempId++,
                  fecha: fechaParsed,
                  diaSemana: dayName,
                  platoCatalogoId: platoId,
                  platoNombre: platoNom,
                  platoDescripcion:
                      platoData['descripcion']?.toString() ??
                      'Plato de la base de datos Supabase',
                  platoRegion: platoData['region']?.toString() ?? 'Bolivia',
                  tipoPlato:
                      platoData['tipo']?.toString() ??
                      platoData['categoria']?.toString() ??
                      'Segundo',
                  estado: 'publicado',
                  imagenUrl: resolveDatabaseDishImage(
                    rawImg?.toString(),
                    dishName: platoNom,
                    dishId: platoId,
                  ),
                ),
              );
            }
          }
        }

        if (itemsFromDb.isNotEmpty) {
          return itemsFromDb;
        }
      }
    } catch (e2) {
      debugPrint('ℹ️ Fallback 2 Supabase menu_dias ($e2).');
    }

    // Nivel 3: Consultar directamente la tabla 'plato' de Supabase
    try {
      final platosRes = await client
          .from('plato')
          .select()
          .order('id_plato', ascending: true);

      final List<dynamic> platosList = platosRes as List<dynamic>;
      if (platosList.isNotEmpty) {
        final List<MenuSemanalItem> weekFromPlatos = [];
        final weekDayNames = [
          'Lunes',
          'Martes',
          'Miércoles',
          'Jueves',
          'Viernes',
        ];

        for (int i = 0; i < 5; i++) {
          final targetDate = monday.add(Duration(days: i));
          final platoData =
              platosList[i % platosList.length] as Map<String, dynamic>;
          final rawImg =
              platoData['imagen_path'] ??
              platoData['imagen_url'] ??
              platoData['image_url'];
          final platoNom = platoData['nombre']?.toString() ?? 'Plato';
          final platoId = platoData['id'] is int
              ? platoData['id'] as int
              : int.tryParse(platoData['id']?.toString() ?? '0') ?? 0;

          weekFromPlatos.add(
            MenuSemanalItem(
              id: 200 + i,
              fecha: targetDate,
              diaSemana: weekDayNames[i],
              platoCatalogoId: platoId,
              platoNombre: platoNom,
              platoDescripcion:
                  platoData['descripcion']?.toString() ??
                  'Plato registrado en base de datos Supabase',
              platoRegion: platoData['region']?.toString() ?? 'Bolivia',
              tipoPlato:
                  platoData['tipo']?.toString() ??
                  platoData['categoria']?.toString() ??
                  'Segundo',
              estado: 'publicado',
              imagenUrl: resolveDatabaseDishImage(
                rawImg?.toString(),
                dishName: platoNom,
                dishId: platoId,
              ),
            ),
          );

          if (platosList.length > 5) {
            final secondIdx = (i + 5) % platosList.length;
            final secondPlato = platosList[secondIdx] as Map<String, dynamic>;
            final secondImg =
                secondPlato['imagen_path'] ??
                secondPlato['imagen_url'] ??
                secondPlato['image_url'];
            final secondNom =
                secondPlato['nombre']?.toString() ?? 'Plato Alternativo';
            final secondId = secondPlato['id'] is int
                ? secondPlato['id'] as int
                : int.tryParse(secondPlato['id']?.toString() ?? '0') ?? 0;

            weekFromPlatos.add(
              MenuSemanalItem(
                id: 300 + i,
                fecha: targetDate,
                diaSemana: weekDayNames[i],
                platoCatalogoId: secondId,
                platoNombre: secondNom,
                platoDescripcion:
                    secondPlato['descripcion']?.toString() ??
                    'Opción alternativa desde Supabase',
                platoRegion: secondPlato['region']?.toString() ?? 'Bolivia',
                tipoPlato:
                    secondPlato['tipo']?.toString() ??
                    secondPlato['categoria']?.toString() ??
                    'Segundo',
                estado: 'publicado',
                imagenUrl: resolveDatabaseDishImage(
                  secondImg?.toString(),
                  dishName: secondNom,
                  dishId: secondId,
                ),
              ),
            );
          }
        }

        if (weekFromPlatos.isNotEmpty) {
          return weekFromPlatos;
        }
      }
    } catch (e3) {
      debugPrint('ℹ️ Fallback 3 Supabase platos ($e3).');
    }

    // Nivel 4: Si no hay conexión o fallan las tablas remotas, retornar memoria local
    return _inMemoryMenuSemanal.where((item) {
      final d = DateTime(item.fecha.year, item.fecha.month, item.fecha.day);
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = DateTime(friday.year, friday.month, friday.day);
      return (d.isAfter(start.subtract(const Duration(days: 1))) &&
          d.isBefore(end.add(const Duration(days: 1))));
    }).toList();
  }

  /// Obtiene el menú de la semana que ya ha sido publicado y está visible para empleados
  Future<List<MenuSemanalItem>> getMenuPublicado(DateTime date) async {
    final list = await getMenuSemanal(date);
    return list.where((item) => item.isPublicado).toList();
  }

  /// Agrega o quita un plato del menú de un día específico
  Future<void> togglePlatoEnMenu({
    required DateTime fecha,
    required String diaSemana,
    required PlatoCatalogo plato,
    required bool agregar,
  }) async {
    final client = SupabaseConfig.client;
    final dateStr =
        "${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";

    if (agregar) {
      // Agregar plato al día
      final exists = _inMemoryMenuSemanal.any(
        (m) =>
            AppDateUtils.isSameDay(m.fecha, fecha) &&
            m.platoCatalogoId == plato.id,
      );
      if (!exists) {
        final newItem = MenuSemanalItem(
          id: DateTime.now().millisecondsSinceEpoch % 1000000,
          fecha: fecha,
          diaSemana: diaSemana,
          platoCatalogoId: plato.id,
          platoNombre: plato.nombre,
          platoDescripcion: plato.descripcion,
          platoRegion: plato.region,
          tipoPlato: plato.categoria,
          estado: 'borrador',
          imagenUrl: plato.imagenUrl,
        );
        _inMemoryMenuSemanal.add(newItem);

        if (client != null) {
          try {
            // Sincronizar en esquema oficial: menu_dia y menu_plato
            var menuDia = await client
                .from('menu_dia')
                .select('id_menu')
                .eq('fecha', dateStr)
                .maybeSingle();

            int? menuId = (menuDia?['id_menu'] as num?)?.toInt();
            if (menuId == null) {
              final inserted = await client
                  .from('menu_dia')
                  .insert({
                    'fecha': dateStr,
                    'estado_publicacion': true,
                  })
                  .select('id_menu')
                  .single();
              menuId = (inserted['id_menu'] as num?)?.toInt();
            }

            if (menuId != null) {
              await client.from('menu_plato').insert({
                'id_menu': menuId,
                'id_plato': plato.id,
              });
            }
          } catch (_) {
            try {
              await client.from('menu_semanal').insert({
                'fecha': dateStr,
                'dia_semana': diaSemana,
                'plato_catalogo_id': plato.id,
                'tipo_plato': plato.categoria,
                'estado': 'borrador',
              });
            } catch (e) {
              debugPrint('⚠️ Error al insertar plato en menú: $e');
            }
          }
        }
      }
    } else {
      // Quitar plato del día
      _inMemoryMenuSemanal.removeWhere(
        (m) =>
            AppDateUtils.isSameDay(m.fecha, fecha) &&
            m.platoCatalogoId == plato.id,
      );

      if (client != null) {
        try {
          final menuDia = await client
              .from('menu_dia')
              .select('id_menu')
              .eq('fecha', dateStr)
              .maybeSingle();
          final menuId = (menuDia?['id_menu'] as num?)?.toInt();
          if (menuId != null) {
            await client
                .from('menu_plato')
                .delete()
                .eq('id_menu', menuId)
                .eq('id_plato', plato.id);
          }
        } catch (_) {
          try {
            await client
                .from('menu_semanal')
                .delete()
                .eq('fecha', dateStr)
                .eq('plato_catalogo_id', plato.id);
          } catch (e) {
            debugPrint('⚠️ Error al eliminar plato de menú: $e');
          }
        }
      }
    }
  }

  /// Publica el menú semanal (cambia el estado de borrador a 'publicado')
  Future<bool> publicarMenuSemanal({required DateTime startOfWeek}) async {
    final monday = startOfWeek.subtract(
      Duration(days: startOfWeek.weekday - 1),
    );
    final friday = monday.add(const Duration(days: 4));

    final mondayStr =
        "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
    final fridayStr =
        "${friday.year.toString().padLeft(4, '0')}-${friday.month.toString().padLeft(2, '0')}-${friday.day.toString().padLeft(2, '0')}";

    // Actualizar estado en memoria
    for (int i = 0; i < _inMemoryMenuSemanal.length; i++) {
      final item = _inMemoryMenuSemanal[i];
      final d = DateTime(item.fecha.year, item.fecha.month, item.fecha.day);
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = DateTime(friday.year, friday.month, friday.day);

      if (!d.isBefore(start) && !d.isAfter(end)) {
        _inMemoryMenuSemanal[i] = item.copyWith(estado: 'publicado');
      }
    }

    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        await client
            .from('menu_dia')
            .update({'estado_publicacion': true})
            .gte('fecha', mondayStr)
            .lte('fecha', fridayStr);
        return true;
      } catch (_) {
        try {
          await client
              .from('menu_semanal')
              .update({
                'estado': 'publicado',
                'actualizado_en': DateTime.now().toIso8601String(),
              })
              .gte('fecha', mondayStr)
              .lte('fecha', fridayStr);
          return true;
        } catch (e) {
          debugPrint('⚠️ Error actualizando estado a publicado en Supabase: $e');
          return true;
        }
      }
    }
    return true;
  }
}
