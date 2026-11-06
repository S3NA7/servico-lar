import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/domain/user_role.dart';
import '../domain/request_status.dart';
import '../domain/service_request.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      RequestStatus.pending => (Colors.amber.shade100, Colors.amber.shade900),
      RequestStatus.accepted => (scheme.primaryContainer, scheme.onPrimaryContainer),
      RequestStatus.completed => (Colors.green.shade100, Colors.green.shade900),
      RequestStatus.rejected ||
      RequestStatus.cancelled =>
        (scheme.errorContainer, scheme.onErrorContainer),
      RequestStatus.expired => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

/// Cartão de solicitação com as ações permitidas para quem está vendo.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.viewer,
    this.now,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.onComplete,
    this.onReview,
  });

  final ServiceRequest request;
  final UserRole viewer;

  /// Injetável para testes; padrão [DateTime.now].
  final DateTime? now;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = request;
    final isClient = viewer == UserRole.client;
    final otherParty = isClient ? r.professionalName : r.clientName;

    final actions = <Widget>[];
    if (isClient) {
      if (r.status.canClientCancel(now: now, startsAt: r.startsAt)) {
        actions.add(OutlinedButton(
          onPressed: onCancel,
          child: const Text('Cancelar'),
        ));
      }
      if (r.canBeReviewed) {
        actions.add(FilledButton.icon(
          onPressed: onReview,
          icon: const Icon(Icons.star_outline),
          label: const Text('Avaliar'),
        ));
      }
    } else {
      if (r.status.canProfessionalRespond) {
        actions.add(OutlinedButton(
          onPressed: onReject,
          child: const Text('Recusar'),
        ));
        actions.add(FilledButton(
          onPressed: onAccept,
          child: const Text('Aceitar'),
        ));
      }
      if (r.status.canProfessionalCancel(now: now, startsAt: r.startsAt)) {
        actions.add(OutlinedButton(
          onPressed: onCancel,
          child: const Text('Cancelar'),
        ));
      }
      if (r.status == RequestStatus.accepted) {
        final enabled = r.status.canComplete(now: now, startsAt: r.startsAt);
        actions.add(Tooltip(
          message: enabled ? '' : 'Disponível após o horário de início',
          child: FilledButton.icon(
            onPressed: enabled ? onComplete : null,
            icon: const Icon(Icons.check),
            label: const Text('Concluir'),
          ),
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.serviceTitle,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                StatusChip(r.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(isClient ? Icons.handyman_outlined : Icons.person_outline,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(otherParty, style: text.bodyMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(Formatters.slot(r.startsAt, r.endsAt), style: text.bodyMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('A partir de ${Formatters.price(r.servicePrice)}',
                    style: text.bodyMedium),
              ],
            ),
            if (r.note case final note? when note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(note, style: text.bodySmall),
              ),
            ],
            if (r.status == RequestStatus.pending) ...[
              const SizedBox(height: 8),
              Text(
                isClient
                    ? 'Aguardando resposta até ${Formatters.dateTime.format(r.respondBy)}'
                    : 'Responda até ${Formatters.dateTime.format(r.respondBy)}',
                style: text.bodySmall?.copyWith(color: Colors.amber.shade900),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
