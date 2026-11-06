import 'package:flutter_test/flutter_test.dart';
import 'package:servico_lar/features/reviews/domain/review.dart';

void main() {
  group('Review', () {
    test('validateRating aceita 1 a 5 e rejeita o resto', () {
      for (final ok in [1, 2, 3, 4, 5]) {
        expect(() => Review.validateRating(ok), returnsNormally);
      }
      expect(() => Review.validateRating(0), throwsArgumentError);
      expect(() => Review.validateRating(6), throwsArgumentError);
    });

    test('fromJson lê nome do cliente do join', () {
      final r = Review.fromJson({
        'id': 'rev1',
        'request_id': 'r1',
        'professional_id': 'p1',
        'rating': 4,
        'comment': 'Muito bom',
        'created_at': '2026-11-09T15:00:00+00:00',
        'client': {'full_name': 'Marina Cliente'},
      });
      expect(r.rating, 4);
      expect(r.comment, 'Muito bom');
      expect(r.clientName, 'Marina Cliente');
      expect(r.clientFirstName, 'Marina');
    });
  });
}
