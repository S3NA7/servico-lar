/// Configuração de ambiente.
///
/// Os valores padrão apontam para o Supabase local (`supabase start`).
/// Para um projeto na nuvem, rode com:
/// `flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_...`
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  /// Chave publicável (ou anon key legada). Não é segredo: vai no app.
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: _localPublishableKey,
  );

  /// Chave padrão do Supabase local, igual em qualquer máquina.
  static const _localPublishableKey =
      'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
}
