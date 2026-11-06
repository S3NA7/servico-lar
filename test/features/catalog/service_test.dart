import 'package:flutter_test/flutter_test.dart';
import 'package:servico_lar/features/catalog/domain/category.dart';
import 'package:servico_lar/features/catalog/domain/service.dart';

void main() {
  final json = {
    'id': 's1',
    'professional_id': 'p1',
    'category_id': 3,
    'title': 'Troca de tomadas',
    'description': 'Até 5 pontos',
    'base_price': '120.00',
    'duration_minutes': 90,
    'is_active': true,
    'professional': {'id': 'p1', 'full_name': 'Carlos Eletricista'},
    'category': {'id': 3, 'name': 'Elétrica', 'slug': 'eletrica', 'icon': 'electrical_services'},
  };

  group('Service', () {
    test('fromJson lê joins aninhados e preço numérico em string', () {
      final s = Service.fromJson(json);
      expect(s.id, 's1');
      expect(s.professionalName, 'Carlos Eletricista');
      expect(s.category?.name, 'Elétrica');
      expect(s.basePrice, 120.0);
      expect(s.durationMinutes, 90);
      expect(s.isActive, isTrue);
      expect(s.avgRating, isNull);
      expect(s.reviewCount, 0);
    });

    test('priceLabel formata em reais e durationLabel em horas', () {
      final s = Service.fromJson(json);
      expect(s.priceLabel.replaceAll(' ', ' '), 'R\$ 120,00');
      expect(s.durationLabel, '1h30');
    });

    test('toInsertJson envia só colunas da tabela', () {
      final s = Service.fromJson(json);
      final out = s.toInsertJson();
      expect(out.keys, containsAll(['professional_id', 'category_id', 'title',
          'description', 'base_price', 'duration_minutes', 'is_active']));
      expect(out.containsKey('professional'), isFalse);
      expect(out.containsKey('id'), isFalse);
    });

    test('withRating preenche média e total', () {
      final s = Service.fromJson(json).withRating(avgRating: 4.5, reviewCount: 8);
      expect(s.avgRating, 4.5);
      expect(s.reviewCount, 8);
      expect(s.ratingLabel, '4,5 (8)');
    });
  });

  group('Category', () {
    test('ícone desconhecido cai no padrão', () {
      final c = Category.fromJson({'id': 1, 'name': 'X', 'slug': 'x', 'icon': 'nao_existe'});
      expect(c.iconData, Category.fallbackIcon);
    });
  });
}
