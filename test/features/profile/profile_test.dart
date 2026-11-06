import 'package:flutter_test/flutter_test.dart';
import 'package:servico_lar/features/auth/domain/user_role.dart';
import 'package:servico_lar/features/profile/domain/profile.dart';

void main() {
  group('Profile.fromJson', () {
    test('mapeia role professional', () {
      final profile = Profile.fromJson({
        'id': 'abc',
        'full_name': 'Carlos Silva',
        'role': 'professional',
        'phone': '11 99999-0000',
        'bio': null,
      });
      expect(profile.id, 'abc');
      expect(profile.fullName, 'Carlos Silva');
      expect(profile.role, UserRole.professional);
      expect(profile.phone, '11 99999-0000');
      expect(profile.bio, isNull);
    });

    test('role desconhecido vira client', () {
      expect(UserRole.fromDb('qualquer'), UserRole.client);
      expect(UserRole.fromDb('client'), UserRole.client);
      expect(UserRole.professional.dbValue, 'professional');
    });

    test('toUpdateJson só envia campos editáveis', () {
      const profile = Profile(
        id: 'abc',
        fullName: 'Ana',
        role: UserRole.client,
        phone: null,
        bio: 'Oi',
      );
      expect(profile.toUpdateJson(), {
        'full_name': 'Ana',
        'phone': null,
        'bio': 'Oi',
      });
    });
  });
}
