import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_lar/features/auth/presentation/login_screen.dart';

void main() {
  Widget build() => const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      );

  testWidgets('mostra erro para e-mail inválido e senha curta', (tester) async {
    await tester.pumpWidget(build());

    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'abc');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(find.text('A senha deve ter pelo menos 6 caracteres'), findsOneWidget);
  });

  testWidgets('oferece link para criar conta', (tester) async {
    await tester.pumpWidget(build());
    expect(find.textContaining('Criar conta'), findsOneWidget);
  });
}
