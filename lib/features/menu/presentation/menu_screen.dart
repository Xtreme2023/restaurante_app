import 'package:flutter/material.dart';
import 'package:restaurante_app/features/menu/data/mock_menu_repository.dart';
import 'package:restaurante_app/features/menu/domain/menu_entity.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final MockMenuRepository _repository = MockMenuRepository();
  List<Dish> _dishes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final dishes = await _repository.getDailyMenu();
    setState(() {
      _dishes = dishes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Permite ver la mesa.jpeg
      appBar: AppBar(
        title: const Text(
          'Menú del Día',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor:
            Colors.white, // Letras blancas para contrastar con el fondo
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _dishes.length,
              itemBuilder: (context, index) {
                final dish = _dishes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12), // Margen interno
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.95,
                    ), // Ligeramente translúcido
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      // AQUÍ CARGAMOS LA IMAGEN DEL PLATO
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          dish.imageUrl, // La ruta de la imagen en mock_menu_repository
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          // Si no encuentra la imagen, muestra este contenedor por defecto
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.fastfood,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dish.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dish.description,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          dish.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: dish.isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
