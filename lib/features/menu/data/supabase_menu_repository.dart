import 'package:flutter/foundation.dart';
import 'package:restaurante_app/core/config/supabase_config.dart';
import 'package:restaurante_app/features/menu/data/mock_menu_repository.dart';
import 'package:restaurante_app/features/menu/domain/daily_menu_entity.dart';
import 'package:restaurante_app/features/menu/domain/daily_menu_policy.dart';
import 'package:restaurante_app/features/menu/domain/menu_entity.dart';
import 'package:restaurante_app/features/menu/domain/menu_repository.dart';
import 'package:restaurante_app/features/menu/data/dish_image_resolver.dart';
import 'package:restaurante_app/features/menu/data/dish_category_resolver.dart';
import 'package:restaurante_app/supabase/menu_service.dart';

class SupabaseMenuRepository implements MenuRepository {
  final MockMenuRepository _mockFallback = MockMenuRepository();

  bool _isDishActive(Map<String, dynamic> dish) {
    final value = dish['activo'] ?? dish['is_available'];
    return value != false &&
        value != 0 &&
        value?.toString().toLowerCase() != 'false';
  }

  List<AlmuerzoCompleto> _buildAlmuerzoOptions(List<Dish> dishes) {
    var entradas = dishes
        .where((d) => d.category.toLowerCase().contains('entrada'))
        .toList();
    if (entradas.isEmpty) {
      entradas = [MockMenuRepository.entradaMock];
    }

    var sopas = dishes
        .where((d) => d.category.toLowerCase().contains('sopa'))
        .toList();
    if (sopas.isEmpty) {
      sopas = [MockMenuRepository.sopaMock];
    }

    var segundos = dishes
        .where(
          (d) =>
              d.category.toLowerCase().contains('segundo') ||
              d.category.toLowerCase().contains('fuerte') ||
              d.category.toLowerCase().contains('regular'),
        )
        .toList();
    if (segundos.isEmpty) {
      segundos = dishes
          .where((d) => !d.category.toLowerCase().contains('sopa'))
          .toList();
      if (segundos.isEmpty) {
        segundos = [MockMenuRepository.segundoMock];
      }
    }

    final count = [
      entradas.length,
      sopas.length,
      segundos.length,
    ].reduce((a, b) => a < b ? a : b).clamp(1, 3).toInt();

    return List.generate(
      count,
      (index) => AlmuerzoCompleto(
        entrada: entradas[index % entradas.length],
        sopa: sopas[index % sopas.length],
        segundo: segundos[index % segundos.length],
      ),
    );
  }

