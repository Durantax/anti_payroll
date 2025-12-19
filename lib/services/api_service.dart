import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/models.dart';
import '../core/constants.dart';

class ApiService {
  String _serverUrl;
  String _apiKey;

  ApiService({
    String? serverUrl,
    String? apiKey,
  })  : _serverUrl = serverUrl ?? AppConstants.defaultServerUrl,
        _apiKey = apiKey ?? AppConstants.defaultApiKey;

  void updateSettings(String serverUrl, String apiKey) {
    _serverUrl = serverUrl;
    _apiKey = apiKey;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
      };

  // ========== 거래처 ==========

  Future<List<ClientModel>> getClients() async {
    final response = await http.get(
      Uri.parse('$_serverUrl/clients'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => ClientModel.fromJson(json)).toList();
    } else {
      throw Exception('거래처 조회 실패: ${response.statusCode}');
    }
  }

  Future<void> updateClient({
    required int clientId,
    bool? has5OrMoreWorkers,
    String? emailSubjectTemplate,
    String? emailBodyTemplate,
  }) async {
    final body = <String, dynamic>{};
    if (has5OrMoreWorkers != null) body['has5OrMoreWorkers'] = has5OrMoreWorkers;
    if (emailSubjectTemplate != null) body['emailSubjectTemplate'] = emailSubjectTemplate;
    if (emailBodyTemplate != null) body['emailBodyTemplate'] = emailBodyTemplate;

    final response = await http.patch(
      Uri.parse('$_serverUrl/clients/$clientId'),
      headers: _headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('거래처 수정 실패: ${response.statusCode}');
    }
  }

  // ========== 직원 ==========

  Future<List<WorkerModel>> getEmployees(int clientId) async {
    final response = await http.get(
      Uri.parse('$_serverUrl/clients/$clientId/employees'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => WorkerModel.fromJson(json)).toList();
    } else {
      throw Exception('직원 조회 실패: ${response.statusCode}');
    }
  }

