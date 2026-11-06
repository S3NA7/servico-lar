enum RequestStatus {
  pending,
  accepted,
  rejected,
  completed,
  cancelled,
  expired;

  static RequestStatus fromDb(String? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => pending);

  String get dbValue => name;

  String get label => switch (this) {
        pending => 'Pendente',
        accepted => 'Aceita',
        rejected => 'Recusada',
        completed => 'Concluída',
        cancelled => 'Cancelada',
        expired => 'Expirada',
      };

  /// Ocupa a agenda do profissional.
  bool get isActive => this == pending || this == accepted;

  bool get canProfessionalRespond => this == pending;

  /// Cliente cancela pendentes a qualquer momento e aceitas antes do início.
  bool canClientCancel({required DateTime now, required DateTime startsAt}) =>
      this == pending || (this == accepted && now.isBefore(startsAt));

  /// Profissional só cancela atendimentos aceitos, antes do início.
  bool canProfessionalCancel(
          {required DateTime now, required DateTime startsAt}) =>
      this == accepted && now.isBefore(startsAt);

  /// Conclusão só depois do horário de início.
  bool canComplete({required DateTime now, required DateTime startsAt}) =>
      this == accepted && !now.isBefore(startsAt);
}
