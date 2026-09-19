import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/student_profile.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));

/// Estado: perfil do aluno logado, ou null quando deslogado.
class AuthController extends AsyncNotifier<StudentProfile?> {
  @override
  Future<StudentProfile?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final stored = await storage.read();
    if (stored == null) return null;
    if (stored.isExpired) {
      await storage.clear();
      return null;
    }
    try {
      return await ref.read(authRepositoryProvider).me();
    } on AppException {
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    final repository = ref.read(authRepositoryProvider);
    final storage = ref.read(tokenStorageProvider);

    final result = await repository.login(email, password);
    if (result.role != 'STUDENT') {
      throw AppException(
        'Este aplicativo é exclusivo para alunos. Use o painel web.',
      );
    }

    await storage.save(
      StoredSession(
        token: result.token,
        expiresAt: DateTime.now().add(Duration(seconds: result.expiresInSeconds)),
      ),
    );

    try {
      state = AsyncData(await repository.me());
    } on AppException {
      await storage.clear();
      rethrow;
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
    AsyncNotifierProvider<AuthController, StudentProfile?>(AuthController.new);
