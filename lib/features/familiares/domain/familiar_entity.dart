class Familiar {
  final String id;
  final String empleadoId;
  final String ci;
  final String telefono;
  final String nombres;
  final String apellidos;
  final String
  parentesco; // 'Hijo', 'Hija', 'Cónyuge', 'Padre', 'Madre', 'Hermano/a', etc.
  final bool activo;
  final DateTime? creadoEn;
  final bool hasMonthlyPlan; // Membresía Plan Mensual (Tarifa Bs. 15 vs Bs. 18)

  const Familiar({
    required this.id,
    required this.empleadoId,
    this.ci = '',
    this.telefono = '',
    required this.nombres,
    required this.apellidos,
    required this.parentesco,
    this.activo = true,
    this.creadoEn,
    this.hasMonthlyPlan = false,
  });

  String get fullName => '$nombres $apellidos'.trim();

  String get displayName => '$fullName ($parentesco)';

  double get tariffPrice => hasMonthlyPlan ? 15.0 : 18.0;

  String get tariffLabel => hasMonthlyPlan
      ? 'Plan Mensual (Bs. 15)'
      : 'Modalidad Diaria (Bs. 18)';

  factory Familiar.fromJson(Map<String, dynamic> json) {
    return Familiar(
      id: json['id']?.toString() ?? json['id_familiar']?.toString() ?? '',
      empleadoId:
          json['empleado_id']?.toString() ??
          json['id_usuario']?.toString() ??
          '',
      ci: json['ci']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      nombres: json['nombres']?.toString() ?? json['nombre']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      parentesco: json['parentesco']?.toString() ?? 'Familiar',
      activo: json['activo'] == true || json['activo'] == 1,
      creadoEn: json['creado_en'] != null
          ? DateTime.tryParse(json['creado_en'].toString())
          : null,
      hasMonthlyPlan: json['has_monthly_plan'] == true ||
          json['hasMonthlyPlan'] == true ||
          json['is_pensioner'] == true ||
          json['modalidad'] == 'Pensionado',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empleado_id': empleadoId,
      'ci': ci,
      'telefono': telefono,
      'nombres': nombres,
      'apellidos': apellidos,
      'parentesco': parentesco,
      'activo': activo,
      'has_monthly_plan': hasMonthlyPlan,
      if (creadoEn != null) 'creado_en': creadoEn!.toIso8601String(),
    };
  }

  Familiar copyWith({
    String? id,
    String? empleadoId,
    String? ci,
    String? telefono,
    String? nombres,
    String? apellidos,
    String? parentesco,
    bool? activo,
    DateTime? creadoEn,
    bool? hasMonthlyPlan,
  }) {
    return Familiar(
      id: id ?? this.id,
      empleadoId: empleadoId ?? this.empleadoId,
      ci: ci ?? this.ci,
      telefono: telefono ?? this.telefono,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      parentesco: parentesco ?? this.parentesco,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
      hasMonthlyPlan: hasMonthlyPlan ?? this.hasMonthlyPlan,
    );
  }
}