  @override
  Future<DailyMenu> getDailyMenuStructure(DateTime date) async {
    // 1. Intento principal con MenuService y la VIEW vista_menu_con_platos (HU5 y HU6)
    try {
      final menuResult = await MenuService.getMenuPorFecha(date);
      if (menuResult.platos.isNotEmpty) {
        final loadedDishes = menuResult.platos;

        final entrada = loadedDishes.firstWhere(
          (d) => d.category.toLowerCase().contains('entrada'),
          orElse: () => MockMenuRepository.entradaMock,
        );
        final sopa = loadedDishes.firstWhere(
          (d) => d.category.toLowerCase().contains('sopa'),
          orElse: () => MockMenuRepository.sopaMock,
        );
        final segundo = loadedDishes.firstWhere(
          (d) =>
              d.category.toLowerCase().contains('segundo') ||
              d.category.toLowerCase().contains('fuerte') ||
              d.category.toLowerCase().contains('regular'),
          orElse: () => loadedDishes.firstWhere(
            (d) => !d.category.toLowerCase().contains('sopa'),
            orElse: () => MockMenuRepository.segundoMock,
          ),
        );
        final vegetariano = loadedDishes.firstWhere(
          (d) => d.category.toLowerCase().contains('veg'),
          orElse: () => MockMenuRepository.vegetarianoMock,
        );
        final especial = loadedDishes.firstWhere(
          (d) => d.category.toLowerCase().contains('esp'),
          orElse: () => MockMenuRepository.especialMock,
        );
        final postre = loadedDishes.firstWhere(
          (d) => d.category.toLowerCase().contains('postre'),
          orElse: () => MockMenuRepository.postreMock,
        );

        final almuerzos = _buildAlmuerzoOptions(loadedDishes);

        return DailyMenuPolicy.buildDailyMenu(
          date: date,
          entrada: entrada,
          sopa: sopa,
          segundo: segundo,
          platoVegetariano: vegetariano,
          platoEspecial: especial,
          postre: postre,
          almuerzosCompletos: almuerzos.isNotEmpty
              ? almuerzos
              : [
                  AlmuerzoCompleto(
                    entrada: entrada,
                    sopa: sopa,
                    segundo: segundo,
                  ),
                ],
        );
      }
    } catch (e) {
      debugPrint('ℹ️ Error obteniendo estructura de menú desde MenuService ($e).');
    }

    // 2. Consulta alternativa directa si Supabase está activo
    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        final platosRes = await client.from('platos').select();
        final List<dynamic> platosList = (platosRes as List<dynamic>)
            .where((row) => _isDishActive(row as Map<String, dynamic>))
            .toList();
        if (platosList.isNotEmpty) {
          final List<Dish> dbDishes = [];
          for (final row in platosList) {
            final platoData = row as Map<String, dynamic>;
            final rawImg =
                platoData['imagen_path'] ??
                platoData['imagen_url'] ??
                platoData['image_url'];
            final platoNom = platoData['nombre']?.toString() ?? 'Plato';
            final platoId = platoData['id'] is int
                ? platoData['id'] as int
                : int.tryParse(platoData['id']?.toString() ?? '0') ?? 0;

            final resolvedImageUrl = resolveDatabaseDishImage(
              rawImg?.toString(),
              dishName: platoNom,
              dishId: platoId,
            );

            dbDishes.add(
              Dish(
                id: platoId.toString(),
                name: platoNom,
                description:
                    platoData['descripcion']?.toString() ??
                    'Plato registrado en Supabase',
                imageUrl: resolvedImageUrl,
                category: resolveDishCategory(
                  type:
                      platoData['tipo']?.toString() ??
                      platoData['categoria']?.toString(),
                  name: platoNom,
                ),
                price: (platoData['precio'] as num?)?.toDouble() ?? 18.0,
              ),
            );
          }

          if (dbDishes.isNotEmpty) {
            return DailyMenuPolicy.buildDailyMenu(
              date: date,
              entrada: dbDishes.firstWhere(
                (d) => d.category.toLowerCase().contains('entrada'),
                orElse: () => MockMenuRepository.entradaMock,
              ),
              sopa: dbDishes.firstWhere(
                (d) => d.category.toLowerCase().contains('sopa'),
                orElse: () => MockMenuRepository.sopaMock,
              ),
              segundo: dbDishes.firstWhere(
                (d) =>
                    d.category.toLowerCase().contains('segundo') ||
                    d.category.toLowerCase().contains('fuerte'),
                orElse: () => MockMenuRepository.segundoMock,
              ),
              platoVegetariano: dbDishes.firstWhere(
                (d) => d.category.toLowerCase().contains('veg'),
                orElse: () => MockMenuRepository.vegetarianoMock,
              ),
              platoEspecial: dbDishes.firstWhere(
                (d) => d.category.toLowerCase().contains('esp'),
                orElse: () => MockMenuRepository.especialMock,
              ),
              postre: dbDishes.firstWhere(
                (d) => d.category.toLowerCase().contains('postre'),
                orElse: () => MockMenuRepository.postreMock,
              ),
              almuerzosCompletos: _buildAlmuerzoOptions(dbDishes),
            );
          }
        }
      } catch (ePlatos) {
        debugPrint('ℹ️ Fallback platos en SupabaseMenuRepository ($ePlatos).');
      }
    }

    // 3. Fallback en memoria si Supabase no tiene datos
    return await _mockFallback.getDailyMenuStructure(date);
  }

  @override
  Future<List<Dish>> getDailyMenu() async {
    try {
      final dishes = await MenuService.getPlatosDelDia(DateTime.now());
      if (dishes.isNotEmpty) {
        return dishes;
      }
    } catch (_) {}

    final today = DateTime.now();
    final structure = await getDailyMenuStructure(today);
    return structure.allDishes;
  }

  @override
  Future<void> toggleFavorite(String dishId) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return _mockFallback.toggleFavorite(dishId);
    }

    try {
      final current = await client
          .from('platos')
          .select('id')
          .eq('id', dishId)
          .maybeSingle();

      if (current != null) {
        // Toggle favorito
      } else {
        await _mockFallback.toggleFavorite(dishId);
      }
    } catch (e) {
      debugPrint('⚠️ Error en toggleFavorite con Supabase: $e');
      await _mockFallback.toggleFavorite(dishId);
    }
  }

  @override
  Future<void> addDish(Dish dish) async {
    final client = SupabaseConfig.client;
    if (client == null) {
      return _mockFallback.addDish(dish);
    }

    try {
      await client.from('platos').insert({
        'nombre': dish.name,
        'tipo': dish.category.toUpperCase(),
        'activo': dish.isAvailable,
      });
    } catch (e) {
      debugPrint('⚠️ Error al agregar plato a Supabase: $e');
      await _mockFallback.addDish(dish);
    }
  }
}
