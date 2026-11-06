import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/domain/user_role.dart';
import '../../reviews/presentation/review_sheet.dart';
import '../domain/request_status.dart';
import '../domain/service_request.dart';
import 'bookings_providers.dart';
import 'request_card.dart';

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, ServiceRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitação?'),
        content: const Text('O horário será liberado para outros clientes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Manter')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar solicitação')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(bookingsRepositoryProvider)
          .updateStatus(r.id, RequestStatus.cancelled);
      ref.invalidate(myRequestsProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Minhas solicitações'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Em andamento'),
            Tab(text: 'Histórico'),
          ]),
        ),
        body: AsyncValueWidget(
          value: requests,
          onRetry: () => ref.invalidate(myRequestsProvider),
          data: (list) {
            final active = list.where((r) => r.status.isActive).toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            final history = list.where((r) => !r.status.isActive).toList();
            Widget buildList(List<ServiceRequest> items, EmptyState empty) =>
                RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myRequestsProvider),
                  child: items.isEmpty
                      ? ListView(children: [SizedBox(height: 300, child: empty)])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final r = items[i];
                            return RequestCard(
                              request: r,
                              viewer: UserRole.client,
                              onCancel: () => _cancel(context, ref, r),
                              onReview: () => showReviewSheet(context, ref, r),
                            );
                          },
                        ),
                );
            return TabBarView(children: [
              buildList(
                active,
                EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nenhuma solicitação em andamento',
                  subtitle: 'Encontre um profissional e agende um horário.',
                  action: FilledButton(
                    onPressed: () => context.go('/client'),
                    child: const Text('Buscar serviços'),
                  ),
                ),
              ),
              buildList(
                history,
                const EmptyState(
                  icon: Icons.history,
                  title: 'Seu histórico está vazio',
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
