import 'package:dio/dio.dart';
import 'package:gymmanager_mobile/core/storage/token_storage.dart';
import 'package:gymmanager_mobile/features/auth/data/auth_repository.dart';
import 'package:gymmanager_mobile/features/auth/domain/student_profile.dart';

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

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.role = 'STUDENT', this.loginError, this.profile = testProfile})
      : super(Dio());

  final String role;
  final Object? loginError;
  final StudentProfile profile;
  int loginCalls = 0;

  @override
  Future<LoginResult> login(String email, String password) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    return LoginResult(token: 'jwt-token', expiresInSeconds: 3600, role: role);
  }

  @override
  Future<StudentProfile> me() async => profile;
}

class StoredSessionFactory {
  static StoredSession valid(String token) =>
      StoredSession(token: token, expiresAt: DateTime.now().add(const Duration(hours: 1)));
}
