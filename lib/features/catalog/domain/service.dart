import '../../../core/utils/formatters.dart';
import 'category.dart';

class Service {
  const Service({
    required this.id,
    required this.professionalId,
    required this.professionalName,
    required this.categoryId,
    this.category,
    required this.title,
    required this.description,
    required this.basePrice,
    required this.durationMinutes,
    required this.isActive,
    this.avgRating,
    this.reviewCount = 0,
  });

  final String id;
  final String professionalId;
  final String professionalName;
  final int categoryId;
  final Category? category;
  final String title;
  final String description;
  final double basePrice;
  final int durationMinutes;
  final bool isActive;
  final double? avgRating;
  final int reviewCount;

  /// Aceita o resultado de
  /// `select *, professional:profiles(id, full_name), category:categories(*)`.
  factory Service.fromJson(Map<String, dynamic> json) {
    final professional = json['professional'] as Map<String, dynamic>?;
    final category = json['category'] as Map<String, dynamic>?;
    return Service(
      id: json['id'] as String,
      professionalId: json['professional_id'] as String,
      professionalName: (professional?['full_name'] as String?) ?? '',
      categoryId: json['category_id'] as int,
      category: category == null ? null : Category.fromJson(category),
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      basePrice: _toDouble(json['base_price']),
      durationMinutes: json['duration_minutes'] as int,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  /// Colunas editáveis da tabela `services`.
  Map<String, dynamic> toInsertJson() => {
        'professional_id': professionalId,
        'category_id': categoryId,
        'title': title,
        'description': description,
        'base_price': basePrice,
        'duration_minutes': durationMinutes,
        'is_active': isActive,
      };

  Duration get duration => Duration(minutes: durationMinutes);
  String get priceLabel => Formatters.price(basePrice);
  String get durationLabel => Formatters.duration(durationMinutes);

  /// Ex.: "4,5 (8)". Vazio quando ainda não há avaliações.
  String get ratingLabel => avgRating == null
      ? ''
      : '${avgRating!.toStringAsFixed(1).replaceAll('.', ',')} ($reviewCount)';

  Service withRating({required double? avgRating, required int reviewCount}) =>
      copyWith(avgRating: avgRating, reviewCount: reviewCount);

  Service copyWith({
    String? title,
    String? description,
    double? basePrice,
    int? durationMinutes,
    int? categoryId,
    Category? category,
    bool? isActive,
    double? avgRating,
    int? reviewCount,
  }) =>
      Service(
        id: id,
        professionalId: professionalId,
        professionalName: professionalName,
        categoryId: categoryId ?? this.categoryId,
        category: category ?? this.category,
        title: title ?? this.title,
        description: description ?? this.description,
        basePrice: basePrice ?? this.basePrice,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        isActive: isActive ?? this.isActive,
        avgRating: avgRating ?? this.avgRating,
        reviewCount: reviewCount ?? this.reviewCount,
      );

  static double _toDouble(Object? v) => switch (v) {
        num n => n.toDouble(),
        String s => double.parse(s),
        _ => 0,
      };
}
