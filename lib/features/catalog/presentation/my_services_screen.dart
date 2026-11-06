import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/async_value_widget.dart';
import 'catalog_providers.dart';
import 'service_card.dart';

class MyServicesScreen extends ConsumerWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(myServicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meus serviços')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/pro/services/new'),
        icon: const Icon(Icons.add),
        label: const Text('Novo serviço'),
      ),
      body: AsyncValueWidget(
        value: services,
        onRetry: () => ref.invalidate(myServicesProvider),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.handyman_outlined,
                title: 'Você ainda não anunciou nenhum serviço',
                subtitle:
                    'Cadastre o que você faz, o preço inicial e a duração estimada.',
                action: FilledButton(
                  onPressed: () => context.go('/pro/services/new'),
                  child: const Text('Anunciar serviço'),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myServicesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return Opacity(
                      opacity: s.isActive ? 1 : 0.6,
                      child: ServiceCard(
                        service: s,
                        onTap: () => context.go('/pro/services/${s.id}/edit'),
                        trailing: Column(
                          children: [
                            Switch(
                              value: s.isActive,
                              onChanged: (v) async {
                                try {
                                  await ref
                                      .read(catalogRepositoryProvider)
                                      .setActive(s.id, v);
                                  ref.invalidate(myServicesProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    showSnack(context, friendlyError(e),
                                        error: true);
                                  }
                                }
                              },
                            ),
                            Text(s.isActive ? 'Ativo' : 'Inativo',
                                style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
