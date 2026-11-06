enum UserRole {
  client,
  professional;

  static UserRole fromDb(String? value) =>
      value == 'professional' ? professional : client;

  String get dbValue => name;

  String get label => switch (this) {
        client => 'Cliente',
        professional => 'Profissional',
      };
}
