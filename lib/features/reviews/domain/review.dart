class Review {
  const Review({
    required this.id,
    required this.requestId,
    required this.professionalId,
    required this.rating,
    this.comment,
    required this.clientName,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String professionalId;
  final int rating;
  final String? comment;
  final String clientName;
  final DateTime createdAt;

  static const select = '*, client:profiles!reviews_client_id_fkey(full_name)';

  factory Review.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>?;
    return Review(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      professionalId: json['professional_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      clientName: (client?['full_name'] as String?) ?? 'Cliente',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  String get clientFirstName => clientName.split(' ').first;

  static void validateRating(int rating) {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'A nota deve ser de 1 a 5');
    }
  }
}
