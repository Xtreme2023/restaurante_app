import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/familiares/presentation/providers/family_providers.dart';
import 'package:restaurante_app/features/menu/domain/menu_entity.dart';
import 'package:restaurante_app/features/pension/presentation/pension_screen.dart';
import 'package:restaurante_app/features/pension/presentation/providers/pension_providers.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';
import 'package:restaurante_app/supabase/menu_service.dart';

class EmployeeScreen extends ConsumerStatefulWidget {
  const EmployeeScreen({super.key});

  @override
  ConsumerState<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends ConsumerState<EmployeeScreen> {
  // Desplazamiento de semana: 0 = Semana actual, 1 = Semana siguiente
  int _weekOffset = 0;
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _weekDays = [];
  Set<String> _excepcionesFechas = {};
  Map<String, String> _excepcionesMotivos = {};

  bool _isExcepcionDay = false;
  String? _motivoExcepcion;
  bool _isMenuDisponible = false;

  // Platos reales del día desde Supabase `vista_menu_con_platos`
  List<Dish> _dishesForSelectedDate = [];
  bool _isLoadingDishes = true;

  // Plato seleccionado por el comensal
  Dish? _selectedDish;

  // Filtro por tipo de plato (enum tipo: Sopa, Segundo, Vegetariano, soporta nulos)
  String _selectedTipoFilter = 'Todos';
  static const List<String> _tiposCategories = [
    'Todos',
    'Segundo',
    'Sopa',
    'Vegetariano',
  ];

  final TextEditingController _notesController = TextEditingController();

  // Modo de reserva:
  // true = "Reserva Conjunta (Empleado + Familiares)"
  // false = "Reserva Individual / Por Comensal"
  bool _isJointReservation = false;

  // Modo conjunto:
  bool _includeEmployee = true;
  final Set<String> _selectedFamiliarIds = {};

  // Modo individual (null = para el empleado, Familiar = para el familiar)
  Familiar? _individualFamiliar;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Si hoy es domingo (weekday == 7), comenzar por defecto en la semana siguiente (offset 1)
    if (now.weekday == DateTime.sunday) {
      _weekOffset = 1;
    }
    _initWeekAndLoad();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Inicializa la semana laboral (Lunes a Viernes) y carga los platos reales
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
    await _loadDishesForDate(_selectedDate);
  }

