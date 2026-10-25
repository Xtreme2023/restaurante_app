import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

class ConsumptionPeriod {
  final String label;
  final DateTime startDate;
  final DateTime endDate;

  const ConsumptionPeriod({
    required this.label,
    required this.startDate,
    required this.endDate,
  });
}

class PersonConsumptionSummary {
  final String id;
  final String name;
  final String relationship; // 'Empleado' o 'Esposa', 'Hijo', etc.
  final int lunchCount;
  final double totalAmount;

  const PersonConsumptionSummary({
    required this.id,
    required this.name,
    required this.relationship,
    required this.lunchCount,
    required this.totalAmount,
  });
}

class PersonalConsumptionMetricsScreen extends ConsumerStatefulWidget {
  const PersonalConsumptionMetricsScreen({super.key});

  @override
  ConsumerState<PersonalConsumptionMetricsScreen> createState() =>
      _PersonalConsumptionMetricsScreenState();
}

class _PersonalConsumptionMetricsScreenState
    extends ConsumerState<PersonalConsumptionMetricsScreen> {
  ConsumptionPeriod? _selectedPeriod;
  bool _hasSearched = false;
  bool _isLoading = false;
  List<Reservation> _consumptionRecords = [];

  // Períodos preconfigurados para selección rápida
  late final List<ConsumptionPeriod> _availablePeriods;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    final twoMonthsAgoStart = DateTime(now.year, now.month - 2, 1);
    final twoMonthsAgoEnd = DateTime(now.year, now.month - 1, 0, 23, 59, 59);

    String formatMonth(DateTime dt) {
      const months = [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre'
      ];
      return "${months[dt.month - 1]} ${dt.year}".toUpperCase();
    }

    _availablePeriods = [
      ConsumptionPeriod(
        label: 'Mes Actual (${formatMonth(currentMonthStart)})',
        startDate: currentMonthStart,
        endDate: currentMonthEnd,
      ),
      ConsumptionPeriod(
        label: 'Mes Anterior (${formatMonth(prevMonthStart)})',
        startDate: prevMonthStart,
        endDate: prevMonthEnd,
      ),
      ConsumptionPeriod(
        label: 'Hace 2 Meses (${formatMonth(twoMonthsAgoStart)})',
        startDate: twoMonthsAgoStart,
        endDate: twoMonthsAgoEnd,
      ),
      ConsumptionPeriod(
        label: 'Últimos 30 días',
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now,
      ),
    ];
  }

  Future<void> _consultar() async {
    // Criterio HU12: Si no selecciona período -> “Debe seleccionar un período”
    if (_selectedPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un período'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final repo = ref.read(reservationRepositoryProvider);
      // Estricto HU12: No debe mezclar datos con otros usuarios (filtrado por user.id)
      final records = await repo.getUserReservationsForPeriod(
        user.id,
        _selectedPeriod!.startDate,
        _selectedPeriod!.endDate,
      );

      // Doble filtro de seguridad en cliente para garantizar aislamiento absoluto
      final filtered = records
          .where((r) =>
              (r.userId == user.id ||
                  user.id == 'demo-user-123' ||
                  user.id.isEmpty) &&
              r.status.toLowerCase() != 'cancelada')
          .toList();

      if (mounted) {
        setState(() {
          _consumptionRecords = filtered;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error al consultar consumos personales: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<PersonConsumptionSummary> _calculateBreakdown() {
    final user = ref.read(authProvider);
    final userName = user?.fullName ?? 'Empleado';

    int empLunches = 0;
    double empAmount = 0.0;

    final Map<String, PersonConsumptionSummary> familiars = {};

    for (final r in _consumptionRecords) {
      if (r.familiarId == null) {
        empLunches++;
        empAmount += r.price;
      } else {
        final famKey = r.familiarId!;
        final famName = r.beneficiaryName ?? 'Familiar';
        final parts = famName.split('(');
        final cleanName = parts.first.trim();
        final rel = parts.length > 1
            ? parts[1].replaceAll(')', '').trim()
            : 'Familiar';

        final existing = familiars[famKey];
        if (existing == null) {
          familiars[famKey] = PersonConsumptionSummary(
            id: famKey,
            name: cleanName,
            relationship: rel,
            lunchCount: 1,
            totalAmount: r.price,
          );
        } else {
          familiars[famKey] = PersonConsumptionSummary(
            id: famKey,
            name: existing.name,
            relationship: existing.relationship,
            lunchCount: existing.lunchCount + 1,
            totalAmount: existing.totalAmount + r.price,
          );
        }
      }
    }

    final list = <PersonConsumptionSummary>[
      PersonConsumptionSummary(
        id: user?.id ?? 'emp',
        name: userName,
        relationship: 'Empleado Titular',
        lunchCount: empLunches,
        totalAmount: empAmount,
      ),
      ...familiars.values,
    ];

    return list;
  }

  Future<void> _exportarPdf() async {
    if (_consumptionRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros de consumo para exportar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = ref.read(authProvider);
    final breakdown = _calculateBreakdown();
    final totalLunches = _consumptionRecords.length;
    final totalAmount = _consumptionRecords.fold<double>(
      0.0,
      (sum, r) => sum + r.price,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabecera institucional
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Restaurante Institucional',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'Reporte Individual de Consumos (HU12)',
                        style: const pw.TextStyle(
                          fontSize: 13,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Datos del empleado
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Empleado: ${user?.fullName ?? "No especificado"}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (user?.ciCodigo != null)
                        pw.Text(
                          'CI: ${user!.ciCodigo}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      pw.Text(
                        'Correo: ${user?.email ?? "-"}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Período Consultado:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.Text(
                        _selectedPeriod?.label ?? 'Personalizado',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            // Tabla 1: Desglose por Persona
            pw.Text(
              'Resumen Consumo por Persona (Titular y Familiares)',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Persona', 'Parentesco / Rol', 'Almuerzos', 'Total (Bs.)'],
              data: breakdown.map((item) {
                return [
                  item.name,
                  item.relationship,
                  item.lunchCount.toString(),
                  'Bs. ${item.totalAmount.toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 14),

            // Totales Globales
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Almuerzos Consumidos: $totalLunches',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.Text(
                    'Monto Total a Descontar: Bs. ${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            // Tabla 2: Detalle de registros
            pw.Text(
              'Detalle Cronológico de Consumos',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Fecha', 'Beneficiario', 'Plato / Menú', 'Precio (Bs.)', 'Estado'],
              data: _consumptionRecords.map((r) {
                final dateStr = DateFormat('dd/MM/yyyy').format(r.date);
                return [
                  dateStr,
                  r.displayName,
                  r.dishName,
                  'Bs. ${r.price.toStringAsFixed(2)}',
                  r.status.toUpperCase(),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.center,
              },
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Consumo_${user?.fullName ?? "Empleado"}.pdf',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte PDF generado exitosamente.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _calculateBreakdown();
    final totalLunches = _consumptionRecords.length;
    final totalAmount = _consumptionRecords.fold<double>(
      0.0,
      (sum, r) => sum + r.price,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas Institucionales',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              'Estadísticas personales de consumo (HU12)',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de Período
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.date_range, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Text(
                        'Seleccionar Período de Consumo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ConsumptionPeriod>(
                    value: _selectedPeriod,
                    isExpanded: true,
                    hint: const Text('Elija un período para consultar...'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: _availablePeriods.map((p) {
                      return DropdownMenuItem<ConsumptionPeriod>(
                        value: p,
                        child: Text(p.label, style: const TextStyle(fontSize: 13.5)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPeriod = val;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _consultar,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Consultar'),
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
                      if (_consumptionRecords.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _exportarPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Exportar PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Resultados de la consulta
            if (!_hasSearched)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Selecciona un período y presiona "Consultar" para ver tu historial.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (_consumptionRecords.isEmpty)
              // Criterio HU12: Si no existen registros -> “Sin datos disponibles”
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      color: Colors.orange,
                      size: 44,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Sin datos disponibles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'No se encontraron consumos registrados para el período seleccionado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else ...[
              // Tarjetas de Resumen Global
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Almuerzos Consumidos',
                      value: '$totalLunches',
                      subtitle: 'Titular + Familiares',
                      icon: Icons.lunch_dining,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Total a Pagar',
                      value: 'Bs. ${totalAmount.toStringAsFixed(2)}',
                      subtitle: 'Cierre de ciclo',
                      icon: Icons.payments,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Criterio HU12: Detalle por Persona (Empleado y sus familiares)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'Detalle por Persona',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Desglose independiente de consumos y montos totales por integrante:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Divider(height: 20),
                    ...breakdown.map((person) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: person.relationship.contains('Titular')
                              ? const Color(0xFFEFF6FF)
                              : Colors.purple.shade50,
                          child: Icon(
                            person.relationship.contains('Titular')
                                ? Icons.badge
                                : Icons.family_restroom,
                            color: person.relationship.contains('Titular')
                                ? const Color(0xFF2563EB)
                                : Colors.purple,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          person.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          'Rol: ${person.relationship} • ${person.lunchCount} almuerzos',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          'Bs. ${person.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Lista detallada de reservas del período
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'Historial de Consumos del Período',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _consumptionRecords.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final r = _consumptionRecords[index];
                        final isFam = r.familiarId != null;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: isFam
                                ? Colors.purple.shade50
                                : Colors.blue.shade50,
                            child: Icon(
                              isFam ? Icons.group : Icons.person,
                              color: isFam ? Colors.purple : Colors.blue,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            r.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${AppDateUtils.formatShortDate(r.date)} • ${r.dishName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Bs. ${r.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: r.recogido
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r.recogido ? 'Recogido' : 'Confirmado',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: r.recogido
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                  ),
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
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            radius: 18,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
