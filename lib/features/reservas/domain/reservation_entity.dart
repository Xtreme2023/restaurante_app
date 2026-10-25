enum ReservationMenuCategory {
  almuerzoCompleto,
  menuVegetariano,
  platoEspecial,
}

extension ReservationMenuCategoryLabel on ReservationMenuCategory {
  String get label {
    switch (this) {
      case ReservationMenuCategory.almuerzoCompleto:
        return 'Almuerzo Completo';
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
  final String? notes;
  final bool recogido; // Marca si el usuario recogió su plato
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.userId,
    this.userName = 'Usuario',
    this.familiarId,
    this.beneficiaryName,
    this.dishId,
    this.dishName = 'Almuerzo Completo del Día',
    this.entradaNombre,
    this.platoPrincipal,
    this.sopaNombre,
    this.isAlmuerzoCompleto = true,
    this.menuCategory = ReservationMenuCategory.almuerzoCompleto,
    required this.date,
    this.type = 'diaria',
    this.status = 'confirmada',
    this.price = 18.0,
    this.notes,
    this.recogido = false,
    required this.createdAt,
  });

  bool get isConfirmed => status.toLowerCase() == 'confirmada';
  bool get isCancelled => status.toLowerCase() == 'cancelada';
  bool get isDelivered => status.toLowerCase() == 'entregada';
  bool get isForFamiliar => familiarId != null;

  String get displayName => beneficiaryName ?? userName;

  Reservation copyWith({
    String? id,
    String? userId,
    String? userName,
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
    String? notes,
    bool? recogido,
    DateTime? createdAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
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
      notes: notes ?? this.notes,
      recogido: recogido ?? this.recogido,
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
        rawDish = 'Almuerzo Completo ($principal + $sopa)';
      } else if (principal != null) {
        rawDish = 'Almuerzo Completo ($principal)';
      } else {
        rawDish = 'Almuerzo Completo del Día';
      }
    }

    final category = ReservationMenuCategoryLabel.fromWireValue(
      json['menu_category']?.toString() ??
          json['categoria_menu']?.toString() ??
          rawDish,
    );

    final famId = json['id_familiar']?.toString() ?? json['familiar_id']?.toString();
    String? beneficiaryName = json['beneficiary_name']?.toString();
    if (beneficiaryName == null && famId != null) {
      if (json['familiar_nombre'] != null && json['familiar_nombre'].toString().trim().isNotEmpty) {
        final nom = json['familiar_nombre'].toString().trim();
        final par = json['familiar_parentesco']?.toString() ?? 'Familiar';
        beneficiaryName = '$nom ($par)';
      } else if (json['familiar'] != null && json['familiar'] is Map) {
        final fam = json['familiar'] as Map;
        final per = fam['persona'] is Map ? fam['persona'] as Map : null;
        if (per != null) {
          final nom = '${per['nombre'] ?? ''} ${per['apellidos'] ?? ''}'.trim();
          final par = fam['parentesco']?.toString() ?? 'Familiar';
          beneficiaryName = nom.isNotEmpty ? '$nom ($par)' : 'Familiar ($par)';
        }
      } else if (json['nombre'] != null || json['apellidos'] != null) {
        final nom = '${json['nombre'] ?? ''} ${json['apellidos'] ?? ''}'.trim();
        final par = json['parentesco']?.toString() ?? 'Familiar';
        beneficiaryName = nom.isNotEmpty ? '$nom ($par)' : 'Familiar ($par)';
      }
    }

    final empName = (json['empleado_nombre'] ?? json['user_name'])?.toString() ?? 'Usuario';

    return Reservation(
      id: json['id_reserva']?.toString() ?? json['id']?.toString() ?? '',
      userId: (json['id_usuario'] ?? json['empleado_id'] ?? json['user_id'])?.toString() ?? '',
      userName: empName,
      familiarId: famId,
      beneficiaryName: beneficiaryName ?? (famId == null ? empName : null),
      dishId: json['dish_id']?.toString(),
      dishName: rawDish,
      entradaNombre: entrada,
      platoPrincipal: principal,
      sopaNombre: sopa,
      isAlmuerzoCompleto:
          json['es_almuerzo_completo'] == true ||
          json['is_almuerzo_completo'] == true ||
          rawDish.contains('Almuerzo Completo') ||
          category == ReservationMenuCategory.almuerzoCompleto,
      menuCategory: category,
      date: json['reservation_date'] != null
          ? DateTime.parse(json['reservation_date'] as String)
          : json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      type: json['tipo'] ?? json['type'] ?? ((json['es_pension'] == true || (json['costo_aplicado'] as num?)?.toDouble() == 15.0) ? 'pension' : 'diaria'),
      status:
          (json['estado'] ?? json['status'])?.toString().toLowerCase() ??
          'confirmada',
      price:
          (json['costo_aplicado'] as num?)?.toDouble() ??
          (json['precio'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          18.0,
      notes: json['notes'] as String? ?? json['notas'] as String?,
      recogido: json['recogido'] == true,
      createdAt: json['creado_en'] != null
          ? DateTime.parse(json['creado_en'] as String)
          : json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      'id': id,
      'user_id': userId,
      'id_usuario': userId,
      'empleado_id': userId,
      if (familiarId != null) 'familiar_id': familiarId,
      if (familiarId != null) 'id_familiar': familiarId,
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
      'costo_aplicado': price,
      'es_pension': price <= 15.0,
      'origen': familiarId != null ? 'FAMILIAR' : 'EMPLEADO',
      'notes': notes,
      'notas': notes,
      'recogido': recogido,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
