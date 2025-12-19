import 'package:intl/intl.dart';

// ============================================================================
// 거래처 모델
// ============================================================================
class ClientModel {
  final int id;
  final String name;
  final String bizId;
  final int? slipSendDay;
  final int? registerSendDay;
  final bool has5OrMoreWorkers;
  final String emailSubjectTemplate;
  final String emailBodyTemplate;

  ClientModel({
    required this.id,
    required this.name,
    required this.bizId,
    this.slipSendDay,
    this.registerSendDay,
    this.has5OrMoreWorkers = false,
    this.emailSubjectTemplate = '{clientName} {year}년 {month}월 {workerName} 급여명세서',
    this.emailBodyTemplate = '안녕하세요,\n\n{year}년 {month}월 급여명세서를 발송드립니다.\n\n감사합니다.',
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      bizId: json['bizId'] as String? ?? '',
      slipSendDay: json['slipSendDay'] as int?,
      registerSendDay: json['registerSendDay'] as int?,
      has5OrMoreWorkers: json['has5OrMoreWorkers'] as bool? ?? false,
      emailSubjectTemplate: json['emailSubjectTemplate'] as String? ??
          '{clientName} {year}년 {month}월 {workerName} 급여명세서',
      emailBodyTemplate: json['emailBodyTemplate'] as String? ??
          '안녕하세요,\n\n{year}년 {month}월 급여명세서를 발송드립니다.\n\n감사합니다.',
    );
  }

  ClientModel copyWith({
    int? id,
    String? name,
    String? bizId,
    int? slipSendDay,
    int? registerSendDay,
    bool? has5OrMoreWorkers,
    String? emailSubjectTemplate,
    String? emailBodyTemplate,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bizId: bizId ?? this.bizId,
      slipSendDay: slipSendDay ?? this.slipSendDay,
      registerSendDay: registerSendDay ?? this.registerSendDay,
      has5OrMoreWorkers: has5OrMoreWorkers ?? this.has5OrMoreWorkers,
      emailSubjectTemplate: emailSubjectTemplate ?? this.emailSubjectTemplate,
      emailBodyTemplate: emailBodyTemplate ?? this.emailBodyTemplate,
    );
  }
}

// ============================================================================
// 직원 모델
// ============================================================================
class WorkerModel {
  final int? id;
  final int clientId;
  final String name;
  final String birthDate; // YYMMDD
  final String phoneNumber;
  final String email;
  final String employmentType; // 'regular' or 'freelance'
  final String salaryType; // 'MONTHLY' or 'HOURLY'
  final int monthlySalary;
  final int hourlyRate;
  final double normalHours;
  final int foodAllowance;
  final int carAllowance;

  final bool hasNationalPension;
  final bool hasHealthInsurance;
  final bool hasEmploymentInsurance;
  final String healthInsuranceBasis; // 'salary' or 'insurable'
  final int? pensionInsurableWage;

  final String? emailTo;
  final String? emailCc;
  final bool useEmail;

  WorkerModel({
    this.id,
    required this.clientId,
    required this.name,
    required this.birthDate,
    this.phoneNumber = '',
    this.email = '',
    this.employmentType = 'regular',
    this.salaryType = 'HOURLY',
    this.monthlySalary = 0,
    this.hourlyRate = 0,
    this.normalHours = 209,
    this.foodAllowance = 0,
    this.carAllowance = 0,
    this.hasNationalPension = true,
    this.hasHealthInsurance = true,
    this.hasEmploymentInsurance = true,
    this.healthInsuranceBasis = 'salary',
    this.pensionInsurableWage,
    this.emailTo,
    this.emailCc,
    this.useEmail = false,
  });

