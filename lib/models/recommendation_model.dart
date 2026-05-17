class Recommendation {
  final String title;
  final String description;
  final DateTime generatedAt;
  final String category;    // 'planting', 'irrigation', 'pest', 'fertilizer'

  Recommendation({
    required this.title,
    required this.description,
    required this.generatedAt,
    required this.category,
  });
}