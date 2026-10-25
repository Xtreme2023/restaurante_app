import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/familiares/presentation/providers/family_providers.dart';
import 'package:restaurante_app/features/menu/data/supabase_menu_repository.dart';
import 'package:restaurante_app/features/menu/domain/menu_entity.dart';
import 'package:restaurante_app/features/menu/domain/menu_repository.dart';
import 'package:restaurante_app/features/pension/presentation/providers/pension_providers.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';
import 'package:restaurante_app/supabase/menu_service.dart';

class MenuScreen extends ConsumerStatefulWidget {
  final void Function(Dish dish)? onSelectDishForReservation;

  const MenuScreen({super.key, this.onSelectDishForReservation});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final MenuRepository _repository = SupabaseMenuRepository();
  final ReservationPolicy _reservationPolicy = ReservationPolicy();

  // Desplazamiento semanal: 0 = Semana actual, 1 = Semana siguiente
  int _weekOffset = 0;
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _weekDays = [];
  Set<String> _excepcionesFechas = {};
  Map<String, String> _excepcionesMotivos = {};

  bool _isExcepcionDay = false;
  String? _motivoExcepcion;
  bool _isMenuDisponible = false;

  List<Dish> _dishes = [];
  bool _isLoading = true;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';

  // Enum de plato: tipo (Sopa, Segundo, Vegetariano). Soporta nulos.
  static const List<String> _categories = [
    'Todos',
    'Segundo',
    'Sopa',
    'Vegetariano',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Si el día actual es domingo (weekday == 7), comenzar por defecto en la semana siguiente (offset 1)
    // para evitar mantenerse en el viernes de la semana anterior.
    if (now.weekday == DateTime.sunday) {
      _weekOffset = 1;
    }
    _initWeekAndLoad();
  }

  /// Inicializa la semana laboral (Lunes a Viernes) según `_weekOffset` y carga el menú
  Future<void> _initWeekAndLoad() async {
    final now = DateTime.now();
    _weekDays = MenuService.getDiasSemana(
      referenceDate: now,
      weekOffset: _weekOffset,
    );

    final normalizedNow = DateTime(now.year, now.month, now.day);
    if (_weekOffset == 0 && now.weekday >= 1 && now.weekday <= 5) {
      _selectedDate = normalizedNow;
    } else if (_weekDays.isNotEmpty) {
      _selectedDate = _weekDays.first;
    } else {
      _selectedDate = normalizedNow;
    }

    await _loadWeekExceptions();
    await _loadMenuForDate(_selectedDate);
  }

  /// Cambia entre la semana actual (0) y la semana siguiente (1)
  void _changeWeek(int newOffset) {
    if (_weekOffset == newOffset) return;
    setState(() {
      _weekOffset = newOffset;
      final now = DateTime.now();
      _weekDays = MenuService.getDiasSemana(
        referenceDate: now,
        weekOffset: _weekOffset,
      );
      if (_weekOffset == 0 && now.weekday >= 1 && now.weekday <= 5) {
        _selectedDate = DateTime(now.year, now.month, now.day);
      } else if (_weekDays.isNotEmpty) {
        _selectedDate = _weekDays.first;
      }
    });
    _loadWeekExceptions();
    _loadMenuForDate(_selectedDate);
  }