  factory WorkerModel.fromJson(Map<String, dynamic> json) {
    return WorkerModel(
      id: json['employeeId'] as int?,
      clientId: json['clientId'] as int,
      name: json['name'] as String? ?? '',
      birthDate: json['birthDate'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      employmentType: json['employmentType'] as String? ?? 'regular',
      salaryType: json['salaryType'] as String? ?? 'HOURLY',
      monthlySalary: (json['baseSalary'] as num?)?.toInt() ?? 0,
      hourlyRate: (json['hourlyRate'] as num?)?.toInt() ?? 0,
      normalHours: (json['normalHours'] as num?)?.toDouble() ?? 209,
      foodAllowance: (json['foodAllowance'] as num?)?.toInt() ?? 0,
      carAllowance: (json['carAllowance'] as num?)?.toInt() ?? 0,
      hasNationalPension: json['hasNationalPension'] as bool? ?? true,
      hasHealthInsurance: json['hasHealthInsurance'] as bool? ?? true,
      hasEmploymentInsurance: json['hasEmploymentInsurance'] as bool? ?? true,
      healthInsuranceBasis: json['healthInsuranceBasis'] as String? ?? 'salary',
      pensionInsurableWage: (json['pensionInsurableWage'] as num?)?.toInt(),
      emailTo: json['emailTo'] as String?,
      emailCc: json['emailCc'] as String?,
      useEmail: json['useEmail'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'name': name,
      'birthDate': birthDate,
      'phoneNumber': phoneNumber,
      'email': email,
      'employmentType': employmentType,
      'salaryType': salaryType,
      'baseSalary': monthlySalary,
      'hourlyRate': hourlyRate,
      'normalHours': normalHours,
      'foodAllowance': foodAllowance,
      'carAllowance': carAllowance,
      'hasNationalPension': hasNationalPension,
      'hasHealthInsurance': hasHealthInsurance,
      'hasEmploymentInsurance': hasEmploymentInsurance,
      'healthInsuranceBasis': healthInsuranceBasis,
      'pensionInsurableWage': pensionInsurableWage,
      'emailTo': emailTo,
      'emailCc': emailCc,
      'useEmail': useEmail,
    };
  }

  WorkerModel copyWith({
    int? id,
    int? clientId,
    String? name,
    String? birthDate,
    String? phoneNumber,
    String? email,
    String? employmentType,
    String? salaryType,
    int? monthlySalary,
    int? hourlyRate,
    double? normalHours,
    int? foodAllowance,
    int? carAllowance,
    bool? hasNationalPension,
    bool? hasHealthInsurance,
    bool? hasEmploymentInsurance,
    String? healthInsuranceBasis,
    int? pensionInsurableWage,
    String? emailTo,
    String? emailCc,
    bool? useEmail,
  }) {
    return WorkerModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      employmentType: employmentType ?? this.employmentType,
      salaryType: salaryType ?? this.salaryType,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      normalHours: normalHours ?? this.normalHours,
      foodAllowance: foodAllowance ?? this.foodAllowance,
      carAllowance: carAllowance ?? this.carAllowance,
      hasNationalPension: hasNationalPension ?? this.hasNationalPension,
      hasHealthInsurance: hasHealthInsurance ?? this.hasHealthInsurance,
      hasEmploymentInsurance: hasEmploymentInsurance ?? this.hasEmploymentInsurance,
      healthInsuranceBasis: healthInsuranceBasis ?? this.healthInsuranceBasis,
      pensionInsurableWage: pensionInsurableWage ?? this.pensionInsurableWage,
      emailTo: emailTo ?? this.emailTo,
      emailCc: emailCc ?? this.emailCc,
      useEmail: useEmail ?? this.useEmail,
    );
  }
}

// ============================================================================
// 월별 근무 데이터
// ============================================================================
class MonthlyData {
  final int employeeId;
  final String ym; // YYYY-MM
  final double normalHours;
  final double overtimeHours;
  final double nightHours;
  final double holidayHours;
  final double weeklyHours; // 주소정근로시간
  final int weekCount; // 개근주수
  final int bonus;
  
  // 추가 수당/공제
  final int additionalPay1;
  final String additionalPay1Name;
  final int additionalPay2;
  final String additionalPay2Name;
  final int additionalPay3;
  final String additionalPay3Name;
  
  final int additionalDeduct1;
  final String additionalDeduct1Name;
  final int additionalDeduct2;
  final String additionalDeduct2Name;
  final int additionalDeduct3;
  final String additionalDeduct3Name;

  MonthlyData({
    required this.employeeId,
    required this.ym,
    this.normalHours = 209,
    this.overtimeHours = 0,
    this.nightHours = 0,
    this.holidayHours = 0,
    this.weeklyHours = 40,
    this.weekCount = 4,
    this.bonus = 0,
    this.additionalPay1 = 0,
    this.additionalPay1Name = '',
    this.additionalPay2 = 0,
    this.additionalPay2Name = '',
    this.additionalPay3 = 0,
    this.additionalPay3Name = '',
    this.additionalDeduct1 = 0,
    this.additionalDeduct1Name = '',
    this.additionalDeduct2 = 0,
    this.additionalDeduct2Name = '',
    this.additionalDeduct3 = 0,
    this.additionalDeduct3Name = '',
  });

  int get totalAdditionalPay => additionalPay1 + additionalPay2 + additionalPay3;
  int get totalAdditionalDeduct => additionalDeduct1 + additionalDeduct2 + additionalDeduct3;
}

// ============================================================================
// 급여 계산 결과
// ============================================================================
class SalaryResult {
  final String workerName;
  final String birthDate;
  final String employmentType;

  // 지급 항목
  final int baseSalary;
  final int overtimePay;
  final int nightPay;
  final int holidayPay;
  final int weeklyHolidayPay;
  final int bonus;
  final int additionalPay1;
  final String additionalPay1Name;
  final int additionalPay2;
  final String additionalPay2Name;
  final int additionalPay3;
  final String additionalPay3Name;

  // 공제 항목
  final int nationalPension;
  final int healthInsurance;
  final int longTermCare;
  final int employmentInsurance;
  final int incomeTax;
  final int localIncomeTax;
  final int additionalDeduct1;
  final String additionalDeduct1Name;
  final int additionalDeduct2;
  final String additionalDeduct2Name;
  final int additionalDeduct3;
  final String additionalDeduct3Name;

