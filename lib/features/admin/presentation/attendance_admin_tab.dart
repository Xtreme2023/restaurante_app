import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/admin/domain/admin_employee_entity.dart';
import 'package:restaurante_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

class AttendanceAdminTab extends ConsumerStatefulWidget {
  const AttendanceAdminTab({super.key});

  @override
  ConsumerState<AttendanceAdminTab> createState() => _AttendanceAdminTabState();
}

class _AttendanceAdminTabState extends ConsumerState<AttendanceAdminTab> {
  DateTime _today = DateTime.now();
  List<Reservation> _todayReservations = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;
  String? _selectedEmployeeId;
  String _searchQuery = '';
  String _statusFilter = 'TODOS'; // 'TODOS', 'RECOGIDO', 'PENDIENTE', 'REGISTRADO'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _today = DateTime.now();
    try {
      final repo = ref.read(reservationRepositoryProvider);
      final reservations = await repo.getAllReservationsForDate(_today);
      final attendance = await repo.getAttendanceForDate(_today);

      if (mounted) {
        setState(() {
          _todayReservations = reservations;
          _attendanceRecords = attendance;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error al cargar datos de asistencia: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Reservation? _getTodayActiveReservation(String userId) {
    try {
      return _todayReservations.firstWhere(
        (r) =>
            r.userId == userId &&
            r.familiarId == null &&
            r.status.toLowerCase() != 'cancelada' &&
            AppDateUtils.isSameDay(r.date, _today),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _getAttendanceRecord(String userId) {
    try {
      return _attendanceRecords.firstWhere(
        (a) => a['id_usuario']?.toString() == userId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _registrarAsistencia({String? specificUserId}) async {
    final targetUserId = specificUserId ?? _selectedEmployeeId;

    // Criterio HU13: Si no selecciona empleado -> “Debe seleccionar un empleado”
    if (targetUserId == null || targetUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un empleado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Criterio HU13: Si el empleado no tiene reserva -> “No existe reserva activa”
    final reservation = _getTodayActiveReservation(targetUserId);
    if (reservation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No existe reserva activa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final repo = ref.read(reservationRepositoryProvider);
      final numericReservationId = int.tryParse(reservation.id);

      await repo.registerAttendance(
        userId: targetUserId,
        reservationId: numericReservationId,
        date: _today,
        asistio: true,
        observacion: reservation.recogido
            ? 'Plato retirado en cocina'
            : 'Asistencia registrada por Administrador',
      );

      await _loadData();

      if (mounted) {
        final employees = ref.read(adminEmployeesProvider).employees;
        final emp = employees.firstWhere(
          (e) => e.id == targetUserId,
          orElse: () => AdminEmployee(
            id: targetUserId,
            ci: '',
            nombres: reservation.userName,
            apellidos: '',
            email: '',
            creadoEn: DateTime.now(),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Asistencia registrada con éxito para ${emp.fullName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error registrando asistencia: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar asistencia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesState = ref.watch(adminEmployeesProvider);
    final allEmployees = employeesState.employees
        .where((e) => e.rol.toUpperCase().contains('EMPLEADO'))
        .toList();

    // Filtros de búsqueda y estado
    final filteredEmployees = allEmployees.where((emp) {
      final matchesSearch = emp.fullName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          emp.ci.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final res = _getTodayActiveReservation(emp.id);
      final attendance = _getAttendanceRecord(emp.id);

      switch (_statusFilter) {
        case 'RECOGIDO':
          return res != null && res.recogido;
        case 'PENDIENTE':
          return res != null && !res.recogido;
        case 'REGISTRADO':
          return attendance != null;
        default:
          return true;
      }
    }).toList();

    final activeReservationsCount = _todayReservations
        .where((r) => r.familiarId == null && r.status.toLowerCase() != 'cancelada')
        .length;
    final recogidosCount = _todayReservations
        .where((r) =>
            r.familiarId == null &&
            r.status.toLowerCase() != 'cancelada' &&
            r.recogido)
        .length;
    final attendanceCount = _attendanceRecords.length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de Asistencia del Día
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Control de Asistencia Diaria (HU13)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            AppDateUtils.formatFullDate(_today),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
                        onPressed: _loadData,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        label: 'Reservas Hoy',
                        value: '$activeReservationsCount',
                        color: Colors.blue,
                        icon: Icons.calendar_today,
                      ),
                      _buildMetricItem(
                        label: 'Plato Recogido',
                        value: '$recogidosCount',
                        color: Colors.orange.shade800,
                        icon: Icons.soup_kitchen,
                      ),
                      _buildMetricItem(
                        label: 'Asistencias',
                        value: '$attendanceCount',
                        color: Colors.green,
                        icon: Icons.how_to_reg,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Barra de Selección de Empleado y Acción Global (Cumplimiento HU13)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registro Rápido de Asistencia',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecciona un empleado de la lista o desde el selector para marcar asistencia en la tabla institucional:',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedEmployeeId,
                    isExpanded: true,
                    hint: const Text('Seleccionar empleado institucional...'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    items: allEmployees.map((emp) {
                      final hasRes = _getTodayActiveReservation(emp.id) != null;
                      return DropdownMenuItem<String>(
                        value: emp.id,
                        child: Text(
                          '${emp.fullName} ${hasRes ? "• (Con Reserva)" : "• (Sin Reserva)"}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                hasRes ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedEmployeeId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _registrarAsistencia(),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Registrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Buscador y Filtros
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Buscar empleado por nombre o CI...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Chips de filtrado
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('TODOS', 'Todos los empleados'),
                  const SizedBox(width: 8),
                  _buildFilterChip('RECOGIDO', 'Recogió su plato'),
                  const SizedBox(width: 8),
                  _buildFilterChip('PENDIENTE', 'Pendiente de retiro'),
                  const SizedBox(width: 8),
                  _buildFilterChip('REGISTRADO', 'Asistieron'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Lista de Empleados con Estado de Plato y Asistencia
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30.0),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (filteredEmployees.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'No se encontraron empleados con los filtros aplicados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredEmployees.length,
                itemBuilder: (context, index) {
                  final emp = filteredEmployees[index];
                  final res = _getTodayActiveReservation(emp.id);
                  final att = _getAttendanceRecord(emp.id);
                  final hasReservation = res != null;
                  final dishPickedUp = hasReservation && res.recogido;
                  final attendanceMarked = att != null;

                  final isSelected = _selectedEmployeeId == emp.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEFF6FF)
                          : Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: hasReservation
                                  ? (dishPickedUp
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100)
                                  : Colors.grey.shade200,
                              child: Icon(
                                hasReservation
                                    ? (dishPickedUp
                                        ? Icons.check
                                        : Icons.restaurant)
                                    : Icons.person_off_outlined,
                                color: hasReservation
                                    ? (dishPickedUp
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800)
                                    : Colors.grey,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emp.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'CI: ${emp.ci.isNotEmpty ? emp.ci : "S/N"} • ${emp.email}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botón directo para seleccionar o registrar
                            if (attendanceMarked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.how_to_reg,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Asistió',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: () {
                                  setState(() => _selectedEmployeeId = emp.id);
                                  _registrarAsistencia(specificUserId: emp.id);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasReservation
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey.shade400,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Registrar',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Estado de reserva y del plato recogido (HU13)
                        Row(
                          children: [
                            if (!hasReservation)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Sin reserva activa para hoy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  res.dishName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Badge de plato recogido
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: dishPickedUp
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: dishPickedUp
                                        ? Colors.green.shade300
                                        : Colors.orange.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      dishPickedUp
                                          ? Icons.check_circle
                                          : Icons.access_time,
                                      size: 13,
                                      color: dishPickedUp
                                          ? Colors.green.shade800
                                          : Colors.orange.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dishPickedUp
                                          ? 'Recogió su plato'
                                          : 'Pendiente de retiro',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: dishPickedUp
                                            ? Colors.green.shade800
                                            : Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      onSelected: (_) => setState(() => _statusFilter = key),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          radius: 18,
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
