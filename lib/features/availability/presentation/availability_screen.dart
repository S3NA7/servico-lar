import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/availability_rule.dart';
import 'availability_providers.dart';
import 'block_form_sheet.dart';

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(myRulesProvider);
    final blocks = ref.watch(myBlocksProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Minha agenda')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBlockFormSheet(context, ref),
        icon: const Icon(Icons.block),
        label: const Text('Bloquear período'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text('Horários de atendimento', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Os clientes só conseguem agendar dentro destes intervalos.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              AsyncValueWidget(
                value: rules,
                onRetry: () => ref.invalidate(myRulesProvider),
                data: (list) => Column(
                  children: [
                    for (final weekday in [1, 2, 3, 4, 5, 6, 7])
                      _WeekdayCard(
                        weekday: weekday,
                        rules: list.where((r) => r.weekday == weekday).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Bloqueios e folgas', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Períodos específicos em que você não atende, mesmo dentro do horário habitual.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              AsyncValueWidget(
                value: blocks,
                onRetry: () => ref.invalidate(myBlocksProvider),
                data: (list) => list.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Nenhum bloqueio futuro.',
                              style: text.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      )
                    : Column(
                        children: [
                          for (final b in list)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.event_busy),
                                title: Text(Formatters.slot(b.range.start, b.range.end)),
                                subtitle: b.reason == null ? null : Text(b.reason!),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remover bloqueio',
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(availabilityRepositoryProvider)
                                          .removeBlock(b.id);
                                      ref.invalidate(myBlocksProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        showSnack(context, friendlyError(e),
                                            error: true);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayCard extends ConsumerWidget {
  const _WeekdayCard({required this.weekday, required this.rules});

  final int weekday;
  final List<AvailabilityRule> rules;

  Future<void> _addInterval(BuildContext context, WidgetRef ref) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Início do atendimento',
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 4).clamp(0, 23), minute: start.minute),
      helpText: 'Fim do atendimento',
    );
    if (end == null || !context.mounted) return;

    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) {
      showSnack(context, 'O fim deve ser depois do início.', error: true);
      return;
    }
    final overlaps = rules.any(
        (r) => startMin < r.endMinutes && r.startMinutes < endMin);
    if (overlaps) {
      showSnack(context, 'Esse intervalo cruza outro já cadastrado.', error: true);
      return;
    }

    try {
      final uid = ref.read(currentUserIdProvider)!;
      await ref.read(availabilityRepositoryProvider).addRule(
            uid,
            AvailabilityRule(
                weekday: weekday, startMinutes: startMin, endMinutes: endMin),
          );
      ref.invalidate(myRulesProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(AvailabilityRule.weekdayNames[weekday]!,
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            Expanded(
              child: rules.isEmpty
                  ? Text('Não atende',
                      style: TextStyle(color: scheme.outline))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final r in rules)
                          InputChip(
                            label: Text(r.label),
                            onDeleted: () async {
                              try {
                                await ref
                                    .read(availabilityRepositoryProvider)
                                    .removeRule(r.id!);
                                ref.invalidate(myRulesProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  showSnack(context, friendlyError(e),
                                      error: true);
                                }
                              }
                            },
                          ),
                      ],
                    ),
            ),
            IconButton(
              tooltip: 'Adicionar intervalo',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _addInterval(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
