import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../../profile/data/profile_repository.dart';
import 'catalog_providers.dart';
import 'service_card.dart';

class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    context.go('/client/services?q=${Uri.encodeQueryComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final categories = ref.watch(categoriesProvider);
    final highlights =
        ref.watch(servicesProvider((categoryId: null, query: '')));
    final text = Theme.of(context).textTheme;
    final firstName = profile?.fullName.split(' ').first ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(firstName.isEmpty ? 'ServiçoLar' : 'Olá, $firstName'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(servicesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('Do que sua casa precisa hoje?', style: text.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitSearch,
              decoration: InputDecoration(
                hintText: 'Buscar serviço (ex.: chuveiro, pintura)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _submitSearch(_search.text),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Categorias', style: text.titleMedium),
            const SizedBox(height: 12),
            AsyncValueWidget(
              value: categories,
              onRetry: () => ref.invalidate(categoriesProvider),
              data: (list) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisExtent: 96,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  final scheme = Theme.of(context).colorScheme;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.go('/client/services?category=${c.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(c.iconData, color: scheme.primary),
                            Text(c.name,
                                style: text.labelLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text('Serviços disponíveis', style: text.titleMedium),
            const SizedBox(height: 12),
            AsyncValueWidget(
              value: highlights,
              onRetry: () => ref.invalidate(servicesProvider),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Nenhum serviço anunciado ainda',
                    )
                  : Column(
                      children: [
                        for (final s in list.take(6)) ...[
                          ServiceCard(
                            service: s,
                            onTap: () => context.go('/client/services/${s.id}'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (list.length > 6)
                          TextButton(
                            onPressed: () => context.go('/client/services'),
                            child: const Text('Ver todos'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
