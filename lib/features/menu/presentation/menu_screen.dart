import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/menu/data/supabase_menu_repository.dart';
import 'package:restaurante_app/features/menu/domain/daily_menu_entity.dart';
import 'package:restaurante_app/features/menu/domain/daily_menu_policy.dart';
import 'package:restaurante_app/features/menu/domain/menu_entity.dart';
import 'package:restaurante_app/features/menu/domain/menu_repository.dart';

class MenuScreen extends ConsumerStatefulWidget {
  final void Function(Dish dish)? onSelectDishForReservation;

  const MenuScreen({super.key, this.onSelectDishForReservation});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final MenuRepository _repository = SupabaseMenuRepository();
  List<Dish> _dishes = [];
  DailyMenu? _dailyMenu;
  bool _isLoading = true;
  String _selectedCategory = 'Almuerzo del día';

  List<String> _categories(bool isThursday) => [
    'Almuerzo del día',
    'Especial',
    'Vegetariano',
    if (isThursday) 'Postre',
  ];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    if (_selectedCategory == 'Postre' && !DailyMenuPolicy.isDessertDay(now)) {
      _selectedCategory = 'Almuerzo del día';
    }
    final structure = await _repository.getDailyMenuStructure(now);
    final dishes = structure.allDishes.toSet().toList();
    if (mounted) {
      setState(() {
        _dailyMenu = structure;
        _dishes = dishes;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(Dish dish) async {
    final updatedFavorites = !dish.isFavorite;
    setState(() {
      final index = _dishes.indexWhere((d) => d.id == dish.id);
      if (index != -1) {
        _dishes[index] = dish.copyWith(isFavorite: updatedFavorites);
      }
    });

    await _repository.toggleFavorite(dish.id);
  }

  List<Dish> get _filteredDishes {
    return _dishes.where((dish) {
      final matchesCategory = (_selectedCategory == 'Almuerzo del día'
          ? dish.category == 'Sopa' ||
                dish.category == 'Segundo' ||
                dish.category == 'Entrada'
          : dish.category.toLowerCase().contains(
              _selectedCategory.toLowerCase(),
            ));
      return matchesCategory;
    }).toList();
  }

  List<Dish> get _selectedDishes {
    if (_selectedCategory == 'Especial' && _dailyMenu != null) {
      return [_dailyMenu!.platoEspecial];
    }
    return _filteredDishes;
  }

  @override
  Widget build(BuildContext context) {
    final isThursday = DailyMenuPolicy.isDessertDay(DateTime.now());
    final categories = _categories(isThursday);
    final currentUser = ref.watch(authProvider);
    final activeUserName = currentUser?.fullName.trim().isNotEmpty == true
        ? currentUser!.fullName
        : 'Cargando usuario...';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menú del Día',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            Text(
              'Usuario activo: $activeUserName',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar menú',
            onPressed: _loadMenu,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen expandible de la estructura del menú del día
          if (_dailyMenu != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 4),
                    leading: const Icon(
                      Icons.restaurant_menu,
                      color: Color(0xFF2563EB),
                    ),
                    title: const Text(
                      'Menú Diario',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      isThursday
                          ? 'Jueves: incluye postre'
                          : 'Consulta las opciones de hoy',
                      style: TextStyle(
                        fontSize: 11,
                        color: isThursday
                            ? Colors.purple
                            : Colors.grey.shade700,
                      ),
                    ),
                    children: [
                      ..._dailyMenu!.opcionesAlmuerzo.asMap().entries.map(
                        (entry) => _buildDailyMenuItem(
                          'Almuerzo del día ${entry.key + 1}',
                          'Entrada: ${entry.value.entrada.name} · '
                              'Sopa: ${entry.value.sopa.name} · '
                              'Segundo: ${entry.value.segundo.name}',
                        ),
                      ),
                      _buildDailyMenuItem(
                        'Opción vegetariana',
                        _dailyMenu!.platoVegetariano.name,
                      ),
                      _buildDailyMenuItem(
                        'Plato especial',
                        _dailyMenu!.platoEspecial.name,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Filtro por categorías
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 6),

          // Lista de platos
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : (_selectedCategory == 'Almuerzo del día'
                      ? _dailyMenu!.opcionesAlmuerzo.isEmpty
                      : _selectedDishes.isEmpty)
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restaurant_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No se encontraron platos para este filtro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadMenu,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _selectedCategory == 'Almuerzo del día'
                          ? _dailyMenu!.opcionesAlmuerzo.length
                          : _selectedDishes.length,
                      itemBuilder: (context, index) {
                        if (_selectedCategory == 'Almuerzo del día') {
                          return _buildCompleteLunchCard(
                            _dailyMenu!.opcionesAlmuerzo[index],
                            index,
                          );
                        }

                        return _buildDishCard(_selectedDishes[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMenuItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteLunchCard(AlmuerzoCompleto combo, int index) {
    final currentUser = ref.watch(authProvider);
    final hasMonthlyPlan = currentUser?.isPensioner ?? false;
    final employeePrice = currentUser?.mealPrice ?? UserProfile.dailyMealPrice;
    final components = [
      ('Entrada / ensalada', combo.entrada),
      ('Sopa del día', combo.sopa),
      ('Segundo', combo.segundo),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Almuerzo del día ${index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                'Bs. ${employeePrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasMonthlyPlan
                      ? Colors.green.shade700
                      : Colors.deepOrange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...components.map(
            (component) =>
                _buildComboComponent(label: component.$1, dish: component.$2),
          ),
          if (widget.onSelectDishForReservation != null) ...[
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    widget.onSelectDishForReservation!(combo.segundo),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Reservar este almuerzo'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComboComponent({required String label, required Dish dish}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: dish.imageUrl.startsWith('http')
                  ? Image.network(
                      dish.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildImagePlaceholder(),
                    )
                  : Image.asset(
                      dish.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildImagePlaceholder(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dish.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(Dish dish) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen redondeada
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: dish.imageUrl.startsWith('http')
                        ? Image.network(
                            dish.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildImagePlaceholder(),
                          )
                        : Image.asset(
                            dish.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildImagePlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Detalles del plato
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dish.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              dish.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: dish.isFavorite ? Colors.red : Colors.grey,
                              size: 22,
                            ),
                            onPressed: () => _toggleFavorite(dish),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dish.description,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Etiquetas (categoría, calorías, precio)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dish.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${dish.calories} kcal',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Bs. ${dish.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.onSelectDishForReservation != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                ),
              ),
              child: InkWell(
                onTap: () => widget.onSelectDishForReservation!(dish),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reservar este plato',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.restaurant, color: Colors.grey, size: 32),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Cerrar Sesión'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión y salir del sistema de forma segura?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      await ref.read(authProvider.notifier).signOut();
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada de forma segura.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
