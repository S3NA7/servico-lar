import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:servico_lar/features/auth/domain/user_role.dart';
import 'package:servico_lar/features/bookings/domain/request_status.dart';
import 'package:servico_lar/features/bookings/domain/service_request.dart';
import 'package:servico_lar/features/bookings/presentation/request_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final start = DateTime(2026, 11, 9, 9);
  final before = DateTime(2026, 11, 8, 12);
  final after = DateTime(2026, 11, 9, 10, 30);

  ServiceRequest request(RequestStatus status, {bool hasReview = false}) =>
      ServiceRequest(
        id: 'r1',
        serviceId: 's1',
        serviceTitle: 'Troca de tomadas',
        servicePrice: 120,
        clientId: 'c1',
        clientName: 'Marina',
        professionalId: 'p1',
        professionalName: 'Carlos',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
        status: status,
        respondBy: start.subtract(const Duration(hours: 12)),
        createdAt: before,
        hasReview: hasReview,
      );

  Widget build(ServiceRequest r, UserRole viewer, DateTime now) => MaterialApp(
        home: Scaffold(
          body: RequestCard(
            request: r,
            viewer: viewer,
            now: now,
            onAccept: () {},
            onReject: () {},
            onCancel: () {},
            onComplete: () {},
            onReview: () {},
          ),
        ),
      );

  testWidgets('pendente: cliente vê Cancelar; profissional vê Aceitar/Recusar',
      (tester) async {
    await tester.pumpWidget(build(request(RequestStatus.pending), UserRole.client, before));
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Aceitar'), findsNothing);
    expect(find.text('Pendente'), findsOneWidget);

    await tester.pumpWidget(build(request(RequestStatus.pending), UserRole.professional, before));
    expect(find.text('Aceitar'), findsOneWidget);
    expect(find.text('Recusar'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('aceita antes do início: Concluir desabilitado; depois, habilitado',
      (tester) async {
    await tester.pumpWidget(build(request(RequestStatus.accepted), UserRole.professional, before));
    final disabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Concluir'));
    expect(disabled.onPressed, isNull);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.pumpWidget(build(request(RequestStatus.accepted), UserRole.professional, after));
    final enabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Concluir'));
    expect(enabled.onPressed, isNotNull);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('concluída sem avaliação: cliente vê Avaliar; com avaliação não',
      (tester) async {
    await tester.pumpWidget(build(request(RequestStatus.completed), UserRole.client, after));
    expect(find.text('Avaliar'), findsOneWidget);

    await tester.pumpWidget(build(
        request(RequestStatus.completed, hasReview: true), UserRole.client, after));
    expect(find.text('Avaliar'), findsNothing);
    expect(find.text('Concluída'), findsOneWidget);
  });
}
