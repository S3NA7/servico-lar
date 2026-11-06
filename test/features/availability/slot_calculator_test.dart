import 'package:flutter_test/flutter_test.dart';
import 'package:servico_lar/features/availability/domain/availability_rule.dart';
import 'package:servico_lar/features/availability/domain/slot_calculator.dart';
import 'package:servico_lar/features/availability/domain/time_range.dart';

void main() {
  // 9 de novembro de 2026 é uma segunda-feira.
  final day = DateTime(2026, 11, 9);
  final dayBefore = DateTime(2026, 11, 8, 12);
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 11, 9, hour, minute);

  const morning = AvailabilityRule(
    weekday: DateTime.monday,
    startMinutes: 8 * 60,
    endMinutes: 12 * 60,
  );
  const oneHour = Duration(minutes: 60);

  group('SlotCalculator.freeSlots', () {
    test('dia sem regra não oferece horários', () {
      const tuesdayOnly = AvailabilityRule(
        weekday: DateTime.tuesday,
        startMinutes: 8 * 60,
        endMinutes: 12 * 60,
      );
      final slots = SlotCalculator.freeSlots(
        day: day,
        rules: const [tuesdayOnly],
        blocked: const [],
        duration: oneHour,
        now: dayBefore,
      );
      expect(slots, isEmpty);
    });

    test('regra 08–12 com duração 60 gera 08:00 até 11:00 de 30 em 30', () {
      final slots = SlotCalculator.freeSlots(
        day: day,
        rules: const [morning],
        blocked: const [],
        duration: oneHour,
        now: dayBefore,
      );
      expect(slots, [
        at(8),
        at(8, 30),
        at(9),
        at(9, 30),
        at(10),
        at(10, 30),
        at(11),
      ]);
    });

    test('duração maior que o intervalo não oferece nada', () {
      const shortWindow = AvailabilityRule(
        weekday: DateTime.monday,
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
      );
      final slots = SlotCalculator.freeSlots(
        day: day,
        rules: const [shortWindow],
        blocked: const [],
        duration: const Duration(minutes: 90),
        now: dayBefore,
      );
      expect(slots, isEmpty);
    });

    test('bloqueio parcial 10:00–10:15 remove 09:30 e 10:00, mantém 10:30',
        () {
      final slots = SlotCalculator.freeSlots(
        day: day,
        rules: const [morning],
        blocked: [TimeRange(at(10), at(10, 15))],
        duration: oneHour,
        now: dayBefore,
      );
      expect(slots, [at(8), at(8, 30), at(9), at(10, 30), at(11)]);
    });

    test('ocupação 09:00–10:00 remove 08:30, 09:00 e 09:30', () {
      final slots = SlotCalculator.freeSlots(
        day: day,
        rules: const [morning],
        blocked: [TimeRange(at(9), at(10))],
        duration: oneHour,
        now: dayBefore,
      );
      expect(slots, [at(8), at(10), at(10, 30), at(11)]);
    });

    test('horários com início até o momento atual não aparecem', () {
      final slots = SlotCalculator.freeSlots(
        day: day,
        rules: const [morning],
        blocked: const [],
        duration: oneHour,
        now: at(9, 10),
      );
      expect(slots, [at(9, 30), at(10), at(10, 30), at(11)]);
    });

    test('dois intervalos no mesmo dia são combinados em ordem', () {
      const afternoon = AvailabilityRule(
        weekday: DateTime.monday,
        startMinutes: 14 * 60,
        endMinutes: 16 * 60,
      );
      const shortMorning = AvailabilityRule(
        weekday: DateTime.monday,
        startMinutes: 8 * 60,
        endMinutes: 10 * 60,
      );
      final slots = SlotCalculator.freeSlots(
        day: day,
        rules: const [afternoon, shortMorning],
        blocked: const [],
        duration: oneHour,
        now: dayBefore,
      );
      expect(slots, [at(8), at(8, 30), at(9), at(14), at(14, 30), at(15)]);
    });
  });

  group('TimeRange.overlaps', () {
    test('intervalos encostados não se sobrepõem', () {
      final a = TimeRange(at(9), at(10));
      final b = TimeRange(at(10), at(11));
      expect(a.overlaps(b), isFalse);
      expect(b.overlaps(a), isFalse);
    });

    test('intervalos cruzados se sobrepõem', () {
      final a = TimeRange(at(9), at(10));
      final b = TimeRange(at(9, 30), at(10, 30));
      expect(a.overlaps(b), isTrue);
    });
  });

  group('AvailabilityRule', () {
    test('converte weekday do banco (0 = domingo) para DateTime.weekday', () {
      final sunday = AvailabilityRule.fromJson({
        'id': 'x',
        'weekday': 0,
        'start_time': '08:00:00',
        'end_time': '12:00:00',
      });
      expect(sunday.weekday, DateTime.sunday);
      expect(sunday.startMinutes, 480);
      expect(sunday.endMinutes, 720);
      expect(sunday.toJson('pro-id')['weekday'], 0);
    });

    test('formata intervalo como HH:mm–HH:mm', () {
      expect(morning.label, '08:00 – 12:00');
    });
  });
}