  /// Carga las excepciones de calendario para la semana seleccionada (HU6)
  Future<void> _loadWeekExceptions() async {
    final rango = MenuService.getRangoSemana(
      referenceDate: DateTime.now(),
      weekOffset: _weekOffset,
    );
    final exceptions = await MenuService.getExcepcionesCalendario(
      fechaInicio: MenuService.formatDate(rango.inicioSemana),
      fechaFin: MenuService.formatDate(rango.finSemana),
    );

    if (mounted) {
      setState(() {
        _excepcionesFechas = exceptions
            .map((e) => e['fecha']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet();
        _excepcionesMotivos = {
          for (final e in exceptions)
            if (e['fecha'] != null)
              e['fecha'].toString():
                  e['motivo']?.toString() ?? 'Día de no atención',
        };
      });
    }
  }

  /// Carga el menú para una fecha específica desde `vista_menu_con_platos`
  /// filtrando estrictamente contra `excepcion_calendario` (HU5 y HU6).
  Future<void> _loadMenuForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _selectedDate = date;
    });

    final dateStr = MenuService.formatDate(date);

    // 1. Verificar si la fecha está en excepcion_calendario (HU6)
    if (_excepcionesFechas.contains(dateStr)) {
      final motivo =
          _excepcionesMotivos[dateStr] ?? 'Feriado / Suspensión de servicio';
      if (mounted) {
        setState(() {
          _isExcepcionDay = true;
          _motivoExcepcion = motivo;
          _isMenuDisponible = false;
          _dishes = const [];
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Consultar menú desde vista_menu_con_platos a través de MenuService
    final menuResult = await MenuService.getMenuPorFecha(date);
    if (menuResult.isExcepcion) {
      if (mounted) {
        setState(() {
          _isExcepcionDay = true;
          _motivoExcepcion = menuResult.motivoExcepcion ?? 'Día de no atención';
          _isMenuDisponible = false;
          _dishes = const [];
          _isLoading = false;
        });
      }
      return;
    }

    // 3. Obtener platos reales del menú del día
    final dishes = menuResult.platos;

    if (mounted) {
      setState(() {
        _isExcepcionDay = false;
        _motivoExcepcion = null;
        _isMenuDisponible = menuResult.isDisponible || dishes.isNotEmpty;
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
      final matchesCategory = _matchesCategory(dish);
      final matchesSearch = _matchesSearch(dish);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// Filtro por `plato.tipo` (Sopa, Segundo, Vegetariano).
  /// Soporta nulos: si es nulo, no coincide con ningún tipo específico ("si es nulo que no muestre nada").
  bool _matchesCategory(Dish dish) {
    if (_selectedCategory == 'Todos') {
      return true;
    }
    final tipo = dish.tipo?.trim().toLowerCase();
    if (tipo == null || tipo.isEmpty) {
      return false; // Nulo no coincide con filtros de tipo
    }
    return tipo == _selectedCategory.toLowerCase();
  }

  bool _matchesSearch(Dish dish) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return dish.name.toLowerCase().contains(query) ||
        dish.description.toLowerCase().contains(query) ||
        (dish.tipo != null && dish.tipo!.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menú del Día',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            Text(
              'Restaurante Institucional',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar menú',
            onPressed: () async {
              await _loadWeekExceptions();
              await _loadMenuForDate(_selectedDate);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: GestureDetector(
        // Soporte de deslizamiento táctil horizontal entre semana actual y siguiente
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -200 && _weekOffset == 0) {
            // Deslizar a la izquierda -> semana siguiente
            _changeWeek(1);
          } else if (velocity > 200 && _weekOffset == 1) {
            // Deslizar a la derecha -> semana actual
            _changeWeek(0);
          }
        },
        child: Column(
          children: [
            // 1. Selector y Deslizador entre Semana Actual y Siguiente
            _buildWeekNavigationHeader(),

            // 2. Selector de días laborales Lunes a Viernes de la semana elegida
            _buildWeekDaySelector(),

            // 3. Barra de búsqueda rápida
            _buildSearchBar(),

            // 4. Filtro por categorías según enum `tipo`: ['Todos', 'Segundo', 'Sopa', 'Vegetariano']
            _buildCategoryFilters(),

            // 5. Contenido según estado: Excepción (HU6), No disponible (HU5) o Menú real
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _isExcepcionDay
                  ? _buildExcepcionBanner()
                  : !_isMenuDisponible
                  ? _buildMenuNoDisponibleBanner()
                  : _buildDishesList(_filteredDishes),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra de navegación superior para deslizar o alternar entre la semana actual y la siguiente
  Widget _buildWeekNavigationHeader() {
    final rango = MenuService.getRangoSemana(
      referenceDate: DateTime.now(),
      weekOffset: _weekOffset,
    );
    final rangoTexto =
        '${rango.inicioSemana.day}/${rango.inicioSemana.month} - ${rango.finSemana.day}/${rango.finSemana.month}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón Semana Actual
          Expanded(
            child: InkWell(
              onTap: () => _changeWeek(0),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _weekOffset == 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chevron_left,
                      size: 18,
                      color: _weekOffset == 0 ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Semana Actual',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _weekOffset == 0
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _weekOffset == 0 ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Indicador de rango
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rangoTexto,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Botón Semana Siguiente
          Expanded(
            child: InkWell(
              onTap: () => _changeWeek(1),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _weekOffset == 1
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Semana Siguiente',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _weekOffset == 1
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _weekOffset == 1 ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: _weekOffset == 1 ? Colors.white : Colors.black87,
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

  /// Selector de días de la semana laboral (Lunes a Viernes)
  Widget _buildWeekDaySelector() {
    final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie'];
    final todayStr = MenuService.formatDate(DateTime.now());
    final selectedStr = MenuService.formatDate(_selectedDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _weekDays.asMap().entries.map((entry) {
          final index = entry.key;
          final dayDate = entry.value;
          final dateStr = MenuService.formatDate(dayDate);
          final isSelected = dateStr == selectedStr;
          final isToday = dateStr == todayStr;
          final isExcepcion = _excepcionesFechas.contains(dateStr);
          final dayNormalized = DateTime(
            dayDate.year,
            dayDate.month,
            dayDate.day,
          );
          final todayNormalized = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
          final isPast = dayNormalized.isBefore(todayNormalized);

          return InkWell(
            onTap: () => _loadMenuForDate(dayDate),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isPast
                          ? const Color(0xFF475569)
                          : Theme.of(context).colorScheme.primary)
                    : (isToday
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12)
                          : (isPast
                                ? Colors.grey.shade100
                                : Colors.transparent)),
                borderRadius: BorderRadius.circular(14),
                border: isToday && !isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      )
                    : (isPast && !isSelected
                          ? Border.all(color: Colors.grey.shade300)
                          : null),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayNames[index % dayNames.length],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isExcepcion
                                    ? Colors.red.shade700
                                    : (isPast
                                          ? Colors.grey.shade600
                                          : const Color(0xFF64748B))),
                        ),
                      ),
                      if (isExcepcion) ...[
                        const SizedBox(width: 3),
                        Icon(
                          Icons.block,
                          size: 11,
                          color: isSelected ? Colors.white : Colors.red,
                        ),
                      ] else if (isPast) ...[
                        const SizedBox(width: 3),
                        Icon(
                          Icons.history,
                          size: 11,
                          color: isSelected
                              ? Colors.white70
                              : Colors.grey.shade500,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayDate.day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isExcepcion
                                ? Colors.red.shade700
                                : (isPast
                                      ? Colors.grey.shade500
                                      : const Color(0xFF1E293B))),
                    ),
                  ),
                  if (isToday)
                    Text(
                      'Hoy',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white70
                            : Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else if (isPast)
                    Text(
                      'Pasado',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white70
                            : Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Banner cuando el día tiene excepción de calendario (HU6)
  Widget _buildExcepcionBanner() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.orange.shade200, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Día no habilitado para atención',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _motivoExcepcion ?? 'Feriado / Suspensión de servicio',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'El restaurante institucional no prestará servicio de almuerzos en esta fecha.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner cuando el menú aún no ha sido cargado por el encargado (HU5)
  Widget _buildMenuNoDisponibleBanner() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Menú no disponible',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El menú para esta fecha aún no ha sido cargado o publicado por el encargado del restaurante (HU5).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra de búsqueda rápida
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Container(
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
        child: TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: const InputDecoration(
            hintText: 'Buscar platos, ingredientes...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  /// Filtro por categorías según enum `tipo`: ['Todos', 'Segundo', 'Sopa', 'Vegetariano']
  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  /// Lista de platos filtrados
  Widget _buildDishesList(List<Dish> filtered) {
    if (filtered.isEmpty) {
      return Center(
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
              Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No se encontraron platos para este filtro.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMenuForDate(_selectedDate),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildDishCard(filtered[index]);
        },
      ),
    );
  }

  /// Tarjeta de plato del menú
  Widget _buildDishCard(Dish dish) {
    // Colores para el tipo de plato (si tiene tipo definido)
    Color tipoColor = const Color(0xFF2563EB);
    if (dish.tipo?.toLowerCase() == 'sopa') {
      tipoColor = Colors.amber.shade800;
    } else if (dish.tipo?.toLowerCase() == 'vegetariano') {
      tipoColor = Colors.green.shade700;
    }

    final hasTipo = dish.tipo != null && dish.tipo!.trim().isNotEmpty;

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
                // Imagen redondeada con control de nulos y carga
                _buildDishImage(
                  dish.imageUrl,
                  width: 90,
                  height: 90,
                  borderRadius: 18,
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
                              dish.name.isNotEmpty
                                  ? dish.name
                                  : 'Plato del día',
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
                        dish.description.isNotEmpty
                            ? dish.description
                            : 'Plato registrado en el menú institucional.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Etiquetas: tipo (si no es nulo) y precio
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Si el campo tipo es nulo, no se muestra nada (regla de HU)
                          if (hasTipo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tipoColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dish.tipo!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tipoColor,
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
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
              ),
            ),
            child: InkWell(
              onTap: () {
                final now = DateTime.now();
                final todayNormalized = DateTime(now.year, now.month, now.day);
                final selectedNormalized = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                );
                final isPast = selectedNormalized.isBefore(todayNormalized);

                if (isPast) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se puede reservar para una fecha pasada',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (widget.onSelectDishForReservation != null) {
                  widget.onSelectDishForReservation!(dish);
                } else {
                  _showReservationSheet(dish);
                }
              },
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final todayNormalized = DateTime(
                    now.year,
                    now.month,
                    now.day,
                  );
                  final selectedNormalized = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                  );
                  final isPast = selectedNormalized.isBefore(todayNormalized);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPast
                              ? Icons.history_toggle_off
                              : Icons.calendar_today,
                          size: 16,
                          color: isPast
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPast
                              ? 'Fecha pasada (Reservas cerradas)'
                              : 'Reservar este plato',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isPast
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Modal interactivo de reserva directa (HU7, HU8, HU9)
  void _showReservationSheet(Dish dish) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReservationModalContent(
        dish: dish,
        date: _selectedDate,
        reservationPolicy: _reservationPolicy,
      ),
    ).then((result) {
      if (result != true && mounted) {
        // HU7 criterio: "Dado que el empleado abandona la pantalla sin confirmar,
        // Cuando cierra la ventana, Entonces el sistema muestra 'Reserva no guardada'."
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva no guardada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// Construye de manera resiliente la imagen del plato soportando URLs remotas (Supabase Storage),
  /// assets locales y placeholders ante fallas o nulos.
  Widget _buildDishImage(
    String? rawUrl, {
    double width = 90,
    double height = 90,
    double borderRadius = 18,
  }) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) {
      return _buildImagePlaceholder(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: url.startsWith('http://') || url.startsWith('https://')
            ? Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    _buildImagePlaceholder(
                      width: width,
                      height: height,
                      borderRadius: borderRadius,
                    ),
              )
            : Image.asset(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildImagePlaceholder(
                      width: width,
                      height: height,
                      borderRadius: borderRadius,
                    ),
              ),
      ),
    );
  }

  Widget _buildImagePlaceholder({
    double width = 90,
    double height = 90,
    double borderRadius = 18,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Icon(Icons.restaurant, color: Colors.grey, size: 28),
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

/// Contenido del modal de reserva directa para un plato (HU7, HU8, HU9)
class _ReservationModalContent extends ConsumerStatefulWidget {
  final Dish dish;
  final DateTime date;
  final ReservationPolicy reservationPolicy;

  const _ReservationModalContent({
    required this.dish,
    required this.date,
    required this.reservationPolicy,
  });

  @override
  ConsumerState<_ReservationModalContent> createState() =>
      _ReservationModalContentState();
}

class _ReservationModalContentState
    extends ConsumerState<_ReservationModalContent> {
  // false = Para mí (Empleado), true = Para un familiar
  bool _isForFamiliar = false;
  Familiar? _selectedFamiliar;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReservation() async {
    final now = DateTime.now();

    // Verificación de política horaria: mismo día después de las 9:00 AM (HU7 / HU9)
    if (AppDateUtils.isSameDay(widget.date, now) &&
        (now.hour > 9 || (now.hour == 9 && now.minute > 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fuera de horario'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // HU9: Si se eligió reservar para familiar, validar que se seleccione uno
    if (_isForFamiliar && _selectedFamiliar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un familiar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final todayNormalized = DateTime(now.year, now.month, now.day);
    final targetNormalized = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    if (targetNormalized.isBefore(todayNormalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede reservar para una fecha pasada'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final allReservations = ref.read(userReservationsProvider);
    final targetFamiliarId = _isForFamiliar ? _selectedFamiliar?.id : null;
    final alreadyHasRes = allReservations.any(
      (r) =>
          AppDateUtils.isSameDay(r.date, widget.date) &&
          r.status.toLowerCase() != 'cancelada' &&
          (targetFamiliarId != null
              ? r.familiarId == targetFamiliarId
              : (!r.isForFamiliar && r.familiarId == null)),
    );

    if (alreadyHasRes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isForFamiliar
                ? 'Ya existe una reserva registrada para ${_selectedFamiliar?.displayName ?? "el familiar"} en esta fecha.'
                : 'Ya tienes una reserva registrada para esta fecha.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(authProvider);
    final pensionMap =
        ref.read(comensalesPensionStatusProvider(widget.date)).value ?? {};
    final isEmployeePensioned =
        pensionMap[null] ?? (currentUser?.isPensioner ?? false);
    final isFamiliarPensioned = _selectedFamiliar != null
        ? (pensionMap[_selectedFamiliar!.id] ?? false)
        : false;
    final tariffPrice = _isForFamiliar
        ? (isFamiliarPensioned ? 15.0 : 18.0)
        : (isEmployeePensioned ? 15.0 : 18.0);

    final beneficiary = _isForFamiliar
        ? _selectedFamiliar!.displayName
        : (currentUser?.fullName ?? 'Empleado');

    final success = await ref
        .read(userReservationsProvider.notifier)
        .createReservation(
          date: widget.date,
          dishId: widget.dish.id,
          dishName: widget.dish.name,
          platoPrincipal: widget.dish.name,
          isAlmuerzoCompleto: false,
          menuCategory: ReservationMenuCategory.almuerzoCompleto,
          familiarId: _isForFamiliar ? _selectedFamiliar?.id : null,
          beneficiaryName: beneficiary,
          price: tariffPrice,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          userName: currentUser?.fullName ?? 'Empleado',
          userId: currentUser?.id ?? 'demo-user-123',
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reserva confirmada para $beneficiary: ${widget.dish.name} (Bs. ${tariffPrice.toStringAsFixed(2)})',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al procesar la reserva'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final familyAsync = ref.watch(employeeFamilyMembersProvider);
    final familiares = familyAsync.value ?? [];

    final pensionAsync = ref.watch(
      comensalesPensionStatusProvider(widget.date),
    );
    final pensionMap = pensionAsync.value ?? {};
    final isEmployeePensioned =
        pensionMap[null] ?? (currentUser?.isPensioner ?? false);
    final isFamiliarPensioned = _selectedFamiliar != null
        ? (pensionMap[_selectedFamiliar!.id] ?? false)
        : false;
    final isTargetPensioned = _isForFamiliar
        ? isFamiliarPensioned
        : isEmployeePensioned;
    final tariffPrice = isTargetPensioned ? 15.0 : 18.0;

    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final targetNormalized = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    final isPast = targetNormalized.isBefore(todayNormalized);
    final isAfterCutoff = AppDateUtils.isSameDay(widget.date, now) &&
        (now.hour > 9 || (now.hour == 9 && now.minute > 0));

    final allReservations = ref.watch(userReservationsProvider);
    final targetFamiliarId = _isForFamiliar ? _selectedFamiliar?.id : null;
    final existingReservation = allReservations
        .where(
          (r) =>
              AppDateUtils.isSameDay(r.date, widget.date) &&
              r.status.toLowerCase() != 'cancelada' &&
              (targetFamiliarId != null
                  ? r.familiarId == targetFamiliarId
                  : (!r.isForFamiliar && r.familiarId == null)),
        )
        .firstOrNull;
    final alreadyReserved = existingReservation != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.bookmark_add,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Confirmar Reserva',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    AppDateUtils.formatDate(widget.date),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            if (isPast) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta fecha ya pasó. No se permiten nuevas reservas para días anteriores.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (alreadyReserved) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isForFamiliar
                            ? 'Este familiar ya cuenta con una reserva activa para este día.'
                            : 'Ya tienes una reserva activa para este día. Solo se permite 1 plato por día.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Resumen del plato
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: widget.dish.imageUrl.startsWith('http')
                          ? Image.network(
                              widget.dish.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Colors.grey,
                                    ),
                                  ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.restaurant,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dish.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.dish.tipo != null)
                          Text(
                            widget.dish.tipo!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Beneficiario: Empleado vs Familiar (HU7 & HU9)
            const Text(
              '¿Para quién es la reserva?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.person, size: 16),
                    label: const Text('Para mí'),
                    selected: !_isForFamiliar,
                    selectedColor: const Color(
                      0xFF2563EB,
                    ).withValues(alpha: 0.15),
                    onSelected: (val) {
                      if (val) setState(() => _isForFamiliar = false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.family_restroom, size: 16),
                    label: const Text('Para familiar'),
                    selected: _isForFamiliar,
                    selectedColor: const Color(
                      0xFF2563EB,
                    ).withValues(alpha: 0.15),
                    onSelected: (val) {
                      if (val) setState(() => _isForFamiliar = true);
                    },
                  ),
                ),
              ],
            ),

            if (_isForFamiliar) ...[
              const SizedBox(height: 10),
              if (familiares.isEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'No tienes familiares registrados. Puedes solicitar su vinculación con el Administrador.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                )
              else
                DropdownButtonFormField<Familiar>(
                  initialValue: _selectedFamiliar,
                  decoration: InputDecoration(
                    labelText: 'Seleccionar familiar',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: familiares.map((f) {
                    return DropdownMenuItem<Familiar>(
                      value: f,
                      child: Text(f.displayName),
                    );
                  }).toList(),
                  onChanged: (fam) => setState(() => _selectedFamiliar = fam),
                ),
            ],

            const SizedBox(height: 14),

            // HU8: Campos listos para modalidad mensual y tarifa institucional independiente
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTargetPensioned
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isTargetPensioned
                      ? Colors.green.shade200
                      : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isTargetPensioned
                        ? Icons.stars_rounded
                        : Icons.info_outline_rounded,
                    color: isTargetPensioned
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTargetPensioned
                              ? '⭐ Modalidad: Pensionado Activo'
                              : 'Modalidad: Regular',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isTargetPensioned
                                ? Colors.green.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          _isForFamiliar
                              ? (isFamiliarPensioned
                                    ? 'Familiar pensionado: Oferta aplicada (Bs. 15.00)'
                                    : 'Familiar no pensionado: Precio por defecto (Bs. 18.00)')
                              : (isEmployeePensioned
                                    ? 'Empleado pensionado: Oferta aplicada (Bs. 15.00)'
                                    : 'Empleado regular: Precio por defecto (Bs. 18.00)'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Bs. ${tariffPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isTargetPensioned
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Observaciones
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Observaciones (ej. Sin ají, para llevar)',
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botón Confirmar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed:
                    (_isSubmitting || isPast || isAfterCutoff || alreadyReserved)
                        ? null
                        : _submitReservation,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isPast || isAfterCutoff
                            ? Icons.history_toggle_off
                            : (alreadyReserved
                                  ? Icons.block
                                  : Icons.check_circle_outline),
                      ),
                label: Text(
                  _isSubmitting
                      ? 'Confirmando...'
                      : (isPast
                            ? 'Fecha pasada'
                            : (isAfterCutoff
                                  ? 'Fuera de horario (Cerró 9:00 AM)'
                                  : (alreadyReserved
                                        ? 'Confirmar Reserva (Ya reservado)'
                                        : 'Confirmar Reserva'))),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (isPast || isAfterCutoff || alreadyReserved)
                          ? Colors.grey.shade400
                          : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
