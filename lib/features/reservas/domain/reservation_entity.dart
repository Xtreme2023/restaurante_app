import 'dart:math';

enum ReservationMenuCategory {
  almuerzoCompleto,
  menuVegetariano,
  platoEspecial,
}

extension ReservationMenuCategoryLabel on ReservationMenuCategory {
  String get label {
    switch (this) {
      case ReservationMenuCategory.almuerzoCompleto:
        return 'Almuerzo del día';
      case ReservationMenuCategory.menuVegetariano:
        return 'Menú Vegetariano';
      case ReservationMenuCategory.platoEspecial:
        return 'Plato Especial';
    }
  }

  String get wireValue {
    switch (this) {
      case ReservationMenuCategory.almuerzoCompleto:
        return 'almuerzo_completo';
      case ReservationMenuCategory.menuVegetariano:
        return 'menu_vegetariano';
      case ReservationMenuCategory.platoEspecial:
        return 'plato_especial';
    }
  }

  static ReservationMenuCategory fromWireValue(String? value) {
    final normalized = value?.toLowerCase() ?? '';
    if (normalized.contains('veget')) {
      return ReservationMenuCategory.menuVegetariano;
    }
    if (normalized.contains('especial')) {
      return ReservationMenuCategory.platoEspecial;
    }
    switch (normalized) {
      case 'menu_vegetariano':
      case 'vegetariano':
        return ReservationMenuCategory.menuVegetariano;
      case 'plato_especial':
      case 'especial':
        return ReservationMenuCategory.platoEspecial;
      default:
        return ReservationMenuCategory.almuerzoCompleto;
    }
  }
}

class Reservation {
  final String id;
  final String userId;
  final String userName;
  final String? storedEmployeeCode;

