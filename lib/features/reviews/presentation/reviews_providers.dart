import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/reviews_repository.dart';
import '../domain/review.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => ReviewsRepository(ref.watch(supabaseClientProvider)),
);

final professionalReviewsProvider =
    FutureProvider.autoDispose.family<List<Review>, String>(
  (ref, professionalId) =>
      ref.watch(reviewsRepositoryProvider).forProfessional(professionalId),
);
