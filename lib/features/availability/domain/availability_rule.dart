/// Intervalo habitual de atendimento em um dia da semana.
///
/// `weekday` segue [DateTime.weekday] (1 = segunda … 7 = domingo).
/// No banco o dia é guardado como no Postgres (0 = domingo … 6 = sábado).
class AvailabilityRule {
  const AvailabilityRule({
    this.id,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
  })  : assert(weekday >= 1 && weekday <= 7),
        assert(endMinutes > startMinutes);

  final String? id;
  final int weekday;

  /// Minutos desde a meia-noite (08:30 = 510).
  final int startMinutes;
  final int endMinutes;

  factory AvailabilityRule.fromJson(Map<String, dynamic> json) {
    return AvailabilityRule(
      id: json['id'] as String?,
      weekday: dbWeekdayToDart(json['weekday'] as int),
      startMinutes: _parseTime(json['start_time'] as String),
      endMinutes: _parseTime(json['end_time'] as String),
    );
  }

  Map<String, dynamic> toJson(String professionalId) => {
        if (id != null) 'id': id,
        'professional_id': professionalId,
        'weekday': dartWeekdayToDb(weekday),
        'start_time': formatMinutes(startMinutes, withSeconds: true),
        'end_time': formatMinutes(endMinutes, withSeconds: true),
      };

  String get label =>
      '${formatMinutes(startMinutes)} – ${formatMinutes(endMinutes)}';

  AvailabilityRule copyWith({
    String? id,
    int? weekday,
    int? startMinutes,
    int? endMinutes,
  }) =>
      AvailabilityRule(
        id: id ?? this.id,
        weekday: weekday ?? this.weekday,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
      );

  static int dbWeekdayToDart(int db) => db == 0 ? DateTime.sunday : db;
  static int dartWeekdayToDb(int dart) => dart == DateTime.sunday ? 0 : dart;

  static int _parseTime(String hhmmss) {
    final parts = hhmmss.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String formatMinutes(int minutes, {bool withSeconds = false}) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return withSeconds ? '$h:$m:00' : '$h:$m';
  }

  static const weekdayNames = {
    DateTime.monday: 'Segunda-feira',
    DateTime.tuesday: 'Terça-feira',
    DateTime.wednesday: 'Quarta-feira',
    DateTime.thursday: 'Quinta-feira',
    DateTime.friday: 'Sexta-feira',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };

  @override
  bool operator ==(Object other) =>
      other is AvailabilityRule &&
      other.id == id &&
      other.weekday == weekday &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(id, weekday, startMinutes, endMinutes);
}
