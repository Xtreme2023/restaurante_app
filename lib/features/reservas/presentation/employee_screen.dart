import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/familiares/presentation/providers/family_providers.dart';
import 'package:restaurante_app/features/menu/domain/bolivian_dish_entity.dart';
import 'package:restaurante_app/features/menu/presentation/providers/weekly_menu_provider.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

enum MenuCategoryOption {
  almuerzoCompleto, // Combo unificado: Ensalada + Sopa + Segundo
  vegetariano, // Opción independiente: Menú Vegetariano
  platoEspecial, // Opción independiente: Plato Especial
}

class DishOptionItem {
  final String nombre;
  final String descripcion;
  final String region;
  final String imagenUrl;
  final String categoria;

  const DishOptionItem({
    required this.nombre,
    required this.descripcion,
    required this.region,
    required this.imagenUrl,
    required this.categoria,
  });
}

const List<DishOptionItem> defaultPlatosFuertes = [
  DishOptionItem(
    nombre: 'Silpancho Cochabambino',
    descripcion:
        'Carne apanada tierna sobre cama de arroz y papas doradas, con huevo frito y sarza criolla.',
    region: 'Cochabamba',
    imagenUrl: 'assets/images/01_silpancho.jpg',
    categoria: 'Segundo',
  ),
  DishOptionItem(
    nombre: 'Majadito Cruceño',
    descripcion:
        'Arroz tostado con charque de res desmenuzado, plátano maduro frito y huevo criollo.',
    region: 'Santa Cruz',
    imagenUrl: 'assets/images/03_charque_kan.jpg',
    categoria: 'Segundo',
  ),
  DishOptionItem(
    nombre: 'Saice Tarijeño',
    descripcion:
        'Guiso tradicional de carne picada en ají colorado, arvejas y chuchusmuti.',
    region: 'Tarija',
    imagenUrl: 'assets/images/06_fricase.jpg',
    categoria: 'Segundo',
  ),
  DishOptionItem(
    nombre: 'Falso Conejo',
    descripcion:
        'Carne apanada en salsa de ají amarillo con arvejas jugosas y fideo tostado.',
    region: 'La Paz',
    imagenUrl: 'assets/images/05_chicharron.jpg',
    categoria: 'Segundo',
  ),
  DishOptionItem(
    nombre: 'Mondongo Chuquisaqueño',
    descripcion:
        'Carne de cerdo dorada en ají colorado acompañada de mote amarillo y papas.',
    region: 'Chuquisaca',
    imagenUrl: 'assets/images/06_fricase.jpg',
    categoria: 'Segundo',
  ),
];

const List<DishOptionItem> defaultEnsaladas = [
  DishOptionItem(
    nombre: 'Ensalada Fresca del Día',
    descripcion:
        'Ensalada de hojas verdes, tomate, zanahoria y aderezo de la casa.',
    region: 'Nacional',
    imagenUrl: '',
    categoria: 'Entrada',
  ),
  DishOptionItem(
    nombre: 'Ensalada Rusa',
    descripcion: 'Papa, zanahoria, arvejas y mayonesa casera.',
    region: 'Nacional',
    imagenUrl: '',
    categoria: 'Entrada',
  ),
];

const List<DishOptionItem> defaultPlatosVegetarianos = [
  DishOptionItem(
    nombre: 'Quinua Real con Champiñones y Palta',
    descripcion:
        'Quinua perlada al wok con verduras salteadas al oliva, hongos dorados y láminas de palta fresca.',
    region: 'Potosí / Oruro',
    imagenUrl: 'assets/images/08_crema_de_quinua.jpg',
    categoria: 'Vegetariano',
  ),
  DishOptionItem(
    nombre: 'Milanesa de Soya con Ensalada Criolla',
    descripcion:
        'Milanesa crocante de proteína de soya con arroz graneado, papas al horno y sarza fresca.',
    region: 'Nacional',
    imagenUrl: 'assets/images/07_milanesa_de_soya.jpg',
    categoria: 'Vegetariano',
  ),
  DishOptionItem(
    nombre: 'Pastel de Verduras Andinas',
    descripcion:
        'Pastel horneado de acelga, espinaca, zanahoria y choclo con queso chaqueño artesanal.',
    region: 'Cochabamba',
    imagenUrl: 'assets/images/11_tortilla_de_verduras.jpg',
    categoria: 'Vegetariano',
  ),
  DishOptionItem(
    nombre: 'Ají de Fideo sin Carne (Vegetariano)',
    descripcion:
        'Fideo tostado en ají amarillo suave con arvejas, zanahorias y papas en cubos.',
    region: 'La Paz',
    imagenUrl: 'assets/images/10_aji_de_fideo_sin_carne.jpg',
    categoria: 'Vegetariano',
  ),
];