  Future<WorkerModel> upsertEmployee(WorkerModel worker) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/employees/upsert'),
      headers: _headers,
      body: json.encode(worker.toJson()),
    );

    if (response.statusCode == 200) {
      return WorkerModel.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('직원 저장 실패: ${response.statusCode}');
    }
  }

  Future<void> deleteEmployee(int employeeId) async {
    final response = await http.delete(
      Uri.parse('$_serverUrl/employees/$employeeId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('직원 삭제 실패: ${response.statusCode}');
    }
  }

  // ========== 월별 근무 데이터 ==========

  Future<MonthlyData?> getMonthlyData({
    required int employeeId,
    required String ym,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/employees/$employeeId/monthly-data/$ym'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return MonthlyData(
          employeeId: data['employeeId'] as int,
          ym: data['ym'] as String,
          normalHours: (data['normalHours'] as num?)?.toDouble() ?? 209,
          overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
          nightHours: (data['nightHours'] as num?)?.toDouble() ?? 0,
          holidayHours: (data['holidayHours'] as num?)?.toDouble() ?? 0,
          weeklyHours: (data['weeklyHours'] as num?)?.toDouble() ?? 40,
          weekCount: (data['weekCount'] as int?) ?? 4,
          bonus: (data['bonus'] as int?) ?? 0,
          additionalPay1: (data['additionalPay1'] as int?) ?? 0,
          additionalPay1Name: (data['additionalPay1Name'] as String?) ?? '',
          additionalPay2: (data['additionalPay2'] as int?) ?? 0,
          additionalPay2Name: (data['additionalPay2Name'] as String?) ?? '',
          additionalPay3: (data['additionalPay3'] as int?) ?? 0,
          additionalPay3Name: (data['additionalPay3Name'] as String?) ?? '',
          additionalDeduct1: (data['additionalDeduct1'] as int?) ?? 0,
          additionalDeduct1Name: (data['additionalDeduct1Name'] as String?) ?? '',
          additionalDeduct2: (data['additionalDeduct2'] as int?) ?? 0,
          additionalDeduct2Name: (data['additionalDeduct2Name'] as String?) ?? '',
          additionalDeduct3: (data['additionalDeduct3'] as int?) ?? 0,
          additionalDeduct3Name: (data['additionalDeduct3Name'] as String?) ?? '',
        );
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('월별 데이터 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('월별 데이터 조회 에러: $e');
      return null;
    }
  }

  Future<void> saveMonthlyData(MonthlyData data) async {
    final body = {
      'employeeId': data.employeeId,
      'ym': data.ym,
      'normalHours': data.normalHours,
      'overtimeHours': data.overtimeHours,
      'nightHours': data.nightHours,
      'holidayHours': data.holidayHours,
      'weeklyHours': data.weeklyHours,
      'weekCount': data.weekCount,
      'bonus': data.bonus,
      'additionalPay1': data.additionalPay1,
      'additionalPay1Name': data.additionalPay1Name,
      'additionalPay2': data.additionalPay2,
      'additionalPay2Name': data.additionalPay2Name,
      'additionalPay3': data.additionalPay3,
      'additionalPay3Name': data.additionalPay3Name,
      'additionalDeduct1': data.additionalDeduct1,
      'additionalDeduct1Name': data.additionalDeduct1Name,
      'additionalDeduct2': data.additionalDeduct2,
      'additionalDeduct2Name': data.additionalDeduct2Name,
      'additionalDeduct3': data.additionalDeduct3,
      'additionalDeduct3Name': data.additionalDeduct3Name,
    };

    final response = await http.post(
      Uri.parse('$_serverUrl/employees/${data.employeeId}/monthly-data'),
      headers: _headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('월별 데이터 저장 실패: ${response.statusCode}');
    }
  }

  // ========== 발송 상태 ==========

  Future<ClientSendStatus> getClientSendStatus({
    required int clientId,
    required String ym,
    String docType = 'slip',
  }) async {
    final response = await http.get(
      Uri.parse('$_serverUrl/clients/$clientId/send-status?ym=$ym&docType=$docType'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ClientSendStatus.fromJson(json.decode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('발송 상태 조회 실패: ${response.statusCode}');
    }
  }

  // ========== 메일 로그 ==========

  Future<void> logMail({
    required int clientId,
    required String ym,
    required String docType,
    required String toEmail,
    required String subject,
    required String status,
    String? errorMessage,
    String? ccEmail,
    int? employeeId,
  }) async {
    final body = {
      'clientId': clientId,
      'ym': ym,
      'docType': docType,
      'toEmail': toEmail,
      'subject': subject,
      'status': status,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (ccEmail != null) 'ccEmail': ccEmail,
      if (employeeId != null) 'employeeId': employeeId,
    };

    final response = await http.post(
      Uri.parse('$_serverUrl/logs/mail'),
      headers: _headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('메일 로그 저장 실패: ${response.statusCode}');
    }
  }

  // ========== SMTP 설정 ==========

  Future<SmtpConfig?> getSmtpConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/smtp/config'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return SmtpConfig.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('SMTP 설정 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('SMTP 설정 조회 에러: $e');
      return null;
    }
  }

  Future<void> saveSmtpConfig(SmtpConfig config) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/smtp/config'),
      headers: _headers,
      body: json.encode(config.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('SMTP 설정 저장 실패: ${response.statusCode}');
    }
  }

  // ========== 앱 설정 ==========

  Future<AppSettings?> getAppSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/app/settings'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return AppSettings.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('앱 설정 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('앱 설정 조회 에러: $e');
      return null;
    }
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/app/settings'),
      headers: _headers,
      body: json.encode(settings.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('앱 설정 저장 실패: ${response.statusCode}');
    }
  }

  // ========== 헬스체크 ==========

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/health'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['ok'] == true && data['db'] == true;
      } else {
        return false;
      }
    } catch (e) {
      print('헬스체크 에러: $e');
      return false;
    }
  }
}
