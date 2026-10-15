import 'package:dio/dio.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/features/auth/data/auth_repository.dart';
import 'package:gymmanager_mobile/features/auth/domain/student_profile.dart';
import 'package:gymmanager_mobile/features/auth/domain/trainer_profile.dart';

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> save(StoredSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

const testProfile = StudentProfile(id: 2, email: 'aluno@example.com', name: 'Maria Aluna');

const testTrainer = TrainerProfile(id: 5, email: 'joao@example.com', displayName: 'João Personal', phone: '11 99999-0000');

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.role = 'STUDENT', this.loginError, this.profile = testProfile, this.trainer = testTrainer})
      : super(Dio());

  final String role;
  final Object? loginError;
  final StudentProfile profile;
  final TrainerProfile trainer;
  int loginCalls = 0;
  int studentMeCalls = 0;
  int trainerMeCalls = 0;

  @override
  Future<LoginResult> login(String email, String password) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    return LoginResult(token: 'jwt-token', expiresInSeconds: 3600, role: role);
  }

  @override
  Future<StudentProfile> me() async {
    studentMeCalls++;
    return profile;
  }

  @override
  Future<TrainerProfile> trainerMe() async {
    trainerMeCalls++;
    return trainer;
  }
}

class StoredSessionFactory {
  static StoredSession valid(String token) =>
      StoredSession(token: token, expiresAt: DateTime.now().add(const Duration(hours: 1)));
}
