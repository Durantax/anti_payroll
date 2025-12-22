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
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/clients/$clientId/employees'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((json) {
          try {
            return WorkerModel.fromJson(json);
          } catch (e) {
            print('⚠️ WorkerModel.fromJson 에러: $e');
            print('   JSON 데이터: $json');
            rethrow;
          }
        }).toList();
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        throw Exception('직원 조회 실패 (${response.statusCode}): $errorBody');
      }
    } catch (e) {
      print('❌ getEmployees 에러: $e');
      rethrow;
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
      // 서버 응답 메시지 포함
      String errorMsg = '직원 저장 실패: ${response.statusCode}';
      try {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        if (errorBody['detail'] != null) {
          errorMsg += ' - ${errorBody['detail']}';
        }
      } catch (e) {
        // JSON 파싱 실패 시 원본 응답 포함
        errorMsg += ' - ${response.body}';
      }
      throw Exception(errorMsg);
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
        Uri.parse('$_serverUrl/payroll/monthly?employeeId=$employeeId&ym=$ym'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data == null) return null;
        
        return MonthlyData(
          employeeId: data['employeeId'] as int,
          ym: data['ym'] as String,
          normalHours: (data['workHours'] as num?)?.toDouble() ?? 209,
          overtimeHours: (data['overtimeHours'] as num?)?.toDouble() ?? 0,
          nightHours: (data['nightHours'] as num?)?.toDouble() ?? 0,
          holidayHours: (data['holidayHours'] as num?)?.toDouble() ?? 0,
          weeklyHours: (data['weeklyHours'] as num?)?.toDouble() ?? 40,  // 서버에서 받아옴
          weekCount: (data['weekCount'] as int?) ?? 4,  // 서버에서 받아옴
          bonus: ((data['bonus'] as num?)?.toDouble() ?? 0).round(),
          additionalPay1: 0,
          additionalPay1Name: '',
          additionalPay2: 0,
          additionalPay2Name: '',
          additionalPay3: 0,
          additionalPay3Name: '',
          additionalDeduct1: 0,
          additionalDeduct1Name: '',
          additionalDeduct2: 0,
          additionalDeduct2Name: '',
          additionalDeduct3: 0,
          additionalDeduct3Name: '',
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
      'workHours': data.normalHours.toDouble(),
      'bonus': data.bonus.toDouble(),
      'overtimeHours': data.overtimeHours.toDouble(),
      'nightHours': data.nightHours.toDouble(),
      'holidayHours': data.holidayHours.toDouble(),
      'weeklyHours': data.weeklyHours.toDouble(),  // 추가: 주소정근로시간
      'weekCount': data.weekCount,  // 추가: 개근주수
    };

    final response = await http.post(
      Uri.parse('$_serverUrl/payroll/monthly/upsert'),
      headers: _headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      final errorBody = utf8.decode(response.bodyBytes);
      throw Exception('월별 데이터 저장 실패: ${response.statusCode}\n$errorBody');
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

  // ========== 급여 결과 저장 ==========

  Future<void> savePayrollResult({
    required int employeeId,
    required int clientId,
    required int year,
    required int month,
    required Map<String, dynamic> salaryData,
    String calculatedBy = 'app',
  }) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/payroll/results/save'),
      headers: _headers,
      body: json.encode({
        'employeeId': employeeId,
        'clientId': clientId,
        'year': year,
        'month': month,
        'baseSalary': salaryData['baseSalary'] ?? 0,
        'overtimeAllowance': salaryData['overtimePay'] ?? 0,
        'nightAllowance': salaryData['nightPay'] ?? 0,
        'holidayAllowance': salaryData['holidayPay'] ?? 0,
        'weeklyHolidayPay': salaryData['weeklyHolidayPay'] ?? 0,
        'bonus': salaryData['bonus'] ?? 0,
        'additionalAllowance1Name': salaryData['additionalPay1Name'],
        'additionalAllowance1Amount': salaryData['additionalPay1'] ?? 0,
        'additionalAllowance2Name': salaryData['additionalPay2Name'],
        'additionalAllowance2Amount': salaryData['additionalPay2'] ?? 0,
        'totalPayment': salaryData['totalPayment'] ?? 0,
        'nationalPension': salaryData['nationalPension'] ?? 0,
        'healthInsurance': salaryData['healthInsurance'] ?? 0,
        'longTermCare': salaryData['longTermCare'] ?? 0,
        'employmentInsurance': salaryData['employmentInsurance'] ?? 0,
        'incomeTax': salaryData['incomeTax'] ?? 0,
        'localIncomeTax': salaryData['localIncomeTax'] ?? 0,
        'additionalDeduction1Name': salaryData['additionalDeduct1Name'],
        'additionalDeduction1Amount': salaryData['additionalDeduct1'] ?? 0,
        'additionalDeduction2Name': salaryData['additionalDeduct2Name'],
        'additionalDeduction2Amount': salaryData['additionalDeduct2'] ?? 0,
        'totalDeduction': salaryData['totalDeduction'] ?? 0,
        'netPay': salaryData['netPayment'] ?? 0,
        'normalHours': salaryData['normalHours'],
        'overtimeHours': salaryData['overtimeHours'],
        'nightHours': salaryData['nightHours'],
        'holidayHours': salaryData['holidayHours'],
        'attendanceWeeks': salaryData['weekCount'],
        'paymentFormulas': salaryData['paymentFormulas'] ?? {},
        'deductionFormulas': salaryData['deductionFormulas'] ?? {},
        'calculatedBy': calculatedBy,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('급여 결과 저장 실패: ${response.statusCode}');
    }
  }

  // ========== 급여 마감 ==========

  Future<Map<String, dynamic>> getConfirmationStatus({
    required int clientId,
    required int year,
    required int month,
  }) async {
    final response = await http.get(
      Uri.parse('$_serverUrl/payroll/results/client/$clientId/confirmation-status?year=$year&month=$month'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('마감 현황 조회 실패: ${response.statusCode}');
    }
  }

  Future<void> confirmPayrollResult({
    required int resultId,
    String confirmedBy = 'admin',
  }) async {
    final response = await http.patch(
      Uri.parse('$_serverUrl/payroll/results/$resultId/confirm'),
      headers: _headers,
      body: json.encode({'confirmedBy': confirmedBy}),
    );

    if (response.statusCode != 200) {
      throw Exception('급여 마감 실패: ${response.statusCode}');
    }
  }

  Future<void> unconfirmPayrollResult(int resultId) async {
    final response = await http.patch(
      Uri.parse('$_serverUrl/payroll/results/$resultId/unconfirm'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('마감 취소 실패: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> confirmAllPayrollResults({
    required int clientId,
    required int year,
    required int month,
    String confirmedBy = 'admin',
  }) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/payroll/results/client/$clientId/confirm-all'),
      headers: _headers,
      body: json.encode({
        'year': year,
        'month': month,
        'confirmedBy': confirmedBy,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('일괄 마감 실패: ${response.statusCode}');
    }
  }
}
