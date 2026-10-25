import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_store.dart';

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client, TokenStore? tokenStore})
      : _client = client ?? http.Client(),
        tokenStore = tokenStore ?? TokenStore();

  final String baseUrl;
  final http.Client _client;
  final TokenStore tokenStore;
  String? accessToken;
  String? otpCode;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<Map<String, dynamic>> health() async {
    final response = await _client.get(Uri.parse('$baseUrl/health'));
    return _decode(response);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final payload = _decode(response);
    final tokens = payload['tokens'] as Map<String, dynamic>?;
    accessToken = tokens?['accessToken'] as String?;
    final refreshToken = tokens?['refreshToken'] as String?;
    if (accessToken != null && refreshToken != null) {
      await tokenStore.save(email: email, accessToken: accessToken!, refreshToken: refreshToken);
    }
    return payload;
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    final payload = _decode(response);
    final tokens = payload['tokens'] as Map<String, dynamic>?;
    accessToken = tokens?['accessToken'] as String?;
    final refreshToken = tokens?['refreshToken'] as String?;
    if (accessToken != null && refreshToken != null) {
      await tokenStore.save(email: email, accessToken: accessToken!, refreshToken: refreshToken);
    }
    return payload;
  }

  Future<bool> restoreSession() async {
    final stored = await tokenStore.read();
    accessToken = stored['accessToken'];
    final refreshToken = stored['refreshToken'];

    if (accessToken == null || refreshToken == null) {
      return false;
    }

    try {
      await me();
      return true;
    } catch (_) {
      return await refreshSession(refreshToken);
    }
  }

  Future<bool> refreshSession(String refreshToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode >= 400) {
      await tokenStore.clear();
      accessToken = null;
      return false;
    }

    final payload = _decode(response);
    final tokens = payload['tokens'] as Map<String, dynamic>?;
    accessToken = tokens?['accessToken'] as String?;
    final saved = await tokenStore.read();
    final email = saved['email'];
    final nextRefresh = tokens?['refreshToken'] as String?;
    if (email != null && accessToken != null && nextRefresh != null) {
      await tokenStore.save(email: email, accessToken: accessToken!, refreshToken: nextRefresh);
    }
    return accessToken != null;
  }

  Future<void> signOut() async {
    accessToken = null;
    await tokenStore.clear();
  }

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _client.get(Uri.parse('$baseUrl/dashboard'), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _client.get(Uri.parse('$baseUrl/me'), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> notifications() async {
    final response = await _client.get(Uri.parse('$baseUrl/notifications'), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> reportSummary(String elderId, {String period = 'weekly'}) async {
    final response = await _client.get(Uri.parse('$baseUrl/reports/summary/$elderId?period=$period'), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> logVital({
    required String elderId,
    required String type,
    required double value,
    required String unit,
    double? systolic,
    double? diastolic,
  }) async {
    return _post('/health/vitals', {
      'elderId': elderId,
      'type': type,
      'value': value,
      'unit': unit,
      if (systolic != null) 'systolic': systolic,
      if (diastolic != null) 'diastolic': diastolic,
    });
  }

  Future<Map<String, dynamic>> logHydration({required String elderId, required double amountMl}) async {
    return _post('/hydration/logs', {'elderId': elderId, 'amountMl': amountMl});
  }

  Future<Map<String, dynamic>> medicationSummary(String elderId) async {
    final response = await _client.get(Uri.parse('$baseUrl/medications/summary/$elderId'), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> myCareCircles() async {
    final response = await _client.get(Uri.parse('$baseUrl/care-circles/me'), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> createAppointment({
    required String elderId,
    required String doctorName,
    required String specialty,
    required String dateTime,
  }) async {
    return _post('/appointments', {
      'elderId': elderId,
      'doctorName': doctorName,
      'specialty': specialty,
      'dateTime': dateTime,
    });
  }

  Future<Map<String, dynamic>> logExercise({required String elderId, required String activityType, required double minutes}) async {
    return _post('/exercise/logs', {'elderId': elderId, 'activityType': activityType, 'minutes': minutes});
  }

  Future<Map<String, dynamic>> askAi({String? elderId, required String question}) async {
    return _post('/ai/chat', {'question': question, if (elderId != null) 'elderId': elderId});
  }

  Future<Map<String, dynamic>> triggerSos({required String elderId, String? location}) async {
    return _post('/sos', {'elderId': elderId, if (location != null) 'location': location});
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message']?.toString() ?? 'Request failed.');
    }
    return data;
  }
}
