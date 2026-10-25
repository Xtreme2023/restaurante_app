import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/core/utils/date_utils.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';
import 'package:restaurante_app/features/familiares/presentation/providers/family_providers.dart';
import 'package:restaurante_app/features/pension/data/supabase_pension_repository.dart';
import 'package:restaurante_app/features/pension/domain/pension_entity.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

class PensionScreen extends ConsumerStatefulWidget {
  const PensionScreen({super.key});

  @override
  ConsumerState<PensionScreen> createState() => _PensionScreenState();
}

class _PensionScreenState extends ConsumerState<PensionScreen> {
  final SupabasePensionRepository _pensionRepo = SupabasePensionRepository();

  bool _isManagingFamiliar = false;
  Familiar? _selectedFamiliar;

  MonthlyPensionSubscription? _currentMonthSub;
  MonthlyPensionSubscription? _nextMonthSub;
  bool _isLoading = true;

  // HU8: Modalidad seleccionada para el próximo mes ('Pensionado', 'Regular', o null si no se ha elegido)
  String? _selectedNextModalidad;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubscriptions();
    });
  }

  String _getEffectiveUserId() {
    final user = ref.read(authProvider);
    return user?.id ?? 'demo-user-123';
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    final userId = _getEffectiveUserId();
    final familiarId = _isManagingFamiliar ? _selectedFamiliar?.id : null;
    final now = DateTime.now();

    final curSub = await _pensionRepo.getSubscription(
      userId,
      now.year,
      now.month,
      familiarId: familiarId,
    );

    final nextMonthDate = DateTime(now.year, now.month + 1, 1);
    final nxtSub = await _pensionRepo.getSubscription(
      userId,
      nextMonthDate.year,
      nextMonthDate.month,
      familiarId: familiarId,
    );

    if (mounted) {
      setState(() {
        _currentMonthSub = curSub;
        _nextMonthSub = nxtSub;
        _selectedNextModalidad = nxtSub != null && nxtSub.isActive
            ? 'Pensionado'
            : (nxtSub != null && nxtSub.isRegular ? 'Regular' : null);
        _hasUnsavedChanges = false;
        _isLoading = false;
      });
    }
  }

  void _onComensalTypeChanged(bool forFamiliar, List<Familiar> familyList) {
    if (_isManagingFamiliar == forFamiliar) return;
    setState(() {
      _isManagingFamiliar = forFamiliar;
      if (forFamiliar && _selectedFamiliar == null && familyList.isNotEmpty) {
        _selectedFamiliar = familyList.first;
      }
    });
    _loadSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(currentTimeProvider);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final holidaysAsync = ref.watch(holidaysProvider);
    final holidays = holidaysAsync.value ?? Holiday.defaultHolidays;
    final familyAsync = ref.watch(employeeFamilyMembersProvider);
    final familyMembers = familyAsync.value ?? [];

    final nextMonthWorkDays = AppDateUtils.countBusinessDays(
      nextMonth.year,
      nextMonth.month,
      holidays: holidays.map((h) => h.date).toList(),
    );
    final nextMonthTotal = nextMonthWorkDays * 15.0;

    final beneficiaryTitle = _isManagingFamiliar
        ? (_selectedFamiliar != null
            ? _selectedFamiliar!.displayName
            : 'Familiar')
        : 'Empleado (Tú)';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _hasUnsavedChanges) {
          // HU9 Criterio de aceptación: "Dado que el empleado abandona la pantalla sin guardar,
          // Cuando cierra la ventana, Entonces el sistema muestra 'Cambios no guardados'."
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cambios no guardados'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Gestión de Pensión Mensual',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta Informativa de Beneficios
                    _buildHeroBanner(),

                    const SizedBox(height: 16),

                    // Selector de Comensal: Empleado vs Familiar (HU8 / HU9)
                    _buildComensalSelector(familyMembers),

                    const SizedBox(height: 18),

                    // Estado Mes Actual (HU8: Muestra mínimo de consumo para todo el mes y bloqueado si ya inició)
                    _buildCurrentMonthCard(
                      title:
                          'Mes Actual: ${AppDateUtils.getMonthName(now.month)} ${now.year}',
                      beneficiary: beneficiaryTitle,
                      subscription: _currentMonthSub,
                      workDays: _currentMonthSub?.totalDays ?? 22,
                      totalPrice: _currentMonthSub?.totalPrice ?? (22 * 15.0),
                    ),

                    const SizedBox(height: 16),

                    // Estado Próximo Mes (HU8 y HU9: Permite seleccionar modalidad y confirmar antes de iniciar)
                    _buildNextMonthCard(
                      title:
                          'Próximo Mes: ${AppDateUtils.getMonthName(nextMonth.month)} ${nextMonth.year}',
                      beneficiary: beneficiaryTitle,
                      subscription: _nextMonthSub,
                      workDays: nextMonthWorkDays,
                      totalPrice: nextMonthTotal,
                      nextYear: nextMonth.year,
                      nextMonthInt: nextMonth.month,
                      holidays: holidays,
                    ),

                    const SizedBox(height: 18),

                    // Explicación de Políticas Institucionales
                    _buildPolicySection(),
                  ],
                ),
              ),
      ),
    );
  }

  /// Banner superior informativo
  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
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
              Icon(Icons.stars, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modalidad Mensual (Pensión)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Asegura tus almuerzos de lunes a viernes con precio preferencial. Tarifas y suscripciones independientes por comensal.',
            style: TextStyle(color: Colors.white, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildBenefitBadge('Bs. 15 / día', 'Pensionado'),
              const SizedBox(width: 10),
              _buildBenefitBadge('Bs. 18 / día', 'Regular'),
              const SizedBox(width: 10),
              _buildBenefitBadge('Mín. 10 días', 'Por Mes'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitBadge(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  /// Selector de comensal: Permite alternar entre gestionar pensión propia o la de un familiar (HU9)
  Widget _buildComensalSelector(List<Familiar> familyMembers) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
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
            '¿A quién deseas gestionar la modalidad?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Para mí (Empleado)')),
                  selected: !_isManagingFamiliar,
                  onSelected: (val) {
                    if (val) _onComensalTypeChanged(false, familyMembers);
                  },
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: !_isManagingFamiliar ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Familiar (HU9)')),
                  selected: _isManagingFamiliar,
                  onSelected: (val) {
                    if (val) _onComensalTypeChanged(true, familyMembers);
                  },
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: _isManagingFamiliar ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_isManagingFamiliar) ...[
            const SizedBox(height: 12),
            if (familyMembers.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tienes familiares registrados aún. Puedes registrarlos en tu perfil o consultar con el administrador.',
                        style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<Familiar>(
                key: const ValueKey('familiar_pension_dropdown'),
                initialValue: _selectedFamiliar,
                decoration: InputDecoration(
                  labelText: 'Seleccionar familiar',
                  prefixIcon: const Icon(Icons.family_restroom, color: Color(0xFF2563EB)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                items: familyMembers.map((f) {
                  return DropdownMenuItem<Familiar>(
                    value: f,
                    child: Text(
                      f.displayName,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  );
                }).toList(),
                onChanged: (fam) {
                  setState(() {
                    _selectedFamiliar = fam;
                  });
                  _loadSubscriptions();
                },
              ),
          ],
        ],
      ),
    );
  }

  /// Tarjeta del Mes Actual (HU8: Muestra regla de 10 almuerzos mínimos y bloqueo si ya inició)
  Widget _buildCurrentMonthCard({
    required String title,
    required String beneficiary,
    required MonthlyPensionSubscription? subscription,
    required int workDays,
    required double totalPrice,
  }) {
    final hasActiveSub = subscription != null && subscription.isActive;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Comensal: $beneficiary',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasActiveSub
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasActiveSub ? 'Pensionado Activo' : 'Modalidad Regular',
                  style: TextStyle(
                    color: hasActiveSub
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tarifa por almuerzo:',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              Text(
                hasActiveSub ? 'Bs. 15.00 (Oferta pensión)' : 'Bs. 18.00 (Regular)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasActiveSub ? Colors.green.shade800 : const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Días laborales calculados:',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              Text(
                '$workDays días hábiles',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // HU8 Criterio de aceptación:
          // "Dado que el empleado se registró en modalidad mensual,
          //  Cuando inicia el mes, Entonces el sistema muestra el mínimo de consumo para todo el mes."
          if (hasActiveSub)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.restaurant_menu, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mínimo de consumo para todo el mes: 10 almuerzos',
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // HU8: Bloqueo de cambio de mes en curso
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mes en curso: Cambios bloqueados por política institucional (HU8 / HU9).',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta del Próximo Mes (HU8 y HU9: Selección de modalidad y confirmación antes del inicio)
  Widget _buildNextMonthCard({
    required String title,
    required String beneficiary,
    required MonthlyPensionSubscription? subscription,
    required int workDays,
    required double totalPrice,
    required int nextYear,
    required int nextMonthInt,
    required List<Holiday> holidays,
  }) {
    final hasActiveSub = subscription != null && subscription.isActive;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Comensal: $beneficiary',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasActiveSub
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasActiveSub ? 'Suscrito' : 'No suscrito',
                  style: TextStyle(
                    color: hasActiveSub
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Selector interactivo de Modalidad (HU8: 'Debe seleccionar modalidad')
          const Text(
            'Elige la modalidad deseada para el próximo mes:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Material(
            color: Colors.transparent,
            child: RadioListTile<String>(
              value: 'Pensionado',
              groupValue: _selectedNextModalidad,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Modalidad Pensionado (Bs. 15.00 / almuerzo)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              subtitle: const Text(
                'Mínimo de 10 almuerzos requeridos en el mes.',
                style: TextStyle(fontSize: 11.5),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedNextModalidad = val;
                  _hasUnsavedChanges = true;
                });
              },
            ),
          ),
          Material(
            color: Colors.transparent,
            child: RadioListTile<String>(
              value: 'Regular',
              groupValue: _selectedNextModalidad,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Modalidad Regular (Bs. 18.00 / almuerzo)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              subtitle: const Text(
                'Sin mínimo obligatorio, cobro individual por cada reserva.',
                style: TextStyle(fontSize: 11.5),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedNextModalidad = val;
                  _hasUnsavedChanges = true;
                });
              },
            ),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Días laborales calculados:',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              Text(
                '$workDays días hábiles',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monto mensual proyectado (si pensiona):',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              Text(
                'Bs. ${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Botón Confirmar Modalidad con validaciones HU8 y HU9
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _handleConfirmModalidad(
                year: nextYear,
                month: nextMonthInt,
                beneficiary: beneficiary,
                holidays: holidays,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                'Confirmar Modalidad para $beneficiary',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Procesa la confirmación con todas las reglas de aceptación de HU8 y HU9
  Future<void> _handleConfirmModalidad({
    required int year,
    required int month,
    required String beneficiary,
    required List<Holiday> holidays,
  }) async {
    // 1. HU9 Criterio de aceptación:
    // "Dado que el empleado no selecciona ningún familiar,
    //  Cuando presiona Confirmar, Entonces el sistema muestra 'Debe seleccionar un familiar'."
    if (_isManagingFamiliar && _selectedFamiliar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un familiar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. HU8 Criterio de aceptación:
    // "Dado que el empleado no selecciona modalidad,
    //  Cuando presiona Confirmar, Entonces el sistema muestra 'Debe seleccionar modalidad'."
    if (_selectedNextModalidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar modalidad'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isPensionado = _selectedNextModalidad == 'Pensionado';
    final targetName = _isManagingFamiliar
        ? _selectedFamiliar!.displayName
        : 'tu cuenta de empleado';

    // Diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPensionado ? 'Confirmar Pensión' : 'Confirmar Modalidad Regular'),
        content: Text(
          '¿Deseas registrar la modalidad $_selectedNextModalidad para $targetName durante todo el mes de ${AppDateUtils.getMonthName(month)} $year?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPensionado ? const Color(0xFF2563EB) : Colors.grey.shade800,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final userId = _getEffectiveUserId();
    final familiarId = _isManagingFamiliar ? _selectedFamiliar?.id : null;

    bool success = false;
    if (isPensionado) {
      success = await _pensionRepo.subscribeMonthly(
        userId: userId,
        familiarId: familiarId,
        year: year,
        month: month,
        holidays: holidays,
      );
    } else {
      success = await _pensionRepo.cancelMonthlySubscription(
        _nextMonthSub?.id ?? '',
        year,
        month,
        DateTime.now(),
        userId: userId,
        familiarId: familiarId,
      );
    }

    if (mounted) {
      if (success) {
        setState(() => _hasUnsavedChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Modalidad registrada: $_selectedNextModalidad para $targetName',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadSubscriptions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo registrar la modalidad (el mes ya inició).'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Sección de políticas y reglas institucionales
  Widget _buildPolicySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.policy_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Reglas y Políticas de Pensión (HU8 / HU9)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPolicyBullet(
            'Tarifas Independientes:',
            'Un usuario pensionado goza de la tarifa preferencial (Bs. 15), pero su familiar no pensionado mantendrá el precio regular (Bs. 18), y viceversa.',
          ),
          _buildPolicyBullet(
            'Mínimo de Almuerzos:',
            'Todo comensal en modalidad pensión debe consumir un mínimo de 10 almuerzos al mes, eligiendo qué días asistir.',
          ),
          _buildPolicyBullet(
            'Inicio de Mes:',
            'Una vez iniciado el mes, la modalidad queda bloqueada institucionalmente y no puede ser modificada hasta el período siguiente.',
          ),
          _buildPolicyBullet(
            'Días Incluidos:',
            'Cubre de lunes a viernes en días hábiles, excluyendo feriados y excepciones del calendario.',
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyBullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$title ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
