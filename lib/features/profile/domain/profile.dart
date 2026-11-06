import '../../auth/domain/user_role.dart';

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.bio,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? bio;

  bool get isProfessional => role == UserRole.professional;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        role: UserRole.fromDb(json['role'] as String?),
        phone: json['phone'] as String?,
        bio: json['bio'] as String?,
      );

  /// Apenas os campos que o próprio usuário pode editar.
  Map<String, dynamic> toUpdateJson() => {
        'full_name': fullName,
        'phone': phone,
        'bio': bio,
      };

  Profile copyWith({String? fullName, String? phone, String? bio}) => Profile(
        id: id,
        fullName: fullName ?? this.fullName,
        role: role,
        phone: phone ?? this.phone,
        bio: bio ?? this.bio,
      );
}
