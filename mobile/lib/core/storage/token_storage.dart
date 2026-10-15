import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  const StoredSession({required this.token, required this.expiresAt, this.role});

  final String token;
  final DateTime expiresAt;

  /// Papel do usuário (STUDENT ou TRAINER). Null em sessões guardadas antes do modo personal:
  /// nesse caso o app trata como aluno, que era o único papel aceito.
  final String? role;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
}

abstract class TokenStorage {
  Future<StoredSession?> read();
  Future<void> save(StoredSession session);
  Future<void> clear();
}

/// Guarda o JWT em armazenamento seguro da plataforma
/// (Keychain no iOS, Keystore no Android).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _expiresKey = 'auth_expires_at';
  static const _roleKey = 'auth_role';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final token = await _storage.read(key: _tokenKey);
    final expires = await _storage.read(key: _expiresKey);
    if (token == null || expires == null) return null;
    final expiresAt = DateTime.tryParse(expires);
    if (expiresAt == null) return null;
    return StoredSession(token: token, expiresAt: expiresAt, role: await _storage.read(key: _roleKey));
  }

  @override
  Future<void> save(StoredSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(
      key: _expiresKey,
      value: session.expiresAt.toIso8601String(),
    );
    final role = session.role;
    if (role == null) {
      await _storage.delete(key: _roleKey);
    } else {
      await _storage.write(key: _roleKey, value: role);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresKey);
    await _storage.delete(key: _roleKey);
  }
}
