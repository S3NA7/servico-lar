import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/review.dart';

class ReviewsRepository {
  ReviewsRepository(this._client);

  final SupabaseClient _client;

  /// O trigger no banco garante que a solicitação está concluída e que o
  /// autor é o cliente do atendimento.
  Future<void> create({
    required String requestId,
    required String clientId,
    required String professionalId,
    required int rating,
    String? comment,
  }) {
    Review.validateRating(rating);
    final text = (comment ?? '').trim();
    return _client.from('reviews').insert({
      'request_id': requestId,
      'client_id': clientId,
      'professional_id': professionalId,
      'rating': rating,
      'comment': text.isEmpty ? null : text,
    });
  }

  Future<List<Review>> forProfessional(String professionalId) async {
    final rows = await _client
        .from('reviews')
        .select(Review.select)
        .eq('professional_id', professionalId)
        .order('created_at', ascending: false);
    return rows.map(Review.fromJson).toList();
  }
}