const List<DishOptionItem> defaultPlatosEspeciales = [
  DishOptionItem(
    nombre: 'Pique Macho Especial',
    descripcion:
        'Trozos selectos de lomo de res, salchichas, papas fritas, huevo duro, cebolla, tomate y locoto.',
    region: 'Cochabamba',
    imagenUrl: 'assets/images/02_pique_macho.jpg',
    categoria: 'Especial',
  ),
  DishOptionItem(
    nombre: 'Trucha del Titicaca al Limón',
    descripcion:
        'Filete fresco de trucha a la plancha con limón criollo, arroz blanco y papas doradas.',
    region: 'La Paz',
    imagenUrl: 'assets/images/11_tortilla_de_verduras.jpg',
    categoria: 'Especial',
  ),
  DishOptionItem(
    nombre: 'Picante Mixto Especial',
    descripcion:
        'Combinación de pollo en ají amarillo y lengua de res en ají rojo con chuño phuti.',
    region: 'Chuquisaca / Cochabamba',
    imagenUrl: 'assets/images/09_locro_de_zapallo.jpg',
    categoria: 'Especial',
  ),
  DishOptionItem(
    nombre: 'Lomo Montado Tradicional',
    descripcion:
        'Corte tierno de lomo con doble huevo frito, arroz blanco, papas fritas y ensalada fresca.',
    region: 'Nacional',
    imagenUrl: 'assets/images/01_silpancho.jpg',
    categoria: 'Especial',
  ),
];

class SopaBolivianaItem {
  final String nombre;
  final String descripcion;
  final String region;
  final String imagenUrl;

  const SopaBolivianaItem({
    required this.nombre,
    required this.descripcion,
    required this.region,
    required this.imagenUrl,
  });
}

const List<SopaBolivianaItem> defaultSopasBolivianas = [
  SopaBolivianaItem(
    nombre: 'Sopa de Maní Tradicional',
    descripcion:
        'Sopa cremosa tradicional a base de maní molido, costilla de res, verduras y papas al hilo.',
    region: 'Cochabamba / Nacional',
    imagenUrl: 'assets/images/04_sopa_de_mani.jpg',
  ),
  SopaBolivianaItem(
    nombre: 'Chairo Paceño',
    descripcion:
        'Sopa andina sustanciosa con chuño machacado, chalona, carne de res, trigo pelado y hierbabuena.',
    region: 'La Paz',
    imagenUrl: 'assets/images/08_crema_de_quinua.jpg',
  ),
  SopaBolivianaItem(
    nombre: 'Crema de Quinua Real',
    descripcion:
        'Crema nutritiva de quinua real andina con verduras frescas, queso criollo y un toque de cilantro.',
    region: 'Potosí / Oruro',
    imagenUrl: 'assets/images/08_crema_de_quinua.jpg',
  ),
  SopaBolivianaItem(
    nombre: 'Locro de Gallina Tradicional',
    descripcion:
        'Caldo aromático del oriente boliviano con presa de gallina criolla, arroz graneado y yuca.',
    region: 'Santa Cruz',
    imagenUrl: 'assets/images/09_locro_de_zapallo.jpg',
  ),
  SopaBolivianaItem(
    nombre: 'Caldo de Costilla Criollo',
    descripcion:
        'Reconfortante caldo cocinado a fuego lento con costilla jugosa de res, papas y verduras de la huerta.',
    region: 'Nacional',
    imagenUrl: 'assets/images/04_sopa_de_mani.jpg',
  ),
];

class EmployeeScreen extends ConsumerStatefulWidget {
  const EmployeeScreen({super.key});

  @override
  ConsumerState<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends ConsumerState<EmployeeScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isNextBusinessDaySelected = false;
  MenuCategoryOption _selectedCategoryOption =
      MenuCategoryOption.almuerzoCompleto;
  String? _selectedDishName;
  String? _selectedVegDishName;
  String? _selectedSpecialDishName;
  String _selectedSaladName = 'Ensalada Fresca del Día';
  String _selectedSoupName = 'Sopa de Maní Tradicional';
  final TextEditingController _notesController = TextEditingController();

  // Modo de reserva:
  // true = "Reserva Conjunta (Empleado + Familiares)"
  // false = "Reserva Individual / Por Comensal"
  bool _isJointReservation = true;

  // Selección en modo conjunto
  bool _includeEmployee = true;
  final Set<String> _selectedFamiliarIds = {};

  // Selección en modo individual (null = para el empleado)
  Familiar? _individualFamiliar;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    // Después del servicio, las nuevas reservas corresponden al siguiente
    // día hábil para que el menú mostrado coincida con la fecha reservada.
    if (now.hour >= ReservationPolicy.deliveryEndHour) {
      _selectedDate = _nextBusinessDay(_selectedDate);
      _isNextBusinessDaySelected = true;
    } else {
      _selectedDate = _nextBusinessDayIfWeekend(_selectedDate);
    }

