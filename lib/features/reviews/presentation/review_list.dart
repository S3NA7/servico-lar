import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../catalog/presentation/service_card.dart';
import 'reviews_providers.dart';

class ReviewList extends ConsumerWidget {
  const ReviewList({super.key, required this.professionalId});

  final String professionalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(professionalReviewsProvider(professionalId));
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AsyncValueWidget(
      value: reviews,
      onRetry: () => ref.invalidate(professionalReviewsProvider(professionalId)),
      data: (list) => list.isEmpty
          ? Text('Este profissional ainda não recebeu avaliações.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
          : Column(
              children: [
                for (final r in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RatingStars(rating: r.rating.toDouble()),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(r.clientFirstName,
                                    style: text.labelLarge),
                              ),
                              Text(Formatters.shortDate.format(r.createdAt),
                                  style: text.bodySmall
                                      ?.copyWith(color: scheme.outline)),
                            ],
                          ),
                          if (r.comment case final c? when c.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(c),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
