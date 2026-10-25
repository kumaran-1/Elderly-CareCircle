import 'package:carecircle_mobile/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveApiBaseUrl', () {
    test('prefers the compile-time URL and strips trailing slashes', () {
      expect(
        resolveApiBaseUrl(
          buildTimeUrl: 'https://api.example.com/',
          storedOverride: 'https://other.example.com',
          isRelease: true,
        ),
        'https://api.example.com',
      );
    });

    test('falls back to the stored runtime override', () {
      expect(
        resolveApiBaseUrl(buildTimeUrl: '', storedOverride: 'https://cloud.example.com/api', isRelease: true),
        'https://cloud.example.com/api',
      );
    });

    test('uses the development default in debug builds only', () {
      expect(
        resolveApiBaseUrl(buildTimeUrl: '', storedOverride: null, isRelease: false),
        'http://10.107.221.125:4000',
      );
      expect(
        () => resolveApiBaseUrl(buildTimeUrl: '   ', storedOverride: ' ', isRelease: true),
        throwsStateError,
      );
    });

    test('rejects non-absolute and non-http URLs', () {
      expect(() => resolveApiBaseUrl(buildTimeUrl: 'not-a-url', isRelease: false), throwsArgumentError);
      expect(() => resolveApiBaseUrl(buildTimeUrl: 'ftp://x.example.com', isRelease: false), throwsArgumentError);
    });

    test('rejects cleartext http outside loopback in release builds', () {
      expect(
        () => resolveApiBaseUrl(buildTimeUrl: 'http://10.0.0.5:4000', isRelease: true),
        throwsArgumentError,
      );
      expect(
        resolveApiBaseUrl(buildTimeUrl: 'http://127.0.0.1:4000', isRelease: true),
        'http://127.0.0.1:4000',
      );
      expect(
        resolveApiBaseUrl(buildTimeUrl: 'http://10.0.0.5:4000', isRelease: false),
        'http://10.0.0.5:4000',
      );
    });
  });

  group('validateApiBaseUrl', () {
    test('normalizes and accepts loopback http', () {
      expect(validateApiBaseUrl('  http://localhost:4000/  ', isRelease: true), 'http://localhost:4000');
    });
  });
}
