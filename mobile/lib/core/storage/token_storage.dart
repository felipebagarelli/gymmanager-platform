import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  const StoredSession({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

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

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final token = await _storage.read(key: _tokenKey);
    final expires = await _storage.read(key: _expiresKey);
    if (token == null || expires == null) return null;
    final expiresAt = DateTime.tryParse(expires);
    if (expiresAt == null) return null;
    return StoredSession(token: token, expiresAt: expiresAt);
  }

  @override
  Future<void> save(StoredSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(
      key: _expiresKey,
      value: session.expiresAt.toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresKey);
  }
}
