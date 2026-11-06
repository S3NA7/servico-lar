import 'time_range.dart';

/// Bloqueio pontual (folga, compromisso) na agenda de um profissional.
class AvailabilityBlock {
  const AvailabilityBlock({
    required this.id,
    required this.range,
    this.reason,
  });

  final String id;
  final TimeRange range;
  final String? reason;

  factory AvailabilityBlock.fromJson(Map<String, dynamic> json) =>
      AvailabilityBlock(
        id: json['id'] as String,
        range: TimeRange(
          DateTime.parse(json['starts_at'] as String).toLocal(),
          DateTime.parse(json['ends_at'] as String).toLocal(),
        ),
        reason: json['reason'] as String?,
      );
}
