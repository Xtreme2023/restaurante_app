class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'empleado', 'admin', 'cocina'
  final String department;
  final bool isPensioner;
  final double monthlyExpense;
  final String? ciCodigo;
  final String? telefono;
  final bool activo;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = 'empleado',
    this.department = 'Administración Central',
    this.isPensioner = true,
    this.monthlyExpense = 280.0,
    this.ciCodigo,
    this.telefono,
    this.activo = true,
  });

  bool get isEmpleado => role.toLowerCase() == 'empleado';
  bool get isAdmin =>
      role.toLowerCase() == 'admin' || role.toLowerCase() == 'administrador';
  bool get isCocina =>
      role.toLowerCase() == 'cocina' || role.toLowerCase() == 'institucion';

  // Compatibilidad hacia atrás
  bool get isEncargado => isCocina;
  bool get isInstitucion => isCocina;

  String get roleDisplay {
    if (isCocina) {
      return 'Empleado de Cocina';
    } else if (isAdmin) {
      return 'Administrador Institucional';
    } else {
      return 'Empleado Institucional';
    }
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? department,
    bool? isPensioner,
    double? monthlyExpense,
    String? ciCodigo,
    String? telefono,
    bool? activo,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      department: department ?? this.department,
      isPensioner: isPensioner ?? this.isPensioner,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
      ciCodigo: ciCodigo ?? this.ciCodigo,
      telefono: telefono ?? this.telefono,
      activo: activo ?? this.activo,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Compatible con vista_usuarios (id_usuario, nombre_completo, nombre, apellidos, rol, ci_codigo, telefono, activo)
    // y tablas legacy usuarios/profiles
    String name =
        json['nombre_completo'] ?? json['full_name'] ?? json['fullName'] ?? '';
    if (name.isEmpty &&
        (json['nombre'] != null ||
            json['nombres'] != null ||
            json['apellidos'] != null)) {
      final primerNombre = json['nombre'] ?? json['nombres'] ?? '';
      name = '$primerNombre ${json['apellidos'] ?? ''}'.trim();
    }
    if (name.isEmpty) {
      name = 'Usuario';
    }

    final rawRole = (json['rol'] ?? json['role'] ?? 'empleado')
        .toString()
        .toLowerCase();
    final normalizedRole = rawRole.contains('admin')
        ? 'admin'
        : (rawRole.contains('cocina') ||
              rawRole.contains('encargado') ||
              rawRole.contains('institucion'))
        ? 'cocina'
        : 'empleado';

    return UserProfile(
      id: json['id_usuario']?.toString() ?? json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      fullName: name,
      role: normalizedRole,
      department: json['department'] ?? 'Administración Central',
      isPensioner: json['is_pensioner'] == true || json['isPensioner'] == true,
      monthlyExpense: (json['monthly_expense'] as num?)?.toDouble() ?? 280.0,
      ciCodigo: json['ci_codigo']?.toString() ?? json['ci']?.toString(),
      telefono: json['telefono']?.toString(),
      activo: json['activo'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_usuario': id,
      'email': email,
      'full_name': fullName,
      'nombre_completo': fullName,
      'role': role,
      'rol': role.toUpperCase(),
      'department': department,
      'is_pensioner': isPensioner,
      'monthly_expense': monthlyExpense,
      'ci_codigo': ciCodigo,
      'telefono': telefono,
      'activo': activo,
    };
  }
}
