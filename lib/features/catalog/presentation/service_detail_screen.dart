import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../../profile/data/profile_repository.dart';
import '../../reviews/presentation/review_list.dart';
import 'catalog_providers.dart';
import 'service_card.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(serviceDetailProvider(serviceId));
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/client/services'),
        ),
        title: const Text('Detalhes do serviço'),
      ),
      body: AsyncValueWidget(
        value: service,
        onRetry: () => ref.invalidate(serviceDetailProvider(serviceId)),
        data: (s) {
          final professional = ref.watch(profileByIdProvider(s.professionalId));
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(s.category?.iconData ?? Icons.build,
                            color: scheme.onSecondaryContainer, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.category?.name ?? '',
                                style: text.labelMedium
                                    ?.copyWith(color: scheme.primary)),
                            Text(s.title, style: text.headlineSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(
                        icon: Icons.payments_outlined,
                        label: 'A partir de ${s.priceLabel}',
                      ),
                      _InfoChip(
                        icon: Icons.schedule,
                        label: 'Duração: ${s.durationLabel}',
                      ),
                      if (s.avgRating != null)
                        _InfoChip(
                          icon: Icons.star_rounded,
                          label: s.ratingLabel,
                          color: Colors.amber.shade700,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Sobre o serviço', style: text.titleMedium),
                  const SizedBox(height: 6),
                  Text(s.description.isEmpty
                      ? 'Sem descrição.'
                      : s.description),
                  const SizedBox(height: 24),
                  Text('Profissional', style: text.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              s.professionalName.isEmpty
                                  ? '?'
                                  : s.professionalName[0].toUpperCase(),
                              style: TextStyle(color: scheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.professionalName, style: text.titleSmall),
                                if (s.avgRating != null)
                                  Row(children: [
                                    RatingStars(rating: s.avgRating!),
                                    const SizedBox(width: 6),
                                    Text(s.ratingLabel, style: text.bodySmall),
                                  ]),
                                if (professional.value?.bio case final bio?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(bio, style: text.bodyMedium),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Avaliações', style: text.titleMedium),
                  const SizedBox(height: 8),
                  ReviewList(professionalId: s.professionalId),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: service.hasValue
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => context.go('/client/services/$serviceId/book'),
                  icon: const Icon(Icons.event_available),
                  label: const Text('Ver horários e agendar'),
                ),
              ),
            )
          : null,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
    );
  }
}
