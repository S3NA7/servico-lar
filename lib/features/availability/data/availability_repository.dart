import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/availability_block.dart';
import '../domain/availability_rule.dart';
import '../domain/time_range.dart';

class AvailabilityRepository {
  AvailabilityRepository(this._client);

  final SupabaseClient _client;

  Future<List<AvailabilityRule>> rules(String professionalId) async {
    final rows = await _client
        .from('professional_availability')
        .select()
        .eq('professional_id', professionalId)
        .order('weekday', ascending: true);
    return rows.map(AvailabilityRule.fromJson).toList()
      ..sort((a, b) => a.weekday != b.weekday
          ? a.weekday.compareTo(b.weekday)
          : a.startMinutes.compareTo(b.startMinutes));
  }

  Future<void> addRule(String professionalId, AvailabilityRule rule) =>
      _client.from('professional_availability').insert(rule.toJson(professionalId));

  Future<void> removeRule(String id) =>
      _client.from('professional_availability').delete().eq('id', id);

  /// Bloqueios do próprio profissional (RLS só permite ler os seus).
  Future<List<AvailabilityBlock>> myBlocks(String professionalId,
      {DateTime? from}) async {
    var q = _client
        .from('availability_blocks')
        .select()
        .eq('professional_id', professionalId);
    if (from != null) q = q.gte('ends_at', from.toUtc().toIso8601String());
    final rows = await q.order('starts_at');
    return rows.map(AvailabilityBlock.fromJson).toList();
  }

  Future<void> addBlock(String professionalId, TimeRange range, String? reason) =>
      _client.from('availability_blocks').insert({
        'professional_id': professionalId,
        'starts_at': range.start.toUtc().toIso8601String(),
        'ends_at': range.end.toUtc().toIso8601String(),
        'reason': (reason ?? '').trim().isEmpty ? null : reason!.trim(),
      });

  Future<void> removeBlock(String id) =>
      _client.from('availability_blocks').delete().eq('id', id);

  /// Períodos ocupados (solicitações ativas + bloqueios) de qualquer
  /// profissional, sem dados pessoais. Alimenta o cálculo de horários livres.
  Future<List<TimeRange>> busySlots(
    String professionalId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _client
        .from('professional_busy_slots')
        .select('starts_at, ends_at')
        .eq('professional_id', professionalId)
        .lt('starts_at', to.toUtc().toIso8601String())
        .gt('ends_at', from.toUtc().toIso8601String());
    return rows
        .map((r) => TimeRange(
              DateTime.parse(r['starts_at'] as String).toLocal(),
              DateTime.parse(r['ends_at'] as String).toLocal(),
            ))
        .toList();
  }
}
