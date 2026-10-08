class Dish {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final bool isFavorite;

  Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.isFavorite = false,
  });
}
