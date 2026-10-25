import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Development fallback. Never used in release builds without explicit
/// configuration (see [resolveApiBaseUrl]).
const String _devDefaultBaseUrl = 'http://10.82.148.125:4000';

const String _overrideKey = 'carecircle_api_base_url';

/// Normalizes and validates a candidate API base URL.
/// Returns the URL without trailing slashes. Throws [ArgumentError] for
/// non-absolute or non-HTTP(S) URLs, and for cleartext HTTP in release
/// builds (localhost bypassed for local testing).
String validateApiBaseUrl(String url, {bool isRelease = kReleaseMode}) {
  final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw ArgumentError('API URL must be an absolute http(s) URL.');
  }
  final host = uri.host.toLowerCase();
  final isLoopback = host == 'localhost' || host == '127.0.0.1' || host == '::1';
  if (isRelease && uri.scheme == 'http' && !isLoopback) {
    throw ArgumentError('Release builds require an https API URL.');
  }
  return normalized;
}

/// Resolves the API base URL with the following precedence:
/// 1. compile-time `--dart-define=CARECIRCLE_API_BASE_URL`
/// 2. runtime override saved in secure storage (editable in Profile)
/// 3. development LAN default (debug builds only)
///
/// Throws [StateError] in release builds when nothing is configured,
/// instead of silently pointing at a development machine.
String resolveApiBaseUrl({
  String buildTimeUrl = const String.fromEnvironment('CARECIRCLE_API_BASE_URL', defaultValue: ''),
  String? storedOverride,
  bool isRelease = kReleaseMode,
}) {
  final fromBuild = buildTimeUrl.trim();
  if (fromBuild.isNotEmpty) {
    return validateApiBaseUrl(fromBuild, isRelease: isRelease);
  }
  final stored = (storedOverride ?? '').trim();
  if (stored.isNotEmpty) {
    return validateApiBaseUrl(stored, isRelease: isRelease);
  }
  if (isRelease) {
    throw StateError(
      'API URL is not configured. Rebuild with --dart-define=CARECIRCLE_API_BASE_URL=https://your-api-host or set it in Profile > Server.',
    );
  }
  return _devDefaultBaseUrl;
}

/// Secure persistence for the runtime API URL override.
class ApiEndpointStore {
  ApiEndpointStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  Future<String?> readOverride() async {
    try {
      final value = await _storage.read(key: _overrideKey);
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    } catch (error) {
      throw Exception('Unable to read stored server URL: $error');
    }
  }

  Future<void> saveOverride(String url) async {
    final normalized = validateApiBaseUrl(url);
    try {
      await _storage.write(key: _overrideKey, value: normalized);
    } catch (error) {
      throw Exception('Unable to store server URL: $error');
    }
  }

  Future<void> clearOverride() async {
    try {
      await _storage.delete(key: _overrideKey);
    } catch (error) {
      throw Exception('Unable to clear stored server URL: $error');
    }
  }
}
