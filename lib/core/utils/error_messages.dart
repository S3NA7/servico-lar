import 'package:supabase_flutter/supabase_flutter.dart';

/// Converte exceções do Supabase em mensagens amigáveis em português.
String friendlyError(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (msg.contains('already registered')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (msg.contains('password')) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case '23P01':
        return 'Esse horário acabou de ser ocupado. Escolha outro.';
      case '42501':
        return 'Você não tem permissão para esta ação.';
      case '23505':
        return 'Registro duplicado.';
    }
    // Mensagens lançadas pelos nossos triggers/funções já vêm em português.
    return error.message;
  }
  return 'Algo deu errado. Tente novamente.';
}
