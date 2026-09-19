class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.email,
    required this.name,
    this.goal,
    this.height,
    this.weight,
  });

  final int id;
  final String email;
  final String name;
  final String? goal;
  final double? height;
  final double? weight;

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        name: json['name'] as String,
        goal: json['goal'] as String?,
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
      );
}
