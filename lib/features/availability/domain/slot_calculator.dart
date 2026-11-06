import 'availability_rule.dart';
import 'time_range.dart';

/// Gera os horários de início realmente livres para um dia.
///
/// Um horário é oferecido quando `[início, início + duração)` cabe dentro
/// de um intervalo de disponibilidade do dia, não cruza nenhum intervalo
/// bloqueado (bloqueios ou solicitações pendentes/aceitas) e começa depois
/// de `now`. O banco faz a validação final; aqui só evitamos oferecer
/// horários que sabidamente falhariam.
class SlotCalculator {
  SlotCalculator._();

  static const defaultStep = Duration(minutes: 30);

  static List<DateTime> freeSlots({
    required DateTime day,
    required List<AvailabilityRule> rules,
    required List<TimeRange> blocked,
    required Duration duration,
    Duration step = defaultStep,
    required DateTime now,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final result = <DateTime>[];

    for (final rule in rules.where((r) => r.weekday == day.weekday)) {
      var start = dayStart.add(Duration(minutes: rule.startMinutes));
      final windowEnd = dayStart.add(Duration(minutes: rule.endMinutes));

      while (!start.add(duration).isAfter(windowEnd)) {
        final candidate = TimeRange(start, start.add(duration));
        final isFuture = start.isAfter(now);
        final isFree = !blocked.any((b) => b.overlaps(candidate));
        if (isFuture && isFree) result.add(start);
        start = start.add(step);
      }
    }

    result.sort();
    return result;
  }
}
