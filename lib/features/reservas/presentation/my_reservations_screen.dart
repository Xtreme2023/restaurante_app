import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

class MyReservationsScreen extends ConsumerStatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  ConsumerState<MyReservationsScreen> createState() =>
      _MyReservationsScreenState();
}

class _MyReservationsScreenState extends ConsumerState<MyReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reservations = ref.watch(userReservationsProvider);
    final policyUseCase = ref.watch(reservationPolicyUseCaseProvider);
    final currentTime = ref.watch(currentTimeProvider);

    final today = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );

    final upcoming = reservations.where((r) {
      final rDate = DateTime(r.date.year, r.date.month, r.date.day);
      return !rDate.isBefore(today);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    final past = reservations.where((r) {
      final rDate = DateTime(r.date.year, r.date.month, r.date.day);
      return rDate.isBefore(today);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mis Reservas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            Text(
              'Control de almuerzos y tickets de retiro',
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
              ref.read(userReservationsProvider.notifier).loadReservations();
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
            Tab(text: 'Próximas'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReservationList(
            upcoming,
            policyUseCase,
            currentTime,
            isUpcoming: true,
          ),
          _buildReservationList(
            past,
            policyUseCase,
            currentTime,
            isUpcoming: false,
          ),
        ],
      ),
    );
  }

  Widget _buildReservationList(
    List<Reservation> list,
    ReservationPolicy policyUseCase,
    DateTime currentTime, {
    required bool isUpcoming,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUpcoming ? Icons.calendar_month : Icons.history,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                isUpcoming
                    ? 'No tienes reservas próximas activas.'
                    : 'Aún no hay reservas en tu historial.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final res = list[index];
        final canCancelCheck = policyUseCase.checkCanCancel(
          res.date,
          currentTime,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppDateUtils.formatFullDate(res.date),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(res.status),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            res.dishName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (res.notes != null && res.notes!.isNotEmpty)
                            Text(
                              'Nota: ${res.notes}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          if (res.isForFamiliar)
                            Container(
                              margin: const EdgeInsets.only(top: 4, bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.family_restroom,
                                    size: 14,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Para: ${res.displayName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            'Modalidad: ${res.type == 'pension' ? 'Pensión Mensual' : 'Reserva Diaria'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Botones de acción
                Row(
                  children: [
                    // Ver Ticket digital
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showTicketModal(context, res),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Ver Ticket'),
                      ),
                    ),
                    if (isUpcoming && res.isConfirmed) ...[
                      const SizedBox(width: 8),
                      // Cancelar reserva
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canCancelCheck.isAllowed
                              ? () => _cancelReservation(res.id)
                              : () => _showCancelPolicyAlert(
                                  context,
                                  canCancelCheck.message,
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canCancelCheck.isAllowed
                                ? Colors.red.shade600
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancelar'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'confirmada':
        bg = Colors.green.withValues(alpha: 0.15);
        text = Colors.green.shade800;
        label = 'Confirmada';
        break;
      case 'entregada':
        bg = Colors.blue.withValues(alpha: 0.15);
        text = Colors.blue.shade800;
        label = 'Consumida';
        break;
      case 'cancelada':
        bg = Colors.red.withValues(alpha: 0.15);
        text = Colors.red.shade800;
        label = 'Cancelada';
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.2);
        text = Colors.grey.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showCancelPolicyAlert(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.red),
            SizedBox(width: 8),
            Text('Cancelación Bloqueada'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(String reservationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar reserva?'),
        content: const Text(
          'Esta acción liberará tu cupo para el almuerzo. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await ref
        .read(userReservationsProvider.notifier)
        .cancelReservation(reservationId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva cancelada con éxito.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo cancelar. Solo es posible cancelar antes de las 9:00 AM del día de la reserva.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTicketModal(BuildContext context, Reservation res) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ticket de Retiro',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Text(
              'Presenta este comprobante en el mostrador del restaurante',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: 'reserva:${res.id}',
                    size: 140,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final cleanCode = res.id.toUpperCase().replaceAll('-', '');
                      final displayCode = cleanCode.length >= 8
                          ? cleanCode.substring(0, 8)
                          : cleanCode.padLeft(8, '0');
                      return Text(
                        'CÓDIGO: #$displayCode',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              dense: true,
              leading: Icon(
                res.isForFamiliar ? Icons.family_restroom : Icons.person,
                color: res.isForFamiliar ? Colors.purple : null,
              ),
              title: Text(res.isForFamiliar ? 'Beneficiario (Familiar)' : 'Comensal'),
              subtitle: Text(res.displayName),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha'),
              subtitle: Text(AppDateUtils.formatFullDate(res.date)),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.lunch_dining),
              title: const Text('Plato Seleccionado'),
              subtitle: Text(res.dishName),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar Ticket'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
