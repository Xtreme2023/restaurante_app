import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/menu/data/dish_image_resolver.dart';
import 'package:restaurante_app/features/menu/domain/bolivian_dish_entity.dart';
import 'package:restaurante_app/features/menu/presentation/providers/weekly_menu_provider.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  List<Reservation> _orders = [];
  bool _isLoadingOrders = true;
  String _orderSearchQuery = '';

  // Día seleccionado en el planificador semanal de cocina (0=Lunes, ..., 4=Viernes)
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final repo = ref.read(reservationRepositoryProvider);
      final list = await repo.getAllReservationsForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _orders = list;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error al cargar pedidos en KitchenScreen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _markAsDelivered(Reservation order) async {
    final deliveryCheck = ReservationPolicy().checkCanDeliver(
      order.date,
      DateTime.now(),
    );
    if (!deliveryCheck.isAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deliveryCheck.message),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      return;
    }

    try {
      final repo = ref.read(reservationRepositoryProvider);
      // Los pedidos del plan mensual se construyen desde el padrón diario y
      // no tienen una fila individual en `reservas`.
      if (!order.id.startsWith('monthly-')) {
        await repo.markReservationAsPickedUp(order.id, true);
        await repo.updateReservationStatus(order.id, 'entregada');
      }
      if (mounted) {
        setState(() {
          final index = _orders.indexWhere((o) => o.id == order.id);
          if (index != -1) {
            _orders[index] = order.copyWith(
              status: 'entregada',
              recogido: true,
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Almuerzo entregado a ${order.displayName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error al marcar entrega: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar entrega: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _publishWeeklyMenu() async {
    final ok = await ref.read(weeklyMenuProvider.notifier).publishMenu();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check, color: Colors.white),
              SizedBox(width: 8),
              Text('¡Menú semanal publicado con éxito para los empleados!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              'Panel de Cocina',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            Text(
              'Métricas de producción y menú semanal boliviano',
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
            onPressed: () {
              _loadOrders();
              ref
                  .read(weeklyMenuProvider.notifier)
                  .loadWeek(ref.read(selectedWeekProvider));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_outlined),
              text: 'Resumen & Totales',
            ),
            Tab(icon: Icon(Icons.card_membership), text: 'Plan mensual'),
            Tab(icon: Icon(Icons.person), text: 'Empleados regulares'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Menú Semanal'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Calendario'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryAndOrdersTab(),
          _buildEmployeeReservationsTab(monthlyPlan: true),
          _buildEmployeeReservationsTab(monthlyPlan: false),
          _buildWeeklyMenuPlanningTab(),
          _buildReservationsCalendarTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: RESUMEN Y TOTALES (DASHBOARD)
  // ===========================================================================
  Widget _buildSummaryAndOrdersTab() {
    final filtered = _orders.where((o) {
      final q = _orderSearchQuery.toLowerCase();
      return o.displayName.toLowerCase().contains(q) ||
          o.dishName.toLowerCase().contains(q);
    }).toList();

    final totalOrders = _orders.where((o) => o.status != 'cancelada').length;
    final deliveredOrders = _orders
        .where((o) => o.status == 'entregada')
        .length;
    final pendingOrders = totalOrders - deliveredOrders;
    final totalCharge = _orders
        .where((o) => o.status != 'cancelada')
        .fold<double>(0, (sum, order) => sum + order.price);
    final ordersByEmployee = <String, int>{};
    for (final order in _orders.where((o) => o.status != 'cancelada')) {
      ordersByEmployee[order.userId] =
          (ordersByEmployee[order.userId] ?? 0) + 1;
    }

    // Métricas agrupadas por plato
    final Map<String, int> dishCounts = {};
    for (final o in _orders.where((o) => o.status != 'cancelada')) {
      dishCounts[o.dishName] = (dishCounts[o.dishName] ?? 0) + 1;
    }

    // Métricas por turno (Turno 1: 12:00, Turno 2: 13:00)
    int turno1 = 0;
    int turno2 = 0;
    for (int i = 0; i < _orders.length; i++) {
      if (i % 2 == 0) {
        turno1++;
      } else {
        turno2++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Selector de fecha y métricas principales
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppDateUtils.formatFullDate(_selectedDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.calendar_month,
                        color: Colors.blue,
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _loadOrders();
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildMetric(
                        'Total Pedidos',
                        '$totalOrders',
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildMetric(
                        'Pendientes',
                        '$pendingOrders',
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildMetric(
                        'Entregados',
                        '$deliveredOrders',
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMetric(
                        'Cobro total',
                        'Bs ${totalCharge.toStringAsFixed(2)}',
                        Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Total de almuerzos a registrar: $totalOrders',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Entregas habilitadas hoy de 12:00 a 14:00',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Dashboard de Totales por Plato y por Turno
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Desglose por Plato y Turno',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Turnos
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Turno 1 (12:00 PM)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$turno1 raciones',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Turno 2 (13:00 PM)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$turno2 raciones',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text(
                  'Producción requerida en cocina:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),

                if (dishCounts.isEmpty)
                  const Text(
                    'No hay reservas registradas para desglosar.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else
                  ...dishCounts.entries.map((entry) {
                    final percent = totalOrders > 0
                        ? (entry.value / totalOrders)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.value} raciones (${(percent * 100).toStringAsFixed(0)}%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percent,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Buscador de comensal
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _orderSearchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Buscar por comensal o plato...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Lista de pedidos a despachar
          if (_isLoadingOrders)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'No hay pedidos registrados para esta fecha.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final order = filtered[index];
                final isDelivered = order.status == 'entregada';
                final isCancelled = order.status == 'cancelada';
                final employeeOrderCount = ordersByEmployee[order.userId] ?? 1;
                final employeeCharge = _orders
                    .where(
                      (o) =>
                          o.userId == order.userId && o.status != 'cancelada',
                    )
                    .fold<double>(0, (sum, item) => sum + item.price);
                final deliveryCheck = ReservationPolicy().checkCanDeliver(
                  order.date,
                  DateTime.now(),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDelivered
                          ? Colors.green.shade300
                          : isCancelled
                          ? Colors.red.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isDelivered
                            ? Colors.green.shade100
                            : isCancelled
                            ? Colors.red.shade100
                            : Colors.blue.shade100,
                        child: Icon(
                          isDelivered
                              ? Icons.check
                              : isCancelled
                              ? Icons.close
                              : Icons.person,
                          color: isDelivered
                              ? Colors.green
                              : isCancelled
                              ? Colors.red
                              : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            Text(
                              order.dishName,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                              ),
                            ),
                            if (employeeOrderCount > 1)
                              Text(
                                'Reserva familiar: $employeeOrderCount almuerzos · '
                                'Cobro: Bs ${employeeCharge.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.indigo.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (order.notes != null)
                              Text(
                                'Nota: ${order.notes}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isDelivered && !isCancelled)
                        ElevatedButton(
                          onPressed: deliveryCheck.isAllowed
                              ? () => _markAsDelivered(order)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Entregar'),
                        )
                      else
                        Text(
                          isDelivered ? 'Entregado' : 'Cancelado',
                          style: TextStyle(
                            color: isDelivered ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReservationsCalendarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
            ),
            child: TableCalendar<void>(
              firstDay: DateTime(2025),
              lastDay: DateTime(2030),
              focusedDay: _selectedDate,
              selectedDayPredicate: (day) =>
                  AppDateUtils.isSameDay(day, _selectedDate),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() => _selectedDate = selectedDay);
                _loadOrders();
              },
              calendarFormat: CalendarFormat.month,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarBuilders: CalendarBuilders<void>(
                markerBuilder: (context, date, events) {
                  final hasReservation = _orders.any(
                    (order) =>
                        order.status != 'cancelada' &&
                        AppDateUtils.isSameDay(order.date, date),
                  );
                  return hasReservation
                      ? const Align(
                          alignment: Alignment.bottomCenter,
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: Colors.green,
                          ),
                        )
                      : null;
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Reservas del ${AppDateUtils.formatFullDate(_selectedDate)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay reservas para la fecha seleccionada.',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            ..._orders.map(
              (order) => Card(
                child: ListTile(
                  leading: const Icon(Icons.lunch_dining),
                  title: Text(order.displayName),
                  subtitle: Text('${order.dishName} · ${order.status}'),
                  trailing: Text('Bs ${order.price.toStringAsFixed(2)}'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmployeeReservationsTab({required bool monthlyPlan}) {
    final reservations = _orders
        .where(
          (order) =>
              order.status != 'cancelada' &&
              (order.type == 'pension') == monthlyPlan,
        )
        .toList();
    final grouped = <String, List<Reservation>>{};
    for (final reservation in reservations) {
      grouped.putIfAbsent(reservation.userId, () => []).add(reservation);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEmployeeTabHeader(
            monthlyPlan: monthlyPlan,
            employeeCount: grouped.length,
            lunchCount: reservations.length,
          ),
          const SizedBox(height: 12),
          if (grouped.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                monthlyPlan
                    ? 'No hay empleados con plan mensual para esta fecha.'
                    : 'No hay empleados regulares con reservas para esta fecha.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...grouped.values.map(_buildEmployeeReservationCard),
        ],
      ),
    );
  }

  Widget _buildEmployeeTabHeader({
    required bool monthlyPlan,
    required int employeeCount,
    required int lunchCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthlyPlan
                ? 'Empleados con plan mensual'
                : 'Empleados regulares sin plan mensual',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '$employeeCount empleados · $lunchCount almuerzos registrados',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            AppDateUtils.formatFullDate(_selectedDate),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeReservationCard(List<Reservation> reservations) {
    final employee = reservations.first;
    final selfReservations = reservations
        .where((reservation) => !reservation.isForFamiliar)
        .toList();
    final familyReservations = reservations
        .where((reservation) => reservation.isForFamiliar)
        .toList();
    final totalCharge = reservations.fold<double>(
      0,
      (sum, reservation) => sum + reservation.price,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.person, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  employee.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                'Bs ${totalCharge.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.deepPurple.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCountChip(
                'Empleado: ${selfReservations.length}',
                Colors.blue,
              ),
              _buildCountChip(
                'Familiares: ${familyReservations.length}',
                Colors.teal,
              ),
              _buildCountChip(
                'Total: ${reservations.length} almuerzos',
                Colors.deepPurple,
              ),
            ],
          ),
          const Divider(height: 22),
          ...reservations.map(
            (reservation) => _buildBeneficiaryRow(reservation),
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, MaterialColor color) {
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(
        color: color.shade800,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: color.shade50,
      side: BorderSide(color: color.shade100),
    );
  }

  Widget _buildBeneficiaryRow(Reservation reservation) {
    final isDelivered = reservation.isDelivered;
    final deliveryCheck = ReservationPolicy().checkCanDeliver(
      reservation.date,
      DateTime.now(),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            reservation.isForFamiliar ? Icons.family_restroom : Icons.person,
            size: 20,
            color: reservation.isForFamiliar ? Colors.teal : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reservation.isForFamiliar
                  ? '${reservation.displayName} (familiar)'
                  : '${reservation.displayName} (empleado)',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          if (isDelivered)
            const Text(
              'Entregado',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            TextButton(
              onPressed: deliveryCheck.isAllowed
                  ? () => _markAsDelivered(reservation)
                  : null,
              child: const Text('Entregar'),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: GESTIÓN DE MENÚ SEMANAL (SELECTOR ÁGIL DE PLATOS BOLIVIANOS)
  // ===========================================================================
  Widget _buildWeeklyMenuPlanningTab() {
    final weekStart = ref.watch(selectedWeekProvider);
    final weeklyState = ref.watch(weeklyMenuProvider);
    final catalogoAsync = ref.watch(platosCatalogoProvider);

    final weekdays = [
      {'name': 'Lunes', 'offset': 0},
      {'name': 'Martes', 'offset': 1},
      {'name': 'Miércoles', 'offset': 2},
      {'name': 'Jueves', 'offset': 3},
      {'name': 'Viernes', 'offset': 4},
    ];

    final currentTargetDate = weekStart.add(Duration(days: _selectedDayIndex));
    final assignedItemsToday = weeklyState.itemsForDay(currentTargetDate);

    final isPublished = assignedItemsToday.any((i) => i.isPublicado);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de Semana (Navegación)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: () =>
                      ref.read(selectedWeekProvider.notifier).previousWeek(),
                ),
                Column(
                  children: [
                    const Text(
                      'Semana Planificada',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${AppDateUtils.formatShortDate(weekStart)} al ${AppDateUtils.formatShortDate(weekStart.add(const Duration(days: 4)))}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: () =>
                      ref.read(selectedWeekProvider.notifier).nextWeek(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Pestañas de días (Lunes a Viernes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(weekdays.length, (index) {
                  final day = weekdays[index];
                  final date = weekStart.add(Duration(days: index));
                  final isSelected = _selectedDayIndex == index;
                  final itemsCount = weeklyState.itemsForDay(date).length;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedDayIndex = index),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              day['name'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              '${date.day}/${date.month}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isSelected
                                    ? Colors.white70
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$itemsCount platos',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Banner de Estado y Botón PUBLICAR MENÚ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final statusColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPublished ? Icons.check_circle : Icons.edit_note,
                          color: isPublished ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isPublished ? 'Menú Publicado' : 'Modo Borrador',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: isPublished
                                  ? Colors.green.shade800
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPublished
                          ? 'Este menú ya es visible y reservable por los empleados.'
                          : 'Selecciona los platos bolivianos con un clic y presiona Publicar.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                );

                final publishBtn = ElevatedButton.icon(
                  onPressed: _publishWeeklyMenu,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text(
                    'Publicar Menú',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      statusColumn,
                      const SizedBox(height: 12),
                      publishBtn,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: statusColumn),
                    const SizedBox(width: 12),
                    publishBtn,
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Título del catálogo
          Text(
            'Catálogo de Gastronomía Boliviana para ${weekdays[_selectedDayIndex]['name']}:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Marca o desmarca con un clic para configurar el menú de este día:',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),

          const SizedBox(height: 10),

          // Selector ágil con chips/tarjetas interactivas
          catalogoAsync.when(
            data: (catalogo) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.70,
                ),
                itemCount: catalogo.length,
                itemBuilder: (context, index) {
                  final dish = catalogo[index];
                  final isSelected = assignedItemsToday.any(
                    (item) => item.platoCatalogoId == dish.id,
                  );

                  return InkWell(
                    onTap: () {
                      final dayName =
                          weekdays[_selectedDayIndex]['name'] as String;
                      ref
                          .read(weeklyMenuProvider.notifier)
                          .toggleDish(
                            fecha: currentTargetDate,
                            diaSemana: dayName,
                            plato: dish,
                            agregar: !isSelected,
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            !isSelected
                                ? 'Agregado al $dayName: ${dish.nombre}'
                                : 'Quitado del $dayName: ${dish.nombre}',
                          ),
                          duration: const Duration(milliseconds: 900),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Tooltip(
                                message: isSelected
                                    ? 'Quitar del menú'
                                    : 'Agregar al menú',
                                child: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: isSelected
                                      ? Colors.red.shade600
                                      : const Color(0xFF2563EB),
                                  child: Icon(
                                    isSelected ? Icons.remove : Icons.add,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      dish.region,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: double.infinity,
                              height: 120,
                              child: _buildCatalogDishImage(dish),
                            ),
                          ),
                          Text(
                            dish.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF1E3A8A)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            dish.categoria,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            error: (err, stack) => Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Text('Error cargando catálogo: $err'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCatalogDishImage(PlatoCatalogo dish) {
    final imagePath = resolveDatabaseDishImage(
      dish.imagenUrl,
      dishName: dish.nombre,
      dishId: dish.id,
    );
    final placeholder = Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, size: 30, color: Colors.blueGrey.shade300),
    );

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildMetric(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
