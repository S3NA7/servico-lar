import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../availability/domain/slot_calculator.dart';
import '../../availability/presentation/availability_providers.dart';
import '../../catalog/domain/service.dart';
import '../../catalog/presentation/catalog_providers.dart';
import 'bookings_providers.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(serviceDetailProvider(serviceId));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/client/services/$serviceId'),
        ),
        title: const Text('Agendar'),
      ),
      body: AsyncValueWidget(
        value: service,
        onRetry: () => ref.invalidate(serviceDetailProvider(serviceId)),
        data: (s) => _BookingBody(service: s),
      ),
    );
  }
}

class _BookingBody extends ConsumerStatefulWidget {
  const _BookingBody({required this.service});

  final Service service;

  @override
  ConsumerState<_BookingBody> createState() => _BookingBodyState();
}

class _BookingBodyState extends ConsumerState<_BookingBody> {
  late DateTime _focused = _today;
  DateTime? _selected;
  DateTime? _slot;
  bool _submitting = false;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _lastDay => _today.add(const Duration(days: 60));

  Future<void> _confirm() async {
    final slot = _slot;
    if (slot == null) return;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar solicitação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.service.title,
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Com ${widget.service.professionalName}'),
            const SizedBox(height: 4),
            Text(Formatters.slot(slot, slot.add(widget.service.duration))),
            const SizedBox(height: 4),
            Text('A partir de ${widget.service.priceLabel}'),
            const SizedBox(height: 16),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                hintText: 'Endereço, referência, detalhes do problema…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar solicitação')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref.read(bookingsRepositoryProvider).create(
            serviceId: widget.service.id,
            startsAt: slot,
            note: note.text,
          );
      ref.invalidate(myRequestsProvider);
      ref.invalidate(busySlotsProvider);
      if (mounted) {
        showSnack(context,
            'Solicitação enviada! O profissional tem até 24h para responder.');
        context.go('/client/requests');
      }
    } catch (e) {
      ref.invalidate(busySlotsProvider);
      if (mounted) {
        setState(() => _slot = null);
        showSnack(context, friendlyError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
      note.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final rules = ref.watch(rulesProvider(s.professionalId));
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AsyncValueWidget(
      value: rules,
      onRetry: () => ref.invalidate(rulesProvider(s.professionalId)),
      data: (ruleList) {
        final workingWeekdays = ruleList.map((r) => r.weekday).toSet();
        if (workingWeekdays.isEmpty) {
          return const EmptyState(
            icon: Icons.event_busy,
            title: 'Este profissional ainda não configurou sua agenda',
            subtitle: 'Tente novamente mais tarde ou escolha outro serviço.',
          );
        }

        final selected = _selected;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(s.category?.iconData ?? Icons.build),
                    title: Text(s.title),
                    subtitle: Text(
                        '${s.professionalName} · ${s.durationLabel} · ${s.priceLabel}'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('1. Escolha o dia', style: text.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: TableCalendar<void>(
                    locale: 'pt_BR',
                    firstDay: _today,
                    lastDay: _lastDay,
                    focusedDay: _focused,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {CalendarFormat.month: 'Mês'},
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    selectedDayPredicate: (d) =>
                        selected != null && isSameDay(d, selected),
                    enabledDayPredicate: (d) =>
                        workingWeekdays.contains(d.weekday),
                    onDaySelected: (day, focused) => setState(() {
                      _selected = DateTime(day.year, day.month, day.day);
                      _focused = focused;
                      _slot = null;
                    }),
                    onPageChanged: (focused) => _focused = focused,
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(color: scheme.onPrimaryContainer),
                      disabledTextStyle: TextStyle(color: scheme.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('2. Escolha o horário', style: text.titleMedium),
                const SizedBox(height: 8),
                if (selected == null)
                  Text('Selecione um dia no calendário.',
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant))
                else
                  _SlotPicker(
                    service: s,
                    day: selected,
                    rules: ruleList,
                    selected: _slot,
                    onSelected: (slot) => setState(() => _slot = slot),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _slot == null || _submitting ? null : _confirm,
                  icon: const Icon(Icons.send),
                  label: Text(_slot == null
                      ? 'Escolha um horário'
                      : 'Solicitar ${Formatters.time.format(_slot!)}'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlotPicker extends ConsumerWidget {
  const _SlotPicker({
    required this.service,
    required this.day,
    required this.rules,
    required this.selected,
    required this.onSelected,
  });

  final Service service;
  final DateTime day;
  final List<dynamic> rules;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = day;
    final to = day.add(const Duration(days: 1));
    final busy = ref.watch(busySlotsProvider(
      (professionalId: service.professionalId, from: from, to: to),
    ));

    return AsyncValueWidget(
      value: busy,
      onRetry: () => ref.invalidate(busySlotsProvider),
      data: (blocked) {
        final slots = SlotCalculator.freeSlots(
          day: day,
          rules: rules.cast(),
          blocked: blocked,
          duration: service.duration,
          now: DateTime.now(),
        );
        if (slots.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nenhum horário livre em ${Formatters.dayMonth.format(day)} '
                'para um serviço de ${service.durationLabel}. Tente outro dia.',
              ),
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in slots)
              ChoiceChip(
                label: Text(Formatters.time.format(slot)),
                selected: selected == slot,
                onSelected: (_) => onSelected(slot),
              ),
          ],
        );
      },
    );
  }
}