  // 계산식
  final String baseSalaryFormula;
  final String overtimeFormula;
  final String nightFormula;
  final String holidayFormula;
  final String weeklyHolidayFormula;
  final String pensionFormula;
  final String healthFormula;
  final String longTermCareFormula;
  final String employmentFormula;
  final String incomeTaxFormula;
  final String localTaxFormula;

  SalaryResult({
    required this.workerName,
    required this.birthDate,
    required this.employmentType,
    required this.baseSalary,
    this.overtimePay = 0,
    this.nightPay = 0,
    this.holidayPay = 0,
    this.weeklyHolidayPay = 0,
    this.bonus = 0,
    this.additionalPay1 = 0,
    this.additionalPay1Name = '',
    this.additionalPay2 = 0,
    this.additionalPay2Name = '',
    this.additionalPay3 = 0,
    this.additionalPay3Name = '',
    this.nationalPension = 0,
    this.healthInsurance = 0,
    this.longTermCare = 0,
    this.employmentInsurance = 0,
    this.incomeTax = 0,
    this.localIncomeTax = 0,
    this.additionalDeduct1 = 0,
    this.additionalDeduct1Name = '',
    this.additionalDeduct2 = 0,
    this.additionalDeduct2Name = '',
    this.additionalDeduct3 = 0,
    this.additionalDeduct3Name = '',
    this.baseSalaryFormula = '',
    this.overtimeFormula = '',
    this.nightFormula = '',
    this.holidayFormula = '',
    this.weeklyHolidayFormula = '',
    this.pensionFormula = '',
    this.healthFormula = '',
    this.longTermCareFormula = '',
    this.employmentFormula = '',
    this.incomeTaxFormula = '',
    this.localTaxFormula = '',
  });

  int get totalPayment =>
      baseSalary +
      overtimePay +
      nightPay +
      holidayPay +
      weeklyHolidayPay +
      bonus +
      additionalPay1 +
      additionalPay2 +
      additionalPay3;

  int get totalDeduction =>
      nationalPension +
      healthInsurance +
      longTermCare +
      employmentInsurance +
      incomeTax +
      localIncomeTax +
      additionalDeduct1 +
      additionalDeduct2 +
      additionalDeduct3;

  int get netPayment => totalPayment - totalDeduction;
}

// ============================================================================
// SMTP 설정
// ============================================================================
class SmtpConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool useSSL;

  SmtpConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.useSSL = true,
  });

  factory SmtpConfig.fromJson(Map<String, dynamic> json) {
    return SmtpConfig(
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 587,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      useSSL: json['useSSL'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'useSSL': useSSL,
    };
  }
}

// ============================================================================
// 앱 설정
// ============================================================================
class AppSettings {
  final String serverUrl;
  final String apiKey;

  AppSettings({
    required this.serverUrl,
    this.apiKey = '',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      serverUrl: json['serverUrl'] as String? ?? 'http://localhost:8000',
      apiKey: json['apiKey'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'apiKey': apiKey,
    };
  }
}

// ============================================================================
// 발송 상태
// ============================================================================
class SendStatusEmployee {
  final int employeeId;
  final String name;
  final String birthDate;
  final bool useEmail;
  final String? emailTo;
  final String? emailCc;
  final String? lastStatus;
  final String? lastSentAt;
  final String? lastError;
  final bool isSent;

  SendStatusEmployee({
    required this.employeeId,
    required this.name,
    required this.birthDate,
    required this.useEmail,
    this.emailTo,
    this.emailCc,
    this.lastStatus,
    this.lastSentAt,
    this.lastError,
    this.isSent = false,
  });

  factory SendStatusEmployee.fromJson(Map<String, dynamic> json) {
    return SendStatusEmployee(
      employeeId: json['employeeId'] as int,
      name: json['name'] as String? ?? '',
      birthDate: json['birthDate'] as String? ?? '',
      useEmail: json['useEmail'] as bool? ?? false,
      emailTo: json['emailTo'] as String?,
      emailCc: json['emailCc'] as String?,
      lastStatus: json['lastStatus'] as String?,
      lastSentAt: json['lastSentAt'] as String?,
      lastError: json['lastError'] as String?,
      isSent: json['isSent'] as bool? ?? false,
    );
  }
}

class ClientSendStatus {
  final int clientId;
  final String ym;
  final String docType;
  final int totalTargets;
  final int sentTargets;
  final bool isDone;
  final List<SendStatusEmployee> employees;

  ClientSendStatus({
    required this.clientId,
    required this.ym,
    required this.docType,
    required this.totalTargets,
    required this.sentTargets,
    required this.isDone,
    required this.employees,
  });

  factory ClientSendStatus.fromJson(Map<String, dynamic> json) {
    return ClientSendStatus(
      clientId: json['clientId'] as int,
      ym: json['ym'] as String,
      docType: json['docType'] as String,
      totalTargets: json['totalTargets'] as int,
      sentTargets: json['sentTargets'] as int,
      isDone: json['isDone'] as bool,
      employees: (json['employees'] as List<dynamic>)
          .map((e) => SendStatusEmployee.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ============================================================================
// 유틸리티
// ============================================================================
String formatMoney(num amount) {
  return NumberFormat('#,###').format(amount);
}

String formatYm(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
