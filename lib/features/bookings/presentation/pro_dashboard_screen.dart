import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/domain/user_role.dart';
import '../domain/request_status.dart';
import '../domain/service_request.dart';
import 'bookings_providers.dart';
import 'request_card.dart';

class ProDashboardScreen extends ConsumerWidget {
  const ProDashboardScreen({super.key});

  Future<void> _setStatus(BuildContext context, WidgetRef ref,
      ServiceRequest r, RequestStatus status,
      {String? confirmTitle, String? confirmBody}) async {
    if (confirmTitle != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(confirmTitle),
          content: confirmBody == null ? null : Text(confirmBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Voltar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ref.read(bookingsRepositoryProvider).updateStatus(r.id, status);
      ref.invalidate(receivedRequestsProvider);
      if (context.mounted) {
        showSnack(context, 'Solicitação ${status.label.toLowerCase()}.');
      }
    } catch (e) {
      ref.invalidate(receivedRequestsProvider);
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(receivedRequestsProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Painel'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Pendentes'),
            Tab(text: 'Agendados'),
            Tab(text: 'Histórico'),
          ]),
        ),
        body: AsyncValueWidget(
          value: requests,
          onRetry: () => ref.invalidate(receivedRequestsProvider),
          data: (list) {
            final pending = list
                .where((r) => r.status == RequestStatus.pending)
                .toList()
              ..sort((a, b) => a.respondBy.compareTo(b.respondBy));
            final accepted = list
                .where((r) => r.status == RequestStatus.accepted)
                .toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            final history = list.where((r) => !r.status.isActive).toList();

            Widget buildList(List<ServiceRequest> items, EmptyState empty) =>
                RefreshIndicator(
                  onRefresh: () async => ref.invalidate(receivedRequestsProvider),
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
                              viewer: UserRole.professional,
                              onAccept: () => _setStatus(
                                  context, ref, r, RequestStatus.accepted),
                              onReject: () => _setStatus(
                                context, ref, r, RequestStatus.rejected,
                                confirmTitle: 'Recusar solicitação?',
                                confirmBody:
                                    'O cliente será avisado e o horário liberado.',
                              ),
                              onCancel: () => _setStatus(
                                context, ref, r, RequestStatus.cancelled,
                                confirmTitle: 'Cancelar atendimento?',
                                confirmBody:
                                    'Evite cancelar em cima da hora: isso afeta sua reputação com o cliente.',
                              ),
                              onComplete: () => _setStatus(
                                context, ref, r, RequestStatus.completed,
                                confirmTitle: 'Marcar como concluído?',
                                confirmBody:
                                    'O cliente poderá avaliar o atendimento.',
                              ),
                            );
                          },
                        ),
                );

            return TabBarView(children: [
              buildList(
                pending,
                const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nenhuma solicitação pendente',
                  subtitle: 'Novas solicitações aparecem aqui para você aceitar ou recusar.',
                ),
              ),
              buildList(
                accepted,
                const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'Nenhum atendimento agendado',
                ),
              ),
              buildList(
                history,
                const EmptyState(
                  icon: Icons.history,
                  title: 'Histórico vazio',
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
