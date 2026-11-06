import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/request_status.dart';
import '../domain/service_request.dart';

class BookingsRepository {
  BookingsRepository(this._client);

  final SupabaseClient _client;

  /// Cria a solicitação via RPC; o banco calcula o fim, valida a agenda e
  /// impede sobreposição (erro 23P01).
  Future<void> create({
    required String serviceId,
    required DateTime startsAt,
    String? note,
  }) =>
      _client.rpc('create_service_request', params: {
        'p_service_id': serviceId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_note': note,
      });

  Future<List<ServiceRequest>> mine(String clientId) async {
    final rows = await _client
        .from('service_requests')
        .select(ServiceRequest.select)
        .eq('client_id', clientId)
        .order('starts_at', ascending: false);
    return rows.map(ServiceRequest.fromJson).toList();
  }

  Future<List<ServiceRequest>> received(String professionalId) async {
    final rows = await _client
        .from('service_requests')
        .select(ServiceRequest.select)
        .eq('professional_id', professionalId)
        .order('starts_at', ascending: false);
    return rows.map(ServiceRequest.fromJson).toList();
  }

  Future<void> updateStatus(String id, RequestStatus status) => _client
      .from('service_requests')
      .update({'status': status.dbValue}).eq('id', id);

  /// Marca como expiradas as pendentes vencidas. Retorna quantas mudaram.
  Future<int> expirePending() async {
    final result = await _client.rpc('expire_pending_requests');
    return (result as num?)?.toInt() ?? 0;
  }
}
