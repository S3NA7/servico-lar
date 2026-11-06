import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_role.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// O perfil é criado por trigger no banco a partir de `full_name` e `role`.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) =>
      _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role.dbValue},
      );

  Future<void> signOut() => _client.auth.signOut();
}
