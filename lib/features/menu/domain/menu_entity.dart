class Dish {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final String category;
  final String? tipo; // 'Sopa', 'Segundo', 'Vegetariano' o null
  final int calories;
  final bool isFavorite;
  final bool isAvailable;

  const Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.price = 15.0,
    this.category = 'Segundo',
    this.tipo,
    this.calories = 650,
    this.isFavorite = false,
    this.isAvailable = true,
  });

  Dish copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    double? price,
    String? category,
    String? tipo,
    int? calories,
    bool? isFavorite,
    bool? isAvailable,
  }) {
    return Dish(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      category: category ?? this.category,
      tipo: tipo ?? this.tipo,
      calories: calories ?? this.calories,
      isFavorite: isFavorite ?? this.isFavorite,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  factory Dish.fromJson(Map<String, dynamic> json) {
    final rawTipo = json['tipo']?.toString().trim();
    return Dish(
      id: json['id']?.toString() ?? json['id_plato']?.toString() ?? '',
      name: json['name'] ?? json['nombre'] ?? '',
      description: json['description'] ?? json['descripcion'] ?? '',
      imageUrl:
          json['image_url'] ??
          json['imageUrl'] ??
          json['imagen_url'] ??
          'assets/images/01_silpancho.jpg',
      price: (json['price'] as num?)?.toDouble() ??
          (json['precio'] as num?)?.toDouble() ??
          15.0,
      category: rawTipo ?? json['category'] ?? 'Segundo',
      tipo: (rawTipo != null && rawTipo.isNotEmpty) ? rawTipo : null,
      calories: (json['calories'] as num?)?.toInt() ??
          (json['calorias'] as num?)?.toInt() ??
          650,
      isFavorite: json['is_favorite'] == true || json['isFavorite'] == true,
      isAvailable: json['is_available'] ?? json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'price': price,
      'category': category,
      if (tipo != null) 'tipo': tipo,
      'calories': calories,
      'is_favorite': isFavorite,
      'is_available': isAvailable,
    };
  }
}
