import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/availability_repository.dart';
import '../domain/availability_block.dart';
import '../domain/availability_rule.dart';
import '../domain/time_range.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>(
  (ref) => AvailabilityRepository(ref.watch(supabaseClientProvider)),
);

/// Regras semanais de um profissional qualquer.
final rulesProvider =
    FutureProvider.autoDispose.family<List<AvailabilityRule>, String>(
  (ref, professionalId) =>
      ref.watch(availabilityRepositoryProvider).rules(professionalId),
);

/// Regras do profissional logado.
final myRulesProvider = FutureProvider<List<AvailabilityRule>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  return ref.watch(availabilityRepositoryProvider).rules(uid);
});

/// Bloqueios futuros do profissional logado.
final myBlocksProvider = FutureProvider<List<AvailabilityBlock>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final today = DateTime.now();
  return ref.watch(availabilityRepositoryProvider).myBlocks(
        uid,
        from: DateTime(today.year, today.month, today.day),
      );
});

typedef BusyQuery = ({String professionalId, DateTime from, DateTime to});

/// Períodos ocupados de um profissional num intervalo.
final busySlotsProvider =
    FutureProvider.autoDispose.family<List<TimeRange>, BusyQuery>(
  (ref, q) => ref
      .watch(availabilityRepositoryProvider)
      .busySlots(q.professionalId, q.from, q.to),
);
