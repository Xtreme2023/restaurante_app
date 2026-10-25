import 'package:restaurante_app/features/familiares/domain/familiar_entity.dart';

class AdminEmployee {
  final String id;
  final String ci;
  final String nombres;
  final String apellidos;
  final String email;
  final String telefono;
  final String departamento;
  final String rol;
  final bool hasMonthlyPlan; // Membresía Plan Mensual (Tarifa Bs. 15 vs Bs. 18)
  final bool activo;
  final List<Familiar> familiares;
  final DateTime creadoEn;

  const AdminEmployee({
    required this.id,
    required this.ci,
    required this.nombres,
    required this.apellidos,
    required this.email,
    this.telefono = '',
    this.departamento = 'Administración General',
    this.rol = 'EMPLEADO',
    this.hasMonthlyPlan = true,
    this.activo = true,
    this.familiares = const [],
    required this.creadoEn,
  });

  String get fullName => '$nombres $apellidos'.trim();

  double get tariffPrice => hasMonthlyPlan ? 15.0 : 18.0;

  String get tariffLabel => hasMonthlyPlan
      ? 'Plan Mensual (Bs. 15)'
      : 'Modalidad Diaria (Bs. 18)';

  AdminEmployee copyWith({
    String? id,
    String? ci,
    String? nombres,
    String? apellidos,
    String? email,
    String? telefono,
    String? departamento,
    String? rol,
    bool? hasMonthlyPlan,
    bool? activo,
    List<Familiar>? familiares,
    DateTime? creadoEn,
  }) {
    return AdminEmployee(
      id: id ?? this.id,
      ci: ci ?? this.ci,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      departamento: departamento ?? this.departamento,
      rol: rol ?? this.rol,
      hasMonthlyPlan: hasMonthlyPlan ?? this.hasMonthlyPlan,
      activo: activo ?? this.activo,
      familiares: familiares ?? this.familiares,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  factory AdminEmployee.fromJson(
    Map<String, dynamic> json, {
    List<Familiar> familiares = const [],
  }) {
    return AdminEmployee(
      id: json['id_usuario']?.toString() ?? json['id']?.toString() ?? '',
      ci: json['ci_codigo']?.toString() ?? json['ci']?.toString() ?? '',
      nombres: json['nombre']?.toString() ?? json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      departamento: json['departamento'] ?? json['department'] ?? 'Administración General',
      rol: (json['rol'] ?? 'EMPLEADO').toString().toUpperCase(),
      hasMonthlyPlan: json['has_monthly_plan'] == true ||
          json['is_pensioner'] == true ||
          json['hasMonthlyPlan'] == true,
      activo: json['activo'] != false,
      familiares: familiares,
      creadoEn: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ??
              (json['creado_en'] != null
                  ? DateTime.tryParse(json['creado_en'].toString()) ?? DateTime.now()
                  : DateTime.now())
          : (json['creado_en'] != null
              ? DateTime.tryParse(json['creado_en'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ci': ci,
      'nombres': nombres,
      'apellidos': apellidos,
      'email': email,
      'telefono': telefono,
      'departamento': departamento,
      'rol': rol,
      'has_monthly_plan': hasMonthlyPlan,
      'activo': activo,
      'creado_en': creadoEn.toIso8601String(),
    };
  }
}
