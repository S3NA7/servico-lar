import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_value_widget.dart';
import 'catalog_providers.dart';
import 'service_card.dart';

class ServiceListScreen extends ConsumerStatefulWidget {
  const ServiceListScreen({super.key, this.categoryId, this.query = ''});

  final int? categoryId;
  final String query;

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  late final _search = TextEditingController(text: widget.query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _navigate({int? categoryId, String? query}) {
    final params = <String, String>{};
    if (categoryId != null) params['category'] = '$categoryId';
    final q = (query ?? _search.text).trim();
    if (q.isNotEmpty) params['q'] = q;
    context.go(Uri(path: '/client/services', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    final filter = (categoryId: widget.categoryId, query: widget.query);
    final services = ref.watch(servicesProvider(filter));
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/client')),
        title: const Text('Serviços'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _navigate(categoryId: widget.categoryId, query: v),
              decoration: InputDecoration(
                hintText: 'Buscar',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: widget.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _navigate(categoryId: widget.categoryId, query: '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Todas'),
                    selected: widget.categoryId == null,
                    onSelected: (_) => _navigate(categoryId: null),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(c.iconData, size: 18),
                      label: Text(c.name),
                      selected: widget.categoryId == c.id,
                      onSelected: (_) => _navigate(
                        categoryId: widget.categoryId == c.id ? null : c.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueWidget(
              value: services,
              onRetry: () => ref.invalidate(servicesProvider(filter)),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'Nenhum serviço encontrado',
                      subtitle: 'Tente outra categoria ou outro termo.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => ServiceCard(
                        service: list[i],
                        onTap: () => context.go('/client/services/${list[i].id}'),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
