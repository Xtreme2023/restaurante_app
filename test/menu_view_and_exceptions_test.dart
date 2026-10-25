import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/menu/data/supabase_menu_repository.dart';
import 'package:restaurante_app/supabase/menu_service.dart';

void main() {
  group('HU5 & HU6: MenuService & Excepciones de Calendario', () {
    test('Calcula correctamente el rango semanal de Lunes a Viernes', () {
      // Sábado 24 de Octubre de 2026 (weekday = 6)
      final refDate = DateTime(2026, 10, 24);
      final rango = MenuService.getRangoSemana(referenceDate: refDate);

      expect(MenuService.formatDate(rango.inicioSemana), '2026-10-19');
      expect(MenuService.formatDate(rango.finSemana), '2026-10-23');

      final dias = MenuService.getDiasSemana(referenceDate: refDate);
      expect(dias.length, 5);
      expect(dias[0].weekday, DateTime.monday);
      expect(dias[4].weekday, DateTime.friday);
      expect(MenuService.formatDate(dias[0]), '2026-10-19');
      expect(MenuService.formatDate(dias[1]), '2026-10-20');
      expect(MenuService.formatDate(dias[2]), '2026-10-21');
      expect(MenuService.formatDate(dias[3]), '2026-10-22');
      expect(MenuService.formatDate(dias[4]), '2026-10-23');
    });

    test('Manejo tolerante a fallos y control de nulos en parseDish', () {
      // 1. Caso plato completo con URL remota
      final platoJson = {
        'id_plato': 5,
        'nombre': 'Majadito',
        'descripcion': 'Majadito tostado, arroz seco.',
        'imagen_url':
            'https://vzcrkhjqdsnxizhyjjjk.supabase.co/storage/v1/object/public/imagenes/platos/plato_1792462774139_bkrv2w.webp',
        'tipo': null,
      };

      final dish = MenuService.parseDish(platoJson);
      expect(dish, isNotNull);
      expect(dish!.id, '5');
      expect(dish.name, 'Majadito');
      expect(dish.description, 'Majadito tostado, arroz seco.');
      expect(dish.imageUrl, startsWith('https://vzcrkhjqdsnxizhyjjjk.supabase.co/'));
      expect(dish.category, 'Segundo');

      // 2. Caso plato con todos los campos opcionales nulos
      final platoNuloJson = {
        'id_plato': 10,
        'nombre': null,
        'descripcion': null,
        'imagen_url': null,
        'tipo': null,
      };

      final dishNulo = MenuService.parseDish(platoNuloJson);
      expect(dishNulo, isNotNull);
      expect(dishNulo!.name, 'Plato del día');
      expect(dishNulo.description, isNotEmpty);
      expect(dishNulo.imageUrl, isNotEmpty);

      // 3. Caso plato inválido o vacío
      final dishVacio = MenuService.parseDish({});
      expect(dishVacio, isNull);
    });

    test('Control de lista dinámica de platos con parsePlatos', () {
      final rawList = [
        {
          'id_plato': 2,
          'nombre': 'Silpancho',
          'descripcion': 'Plato tradicional',
          'imagen_url': null,
          'tipo': 'Segundo',
        },
        null,
        'invalid_item',
        {
          'id_plato': 3,
          'nombre': 'Sopa de maní',
          'descripcion': 'Sopa emblemática',
          'imagen_url': 'assets/images/04_sopa_de_mani.jpg',
          'tipo': 'Sopa',
        },
      ];

      final dishes = MenuService.parsePlatos(rawList);
      expect(dishes.length, 2);
      expect(dishes[0].name, 'Silpancho');
      expect(dishes[1].name, 'Sopa de maní');
      expect(dishes[1].category, 'Sopa');
    });

    test('HU6: Estado de excepción de calendario no expone menú habilitado', () {
      const resultExcepcion = MenuDiaResult(
        fecha: '2026-10-22',
        isExcepcion: true,
        motivoExcepcion: 'Feriado Nacional',
        isDisponible: false,
        platos: [],
      );

      expect(resultExcepcion.isExcepcion, isTrue);
      expect(resultExcepcion.motivoExcepcion, 'Feriado Nacional');
      expect(resultExcepcion.tieneMenuValido, isFalse);
      expect(resultExcepcion.platos, isEmpty);
    });

    test('HU5: Menú no disponible cuando no hay platos cargados', () {
      const resultSinMenu = MenuDiaResult(
        fecha: '2026-10-25',
        isExcepcion: false,
        isDisponible: false,
        platos: [],
      );

      expect(resultSinMenu.isExcepcion, isFalse);
      expect(resultSinMenu.isDisponible, isFalse);
      expect(resultSinMenu.tieneMenuValido, isFalse);
      expect(resultSinMenu.platos, isEmpty);
    });

    test('SupabaseMenuRepository genera DailyMenu robusto a partir de platos', () async {
      final repo = SupabaseMenuRepository();
      // Prueba con fecha de día laborable
      final date = DateTime(2026, 10, 19);
      final dailyMenu = await repo.getDailyMenuStructure(date);

      expect(dailyMenu, isNotNull);
      expect(dailyMenu.opcionesAlmuerzo, isNotEmpty);
      expect(dailyMenu.allDishes, isNotEmpty);
      expect(dailyMenu.almuerzoCompleto.segundo, isNotNull);
      expect(dailyMenu.almuerzoCompleto.sopa, isNotNull);
      expect(dailyMenu.almuerzoCompleto.entrada, isNotNull);
    });
  });
}