  /// Código de retiro aleatorio y único de esta reserva (ej. A3F9-0C7E).
  /// Las reservas antiguas o generadas sin servidor no lo tienen.
  final String? storedPickupCode;
  final String? familiarId; // ID del familiar en Supabase (public.familiares)
  final String?
  beneficiaryName; // Nombre del beneficiario (Empleado o Familiar)
  final String? dishId;
  final String dishName;
  final String? entradaNombre; // Ensalada de entrada del combo
  final String? platoPrincipal; // Segundo de gastronomía boliviana
  final String? sopaNombre; // Sopa típica de la gastronomía boliviana incluida
  final bool
  isAlmuerzoCompleto; // Combo Almuerzo Completo (Ensalada + Sopa + Segundo)
  final ReservationMenuCategory menuCategory;
  final DateTime date;
  final String type; // 'diaria' o 'pension'
  final String status; // 'confirmada', 'cancelada', 'entregada'
  final double price; // 15.0 para Plan Mensual, 18.0 para Particular
  final int quantity;
  final String? notes;
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.userId,
    this.userName = 'Usuario',
    this.storedEmployeeCode,
    this.storedPickupCode,
    this.familiarId,
    this.beneficiaryName,
    this.dishId,
    this.dishName = 'Almuerzo del día',
    this.entradaNombre,
    this.platoPrincipal,
    this.sopaNombre,
    this.isAlmuerzoCompleto = true,
    this.menuCategory = ReservationMenuCategory.almuerzoCompleto,
    required this.date,
    this.type = 'diaria',
    this.status = 'confirmada',
    this.price = 18.0,
    this.quantity = 1,
    this.notes,
    required this.createdAt,
  });

  bool get isConfirmed => status == 'confirmada';
  bool get isCancelled => status == 'cancelada';
  bool get isDelivered => status == 'entregada';
  bool get isForFamiliar => familiarId != null;

  String get displayName => beneficiaryName ?? userName;

  String get employeeCode {
    final storedCode = storedEmployeeCode?.trim().toUpperCase();
    if (storedCode != null && RegExp(r'^EMP-\d{3}$').hasMatch(storedCode)) {
      return storedCode;
    }
    final normalized = userId.trim();
    if (normalized.isEmpty) return 'EMP-000';
    final suffix = normalized.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final numericCode = suffix.codeUnits.fold<int>(
      0,
      (total, unit) => (total * 31 + unit) % 1000,
    );
    return 'EMP-${numericCode.toString().padLeft(3, '0')}';
  }

  /// Genera un código de retiro aleatorio con el mismo formato que la BD.
  static String generatePickupCode([Random? random]) {
    final rng = random ?? Random.secure();
    String block() => List.generate(
      4,
      (_) => rng.nextInt(16).toRadixString(16),
    ).join().toUpperCase();
    return '${block()}-${block()}';
  }

  /// Código que se muestra en el QR. Usa el código aleatorio guardado y, solo
  /// para reservas sin él, el formato anterior basado en empleado y fecha.
  String get pickupCode {
    final stored = storedPickupCode?.trim();
    if (stored != null && stored.isNotEmpty) return stored.toUpperCase();
    const weekdays = <String>[
      'LUNES',
      'MARTES',
      'MIERCOLES',
      'JUEVES',
      'VIERNES',
      'SABADO',
      'DOMINGO',
    ];
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${employeeCode}_${weekdays[date.weekday - 1]}_$dateText';
  }

  Reservation copyWith({
    String? id,
    String? userId,
    String? userName,
    String? storedEmployeeCode,
    String? storedPickupCode,
    String? familiarId,
    String? beneficiaryName,
    String? dishId,
    String? dishName,
    String? entradaNombre,
    String? platoPrincipal,
    String? sopaNombre,
    bool? isAlmuerzoCompleto,
    ReservationMenuCategory? menuCategory,
    DateTime? date,
    String? type,
    String? status,
    double? price,
    int? quantity,
    String? notes,
    DateTime? createdAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      storedEmployeeCode: storedEmployeeCode ?? this.storedEmployeeCode,
      storedPickupCode: storedPickupCode ?? this.storedPickupCode,
      familiarId: familiarId ?? this.familiarId,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      dishId: dishId ?? this.dishId,
      dishName: dishName ?? this.dishName,
      entradaNombre: entradaNombre ?? this.entradaNombre,
      platoPrincipal: platoPrincipal ?? this.platoPrincipal,
      sopaNombre: sopaNombre ?? this.sopaNombre,
      isAlmuerzoCompleto: isAlmuerzoCompleto ?? this.isAlmuerzoCompleto,
      menuCategory: menuCategory ?? this.menuCategory,
      date: date ?? this.date,
      type: type ?? this.type,
      status: status ?? this.status,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final principal =
        json['plato_principal']?.toString() ?? json['segundo']?.toString();
    final sopa = json['sopa_nombre']?.toString() ?? json['sopa']?.toString();
    final entrada =
        json['entrada_nombre']?.toString() ??
        json['ensalada_nombre']?.toString();
    String rawDish =
        json['dish_name']?.toString() ?? json['plato_nombre']?.toString() ?? '';

    if (rawDish.isEmpty) {
      if (principal != null && sopa != null) {
        rawDish = 'Almuerzo del día ($principal + $sopa)';
      } else if (principal != null) {
        rawDish = 'Almuerzo del día ($principal)';
      } else {
        rawDish = 'Almuerzo del día';
      }
    }

    final category = ReservationMenuCategoryLabel.fromWireValue(
      json['menu_category']?.toString() ??
          json['categoria_menu']?.toString() ??
          rawDish,
    );

    return Reservation(
      id: json['id']?.toString() ?? '',
      userId: (json['empleado_id'] ?? json['user_id'])?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Usuario',
      storedEmployeeCode: json['employee_code']?.toString(),
      storedPickupCode: (json['pickup_code'] ?? json['codigo_retiro'])
          ?.toString(),
      familiarId: json['familiar_id']?.toString(),
      beneficiaryName: json['beneficiary_name']?.toString(),
      dishId: json['dish_id']?.toString(),
      dishName: rawDish,
      entradaNombre: entrada,
      platoPrincipal: principal,
      sopaNombre: sopa,
      isAlmuerzoCompleto:
          json['es_almuerzo_completo'] == true ||
          json['is_almuerzo_completo'] == true ||
          rawDish.contains('Almuerzo Completo') ||
          rawDish.contains('Almuerzo del día') ||
          category == ReservationMenuCategory.almuerzoCompleto,
      menuCategory: category,
      date: json['reservation_date'] != null
          ? DateTime.parse(json['reservation_date'] as String)
          : json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      type: json['tipo'] ?? json['type'] ?? 'diaria',
      status: _normalizeStatus(json['estado'] ?? json['status']),
      price:
          (json['precio'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          18.0,
      quantity:
          (json['quantity'] as num?)?.toInt() ??
          (json['cantidad'] as num?)?.toInt() ??
          1,
      notes: json['notes'] as String? ?? json['notas'] as String?,
      createdAt: json['creado_en'] != null
          ? DateTime.parse(json['creado_en'] as String)
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// La tabla reservas usa 'ACTIVA' para lo que la app llama 'confirmada'.
  static String _normalizeStatus(Object? raw) {
    final status = raw?.toString().trim().toLowerCase() ?? '';
    if (status.isEmpty || status == 'activa') return 'confirmada';
    return status;
  }

  Map<String, dynamic> toJson() {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      'id': id,
      'user_id': userId,
      'empleado_id': userId,
      'employee_code': storedEmployeeCode,
      if (storedPickupCode != null) 'pickup_code': storedPickupCode,
      if (familiarId != null) 'familiar_id': familiarId,
      'beneficiary_name': beneficiaryName ?? userName,
      'dish_id': dishId,
      'dish_name': dishName,
      'entrada_nombre': entradaNombre,
      'ensalada_nombre': entradaNombre,
      'plato_principal': platoPrincipal,
      'sopa_nombre': sopaNombre,
      'es_almuerzo_completo': isAlmuerzoCompleto,
      'menu_category': menuCategory.wireValue,
      'categoria_menu': menuCategory.label,
      'reservation_date': dateStr,
      'fecha': dateStr,
      'type': type,
      'status': status,
      'precio': price,
      'price': price,
      'quantity': quantity,
      'notes': notes,
      'notas': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
