/// Intervalo meio-aberto `[start, end)`.
class TimeRange {
  TimeRange(this.start, this.end)
      : assert(end.isAfter(start), 'end deve ser depois de start');

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  /// Dois intervalos encostados (`a.end == b.start`) não se sobrepõem.
  bool overlaps(TimeRange other) =>
      start.isBefore(other.end) && other.start.isBefore(end);

  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is TimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeRange($start → $end)';
}
