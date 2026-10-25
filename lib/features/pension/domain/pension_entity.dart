class MonthlyPensionSubscription {
  final String id;
  final String userId;
  final String? familiarId;
  final int year;
  final int month;
  final int totalDays;
  final double pricePerDay;
  final double totalPrice;
  final String status; // 'Pensionado', 'Regular'
  final DateTime createdAt;

  const MonthlyPensionSubscription({
    required this.id,
    required this.userId,
    this.familiarId,
    required this.year,
    required this.month,
    required this.totalDays,
    this.pricePerDay = 15.0,
    required this.totalPrice,
    this.status = 'Pensionado',
    required this.createdAt,
  });

  bool get isActive => status == 'Pensionado' || status.toLowerCase() == 'activa';
  bool get isRegular => status == 'Regular';
  bool get isForFamiliar => familiarId != null;

  /// Regla de negocio HU8 / HU9: Bloquea cambio o cancelación una vez el mes ha iniciado.
  /// Si el año y mes seleccionado ya inició (o pasó), no se puede cancelar ni suscribir.
  bool canModifyOrCancel(DateTime currentTime) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final today = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    return today.isBefore(firstDayOfMonth);
  }

  factory MonthlyPensionSubscription.fromJson(Map<String, dynamic> json) {
    final mes = (json['mes'] ?? json['month'] as num?)?.toInt() ?? 1;
    final anio = (json['year'] as num?)?.toInt() ?? DateTime.now().year;
    final modalidad = json['modalidad']?.toString() ?? json['status']?.toString() ?? 'Pensionado';
    final idPension = json['id_pension']?.toString() ?? json['id']?.toString() ?? '';
    final idUsuario = json['id_usuario']?.toString() ?? json['user_id']?.toString() ?? '';
    final idFamiliar = json['id_familiar']?.toString() ?? json['familiar_id']?.toString();
    final days = (json['total_days'] as num?)?.toInt() ?? 22;
    final priceDay = (json['price_per_day'] as num?)?.toDouble() ?? 15.0;
    final total = (json['total_price'] as num?)?.toDouble() ?? (days * priceDay);

    return MonthlyPensionSubscription(
      id: idPension,
      userId: idUsuario,
      familiarId: idFamiliar,
      year: anio,
      month: mes,
      totalDays: days,
      pricePerDay: priceDay,
      totalPrice: total,
      status: modalidad,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty && int.tryParse(id) != null) 'id_pension': int.parse(id),
      'id': id,
      'id_usuario': userId,
      'user_id': userId,
      if (familiarId != null) 'id_familiar': familiarId,
      if (familiarId != null) 'familiar_id': familiarId,
      'mes': month,
      'month': month,
      'year': year,
      'modalidad': status,
      'status': status,
      'total_days': totalDays,
      'price_per_day': pricePerDay,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
