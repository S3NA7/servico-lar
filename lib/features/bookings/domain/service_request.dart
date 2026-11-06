import 'request_status.dart';

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.servicePrice,
    required this.clientId,
    required this.clientName,
    required this.professionalId,
    required this.professionalName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.note,
    required this.respondBy,
    required this.createdAt,
    this.hasReview = false,
  });

  final String id;
  final String serviceId;
  final String serviceTitle;
  final double servicePrice;
  final String clientId;
  final String clientName;
  final String professionalId;
  final String professionalName;
  final DateTime startsAt;
  final DateTime endsAt;
  final RequestStatus status;
  final String? note;
  final DateTime respondBy;
  final DateTime createdAt;
  final bool hasReview;

  static const select = '*, '
      'service:services(id, title, base_price, duration_minutes), '
      'client:profiles!service_requests_client_id_fkey(id, full_name), '
      'professional:profiles!service_requests_professional_id_fkey(id, full_name), '
      'review:reviews(id)';

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    final service = json['service'] as Map<String, dynamic>?;
    final client = json['client'] as Map<String, dynamic>?;
    final professional = json['professional'] as Map<String, dynamic>?;
    final review = json['review'];
    final hasReview = switch (review) {
      List l => l.isNotEmpty,
      Map _ => true,
      _ => false,
    };
    return ServiceRequest(
      id: json['id'] as String,
      serviceId: json['service_id'] as String,
      serviceTitle: (service?['title'] as String?) ?? 'Serviço',
      servicePrice: _toDouble(service?['base_price']),
      clientId: json['client_id'] as String,
      clientName: (client?['full_name'] as String?) ?? '',
      professionalId: json['professional_id'] as String,
      professionalName: (professional?['full_name'] as String?) ?? '',
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      status: RequestStatus.fromDb(json['status'] as String?),
      note: json['note'] as String?,
      respondBy: DateTime.parse(json['respond_by'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      hasReview: hasReview,
    );
  }

  bool get canBeReviewed => status == RequestStatus.completed && !hasReview;

  static double _toDouble(Object? v) => switch (v) {
        num n => n.toDouble(),
        String s => double.tryParse(s) ?? 0,
        _ => 0,
      };
}
