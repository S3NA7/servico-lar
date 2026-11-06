import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/catalog_repository.dart';
import '../domain/category.dart';
import '../domain/service.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(supabaseClientProvider)),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);

typedef ServiceFilter = ({int? categoryId, String query});

final servicesProvider =
    FutureProvider.autoDispose.family<List<Service>, ServiceFilter>(
  (ref, filter) => ref.watch(catalogRepositoryProvider).activeServices(
        categoryId: filter.categoryId,
        query: filter.query,
      ),
);

final serviceDetailProvider = FutureProvider.autoDispose.family<Service, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).byId(id),
);

final myServicesProvider = FutureProvider<List<Service>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  return ref.watch(catalogRepositoryProvider).myServices(uid);
});
