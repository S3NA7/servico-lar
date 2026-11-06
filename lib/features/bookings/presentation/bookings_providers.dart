import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/bookings_repository.dart';
import '../domain/service_request.dart';

final bookingsRepositoryProvider = Provider<BookingsRepository>(
  (ref) => BookingsRepository(ref.watch(supabaseClientProvider)),
);

/// Solicitações feitas pelo cliente logado. Expira pendentes vencidas antes.
final myRequestsProvider = FutureProvider<List<ServiceRequest>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final repo = ref.watch(bookingsRepositoryProvider);
  await repo.expirePending();
  return repo.mine(uid);
});

/// Solicitações recebidas pelo profissional logado.
final receivedRequestsProvider =
    FutureProvider<List<ServiceRequest>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final repo = ref.watch(bookingsRepositoryProvider);
  await repo.expirePending();
  return repo.received(uid);
});
