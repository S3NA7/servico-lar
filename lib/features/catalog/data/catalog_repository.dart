import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/category.dart';
import '../domain/service.dart';

class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, professional:profiles(id, full_name), category:categories(*)';

  Future<List<Category>> categories() async {
    final rows = await _client.from('categories').select().order('name');
    return rows.map(Category.fromJson).toList();
  }

  /// Serviços ativos, com nome do profissional e reputação.
  Future<List<Service>> activeServices({int? categoryId, String? query}) async {
    var q = _client.from('services').select(_select).eq('is_active', true);
    if (categoryId != null) q = q.eq('category_id', categoryId);
    final text = query?.trim() ?? '';
    if (text.isNotEmpty) {
      final pattern = '%${text.replaceAll('%', '')}%';
      q = q.or('title.ilike.$pattern,description.ilike.$pattern');
    }
    final rows = await q.order('created_at', ascending: false);
    return _attachRatings(rows.map(Service.fromJson).toList());
  }

  Future<Service> byId(String id) async {
    final row =
        await _client.from('services').select(_select).eq('id', id).single();
    final list = await _attachRatings([Service.fromJson(row)]);
    return list.first;
  }

  Future<List<Service>> myServices(String professionalId) async {
    final rows = await _client
        .from('services')
        .select(_select)
        .eq('professional_id', professionalId)
        .order('is_active', ascending: false)
        .order('created_at', ascending: false);
    return _attachRatings(rows.map(Service.fromJson).toList());
  }

  Future<void> create(Service service) =>
      _client.from('services').insert(service.toInsertJson());

  Future<void> update(Service service) =>
      _client.from('services').update(service.toInsertJson()).eq('id', service.id);

  Future<void> setActive(String id, bool active) =>
      _client.from('services').update({'is_active': active}).eq('id', id);

  Future<List<Service>> _attachRatings(List<Service> services) async {
    if (services.isEmpty) return services;
    final ids = services.map((s) => s.professionalId).toSet().toList();
    final rows = await _client
        .from('professional_ratings')
        .select()
        .inFilter('professional_id', ids);
    final byPro = {
      for (final r in rows)
        r['professional_id'] as String: (
          avg: (r['avg_rating'] as num?)?.toDouble(),
          count: (r['review_count'] as int?) ?? 0,
        ),
    };
    return [
      for (final s in services)
        if (byPro[s.professionalId] case final r?)
          s.withRating(avgRating: r.avg, reviewCount: r.count)
        else
          s,
    ];
  }
}
