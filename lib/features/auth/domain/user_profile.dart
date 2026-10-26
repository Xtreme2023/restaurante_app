class UserProfile {
  static const double monthlyMealPrice = 15.0;
  static const double dailyMealPrice = 18.0;

  final String id;
  final String email;
  final String employeeCode;
  final String fullName;
  final String role; // 'empleado', 'admin', 'cocina', 'encargado'
  final String department;
  final bool isPensioner;
  final double monthlyExpense;

  const UserProfile({
    required this.id,
    required this.email,
    this.employeeCode = '',
    required this.fullName,
    this.role = 'empleado',
    this.department = 'Administración Central',
    this.isPensioner = true,
    this.monthlyExpense = 280.0,
  });

  bool get isEmpleado => role.toLowerCase() == 'empleado';
  double get mealPrice => isPensioner ? monthlyMealPrice : dailyMealPrice;
  bool get isAdmin =>
      role.toLowerCase() == 'admin' || role.toLowerCase() == 'institucion';
  bool get isCocina =>
      role.toLowerCase() == 'cocina' || role.toLowerCase() == 'encargado';
  bool get isEncargado => isCocina;

  // Compatibilidad hacia atrás
  bool get isInstitucion => isAdmin;

  String get roleDisplay {
    if (isAdmin) {
      return 'Administrador Institucional';
    } else if (isCocina) {
      return 'Empleado de Cocina';
    } else if (role.toLowerCase() == 'encargado') {
      return 'Encargado';
    } else {
      return 'Empleado Institucional';
    }
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? employeeCode,
    String? fullName,
    String? role,
    String? department,
    bool? isPensioner,
    double? monthlyExpense,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      department: department ?? this.department,
      isPensioner: isPensioner ?? this.isPensioner,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Si viene de public.usuarios (db.md): tiene nombres, apellidos y rol
    String name = json['full_name'] ?? json['fullName'] ?? '';
    if (name.isEmpty &&
        (json['nombres'] != null || json['apellidos'] != null)) {
      name = '${json['nombres'] ?? ''} ${json['apellidos'] ?? ''}'.trim();
    }
    if (name.isEmpty) {
      name = 'Usuario';
    }

    final rawRole = (json['rol'] ?? json['role'] ?? 'empleado')
        .toString()
        .toLowerCase();
    final normalizedRole =
        rawRole.contains('admin') || rawRole.contains('institucion')
        ? 'admin'
        : rawRole.contains('cocina')
        ? 'cocina'
        : rawRole.contains('encargado')
        ? 'encargado'
        : 'empleado';

    final hasMonthlyPlan =
        _parseBoolean(json['has_monthly_plan']) ||
        _parseBoolean(json['hasMonthlyPlan']) ||
        _parseBoolean(json['is_pensioner']) ||
        _parseBoolean(json['isPensioner']);

    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      employeeCode:
          json['employee_code']?.toString() ??
          json['employeeCode']?.toString() ??
          '',
      fullName: name,
      role: normalizedRole,
      department:
          json['department'] ??
          json['departamento'] ??
          'Administración Central',
      isPensioner: hasMonthlyPlan,
      monthlyExpense: (json['monthly_expense'] as num?)?.toDouble() ?? 280.0,
    );
  }

  static bool _parseBoolean(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'employee_code': employeeCode,
      'full_name': fullName,
      'role': role,
      'rol': role.toUpperCase(),
      'department': department,
      'is_pensioner': isPensioner,
      'monthly_expense': monthlyExpense,
    };
  }
}
