import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';

class EncargadoScreen extends ConsumerStatefulWidget {
  const EncargadoScreen({super.key});

  @override
  ConsumerState<EncargadoScreen> createState() => _EncargadoScreenState();
}

class _EncargadoScreenState extends ConsumerState<EncargadoScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Reservation> _orders = [];
  bool _isLoading = true;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(reservationRepositoryProvider);
      final list = await repo.getAllReservationsForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _orders = list;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error al cargar pedidos en EncargadoScreen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      await repo.markReservationAsPickedUp(order.id, true);
      await repo.updateReservationStatus(order.id, 'entregada');
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
            content: Text('Almuerzo entregado a ${order.userName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error al marcar entrega en EncargadoScreen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo marcar la entrega: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _orders.where((o) {
      return o.userName.toLowerCase().contains(_filterQuery.toLowerCase()) ||
          o.dishName.toLowerCase().contains(_filterQuery.toLowerCase());
    }).toList();

    final totalOrders = _orders.where((o) => o.status != 'cancelada').length;
    final deliveredOrders = _orders
        .where((o) => o.status == 'entregada')
        .length;
    final pendingOrders = totalOrders - deliveredOrders;

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
              'Control de comensales y despacho de almuerzos',
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
            onPressed: _loadOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Resumen de producción del día
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
                      Text(
                        AppDateUtils.formatFullDate(_selectedDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
                      _buildMetric(
                        'Total Pedidos',
                        '$totalOrders',
                        Colors.blue,
                      ),
                      _buildMetric(
                        'Pendientes',
                        '$pendingOrders',
                        Colors.orange,
                      ),
                      _buildMetric(
                        'Entregados',
                        '$deliveredOrders',
                        Colors.green,
                      ),
                    ],
                  ),
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
                onChanged: (val) => setState(() => _filterQuery = val),
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
            if (_isLoading)
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
                  'No hay almuerzos registrados para esta fecha.',
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
                                order.userName,
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
                                horizontal: 12,
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
      ),
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