    // También cubre el caso viernes por la tarde, cuando el siguiente día
    // hábil pertenece a la semana siguiente. La actualización se difiere
    // hasta después del primer frame para no modificar un provider durante
    // la construcción del árbol de widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(selectedWeekProvider.notifier).setWeek(_selectedDate);
      }
    });
  }

  DateTime _nextBusinessDay(DateTime date) {
    var nextDate = DateTime(date.year, date.month, date.day + 1);
    while (AppDateUtils.isWeekend(nextDate)) {
      nextDate = nextDate.add(const Duration(days: 1));
    }
    return nextDate;
  }

  DateTime _nextBusinessDayIfWeekend(DateTime date) {
    var businessDate = date;
    while (AppDateUtils.isWeekend(businessDate)) {
      businessDate = businessDate.add(const Duration(days: 1));
    }
    return businessDate;
  }

  void _selectReservationDate(
    DateTime date,
    List<MenuSemanalItem> dishesForDate,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var targetDate = date;
    var redirectedAfterService = false;

    if (AppDateUtils.isSameDay(date, today) &&
        now.hour >= ReservationPolicy.deliveryEndHour) {
      targetDate = _nextBusinessDay(today);
      redirectedAfterService = true;
      ref.read(selectedWeekProvider.notifier).setWeek(targetDate);
    }

    setState(() {
      _selectedDate = targetDate;
      _isNextBusinessDaySelected = redirectedAfterService;
      if (!redirectedAfterService && dishesForDate.isNotEmpty) {
        _selectedDishName = dishesForDate.first.platoNombre;
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final familyAsync = ref.watch(employeeFamilyMembersProvider);
    final publishedMenuAsync = ref.watch(publishedWeeklyMenuProvider);
    final weekStart = ref.watch(selectedWeekProvider);

    final familyMembers = familyAsync.value ?? [];
    final activeUserName = currentUser?.fullName ?? 'Cargando usuario...';
    final activeUserEmail = currentUser?.email ?? 'Sesión en preparación';
    final activeEmployeeCode = currentUser?.employeeCode.trim() ?? '';
    final screenTitle = currentUser?.fullName.trim().isNotEmpty == true
        ? currentUser!.fullName
        : 'Empleado';

    // Determinar tarifa aplicable:
    // 15 Bs si cuenta con Plan Mensual (isPensioner / hasMonthlyPlan)
    // 18 Bs si es particular / sin plan registrado
    final hasMonthlyPlan = currentUser?.isPensioner ?? false;
    final double tariffPrice =
        currentUser?.mealPrice ?? UserProfile.dailyMealPrice;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservas · $screenTitle',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Menú semanal boliviano y tarifas institucionales',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Membresía y Tarifa Fija del Usuario
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: hasMonthlyPlan
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    child: Icon(
                      hasMonthlyPlan
                          ? Icons.stars_rounded
                          : Icons.account_circle_outlined,
                      color: hasMonthlyPlan ? Colors.green : Colors.orange,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 14,
                              color: Colors.blueGrey.shade600,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Usuario activo',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeUserName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeUserEmail,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (activeEmployeeCode.isNotEmpty)
                          Text(
                            'Código: $activeEmployeeCode',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.blueGrey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 3),
                        Text(
                          hasMonthlyPlan
                              ? '⭐ Cuenta con Plan Mensual Activo'
                              : 'Modalidad Diaria / Particular',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasMonthlyPlan
                                ? Colors.green.shade800
                                : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasMonthlyPlan
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Bs. ${tariffPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hasMonthlyPlan
                                ? Colors.green.shade800
                                : Colors.deepOrange,
                          ),
                        ),
                        const Text(
                          'por plato',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // SECCIÓN 1: MENÚ PUBLICADO DE LA SEMANA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Menú Publicado de la Semana',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppDateUtils.formatShortDate(weekStart)} - ${AppDateUtils.formatShortDate(weekStart.add(const Duration(days: 4)))}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isNextBusinessDaySelected) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El servicio de hoy terminó. Se muestra el menú y la reserva para el siguiente día hábil.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Días de la semana (Lunes a Viernes)
                  publishedMenuAsync.when(
                    data: (menuItems) {
                      final publishedDays = [
                        {'name': 'Lunes', 'offset': 0},
                        {'name': 'Martes', 'offset': 1},
                        {'name': 'Miércoles', 'offset': 2},
                        {'name': 'Jueves', 'offset': 3},
                        {'name': 'Viernes', 'offset': 4},
                      ];

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: publishedDays.map((dayMap) {
                            final offset = dayMap['offset'] as int;
                            final date = weekStart.add(Duration(days: offset));
                            final isDaySelected = AppDateUtils.isSameDay(
                              _selectedDate,
                              date,
                            );

                            final dishesToday = menuItems.where((i) {
                              return i.fecha.year == date.year &&
                                  i.fecha.month == date.month &&
                                  i.fecha.day == date.day;
                            }).toList();

                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: InkWell(
                                onTap: () {
                                  _selectReservationDate(date, dishesToday);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 140,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDaySelected
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDaySelected
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dayMap['name'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDaySelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '${date.day}/${date.month}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDaySelected
                                              ? Colors.white70
                                              : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (dishesToday.isEmpty)
                                        Text(
                                          'Menú en preparación',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontStyle: FontStyle.italic,
                                            color: isDaySelected
                                                ? Colors.white70
                                                : Colors.grey,
                                          ),
                                        )
                                      else ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: _buildDishImageWidget(
                                            imageUrl:
                                                dishesToday.first.imagenUrl,
                                            width: double.infinity,
                                            height: 54,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          dishesToday.first.platoNombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDaySelected
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (dishesToday.length > 1)
                                          Text(
                                            '+${dishesToday.length - 1} opción más',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: isDaySelected
                                                  ? Colors.white70
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, stack) => Text('Error al cargar menú: $e'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // SECCIÓN 2: FORMULARIO DE RESERVA (FLEXIBLE: EMPLEADO + FAMILIARES O INDIVIDUAL)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Configurar Reserva',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          AppDateUtils.formatDate(_selectedDate),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Estructura de Categorías del Menú
                  const Text(
                    'Categoría del Menú:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  _buildCategoryTabs(),
                  const SizedBox(height: 14),

                  _buildDishSelector(publishedMenuAsync),

                  const SizedBox(height: 16),

                  // Alternar Modo: Reserva Conjunta vs Individual
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.group, size: 16),
                          label: const Text('Reserva Conjunta'),
                          selected: _isJointReservation,
                          selectedColor: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.15),
                          onSelected: (val) {
                            if (val) setState(() => _isJointReservation = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: const Text('Reserva Individual'),
                          selected: !_isJointReservation,
                          selectedColor: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.15),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _isJointReservation = false);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // MODO A: RESERVA CONJUNTA (Marcar empleado + familiares en una sola acción)
                  if (_isJointReservation) ...[
                    const Text(
                      'Marcar comensales para esta fecha:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Puedes incluir al empleado y a uno o más familiares con un clic:',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    // Opción: Empleado
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Empleado: ${currentUser?.fullName ?? 'Usuario'}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          hasMonthlyPlan
                              ? 'Tarifa Plan Mensual: Bs. 15.00'
                              : 'Tarifa Particular: Bs. 18.00',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: hasMonthlyPlan
                                ? Colors.green
                                : Colors.deepOrange,
                          ),
                        ),
                        value: _includeEmployee,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) {
                          setState(() => _includeEmployee = val ?? false);
                        },
                      ),
                    ),

                    // Opciones: Familiares
                    if (familyMembers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'No tienes familiares registrados. Puedes solicitar su vinculación con el Administrador.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      )
                    else
                      ...familyMembers.map((fam) {
                        final isChecked = _selectedFamiliarIds.contains(fam.id);
                        return Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Familiar: ${fam.displayName}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              'CI: ${fam.ci} • Tarifa: Bs. ${tariffPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            value: isChecked,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedFamiliarIds.add(fam.id);
                                } else {
                                  _selectedFamiliarIds.remove(fam.id);
                                }
                              });
                            },
                          ),
                        );
                      }),
                  ] else ...[
                    // MODO B: RESERVA INDIVIDUAL POR COMENSAL
                    const Text(
                      'Seleccionar comensal para la reserva individual:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Familiar?>(
                      initialValue: _individualFamiliar,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      items: [
                        DropdownMenuItem<Familiar?>(
                          value: null,
                          child: Text(
                            'Para mí (Empleado: ${currentUser?.fullName ?? 'Usuario'})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...familyMembers.map((f) {
                          return DropdownMenuItem<Familiar?>(
                            value: f,
                            child: Text(
                              'Familiar: ${f.displayName}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: (f) {
                        setState(() => _individualFamiliar = f);
                      },
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Campo Notas / Observaciones
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText:
                          'Notas especiales (ej. Para llevar, sin locoto, vegetariano)',
                      prefixIcon: const Icon(Icons.edit_note),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CÁLCULO Y DESGLOSE DE COSTO EN TIEMPO REAL ANTES DE CONFIRMAR
                  _buildCostSummary(tariffPrice, familyMembers),

                  const SizedBox(height: 16),

                  // Botón Confirmar Reserva
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _handleConfirmReservation(
                              context,
                              tariffPrice,
                              familyMembers,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isSubmitting
                            ? 'Registrando reserva...'
                            : 'Confirmar Reserva (${AppDateUtils.formatShortDate(_selectedDate)})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGETS AUXILIARES
  // ===========================================================================

  Widget _buildCategoryTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildCategoryTabItem(
              title: 'Almuerzo del día',
              subtitle: 'Ensalada + Sopa + Segundo',
              icon: Icons.lunch_dining,
              option: MenuCategoryOption.almuerzoCompleto,
              selectedColor: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildCategoryTabItem(
              title: 'Menú Vegetariano',
              subtitle: 'Saludable',
              icon: Icons.eco,
              option: MenuCategoryOption.vegetariano,
              selectedColor: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildCategoryTabItem(
              title: 'Plato Especial',
              subtitle: 'Premium',
              icon: Icons.stars_rounded,
              option: MenuCategoryOption.platoEspecial,
              selectedColor: Colors.amber.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required MenuCategoryOption option,
    required Color selectedColor,
  }) {
    final isSelected = _selectedCategoryOption == option;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategoryOption = option;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          border: isSelected
              ? Border.all(
                  color: selectedColor.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? selectedColor : Colors.grey.shade600,
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? selectedColor : Colors.grey.shade800,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.8)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishSelector(
    AsyncValue<List<MenuSemanalItem>> publishedMenuAsync,
  ) {
    return publishedMenuAsync.when(
      data: (items) {
        final dishesToday = items.where((i) {
          return i.fecha.year == _selectedDate.year &&
              i.fecha.month == _selectedDate.month &&
              i.fecha.day == _selectedDate.day;
        }).toList();

        switch (_selectedCategoryOption) {
          case MenuCategoryOption.almuerzoCompleto:
            return _buildAlmuerzoCompletoSection(dishesToday, items);
          case MenuCategoryOption.vegetariano:
            return _buildVegetarianoSection(dishesToday, items);
          case MenuCategoryOption.platoEspecial:
            return _buildPlatoEspecialSection(dishesToday, items);
        }
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, stack) => const Text('Error al cargar platos'),
    );
  }

  Widget _buildAlmuerzoCompletoSection(
    List<MenuSemanalItem> dishesToday,
    List<MenuSemanalItem> allItems,
  ) {
    final secondDishesToday = dishesToday
        .where((d) => _isSecond(d.tipoPlato))
        .toList();
    final soupDishesToday = dishesToday
        .where((d) => _isSoup(d.tipoPlato))
        .toList();
    final options = secondDishesToday.isNotEmpty
        ? secondDishesToday.map((d) => d.platoNombre).toSet().toList()
        : defaultPlatosFuertes.map((d) => d.nombre).toList();
    final soupOptions = soupDishesToday.isNotEmpty
        ? soupDishesToday.map((d) => d.platoNombre).toList()
        : defaultSopasBolivianas.map((s) => s.nombre).toList();
    final saladDishesToday = dishesToday
        .where((d) => _isSalad(d.tipoPlato))
        .toList();
    final saladOptions = saladDishesToday.isNotEmpty
        ? saladDishesToday.map((d) => d.platoNombre).toList()
        : defaultEnsaladas.map((s) => s.nombre).toList();
    if (!saladOptions.contains(_selectedSaladName)) {
      _selectedSaladName = saladOptions.first;
    }
    if (!soupOptions.contains(_selectedSoupName)) {
      _selectedSoupName = soupOptions.first;
    }

    if (_selectedDishName == null || !options.contains(_selectedDishName)) {
      _selectedDishName = options.first;
    }

    final (
      selectedImg,
      selectedDesc,
      selectedCategory,
      selectedRegion,
    ) = _resolveDishInfo(
      dishName: _selectedDishName!,
      dishesToday: dishesToday,
      allItems: allItems,
      fallbackList: defaultPlatosFuertes,
      defaultCategory: 'Segundo',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Almuerzo del día: Entrada + Sopa del día + Segundo',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          '1. Entrada / Ensalada:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'salad_selector_${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}',
          ),
          isExpanded: true,
          initialValue: _selectedSaladName,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            prefixIcon: const Icon(Icons.eco_outlined),
          ),
          items: saladOptions
              .map(
                (name) => DropdownMenuItem<String>(
                  value: name,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedSaladName = value);
          },
        ),
        const SizedBox(height: 12),
        const Text(
          '2. Sopa del día:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        // El selector de sopa permanece dentro del mismo Almuerzo del día.
        DropdownButtonFormField<String>(
          key: ValueKey(
            'dish_selector_${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}',
          ),
          isExpanded: true,
          initialValue: _selectedDishName,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            prefixIcon: const Icon(Icons.lunch_dining_outlined),
          ),
          items: options.map((dishName) {
            final (img, _, _, _) = _resolveDishInfo(
              dishName: dishName,
              dishesToday: dishesToday,
              allItems: allItems,
              fallbackList: defaultPlatosFuertes,
              defaultCategory: 'Segundo',
            );

            return DropdownMenuItem<String>(
              value: dishName,
              child: Row(
                children: [
                  _buildDishImageWidget(
                    imageUrl: img,
                    width: 26,
                    height: 26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dishName,
                      style: const TextStyle(fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedDishName = val);
          },
        ),

        if (dishesToday.length > 1) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: secondDishesToday.map((dish) {
                final isSelected = dish.platoNombre == _selectedDishName;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    avatar: _buildDishImageWidget(
                      imageUrl: dish.imagenUrl,
                      width: 20,
                      height: 20,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    label: Text(dish.platoNombre),
                    selected: isSelected,
                    selectedColor: const Color(
                      0xFF2563EB,
                    ).withValues(alpha: 0.15),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedDishName = dish.platoNombre);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Card visual destacada con la imagen del segundo
        _buildSelectedDishCard(
          name: _selectedDishName ?? 'Plato Boliviano',
          imageUrl: selectedImg,
          description: selectedDesc,
          category: selectedCategory,
          region: selectedRegion,
        ),

        const SizedBox(height: 16),

        // La sopa y el segundo se registran como un único Almuerzo del día.
        Row(
          children: [
            const Icon(Icons.soup_kitchen, color: Color(0xFF2563EB), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sopa del día incluida:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Combo Completo',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 26, top: 2),
          child: Text(
            'Parte del Almuerzo del día: sopa del día',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'soup_selector_${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}',
          ),
          isExpanded: true,
          initialValue: _selectedSoupName,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            prefixIcon: const Icon(Icons.ramen_dining_outlined),
          ),
          items: soupOptions.map((soupName) {
            final soup = defaultSopasBolivianas.firstWhere(
              (item) => item.nombre == soupName,
              orElse: () => SopaBolivianaItem(
                nombre: soupName,
                descripcion: 'Sopa del día del menú institucional.',
                region: 'Bolivia',
                imagenUrl: '',
              ),
            );
            return DropdownMenuItem<String>(
              value: soupName,
              child: Row(
                children: [
                  _buildDishImageWidget(
                    imageUrl: soup.imagenUrl,
                    width: 26,
                    height: 26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      soupName,
                      style: const TextStyle(fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${soup.region.split(' / ').first})',
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedSoupName = val);
          },
        ),
        const SizedBox(height: 10),
        _buildSoupCard(
          defaultSopasBolivianas.firstWhere(
            (s) => s.nombre == _selectedSoupName,
            orElse: () => SopaBolivianaItem(
              nombre: _selectedSoupName,
              descripcion: 'Sopa del día del menú institucional.',
              region: 'Bolivia',
              imagenUrl: '',
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildAlmuerzoCompletoBanner(
          platoPrincipal: _selectedDishName ?? 'Silpancho Cochabambino',
          sopa: _selectedSoupName,
        ),
      ],
    );
  }

  Widget _buildVegetarianoSection(
    List<MenuSemanalItem> dishesToday,
    List<MenuSemanalItem> allItems,
  ) {
    final vegDishesToday = dishesToday
        .where(
          (d) =>
              d.tipoPlato.toLowerCase().contains('veg') ||
              d.platoNombre.toLowerCase().contains('soya') ||
              d.platoNombre.toLowerCase().contains('quinua') ||
              d.platoNombre.toLowerCase().contains('verdura'),
        )
        .toList();

    final options = vegDishesToday.isNotEmpty
        ? vegDishesToday.map((d) => d.platoNombre).toSet().toList()
        : defaultPlatosVegetarianos.map((d) => d.nombre).toList();

    if (_selectedVegDishName == null ||
        !options.contains(_selectedVegDishName)) {
      _selectedVegDishName = options.first;
    }

    final (
      selectedImg,
      selectedDesc,
      selectedCategory,
      selectedRegion,
    ) = _resolveDishInfo(
      dishName: _selectedVegDishName!,
      dishesToday: dishesToday,
      allItems: allItems,
      fallbackList: defaultPlatosVegetarianos,
      defaultCategory: 'Vegetariano',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plato Vegetariano Seleccionado:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'veg_dish_selector_${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}',
          ),
          isExpanded: true,
          initialValue: _selectedVegDishName,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            prefixIcon: const Icon(Icons.eco_outlined, color: Colors.green),
          ),
          items: options.map((dishName) {
            final (img, _, _, _) = _resolveDishInfo(
              dishName: dishName,
              dishesToday: dishesToday,
              allItems: allItems,
              fallbackList: defaultPlatosVegetarianos,
              defaultCategory: 'Vegetariano',
            );

            return DropdownMenuItem<String>(
              value: dishName,
              child: Row(
                children: [
                  _buildDishImageWidget(
                    imageUrl: img,
                    width: 26,
                    height: 26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dishName,
                      style: const TextStyle(fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedVegDishName = val);
          },
        ),

        if (options.length > 1) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((dishName) {
                final isSelected = dishName == _selectedVegDishName;
                final (img, _, _, _) = _resolveDishInfo(
                  dishName: dishName,
                  dishesToday: dishesToday,
                  allItems: allItems,
                  fallbackList: defaultPlatosVegetarianos,
                  defaultCategory: 'Vegetariano',
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    avatar: _buildDishImageWidget(
                      imageUrl: img,
                      width: 20,
                      height: 20,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    label: Text(dishName),
                    selected: isSelected,
                    selectedColor: Colors.green.withValues(alpha: 0.18),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedVegDishName = dishName);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Card visual destacada del plato vegetariano
        _buildSelectedDishCard(
          name: _selectedVegDishName ?? 'Plato Vegetariano',
          imageUrl: selectedImg,
          description: selectedDesc,
          category: selectedCategory,
          region: selectedRegion,
        ),

        const SizedBox(height: 12),

        _buildVegetarianoBanner(
          plato: _selectedVegDishName ?? 'Quinua Real con Champiñones y Palta',
        ),
      ],
    );
  }

  Widget _buildPlatoEspecialSection(
    List<MenuSemanalItem> dishesToday,
    List<MenuSemanalItem> allItems,
  ) {
    final espDishesToday = dishesToday
        .where(
          (d) =>
              d.tipoPlato.toLowerCase().contains('esp') ||
              d.platoNombre.toLowerCase().contains('especial') ||
              d.platoNombre.toLowerCase().contains('pique') ||
              d.platoNombre.toLowerCase().contains('trucha') ||
              d.platoNombre.toLowerCase().contains('mixto'),
        )
        .toList();

    final options = espDishesToday.isNotEmpty
        ? espDishesToday.map((d) => d.platoNombre).toSet().toList()
        : defaultPlatosEspeciales.map((d) => d.nombre).toList();

    if (_selectedSpecialDishName == null ||
        !options.contains(_selectedSpecialDishName)) {
      _selectedSpecialDishName = options.first;
    }

    final (
      selectedImg,
      selectedDesc,
      selectedCategory,
      selectedRegion,
    ) = _resolveDishInfo(
      dishName: _selectedSpecialDishName!,
      dishesToday: dishesToday,
      allItems: allItems,
      fallbackList: defaultPlatosEspeciales,
      defaultCategory: 'Especial',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plato Especial Seleccionado:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'special_dish_selector_${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}',
          ),
          isExpanded: true,
          initialValue: _selectedSpecialDishName,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            prefixIcon: const Icon(Icons.stars_outlined, color: Colors.amber),
          ),
          items: options.map((dishName) {
            final (img, _, _, _) = _resolveDishInfo(
              dishName: dishName,
              dishesToday: dishesToday,
              allItems: allItems,
              fallbackList: defaultPlatosEspeciales,
              defaultCategory: 'Especial',
            );

            return DropdownMenuItem<String>(
              value: dishName,
              child: Row(
                children: [
                  _buildDishImageWidget(
                    imageUrl: img,
                    width: 26,
                    height: 26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dishName,
                      style: const TextStyle(fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedSpecialDishName = val);
          },
        ),

        if (options.length > 1) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((dishName) {
                final isSelected = dishName == _selectedSpecialDishName;
                final (img, _, _, _) = _resolveDishInfo(
                  dishName: dishName,
                  dishesToday: dishesToday,
                  allItems: allItems,
                  fallbackList: defaultPlatosEspeciales,
                  defaultCategory: 'Especial',
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    avatar: _buildDishImageWidget(
                      imageUrl: img,
                      width: 20,
                      height: 20,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    label: Text(dishName),
                    selected: isSelected,
                    selectedColor: Colors.amber.withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedSpecialDishName = dishName);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Card visual destacada del plato especial
        _buildSelectedDishCard(
          name: _selectedSpecialDishName ?? 'Plato Especial',
          imageUrl: selectedImg,
          description: selectedDesc,
          category: selectedCategory,
          region: selectedRegion,
        ),

        const SizedBox(height: 12),

        _buildEspecialBanner(
          plato: _selectedSpecialDishName ?? 'Pique Macho Especial',
        ),
      ],
    );
  }

  bool _isSecond(String category) {
    final normalized = category.toLowerCase();
    return normalized.contains('segundo') ||
        normalized.contains('fuerte') ||
        normalized.contains('principal');
  }

  bool _isSoup(String category) {
    final normalized = category.toLowerCase();
    return normalized.contains('sopa');
  }

  bool _isSalad(String category) {
    final normalized = category.toLowerCase();
    return normalized.contains('entrada') || normalized.contains('ensalada');
  }

  (String, String, String, String) _resolveDishInfo({
    required String dishName,
    required List<MenuSemanalItem> dishesToday,
    required List<MenuSemanalItem> allItems,
    required List<DishOptionItem> fallbackList,
    required String defaultCategory,
  }) {
    for (final item in dishesToday) {
      if (item.platoNombre == dishName) {
        final img = item.imagenUrl.isNotEmpty
            ? item.imagenUrl
            : resolveDishImageUrl('', dishName: dishName);
        final desc = item.platoDescripcion.isNotEmpty
            ? item.platoDescripcion
            : 'Plato boliviano disponible en el menú institucional de Supabase.';
        final cat = item.tipoPlato.isNotEmpty
            ? item.tipoPlato
            : defaultCategory;
        final reg = item.platoRegion.isNotEmpty ? item.platoRegion : 'Bolivia';
        return (img, desc, cat, reg);
      }
    }

    for (final item in allItems) {
      if (item.platoNombre == dishName) {
        final img = item.imagenUrl.isNotEmpty
            ? item.imagenUrl
            : resolveDishImageUrl('', dishName: dishName);
        final desc = item.platoDescripcion.isNotEmpty
            ? item.platoDescripcion
            : 'Plato boliviano disponible en el menú institucional de Supabase.';
        final cat = item.tipoPlato.isNotEmpty
            ? item.tipoPlato
            : defaultCategory;
        final reg = item.platoRegion.isNotEmpty ? item.platoRegion : 'Bolivia';
        return (img, desc, cat, reg);
      }
    }

    for (final d in fallbackList) {
      if (d.nombre == dishName) {
        return (d.imagenUrl, d.descripcion, d.categoria, d.region);
      }
    }

    return (
      resolveDishImageUrl('', dishName: dishName),
      'Plato boliviano disponible en el comedor institucional.',
      defaultCategory,
      'Bolivia',
    );
  }

  Widget _buildVegetarianoBanner({required String plato}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.09),
            Colors.teal.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🥗 Menú Vegetariano (Opción Independiente)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plato,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Opción saludable e independiente basada en proteínas vegetales y cereales andinos.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEspecialBanner({required String plato}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.12),
            Colors.orange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⭐ Plato Especial (Categoría Independiente)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plato,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Plato tradicional de corte premium elaborado bajo receta especial institucional.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlmuerzoCompletoBanner({
    required String platoPrincipal,
    required String sopa,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: 0.08),
            const Color(0xFF1E40AF).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lunch_dining,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🍱 Almuerzo del día (Combo del Día)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$platoPrincipal + $sopa',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'El combo pasa a denominarse Almuerzo del día y se registrará en Supabase.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoupCard(SopaBolivianaItem soup) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _buildDishImageWidget(
                imageUrl: soup.imagenUrl,
                width: double.infinity,
                height: 110,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Sopa Boliviana',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        soup.region,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        soup.nombre,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Gastronomía Boliviana',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  soup.descripcion,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDishCard({
    required String name,
    required String imageUrl,
    required String description,
    required String category,
    required String region,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _buildDishImageWidget(
                imageUrl: imageUrl,
                width: double.infinity,
                height: 145,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        region,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done, color: Colors.green, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Supabase',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishImageWidget({
    required String imageUrl,
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    final isNetwork =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    Widget imageWidget;
    if (isNetwork) {
      imageWidget = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildDishImagePlaceholder(width, height),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    } else {
      final assetPath = imageUrl.isNotEmpty
          ? (imageUrl.startsWith('assets/')
                ? imageUrl
                : 'assets/images/$imageUrl')
          : 'assets/images/01_silpancho.jpg';

      imageWidget = Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildDishImagePlaceholder(width, height),
      );
    }

    return ClipRRect(borderRadius: radius, child: imageWidget);
  }

  Widget _buildDishImagePlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.blue.shade50,
      child: const Center(
        child: Icon(Icons.restaurant, color: Color(0xFF2563EB), size: 22),
      ),
    );
  }

  Widget _buildCostSummary(double tariffPrice, List<Familiar> familyMembers) {
    int count = 0;
    if (_isJointReservation) {
      if (_includeEmployee) count++;
      count += _selectedFamiliarIds.length;
    } else {
      count = 1;
    }

    final double totalCost = count * tariffPrice;
    final isPlanMensual = tariffPrice == 15.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPlanMensual
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlanMensual
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Desglose y Subtotal:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isPlanMensual ? Colors.green : Colors.deepOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPlanMensual ? 'Tarifa Plan Mensual' : 'Tarifa Particular',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Cantidad de raciones: $count comensal(es)',
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count × Bs. ${tariffPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _getSummaryOptionText(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPlanMensual
                  ? Colors.green.shade900
                  : Colors.deepOrange.shade900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total a Cobrar:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Bs. ${totalCost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPlanMensual
                      ? Colors.green.shade800
                      : Colors.deepOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSummaryOptionText() {
    switch (_selectedCategoryOption) {
      case MenuCategoryOption.almuerzoCompleto:
        return '• Almuerzo del día: Ensalada ($_selectedSaladName) + Sopa del día ($_selectedSoupName) + Segundo (${_selectedDishName ?? "Silpancho Cochabambino"})';
      case MenuCategoryOption.vegetariano:
        return '• Menú Vegetariano: ${_selectedVegDishName ?? "Quinua Real con Champiñones y Palta"}';
      case MenuCategoryOption.platoEspecial:
        return '• Plato Especial: ${_selectedSpecialDishName ?? "Pique Macho Especial"}';
    }
  }

  Future<void> _handleConfirmReservation(
    BuildContext context,
    double tariffPrice,
    List<Familiar> familyMembers,
  ) async {
    final currentUser = ref.read(authProvider);
    final userId = currentUser?.id ?? 'demo-user-123';
    final userName = currentUser?.fullName ?? 'Empleado';

    final String comboName;
    final String? entrada;
    final String platoPrincipal;
    final String? sopa;
    final bool isAlmuerzoCompleto;
    final ReservationMenuCategory menuCategory;

    switch (_selectedCategoryOption) {
      case MenuCategoryOption.almuerzoCompleto:
        entrada = _selectedSaladName;
        platoPrincipal = _selectedDishName ?? 'Silpancho Cochabambino';
        sopa = _selectedSoupName;
        comboName = 'Almuerzo del día ($entrada + $sopa + $platoPrincipal)';
        isAlmuerzoCompleto = true;
        menuCategory = ReservationMenuCategory.almuerzoCompleto;
        break;
      case MenuCategoryOption.vegetariano:
        entrada = null;
        platoPrincipal =
            _selectedVegDishName ?? 'Quinua Real con Champiñones y Palta';
        sopa = null;
        comboName = 'Menú Vegetariano ($platoPrincipal)';
        isAlmuerzoCompleto = false;
        menuCategory = ReservationMenuCategory.menuVegetariano;
        break;
      case MenuCategoryOption.platoEspecial:
        entrada = null;
        platoPrincipal = _selectedSpecialDishName ?? 'Pique Macho Especial';
        sopa = null;
        comboName = 'Plato Especial ($platoPrincipal)';
        isAlmuerzoCompleto = false;
        menuCategory = ReservationMenuCategory.platoEspecial;
        break;
    }

    final notes = _notesController.text.trim();

    // Validar selección
    if (_isJointReservation &&
        !_includeEmployee &&
        _selectedFamiliarIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor marca al menos un comensal para reservar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isJointReservation) {
        final Map<String, String> famNames = {
          for (final f in familyMembers) f.id: f.displayName,
        };

        final createdCount = await ref
            .read(userReservationsProvider.notifier)
            .createJointReservations(
              date: _selectedDate,
              dishName: comboName,
              entradaNombre: entrada,
              platoPrincipal: platoPrincipal,
              sopaNombre: sopa,
              isAlmuerzoCompleto: isAlmuerzoCompleto,
              menuCategory: menuCategory,
              reserveForEmployee: _includeEmployee,
              selectedFamiliarIds: _selectedFamiliarIds.toList(),
              familiarNames: famNames,
              pricePerPerson: tariffPrice,
              notes: notes.isNotEmpty ? notes : null,
              userName: userName,
              userId: userId,
            );

        if (context.mounted) {
          final total = createdCount * tariffPrice;
          _showReservationConfirmation(
            title: 'Reserva confirmada',
            detail:
                '$createdCount comensales · $comboName\nTotal: Bs. ${total.toStringAsFixed(2)}',
          );
          _notesController.clear();
        }
      } else {
        // Reserva individual
        final isForFam = _individualFamiliar != null;
        final beneficiary = isForFam
            ? _individualFamiliar!.displayName
            : userName;

        final success = await ref
            .read(userReservationsProvider.notifier)
            .createReservation(
              date: _selectedDate,
              dishName: comboName,
              entradaNombre: entrada,
              platoPrincipal: platoPrincipal,
              sopaNombre: sopa,
              isAlmuerzoCompleto: isAlmuerzoCompleto,
              menuCategory: menuCategory,
              familiarId: _individualFamiliar?.id,
              beneficiaryName: beneficiary,
              price: tariffPrice,
              notes: notes.isNotEmpty ? notes : null,
              userName: userName,
              userId: userId,
            );

        if (context.mounted && success) {
          _showReservationConfirmation(
            title: 'Reserva confirmada',
            detail:
                '$beneficiary · $comboName\nTotal: Bs. ${tariffPrice.toStringAsFixed(2)}',
          );
          _notesController.clear();
        } else if (context.mounted) {
          final error = ref.read(userReservationsProvider.notifier).lastError;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo registrar la reserva${error != null ? ': $error' : '.'}',
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar reserva: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showReservationConfirmation({
    required String title,
    required String detail,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          backgroundColor: const Color(0xFF166534),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: messenger.hideCurrentSnackBar,
          ),
        ),
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
