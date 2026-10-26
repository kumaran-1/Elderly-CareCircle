import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'token_store.dart';

String reportPdfFileName(String period, DateTime generatedAt) {
  final normalized = period == 'monthly' ? 'monthly' : 'weekly';
  final year = generatedAt.year.toString().padLeft(4, '0');
  final month = generatedAt.month.toString().padLeft(2, '0');
  final day = generatedAt.day.toString().padLeft(2, '0');
  return 'carecircle-report-$normalized-$year$month$day.pdf';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    TokenStore? tokenStore,
    this.requestTimeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        tokenStore = tokenStore ?? TokenStore();

  final String baseUrl;
  final http.Client _client;
  final TokenStore tokenStore;
  final Duration requestTimeout;
  String? accessToken;
  String? otpCode;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> health() async {
    return _decode(await _get('/health'));
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final payload = _decode(await _post(
      '/auth/login',
      {'email': email, 'password': password},
      authenticated: false,
    ));
    await _captureTokens(payload, email);
    return payload;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await _post(
      '/auth/register',
      {'name': name, 'email': email, 'password': password, 'role': role},
      authenticated: false,
    );
    final payload = _decode(response);
    otpCode = payload['otpCode']?.toString();
    return payload;
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final payload = _decode(await _post(
      '/auth/verify-otp',
      {'email': email, 'otp': otp},
      authenticated: false,
    ));
    await _captureTokens(payload, email);
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
      return refreshSession(refreshToken);
    }
  }

  Future<bool> refreshSession(String refreshToken) async {
    try {
      final response = await _post(
        '/auth/refresh',
        {'refreshToken': refreshToken},
        authenticated: false,
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
        await tokenStore.save(
            email: email, accessToken: accessToken!, refreshToken: nextRefresh);
      }
      return accessToken != null;
    } catch (_) {
      await tokenStore.clear();
      accessToken = null;
      return false;
    }
  }

  Future<void> signOut() async {
    accessToken = null;
    await tokenStore.clear();
  }

  Future<Map<String, dynamic>> me() async => _decode(await _get('/me'));

  Future<Map<String, dynamic>> dashboard() async =>
      _decode(await _get('/dashboard'));

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required Map<String, dynamic> profile,
  }) async {
    final normalized = <String, dynamic>{};
    profile.forEach((key, value) {
      if (value != null) normalized[key] = value;
    });
    return _decode(await _put('/me', {'name': name, 'profile': normalized}));
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _decode(await _put('/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }));
  }

  Future<Map<String, dynamic>> myCareCircles() async =>
      _decode(await _get('/care-circles/me'));

  Future<Map<String, dynamic>> createCareCircle(
      {String? elderId, String? name}) async {
    return _decode(await _post('/care-circles', {
      if (elderId != null) 'elderId': elderId,
      if (name != null) 'name': name,
    }));
  }

  Future<Map<String, dynamic>> inviteToCareCircle({
    required String circleId,
    required String email,
    required String relation,
  }) async {
    return _decode(await _post('/care-circles/$circleId/invite', {
      'email': email,
      'relation': relation,
    }));
  }

  Future<Map<String, dynamic>> removeMember({
    required String circleId,
    required String userId,
  }) async {
    return _decode(await _delete('/care-circles/$circleId/members/$userId'));
  }

  Future<Map<String, dynamic>> myInvitations() async =>
      _decode(await _get('/care-circles/invitations/me'));

  Future<Map<String, dynamic>> acceptInvitation({
    required String inviteCode,
    required String relation,
  }) async {
    return _decode(await _post('/care-circles/accept', {
      'inviteCode': inviteCode,
      'relation': relation,
    }));
  }

  Future<Map<String, dynamic>> vitalsForElder(String elderId) async {
    return _decode(await _get('/health/vitals/$elderId'));
  }

  Future<Map<String, dynamic>> logVital({
    required String elderId,
    required String type,
    required double value,
    required String unit,
    double? systolic,
    double? diastolic,
  }) async {
    return _decode(await _post('/health/vitals', {
      'elderId': elderId,
      'type': type,
      'value': value,
      'unit': unit,
      if (systolic != null) 'systolic': systolic,
      if (diastolic != null) 'diastolic': diastolic,
    }));
  }

  Future<Map<String, dynamic>> medicationSummary(String elderId) async {
    return _decode(await _get('/medications/summary/$elderId'));
  }

  Future<Map<String, dynamic>> createMedication({
    required String elderId,
    required String name,
    required String dosage,
    required String frequency,
    required String reminderTime,
  }) async {
    return _decode(await _post('/medications', {
      'elderId': elderId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'reminderTime': reminderTime,
    }));
  }

  Future<Map<String, dynamic>> logMedication({
    required String elderId,
    required String medicationId,
    required String status,
  }) async {
    return _decode(await _post('/medications/$medicationId/logs', {
      'elderId': elderId,
      'status': status,
    }));
  }

  Future<Map<String, dynamic>> hydrationSummary(String elderId) async {
    return _decode(await _get('/hydration/summary/$elderId'));
  }

  Future<Map<String, dynamic>> logHydration(
      {required String elderId, required double amountMl}) async {
    return _decode(await _post(
        '/hydration/logs', {'elderId': elderId, 'amountMl': amountMl}));
  }

  Future<Map<String, dynamic>> exerciseSummary(String elderId) async {
    return _decode(await _get('/exercise/summary/$elderId'));
  }

  Future<Map<String, dynamic>> logExercise({
    required String elderId,
    required String activityType,
    required double minutes,
  }) async {
    return _decode(await _post('/exercise/logs', {
      'elderId': elderId,
      'activityType': activityType,
      'minutes': minutes,
    }));
  }

  Future<Map<String, dynamic>> appointmentsForElder(String elderId) async {
    return _decode(await _get('/appointments/$elderId'));
  }

  Future<Map<String, dynamic>> createAppointment({
    required String elderId,
    required String doctorName,
    required String specialty,
    required String dateTime,
    String? notes,
    String? followUpNotes,
    String? followUpAt,
  }) async {
    return _decode(await _post('/appointments', {
      'elderId': elderId,
      'doctorName': doctorName,
      'specialty': specialty,
      'dateTime': dateTime,
      if (notes != null) 'notes': notes,
      if (followUpNotes != null) 'followUpNotes': followUpNotes,
      if (followUpAt != null) 'followUpAt': followUpAt,
    }));
  }

  Future<Map<String, dynamic>> updateAppointment({
    required String appointmentId,
    required String elderId,
    required String doctorName,
    required String specialty,
    required String dateTime,
    String? notes,
    String? followUpNotes,
    String? followUpAt,
  }) async {
    return _decode(await _patch('/appointments/$appointmentId', {
      'elderId': elderId,
      'doctorName': doctorName,
      'specialty': specialty,
      'dateTime': dateTime,
      if (notes != null) 'notes': notes,
      if (followUpNotes != null) 'followUpNotes': followUpNotes,
      if (followUpAt != null) 'followUpAt': followUpAt,
    }));
  }

  Future<Map<String, dynamic>> cancelAppointment({
    required String appointmentId,
    required String elderId,
  }) async {
    return _decode(await _post(
        '/appointments/$appointmentId/cancel', {'elderId': elderId}));
  }

  Future<Map<String, dynamic>> createCareInstruction({
    required String elderId,
    required String title,
    required String message,
    required String priority,
    required String category,
  }) async {
    return _decode(await _post('/care-instructions', {
      'elderId': elderId,
      'title': title,
      'message': message,
      'priority': priority,
      'category': category,
    }));
  }

  Future<Map<String, dynamic>> elderInstructions(String elderId) async {
    return _decode(await _get('/care-instructions/$elderId'));
  }

  Future<Map<String, dynamic>> myInstructions() async =>
      _decode(await _get('/care-instructions'));

  Future<Map<String, dynamic>> elderMedicalRecords(String elderId) async {
    return _decode(await _get('/care-instructions/elder/$elderId'));
  }

  Future<Map<String, dynamic>> careTasks(String elderId) async {
    return _decode(await _get('/care-tasks/elder/$elderId'));
  }

  Future<Map<String, dynamic>> createCareTask({
    required String elderId,
    required String title,
    String? notes,
    String? dueAt,
    String? priority,
    String? assignedToUserId,
  }) async {
    return _decode(await _post('/care-tasks', {
      'elderId': elderId,
      'title': title,
      if (notes != null) 'notes': notes,
      if (dueAt != null) 'dueAt': dueAt,
      if (priority != null) 'priority': priority,
      if (assignedToUserId != null) 'assignedToUserId': assignedToUserId,
    }));
  }

  Future<Map<String, dynamic>> updateCareTask({
    required String taskId,
    required String elderId,
    String? status,
    String? title,
    String? notes,
    String? dueAt,
    String? priority,
    String? assignedToUserId,
  }) async {
    return _decode(await _patch('/care-tasks/$taskId', {
      'elderId': elderId,
      if (status != null) 'status': status,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (dueAt != null) 'dueAt': dueAt,
      if (priority != null) 'priority': priority,
      if (assignedToUserId != null) 'assignedToUserId': assignedToUserId,
    }));
  }

  Future<Map<String, dynamic>> careNotes(String elderId) async {
    return _decode(await _get('/care-notes/elder/$elderId'));
  }

  Future<Map<String, dynamic>> createCareNote({
    required String elderId,
    required String type,
    required String title,
    required String body,
    String? shift,
  }) async {
    return _decode(await _post('/care-notes', {
      'elderId': elderId,
      'type': type,
      'title': title,
      'body': body,
      if (shift != null) 'shift': shift,
    }));
  }

  Future<Map<String, dynamic>> askAi(
      {String? elderId, required String question}) async {
    return _decode(await _post('/ai/chat', {
      'question': question,
      if (elderId != null) 'elderId': elderId,
    }));
  }

  Future<Map<String, dynamic>> aiConversations() async =>
      _decode(await _get('/ai/conversations'));

  Future<Map<String, dynamic>> notifications() async =>
      _decode(await _get('/notifications'));

  Future<Map<String, dynamic>> markNotificationRead(
      String notificationId) async {
    return _decode(await _post('/notifications/$notificationId/read', {}));
  }

  Future<Map<String, dynamic>> registerDevice(String token) async {
    return _decode(await _post('/notifications/device', {'token': token}));
  }

  Future<Map<String, dynamic>> sosEvents() async => _decode(await _get('/sos'));

  Future<Map<String, dynamic>> triggerSos(
      {required String elderId, String? location}) async {
    return _decode(await _post('/sos', {
      'elderId': elderId,
      if (location != null) 'location': location,
    }));
  }

  Future<Map<String, dynamic>> acknowledgeSos(String eventId) async {
    return _decode(await _post('/sos/$eventId/acknowledge', {}));
  }

  Future<Map<String, dynamic>> resolveSos(String eventId) async {
    return _decode(await _post('/sos/$eventId/resolve', {}));
  }

  Future<Map<String, dynamic>> reportSummary(String elderId,
      {String period = 'weekly'}) async {
    final safePeriod = period == 'monthly' ? 'monthly' : 'weekly';
    return _decode(await _get('/reports/summary/$elderId?period=$safePeriod'));
  }

  Future<Uint8List> downloadReportPdf(String elderId,
      {String period = 'weekly'}) async {
    final safePeriod = period == 'monthly' ? 'monthly' : 'weekly';
    try {
      final response = await _client
          .get(_uri('/reports/summary/$elderId/pdf?period=$safePeriod'),
              headers: _headers)
          .timeout(requestTimeout);
      if (response.statusCode >= 400) {
        _decode(response);
        throw Exception('Report download failed.');
      }
      final bytes = response.bodyBytes;
      if (bytes.length < 4 ||
          String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
        throw Exception('Server did not return a PDF report.');
      }
      return bytes;
    } on TimeoutException {
      throw Exception('Report download timed out. Please try again.');
    } on http.ClientException {
      throw Exception(
          'Unable to reach the CareCircle server. Check your connection.');
    }
  }

  Future<void> _captureTokens(
      Map<String, dynamic> payload, String email) async {
    final tokens = payload['tokens'] as Map<String, dynamic>?;
    accessToken = tokens?['accessToken'] as String?;
    final refreshToken = tokens?['refreshToken'] as String?;
    if (accessToken != null && refreshToken != null) {
      await tokenStore.save(
          email: email, accessToken: accessToken!, refreshToken: refreshToken);
    }
  }

  Future<http.Response> _get(String path) => _send('GET', path);

  Future<http.Response> _post(String path, Map<String, dynamic> body,
      {bool authenticated = true}) {
    return _send('POST', path, body: body, authenticated: authenticated);
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) {
    return _send('PUT', path, body: body);
  }

  Future<http.Response> _patch(String path, Map<String, dynamic> body) {
    return _send('PATCH', path, body: body);
  }

  Future<http.Response> _delete(String path) => _send('DELETE', path);

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final request = http.Request(method, _uri(path))
        ..headers.addAll(
            authenticated ? _headers : {'Content-Type': 'application/json'});
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(requestTimeout);
      return await http.Response.fromStream(streamed).timeout(requestTimeout);
    } on TimeoutException {
      throw Exception(
          'Request timed out. Please check your connection and try again.');
    } on http.ClientException {
      throw Exception(
          'Unable to reach the CareCircle server. Check your connection.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    final raw = response.body.trim();
    if (raw.isEmpty) {
      decoded = <String, dynamic>{};
    } else {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = <String, dynamic>{'raw': raw};
      }
    }

    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
    if (response.statusCode >= 400) {
      final message = payload['message'] ??
          payload['error'] ??
          'Request failed (${response.statusCode}).';
      throw Exception(message.toString());
    }
    return payload;
  }
}