  /// Cambia entre la semana actual (0) y la siguiente (1)
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
      _selectedDish = null;
    });
    _loadWeekExceptions();
    _loadDishesForDate(_selectedDate);
  }

  /// Carga las excepciones de calendario para la semana (HU6)
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

  /// Carga los platos reales para una fecha específica desde `vista_menu_con_platos`
  Future<void> _loadDishesForDate(DateTime date) async {
    setState(() {
      _isLoadingDishes = true;
      _selectedDate = date;
      _selectedDish = null;
    });

    final dateStr = MenuService.formatDate(date);

    // 1. Verificar excepciones de calendario (HU6)
    if (_excepcionesFechas.contains(dateStr)) {
      final motivo =
          _excepcionesMotivos[dateStr] ?? 'Feriado / Suspensión de servicio';
      if (mounted) {
        setState(() {
          _isExcepcionDay = true;
          _motivoExcepcion = motivo;
          _isMenuDisponible = false;
          _dishesForSelectedDate = const [];
          _isLoadingDishes = false;
        });
      }
      return;
    }

    // 2. Consultar menú desde vista_menu_con_platos (HU5)
    final menuResult = await MenuService.getMenuPorFecha(date);
    if (menuResult.isExcepcion) {
      if (mounted) {
        setState(() {
          _isExcepcionDay = true;
          _motivoExcepcion = menuResult.motivoExcepcion ?? 'Día de no atención';
          _isMenuDisponible = false;
          _dishesForSelectedDate = const [];
          _isLoadingDishes = false;
        });
      }
      return;
    }

    final realDishes = menuResult.platos;

    if (mounted) {
      setState(() {
        _isExcepcionDay = false;
        _motivoExcepcion = null;
        _isMenuDisponible = menuResult.isDisponible || realDishes.isNotEmpty;
        _dishesForSelectedDate = realDishes;
        _isLoadingDishes = false;
        // Preseleccionar el primer plato disponible si existe
        if (realDishes.isNotEmpty) {
          _selectedDish = realDishes.first;
        }
      });
    }
  }

  /// Filtra los platos según el enum `tipo`: ['Todos', 'Segundo', 'Sopa', 'Vegetariano'].
  /// Soporta nulos: si `dish.tipo` es nulo, no se muestra bajo filtros específicos.
  List<Dish> get _filteredDishes {
    if (_selectedTipoFilter == 'Todos') {
      return _dishesForSelectedDate;
    }
    return _dishesForSelectedDate.where((d) {
      final tipo = d.tipo?.trim().toLowerCase();
      if (tipo == null || tipo.isEmpty) {
        return false; // Nulo no coincide con tipos específicos
      }
      return tipo == _selectedTipoFilter.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final familyAsync = ref.watch(employeeFamilyMembersProvider);
    final familyMembers = familyAsync.value ?? [];

    // HU8 / HU9: Tarifas independientes por comensal consultadas desde Supabase / tabla pension
    final pensionAsync = ref.watch(
      comensalesPensionStatusProvider(_selectedDate),
    );
    final pensionMap = pensionAsync.value ?? {};
    final isEmployeePensioned =
        pensionMap[null] ?? (currentUser?.isPensioner ?? false);
    final double employeeTariff = isEmployeePensioned ? 15.0 : 18.0;

    final Map<String, double> familiarTariffs = {
      for (final fam in familyMembers)
        fam.id: (pensionMap[fam.id] == true ? 15.0 : 18.0),
    };

    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final selectedNormalized = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final isPastDate = selectedNormalized.isBefore(todayNormalized);

    final allUserReservations = ref.watch(userReservationsProvider);
    final activeForSelectedDate = allUserReservations
        .where(
          (r) =>
              AppDateUtils.isSameDay(r.date, _selectedDate) &&
              r.status.toLowerCase() != 'cancelada',
        )
        .toList();

    final employeeActiveRes = activeForSelectedDate
        .where((r) => !r.isForFamiliar && r.familiarId == null)
        .firstOrNull;

    final Map<String, Reservation> familiarActiveRes = {
      for (final r in activeForSelectedDate.where((r) => r.familiarId != null))
        r.familiarId!: r,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservas de Comedor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            Text(
              'Platos reales del menú institucional',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar',
            onPressed: () async {
              await _loadWeekExceptions();
              await _loadDishesForDate(_selectedDate);
            },
          ),
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
            // Banner de Usuario y Modalidad Mensual (HU8: campos listos)
            _buildUserTariffBanner(
              currentUser,
              isEmployeePensioned,
              employeeTariff,
            ),

            const SizedBox(height: 12),

            // Navegador de Semanas: Deslizar entre Semana Actual y Siguiente
            _buildWeekNavigationHeader(),

            const SizedBox(height: 8),

            // Selector de Días de la Semana (Lunes a Viernes)
            _buildWeekDaysSelector(),

            // Visual: Alerta si es fecha pasada
            if (isPastDate)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      color: Colors.amber.shade800,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha pasada (${AppDateUtils.formatDate(_selectedDate)})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Esta fecha ya concluyó. No se permiten reservas para días anteriores.',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Visual: Alerta si el comensal actual ya tiene reserva registrada
            if (!isPastDate &&
                !_isJointReservation &&
                _individualFamiliar == null &&
                employeeActiveRes != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade300, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.blue.shade800,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ya tienes una reserva para esta fecha',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Plato: ${employeeActiveRes.dishName} · Estado: ${employeeActiveRes.status.toUpperCase()} (Límite: 1 reserva por comensal).',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (!isPastDate &&
                !_isJointReservation &&
                _individualFamiliar != null &&
                familiarActiveRes.containsKey(_individualFamiliar!.id))
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.shade300, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.family_restroom,
                      color: Colors.purple.shade800,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reserva existente para ${_individualFamiliar!.displayName}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade900,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Plato: ${familiarActiveRes[_individualFamiliar!.id]?.dishName} · Estado: ${familiarActiveRes[_individualFamiliar!.id]?.status.toUpperCase()} (Límite: 1 reserva por comensal).',
                            style: TextStyle(
                              color: Colors.purple.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // Sección de Platos Reales del Día
            _buildDishesSection(),

            const SizedBox(height: 14),

            // Configuración de Reserva: Comensales (HU7 y HU9)
            _buildBeneficiarySection(
              currentUser,
              familyMembers,
              employeeTariff,
              familiarTariffs,
              employeeActiveRes,
              familiarActiveRes,
            ),

            const SizedBox(height: 14),

            // Observaciones / Notas
            _buildNotesSection(),

            const SizedBox(height: 14),

            // Resumen de Costo en tiempo real
            _buildCostSummary(
              employeeTariff,
              familiarTariffs,
              familyMembers,
              employeeActiveRes,
              familiarActiveRes,
            ),

            const SizedBox(height: 16),

            // Botón Confirmar Reserva
            _buildConfirmButton(
              employeeTariff: employeeTariff,
              familiarTariffs: familiarTariffs,
              familyMembers: familyMembers,
              isPastDate: isPastDate,
              employeeActiveRes: employeeActiveRes,
              familiarActiveRes: familiarActiveRes,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Banner del usuario con modalidad de pensión (HU8)
  Widget _buildUserTariffBanner(
    dynamic currentUser,
    bool hasMonthlyPlan,
    double tariffPrice,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PensionScreen()),
        ).then((_) {
          ref.invalidate(comensalesPensionStatusProvider(_selectedDate));
        });
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
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
                  : Colors.blue.withValues(alpha: 0.15),
              child: Icon(
                hasMonthlyPlan
                    ? Icons.stars_rounded
                    : Icons.account_circle_outlined,
                color: hasMonthlyPlan ? Colors.green : const Color(0xFF2563EB),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, ${currentUser?.fullName ?? 'Empleado'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    hasMonthlyPlan
                        ? '⭐ Modalidad: Pensionado Activo · Toca para gestionar'
                        : 'Modalidad: Regular (Bs. 18/plato) · Toca para pensionar',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: hasMonthlyPlan
                          ? Colors.green.shade800
                          : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: hasMonthlyPlan
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.blue.withValues(alpha: 0.12),
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
                          : const Color(0xFF2563EB),
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
    );
  }

  /// Barra de navegación para deslizar o alternar entre la semana actual y la siguiente
  Widget _buildWeekNavigationHeader() {
    final rango = MenuService.getRangoSemana(
      referenceDate: DateTime.now(),
      weekOffset: _weekOffset,
    );
    final rangoTexto =
        '${rango.inicioSemana.day}/${rango.inicioSemana.month} - ${rango.finSemana.day}/${rango.finSemana.month}';

    return Container(
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
          Expanded(
            child: InkWell(
              onTap: () => _changeWeek(0),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _weekOffset == 0
                      ? const Color(0xFF2563EB)
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
          Expanded(
            child: InkWell(
              onTap: () => _changeWeek(1),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _weekOffset == 1
                      ? const Color(0xFF2563EB)
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

  /// Selector horizontal de días hábiles de la semana
  Widget _buildWeekDaysSelector() {
    final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final todayStr = MenuService.formatDate(now);
    final selectedStr = MenuService.formatDate(_selectedDate);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _weekDays.asMap().entries.map((entry) {
          final index = entry.key;
          final date = entry.value;
          final dateStr = MenuService.formatDate(date);
          final isSelected = dateStr == selectedStr;
          final isToday = dateStr == todayStr;
          final isExcepcion = _excepcionesFechas.contains(dateStr);
          final dayNormalized = DateTime(date.year, date.month, date.day);
          final isPast = dayNormalized.isBefore(todayNormalized);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () => _loadDishesForDate(date),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(minWidth: 110),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isPast
                            ? const Color(0xFF475569)
                            : const Color(0xFF2563EB))
                      : (isPast
                            ? Colors.grey.shade100
                            : Colors.white.withValues(alpha: 0.95)),
                  borderRadius: BorderRadius.circular(16),
                  border: isToday && !isSelected
                      ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
                      : (isPast && !isSelected
                            ? Border.all(color: Colors.grey.shade300)
                            : null),
                  boxShadow: isPast
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayNames[index % dayNames.length],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isPast
                                      ? Colors.grey.shade600
                                      : Colors.black87),
                          ),
                        ),
                        if (isExcepcion) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.block,
                            size: 12,
                            color: isSelected ? Colors.white : Colors.red,
                          ),
                        ] else if (isPast) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.history,
                            size: 12,
                            color: isSelected
                                ? Colors.white70
                                : Colors.grey.shade500,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white70
                            : (isPast ? Colors.grey.shade500 : Colors.grey),
                      ),
                    ),
                    if (isToday)
                      Text(
                        '• Hoy',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF2563EB),
                        ),
                      )
                    else if (isPast)
                      Text(
                        '• Pasado',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white70
                              : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Sección de Platos Reales del Día (eliminando datos estáticos y lógica de almuerzo completo)
  Widget _buildDishesSection() {
    return Container(
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
                        'Platos Disponibles del Menú',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 10),

          // Filtros por enum tipo: ['Todos', 'Segundo', 'Sopa', 'Vegetariano']
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tiposCategories.map((cat) {
                final isSelected = _selectedTipoFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: Colors.grey.shade100,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedTipoFilter = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Estado: Excepción, Menú no disponible, cargando o lista de platos
          if (_isLoadingDishes)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_isExcepcionDay)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Día no habilitado: ${_motivoExcepcion ?? "Feriado / Sin servicio"}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!_isMenuDisponible || _dishesForSelectedDate.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.restaurant_outlined, color: Colors.grey),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Menú en preparación para esta fecha. No hay platos cargados.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else if (_filteredDishes.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No se encontraron platos para este filtro.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            Column(
              children: _filteredDishes.map((dish) {
                final isSelected = _selectedDish?.id == dish.id;
                final hasTipo =
                    dish.tipo != null && dish.tipo!.trim().isNotEmpty;

                Color tipoColor = const Color(0xFF2563EB);
                if (dish.tipo?.toLowerCase() == 'sopa') {
                  tipoColor = Colors.amber.shade800;
                } else if (dish.tipo?.toLowerCase() == 'vegetariano') {
                  tipoColor = Colors.green.shade700;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedDish = dish);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Imagen del plato
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child:
                                  dish.imageUrl.startsWith('http') ||
                                      dish.imageUrl.startsWith('assets')
                                  ? Image.network(
                                      dish.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dish.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF2563EB),
                                        size: 20,
                                      ),
                                  ],
                                ),
                                if (dish.description.isNotEmpty)
                                  Text(
                                    dish.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    // Si el campo tipo es nulo, no se muestra nada
                                    if (hasTipo) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tipoColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          dish.tipo!,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: tipoColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      'Bs. ${dish.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
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
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Sección de Comensales y Beneficiario (HU7 y HU9)
  Widget _buildBeneficiarySection(
    dynamic currentUser,
    List<Familiar> familyMembers,
    double employeeTariff,
    Map<String, double> familiarTariffs,
    Reservation? employeeActiveRes,
    Map<String, Reservation> familiarActiveRes,
  ) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configurar Comensales (HU7 y HU9)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Alternar Modo: Individual vs Conjunta
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  avatar: const Icon(Icons.person, size: 16),
                  label: const Text('Reserva Individual'),
                  selected: !_isJointReservation,
                  selectedColor: const Color(
                    0xFF2563EB,
                  ).withValues(alpha: 0.15),
                  onSelected: (val) {
                    if (val) setState(() => _isJointReservation = false);
                  },
                ),
              ),
              const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 12),

          if (!_isJointReservation) ...[
            // MODO INDIVIDUAL: Empleado o Familiar
            const Text(
              'Seleccionar comensal para la reserva individual:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                    employeeActiveRes != null
                        ? 'Para mí (Ya reservado)'
                        : 'Para mí (Empleado: ${currentUser?.fullName ?? 'Usuario'}) · Bs. ${employeeTariff.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: employeeActiveRes != null ? Colors.blueGrey : null,
                    ),
                  ),
                ),
                ...familyMembers.map((f) {
                  final fPrice = familiarTariffs[f.id] ?? 18.0;
                  final famRes = familiarActiveRes[f.id];
                  return DropdownMenuItem<Familiar?>(
                    value: f,
                    child: Text(
                      famRes != null
                          ? 'Familiar: ${f.displayName} (Ya reservado)'
                          : 'Familiar: ${f.displayName} · Bs. ${fPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: famRes != null ? Colors.blueGrey : null,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (f) {
                setState(() => _individualFamiliar = f);
              },
            ),
          ] else ...[
            // MODO CONJUNTO: Empleado + Familiares seleccionados
            const Text(
              'Marcar comensales para esta fecha (Límite: 1 por comensal):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  employeeActiveRes != null
                      ? 'Empleado: ${currentUser?.fullName ?? 'Usuario'} (Ya reservado)'
                      : 'Empleado: ${currentUser?.fullName ?? 'Usuario'}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: employeeActiveRes != null
                        ? Colors.grey.shade600
                        : null,
                  ),
                ),
                subtitle: Text(
                  employeeActiveRes != null
                      ? 'Ya cuenta con una reserva activa (${employeeActiveRes.dishName})'
                      : 'Tarifa: Bs. ${employeeTariff.toStringAsFixed(2)} ${employeeTariff == 15.0 ? "(Pensionado)" : "(Regular)"}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: employeeActiveRes != null
                        ? Colors.blue.shade700
                        : Colors.grey,
                  ),
                ),
                value: employeeActiveRes != null ? false : _includeEmployee,
                activeColor: const Color(0xFF2563EB),
                onChanged: employeeActiveRes != null
                    ? null
                    : (val) {
                        setState(() => _includeEmployee = val ?? false);
                      },
              ),
            ),
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
                final famRes = familiarActiveRes[fam.id];
                final isChecked =
                    famRes == null && _selectedFamiliarIds.contains(fam.id);
                final fPrice = familiarTariffs[fam.id] ?? 18.0;
                return Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      famRes != null
                          ? 'Familiar: ${fam.displayName} (Ya reservado)'
                          : 'Familiar: ${fam.displayName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: famRes != null ? Colors.grey.shade600 : null,
                      ),
                    ),
                    subtitle: Text(
                      famRes != null
                          ? 'Ya cuenta con una reserva activa (${famRes.dishName})'
                          : 'Tarifa: Bs. ${fPrice.toStringAsFixed(2)} ${fPrice == 15.0 ? "(Pensionado)" : "(Regular)"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: famRes != null
                            ? Colors.purple.shade700
                            : Colors.grey,
                      ),
                    ),
                    value: isChecked,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: famRes != null
                        ? null
                        : (val) {
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
          ],
        ],
      ),
    );
  }

  /// Sección de Notas / Observaciones
  Widget _buildNotesSection() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notas u Observaciones (Opcional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Ej. Para llevar, sin locoto, ración extra...',
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
        ],
      ),
    );
  }

  /// Desglose y cálculo de costo en tiempo real con tarifas independientes
  Widget _buildCostSummary(
    double employeeTariff,
    Map<String, double> familiarTariffs,
    List<Familiar> familyMembers,
    Reservation? employeeActiveRes,
    Map<String, Reservation> familiarActiveRes,
  ) {
    double totalCost = 0.0;
    int count = 0;
    if (_isJointReservation) {
      if (_includeEmployee && employeeActiveRes == null) {
        totalCost += employeeTariff;
        count++;
      }
      for (final id in _selectedFamiliarIds) {
        if (!familiarActiveRes.containsKey(id)) {
          totalCost += (familiarTariffs[id] ?? 18.0);
          count++;
        }
      }
    } else {
      final isForFam = _individualFamiliar != null;
      final bool alreadyReserved = isForFam
          ? familiarActiveRes.containsKey(_individualFamiliar!.id)
          : (employeeActiveRes != null);
      if (!alreadyReserved) {
        count = 1;
        totalCost = isForFam
            ? (familiarTariffs[_individualFamiliar!.id] ?? 18.0)
            : employeeTariff;
      }
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de Reserva',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plato: ${_selectedDish?.name ?? "No seleccionado"}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!_isJointReservation)
                Text(
                  'Tarifa: Bs. ${totalCost.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Raciones: $count comensal(es)',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                'Total: Bs. ${totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Botón Confirmar Reserva con validaciones HU7, HU8, HU9 y restricción de fechas pasadas / duplicadas
  Widget _buildConfirmButton({
    required double employeeTariff,
    required Map<String, double> familiarTariffs,
    required List<Familiar> familyMembers,
    required bool isPastDate,
    required Reservation? employeeActiveRes,
    required Map<String, Reservation> familiarActiveRes,
  }) {
    bool alreadyReservedSelected = false;
    String disabledReason = '';

    final now = DateTime.now();
    final isToday = AppDateUtils.isSameDay(_selectedDate, now);
    final isAfterCutoff =
        isToday && (now.hour > 9 || (now.hour == 9 && now.minute > 0));

    if (isPastDate) {
      disabledReason = 'Fecha pasada (Reservas cerradas)';
    } else if (isAfterCutoff) {
      disabledReason = 'Fuera de horario';
    } else if (!_isJointReservation) {
      if (_individualFamiliar == null && employeeActiveRes != null) {
        alreadyReservedSelected = true;
        disabledReason = 'Ya tienes una reserva para hoy';
      } else if (_individualFamiliar != null &&
          familiarActiveRes.containsKey(_individualFamiliar!.id)) {
        alreadyReservedSelected = true;
        disabledReason = 'Ya reservado para ${_individualFamiliar!.nombres}';
      }
    } else {
      final bool empHas = _includeEmployee && employeeActiveRes != null;
      final bool allFamsHave =
          _selectedFamiliarIds.isNotEmpty &&
          _selectedFamiliarIds.every((id) => familiarActiveRes.containsKey(id));
      if (empHas && allFamsHave) {
        alreadyReservedSelected = true;
        disabledReason = 'Comensales ya cuentan con reserva';
      }
    }

    final bool isActionRestricted =
        isPastDate || isAfterCutoff || alreadyReservedSelected;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting
            ? null
            : () => _handleConfirmReservation(
                employeeTariff,
                familiarTariffs,
                familyMembers,
                isPastDate: isPastDate,
                employeeActiveRes: employeeActiveRes,
                familiarActiveRes: familiarActiveRes,
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActionRestricted
              ? Colors.grey.shade400
              : const Color(0xFF2563EB),
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
            : Icon(
                isPastDate
                    ? Icons.history_toggle_off
                    : (alreadyReservedSelected
                          ? Icons.check_circle
                          : Icons.check_circle_outline),
              ),
        label: Text(
          _isSubmitting
              ? 'Registrando reserva...'
              : (disabledReason.isNotEmpty
                    ? '($disabledReason)'
                    : 'Confirmar Reserva (${AppDateUtils.formatShortDate(_selectedDate)})'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Procesa la confirmación con todas las reglas de aceptación HU7, HU8, HU9
  Future<void> _handleConfirmReservation(
    double employeeTariff,
    Map<String, double> familiarTariffs,
    List<Familiar> familyMembers, {
    required bool isPastDate,
    required Reservation? employeeActiveRes,
    required Map<String, Reservation> familiarActiveRes,
  }) async {
    final now = DateTime.now();

    // 0. Bloqueo de fechas pasadas
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final selectedNormalized = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (selectedNormalized.isBefore(todayNormalized) || isPastDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede reservar para fechas pasadas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 1. HU7: "Dado que el empleado no selecciona ningún plato,
    //    Cuando presiona Confirmar, Entonces el sistema muestra 'Debe seleccionar un plato'."
    if (_selectedDish == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un plato'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. HU7 / HU9: "Dado que el empleado intenta reservar después de la hora límite,
    //    Cuando presiona Confirmar, Entonces el sistema muestra 'Fuera de horario'."
    if (AppDateUtils.isSameDay(_selectedDate, now) &&
        (now.hour > 9 || (now.hour == 9 && now.minute > 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fuera de horario'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. HU9: "Dado que el empleado no selecciona ningún familiar,
    //    Cuando presiona Confirmar, Entonces el sistema muestra 'Debe seleccionar un familiar'."
    if (!_isJointReservation &&
        _individualFamiliar == null &&
        familyMembers.isNotEmpty &&
        _isChoosingFamiliarMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un familiar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 4. Bloqueo de reservas duplicadas (máximo 1 por persona/familiar por día)
    if (!_isJointReservation) {
      if (_individualFamiliar == null && employeeActiveRes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya tienes una reserva registrada para este día.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_individualFamiliar != null &&
          familiarActiveRes.containsKey(_individualFamiliar!.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ya existe una reserva registrada para ${_individualFamiliar!.displayName} en este día.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      final validFams = _selectedFamiliarIds
          .where((id) => !familiarActiveRes.containsKey(id))
          .toList();
      final canIncludeEmp = _includeEmployee && employeeActiveRes == null;

      if (!canIncludeEmp && validFams.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Todos los comensales seleccionados ya cuentan con una reserva para este día.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_isJointReservation &&
        !_includeEmployee &&
        _selectedFamiliarIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor marca al menos un comensal para reservar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(authProvider);
    final userId = currentUser?.id ?? 'demo-user-123';
    final userName = currentUser?.fullName ?? 'Empleado';
    final notes = _notesController.text.trim();
    final dishName = _selectedDish!.name;

    try {
      if (_isJointReservation) {
        final Map<String, String> famNames = {
          for (final f in familyMembers) f.id: f.displayName,
        };

        // Filtrar familiares elegibles (sin reserva previa en este día)
        final eligibleFamiliarIds = _selectedFamiliarIds
            .where((id) => !familiarActiveRes.containsKey(id))
            .toList();
        final canIncludeEmployee =
            _includeEmployee && employeeActiveRes == null;

        double jointTotal = 0.0;
        if (canIncludeEmployee) jointTotal += employeeTariff;
        for (final id in eligibleFamiliarIds) {
          jointTotal += (familiarTariffs[id] ?? 18.0);
        }

        final createdCount = await ref
            .read(userReservationsProvider.notifier)
            .createJointReservations(
              date: _selectedDate,
              dishName: dishName,
              platoPrincipal: dishName,
              isAlmuerzoCompleto: false,
              menuCategory: ReservationMenuCategory.almuerzoCompleto,
              reserveForEmployee: canIncludeEmployee,
              selectedFamiliarIds: eligibleFamiliarIds,
              familiarNames: famNames,
              pricePerPerson: employeeTariff,
              individualPrices: {null: employeeTariff, ...familiarTariffs},
              notes: notes.isNotEmpty ? notes : null,
              userName: userName,
              userId: userId,
            );

        if (mounted) {
          _showReservationConfirmation(
            title: 'Reserva confirmada',
            detail:
                '$createdCount comensales · $dishName\nTotal: Bs. ${jointTotal.toStringAsFixed(2)}',
          );
          _notesController.clear();
        }
      } else {
        // Reserva individual
        final isForFam = _individualFamiliar != null;
        final beneficiary = isForFam
            ? _individualFamiliar!.displayName
            : userName;
        final singlePrice = isForFam
            ? (familiarTariffs[_individualFamiliar!.id] ?? 18.0)
            : employeeTariff;

        final success = await ref
            .read(userReservationsProvider.notifier)
            .createReservation(
              date: _selectedDate,
              dishId: _selectedDish!.id,
              dishName: dishName,
              platoPrincipal: dishName,
              isAlmuerzoCompleto: false,
              menuCategory: ReservationMenuCategory.almuerzoCompleto,
              familiarId: _individualFamiliar?.id,
              beneficiaryName: beneficiary,
              price: singlePrice,
              notes: notes.isNotEmpty ? notes : null,
              userName: userName,
              userId: userId,
            );

        if (mounted && success) {
          _showReservationConfirmation(
            title: 'Reserva confirmada',
            detail:
                '$beneficiary · $dishName\nTotal: Bs. ${singlePrice.toStringAsFixed(2)}',
          );
          _notesController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
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

  bool get _isChoosingFamiliarMode => false;

  void _showReservationConfirmation({
    required String title,
    required String detail,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
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
