import 'package:restaurante_app/features/menu/domain/menu_entity.dart';

class MockMenuRepository {
  Future<List<Dish>> getDailyMenu() async {
    // Simulamos que carga de una base de datos por 1 segundo
    await Future.delayed(const Duration(seconds: 1));

    return [
      Dish(
        id: '1',
        name: 'Silpancho Cochabambino',
        description: 'Carne apanada sobre cama de arroz y papas con huevo.',
        imageUrl: 'assets/silpancho.png',
      ),
      Dish(
        id: '2',
        name: 'Sopa de Maní',
        description: 'Sopa tradicional boliviana con fideos tostados.',
        imageUrl: 'assets/sopa.png',
        isFavorite: true,
      ),
    ];
  }
}
