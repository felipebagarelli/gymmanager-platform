import 'student_profile.dart';
import 'trainer_profile.dart';

/// Papéis aceitos no app (o mesmo app atende aluno e personal).
abstract final class UserRole {
  static const student = 'STUDENT';
  static const trainer = 'TRAINER';
}

/// Usuário logado. O papel define o modo do app: aluno ou personal.
/// A autorização continua no backend; isto só decide a navegação.
sealed class AppUser {
  const AppUser();

  String get name;
  String get email;
}

class StudentUser extends AppUser {
  const StudentUser(this.profile);

  final StudentProfile profile;

  @override
  String get name => profile.name;

  @override
  String get email => profile.email;
}

class TrainerUser extends AppUser {
  const TrainerUser(this.profile);

  final TrainerProfile profile;

  @override
  String get name => profile.displayName;

  @override
  String get email => profile.email;
}
