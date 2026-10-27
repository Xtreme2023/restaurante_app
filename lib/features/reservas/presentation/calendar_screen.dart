import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/familiares/presentation/providers/family_providers.dart';
import 'package:restaurante_app/features/menu/data/supabase_menu_repository.dart';
import 'package:restaurante_app/features/menu/domain/daily_menu_entity.dart';
import 'package:restaurante_app/features/menu/domain/daily_menu_policy.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  final TextEditingController _notesController = TextEditingController();

  DailyMenu? _dailyMenu;
  String _selectedMenuType =
      'Almuerzo del día'; // 'Almuerzo del día', 'Vegetariano', 'Especial'
  Familiar? _selectedFamiliar; // null = para el empleado
  bool _isLoadingMenu = true;

  @override
  void initState() {
    super.initState();
    _loadMenuStructure(DateTime.now());
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuStructure(DateTime date) async {
    setState(() => _isLoadingMenu = true);
    final menu = await SupabaseMenuRepository().getDailyMenuStructure(date);
    if (mounted) {
      setState(() {
        _dailyMenu = menu;
        _isLoadingMenu = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final policy = ref.watch(reservationPolicyProvider);
    final holidaysAsync = ref.watch(holidaysProvider);
    final holidays = holidaysAsync.value ?? Holiday.defaultHolidays;
    final userReservations = ref.watch(userReservationsProvider);
    final currentUser = ref.watch(authProvider);

    final familyAsync = ref.watch(employeeFamilyMembersProvider);
    final familyMembers = familyAsync.value ?? [];

    final isThursday = DailyMenuPolicy.isDessertDay(selectedDate);

    // Ver si el usuario ya tiene reserva en la fecha seleccionada
    final existingReservation = userReservations
        .cast<Reservation?>()
        .firstWhere(
          (r) =>
              r != null &&
              AppDateUtils.isSameDay(r.date, selectedDate) &&
              r.isConfirmed,
          orElse: () => null,
        );

    final isHoliday = holidays.any(
      (h) => AppDateUtils.isSameDay(h.date, selectedDate),
    );
    final holidayObj = isHoliday
        ? holidays.firstWhere(
            (h) => AppDateUtils.isSameDay(h.date, selectedDate),
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservar Almuerzo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            Text(
              'Servicio para empleado o familiares registrados',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Contenedor blanco translúcido para el calendario
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 30)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                currentDay: DateTime.now(),
                selectedDayPredicate: (day) =>
                    AppDateUtils.isSameDay(selectedDate, day),
                onDaySelected: (newSelectedDay, newFocusedDay) {
                  setState(() {
                    _focusedDay = newFocusedDay;
                  });
                  ref.read(selectedDateProvider.notifier).state =
                      newSelectedDay;
                  _loadMenuStructure(newSelectedDay);
                },
                calendarFormat: CalendarFormat.month,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(color: Colors.redAccent),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final hasRes = userReservations.any(
                      (r) =>
                          AppDateUtils.isSameDay(r.date, date) && r.isConfirmed,
                    );
                    final isHol = holidays.any(
                      (h) => AppDateUtils.isSameDay(h.date, date),
                    );

                    if (hasRes || isHol) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasRes)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                            ),
                          if (isHol)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber,
                              ),
                            ),
                        ],
                      );
                    }
                    return null;
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Leyenda rápida
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(Colors.green, 'Tienes Reserva'),
                  const SizedBox(width: 16),
                  _buildLegendItem(Colors.amber, 'Feriado'),
                  const SizedBox(width: 16),
                  _buildLegendItem(
                    Theme.of(context).colorScheme.primary,
                    'Seleccionado',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tarjeta de estado de política para la fecha seleccionada
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isHoliday
                      ? Colors.amber.shade400
                      : policy.canReserve
                      ? Colors.green.shade300
                      : Colors.red.shade200,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isHoliday
                            ? Icons.celebration
                            : policy.canReserve
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: isHoliday
                            ? Colors.amber.shade800
                            : policy.canReserve
                            ? Colors.green
                            : Colors.red,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppDateUtils.formatFullDate(selectedDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (existingReservation != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bookmark_added,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ya reservaste: "${existingReservation.dishName}" (${existingReservation.displayName})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    isHoliday
                        ? 'Feriado: ${holidayObj?.name ?? 'Feriado Oficial'}. Restaurante no atiende.'
                        : policy.canReserve
                        ? 'Día habilitado para reserva de almuerzo institucional.'
                        : policy.reserveReason,
                    style: TextStyle(
                      fontSize: 13,
                      color: isHoliday
                          ? Colors.amber.shade900
                          : policy.canReserve
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Opciones de reserva si está habilitado y no tiene reserva previa
            if (policy.canReserve && existingReservation == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de Beneficiario (Empleado o hasta 3 familiares)
                    const Text(
                      '¿Para quién es la reserva?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Familiar?>(
                      initialValue: _selectedFamiliar,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        prefixIcon: const Icon(Icons.people_outline),
                      ),
                      items: [
                        DropdownMenuItem<Familiar?>(
                          value: null,
                          child: Text(
                            'Para mí (Empleado: ${currentUser?.fullName ?? 'Usuario'})',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...familyMembers.map((fam) {
                          return DropdownMenuItem<Familiar?>(
                            value: fam,
                            child: Text(
                              'Familiar: ${fam.displayName}',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          );
                        }),
                      ],
                      onChanged: (fam) {
                        setState(() => _selectedFamiliar = fam);
                      },
                    ),

                    const SizedBox(height: 14),

                    // Selector de tipo de plato
                    const Text(
                      'Opción de Plato:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_isLoadingMenu)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMenuType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.restaurant),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Almuerzo del día',
                            child: Text(
                              '🍽️ Almuerzo del día (${_dailyMenu != null ? _dailyMenu!.almuerzoCompleto.summary : "Ensalada + Sopa del día + Segundo"})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Vegetariano',
                            child: Text(
                              '🥗 Plato Vegetariano: ${_dailyMenu?.platoVegetariano.name ?? "Opción Vegetariana"}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Especial',
                            child: Text(
                              '⭐ Plato Especial: ${_dailyMenu?.platoEspecial.name ?? "Opción Especial"}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMenuType = val);
                          }
                        },
                      ),

                    const SizedBox(height: 10),

                    // Nota de postre
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isThursday
                            ? Colors.purple.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isThursday
                              ? Colors.purple.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isThursday ? Icons.cake : Icons.info_outline,
                            color: isThursday
                                ? Colors.purple
                                : Colors.grey.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isThursday
                                  ? '🍰 ¡Hoy Jueves incluye postre!: ${_dailyMenu?.postre?.name ?? "Postre tradicional"}'
                                  : 'Nota: El postre se sirve exclusivamente los días Jueves.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isThursday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isThursday
                                    ? Colors.purple.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText:
                            'Observaciones (ej. Sin locoto, para llevar, etc.)',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Botón de acción principal
            if (existingReservation != null)
              // Botón de Cancelación respetando política de las 8:59 AM
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: policy.canCancel
                      ? () =>
                            _handleCancellation(context, existingReservation.id)
                      : () => _showPolicyError(context, policy.cancelReason),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: policy.canCancel ? Colors.red : Colors.grey,
                      width: 1.5,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: policy.canCancel ? Colors.red : Colors.grey,
                  ),
                  label: Text(
                    'Cancelar esta Reserva',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: policy.canCancel ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
              )
            else
              // Botón de Reserva respetando política de las 9:00 AM
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: policy.canReserve
                      ? () => _handleReservation(context, selectedDate)
                      : () => _showPolicyError(
                          context,
                          isHoliday
                              ? 'No se puede reservar en días feriados'
                              : policy.reserveReason,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: policy.canReserve
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    policy.canReserve
                        ? 'Confirmar Reserva (${selectedDate.day}/${selectedDate.month})'
                        : 'Reserva no disponible',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _handleReservation(
    BuildContext context,
    DateTime selectedDate,
  ) async {
    final user = ref.read(authProvider);
    final userId = user?.id ?? 'demo-user-123';
    final userDisplayName = user?.fullName ?? 'Empleado';

    String dishDescription;
    if (_selectedMenuType == 'Vegetariano') {
      dishDescription =
          'Vegetariano: ${_dailyMenu?.platoVegetariano.name ?? "Opción Vegetariana"}';
    } else if (_selectedMenuType == 'Especial') {
      dishDescription =
          'Especial: ${_dailyMenu?.platoEspecial.name ?? "Opción Especial"}';
    } else {
      dishDescription = 'Almuerzo del día (Ensalada + Sopa del día + Segundo)';
    }

    if (DailyMenuPolicy.isDessertDay(selectedDate) &&
        _dailyMenu?.postre != null) {
      dishDescription += ' + Postre: ${_dailyMenu!.postre!.name}';
    }

    final beneficiary = _selectedFamiliar != null
        ? _selectedFamiliar!.displayName
        : userDisplayName;

    final notes = _notesController.text.trim();

    final success = await ref
        .read(userReservationsProvider.notifier)
        .createReservation(
          date: selectedDate,
          userId: userId,
          userName: userDisplayName,
          familiarId: _selectedFamiliar?.id,
          beneficiaryName: beneficiary,
          dishId: _selectedMenuType,
          dishName: dishDescription,
          notes: notes.isNotEmpty ? notes : null,
        );

    if (!context.mounted) return;

    if (success) {
      _notesController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Reserva confirmada para $beneficiary el ${AppDateUtils.formatShortDate(selectedDate)}!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = ref.read(userReservationsProvider.notifier).lastError;
      _showPolicyError(
        context,
        'No se pudo registrar la reserva${error != null ? ': $error' : '.'}',
      );
    }
  }

  Future<void> _handleCancellation(
    BuildContext context,
    String reservationId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cancelación'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar tu reserva para este día?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final result = await ref
        .read(userReservationsProvider.notifier)
        .cancelReservation(reservationId);

    if (!context.mounted) return;

    if (!result.isAllowed) {
      _showPolicyError(context, result.message);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu reserva ha sido cancelada exitosamente.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPolicyError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
