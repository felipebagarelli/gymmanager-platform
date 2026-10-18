import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/student_profile.dart';
import '../domain/trainer_profile.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));

/// Estado: usuário logado (aluno ou personal), ou null quando deslogado.
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final stored = await storage.read();
    if (stored == null) return null;
    if (stored.isExpired) {
      await storage.clear();
      return null;
    }
    try {
      // sessão sem papel guardado vem de antes do modo personal, quando só alunos entravam
      return await _loadUser(stored.role ?? UserRole.student);
    } on AppException {
      return null;
    }
  }

  Future<AppUser> _loadUser(String role) async {
    final repository = ref.read(authRepositoryProvider);
    return switch (role) {
      UserRole.trainer => TrainerUser(await repository.trainerMe()),
      _ => StudentUser(await repository.me()),
    };
  }

  Future<void> login(String email, String password) async {
    final repository = ref.read(authRepositoryProvider);
    final storage = ref.read(tokenStorageProvider);
    final result = await repository.login(email, password);
    if (result.role != UserRole.student && result.role != UserRole.trainer) {
      // administração da plataforma fica no painel web
      throw AppException('Esta conta é de administração. Use o painel web.');
    }
    await storage.save(
      StoredSession(
        token: result.token,
        expiresAt: DateTime.now().add(Duration(seconds: result.expiresInSeconds)),
        role: result.role,
      ),
    );
    try {
      state = AsyncData(await _loadUser(result.role));
    } on AppException {
      await storage.clear();
      rethrow;
    }
  }

  /// Relê os dados do usuário logado (ex.: o pagamento ao personal foi confirmado e o aluno ganhou um vínculo).
  Future<void> refreshUser() async {
    final stored = await ref.read(tokenStorageProvider).read();
    if (stored == null || state.value == null) return;
    try {
      state = AsyncData(await _loadUser(stored.role ?? UserRole.student));
    } on AppException {
      // sem conexão: mantém o que já tinha
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }

  void sessionExpired() {
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

/// Perfil do aluno logado; null se ninguém estiver logado ou se o usuário for personal.
final currentStudentProvider = Provider<StudentProfile?>((ref) => switch (ref.watch(authControllerProvider).value) {
      StudentUser(:final profile) => profile,
      _ => null,
    });

/// Perfil do personal logado; null se ninguém estiver logado ou se o usuário for aluno.
final currentTrainerProvider = Provider<TrainerProfile?>((ref) => switch (ref.watch(authControllerProvider).value) {
      TrainerUser(:final profile) => profile,
      _ => null,
    });
