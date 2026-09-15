import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Refresh-token persistence only — Android Keystore-backed
/// (SEC-ID-05/06, SRS §4.8). The access token never touches disk; it's kept
/// in memory by [AuthController] only.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = 'thunderid_refresh_token';

  final FlutterSecureStorage _storage;

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clear() => _storage.delete(key: _refreshTokenKey);
}
