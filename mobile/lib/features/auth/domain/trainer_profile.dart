/// Perfil do personal logado (`GET /api/v1/trainers/me`).
class TrainerProfile {
  const TrainerProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.phone,
  });

  final int id;
  final String email;
  final String displayName;
  final String? phone;

  factory TrainerProfile.fromJson(Map<String, dynamic> json) => TrainerProfile(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
            ? json['displayName'] as String
            : json['email'] as String,
        phone: json['phone'] as String?,
      );
}
