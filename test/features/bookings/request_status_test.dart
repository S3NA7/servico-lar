import 'package:flutter_test/flutter_test.dart';
import 'package:servico_lar/features/bookings/domain/request_status.dart';
import 'package:servico_lar/features/bookings/domain/service_request.dart';

void main() {
  final start = DateTime(2026, 11, 9, 9);
  final before = DateTime(2026, 11, 8, 12);
  final after = DateTime(2026, 11, 9, 10, 30);

  group('RequestStatus', () {
    test('labels em português', () {
      expect(RequestStatus.pending.label, 'Pendente');
      expect(RequestStatus.accepted.label, 'Aceita');
      expect(RequestStatus.rejected.label, 'Recusada');
      expect(RequestStatus.completed.label, 'Concluída');
      expect(RequestStatus.cancelled.label, 'Cancelada');
      expect(RequestStatus.expired.label, 'Expirada');
    });

    test('fromDb é tolerante e dbValue é o nome', () {
      expect(RequestStatus.fromDb('accepted'), RequestStatus.accepted);
      expect(RequestStatus.fromDb('xyz'), RequestStatus.pending);
      expect(RequestStatus.completed.dbValue, 'completed');
    });

    test('isActive só para pending e accepted', () {
      expect(RequestStatus.pending.isActive, isTrue);
      expect(RequestStatus.accepted.isActive, isTrue);
      for (final s in [
        RequestStatus.rejected,
        RequestStatus.completed,
        RequestStatus.cancelled,
        RequestStatus.expired,
      ]) {
        expect(s.isActive, isFalse, reason: s.name);
      }
    });

    test('cliente cancela pendente sempre e aceita só antes do início', () {
      expect(RequestStatus.pending.canClientCancel(now: after, startsAt: start),
          isTrue);
      expect(RequestStatus.accepted.canClientCancel(now: before, startsAt: start),
          isTrue);
      expect(RequestStatus.accepted.canClientCancel(now: after, startsAt: start),
          isFalse);
      expect(RequestStatus.completed.canClientCancel(now: before, startsAt: start),
          isFalse);
    });

    test('profissional responde só pendente e cancela aceita antes do início',
        () {
      expect(RequestStatus.pending.canProfessionalRespond, isTrue);
      expect(RequestStatus.accepted.canProfessionalRespond, isFalse);
      expect(
          RequestStatus.accepted
              .canProfessionalCancel(now: before, startsAt: start),
          isTrue);
      expect(
          RequestStatus.accepted
              .canProfessionalCancel(now: after, startsAt: start),
          isFalse);
      expect(
          RequestStatus.pending.canProfessionalCancel(now: before, startsAt: start),
          isFalse);
    });

    test('conclui só aceita e depois do início', () {
      expect(RequestStatus.accepted.canComplete(now: after, startsAt: start),
          isTrue);
      expect(RequestStatus.accepted.canComplete(now: before, startsAt: start),
          isFalse);
      expect(RequestStatus.pending.canComplete(now: after, startsAt: start),
          isFalse);
    });
  });

  group('ServiceRequest.fromJson', () {
    final json = {
      'id': 'r1',
      'service_id': 's1',
      'client_id': 'c1',
      'professional_id': 'p1',
      'starts_at': '2026-11-09T12:00:00+00:00',
      'ends_at': '2026-11-09T13:00:00+00:00',
      'status': 'completed',
      'note': 'Portão azul',
      'respond_by': '2026-11-08T12:00:00+00:00',
      'created_at': '2026-11-07T12:00:00+00:00',
      'service': {'id': 's1', 'title': 'Troca de tomadas', 'base_price': 120, 'duration_minutes': 60},
      'client': {'id': 'c1', 'full_name': 'Marina'},
      'professional': {'id': 'p1', 'full_name': 'Carlos'},
      'review': [{'id': 'rev1'}],
    };

    test('lê joins e detecta avaliação existente', () {
      final r = ServiceRequest.fromJson(json);
      expect(r.serviceTitle, 'Troca de tomadas');
      expect(r.clientName, 'Marina');
      expect(r.professionalName, 'Carlos');
      expect(r.status, RequestStatus.completed);
      expect(r.hasReview, isTrue);
      expect(r.endsAt.difference(r.startsAt), const Duration(hours: 1));
      expect(r.servicePrice, 120.0);
    });

    test('sem avaliação quando review é lista vazia ou null', () {
      expect(ServiceRequest.fromJson({...json, 'review': []}).hasReview, isFalse);
      expect(ServiceRequest.fromJson({...json, 'review': null}).hasReview, isFalse);
      expect(ServiceRequest.fromJson({...json, 'review': {'id': 'x'}}).hasReview, isTrue);
    });
  });
}
