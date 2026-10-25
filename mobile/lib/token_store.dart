import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  TokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _accessKey = 'carecircle_access_token';
  static const _refreshKey = 'carecircle_refresh_token';
  static const _emailKey = 'carecircle_email';

  Future<void> save({required String email, required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<Map<String, String?>> read() async {
    return {
      'email': await _storage.read(key: _emailKey),
      'accessToken': await _storage.read(key: _accessKey),
      'refreshToken': await _storage.read(key: _refreshKey),
    };
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
