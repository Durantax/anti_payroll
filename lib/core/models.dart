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
  final String? empNo; // 사번 (동명이인 관리용, DB 자동부여)
  final String? joinDate; // YYYY-MM-DD (입사일)
  final String? resignDate; // YYYY-MM-DD (퇴사일)
  final String phoneNumber;
  final String email;
  final String employmentType; // 'labor' (근로소득) or 'business' (사업소득)
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
  
  // 세금 관련 필드 (서버 API 스펙과 일치)
  final int taxDependents;        // 공제대상 가족 수 (본인 포함)
  final int childrenCount;        // 8세~20세 자녀 수
  final int taxFreeMeal;          // 비과세 식대
  final int taxFreeCarMaintenance; // 비과세 차량유지비
  final int otherTaxFree;         // 기타 비과세
  final int incomeTaxRate;        // 소득세 배율 (80, 100, 120)

  WorkerModel({
    this.id,
    required this.clientId,
    required this.name,
    required this.birthDate,
    this.empNo, // 사번 (서버에서 자동부여)
    this.joinDate,
    this.resignDate,
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
    this.taxDependents = 1,
    this.childrenCount = 0,
    this.taxFreeMeal = 0,
    this.taxFreeCarMaintenance = 0,
    this.otherTaxFree = 0,
    this.incomeTaxRate = 100,
  });

  factory WorkerModel.fromJson(Map<String, dynamic> json) {
    return WorkerModel(
      id: json['employeeId'] as int?,
      clientId: (json['clientId'] as int?) ?? 0,
      name: json['name'] as String? ?? '',
      birthDate: json['birthDate'] as String? ?? '',
      empNo: json['empNo'] as String?, // 사번 (서버에서 자동부여)
      joinDate: json['joinDate'] as String?,
      resignDate: json['resignDate'] as String?,
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
      taxDependents: (json['taxDependents'] as num?)?.toInt() ?? 1,
      childrenCount: (json['childrenCount'] as num?)?.toInt() ?? 0,
      taxFreeMeal: (json['taxFreeMeal'] as num?)?.toInt() ?? 0,
      taxFreeCarMaintenance: (json['taxFreeCarMaintenance'] as num?)?.toInt() ?? 0,
      otherTaxFree: (json['otherTaxFree'] as num?)?.toInt() ?? 0,
      incomeTaxRate: (json['incomeTaxRate'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
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
      'taxDependents': taxDependents,
      'childrenCount': childrenCount,
      'taxFreeMeal': taxFreeMeal,
      'taxFreeCarMaintenance': taxFreeCarMaintenance,
      'otherTaxFree': otherTaxFree,
      'incomeTaxRate': incomeTaxRate,
      'joinDate': joinDate,
      'resignDate': resignDate,
    };
    
    // employeeId가 있으면 포함 (업데이트 시 필수)
    if (id != null) {
      map['employeeId'] = id;
    }
    
    return map;
  }

  WorkerModel copyWith({
    int? id,
    int? clientId,
    String? name,
    String? birthDate,
    String? empNo,
    String? joinDate,
    String? resignDate,
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
    int? taxDependents,
    int? childrenCount,
    int? taxFreeMeal,
    int? taxFreeCarMaintenance,
    int? otherTaxFree,
    int? incomeTaxRate,
  }) {
    return WorkerModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      empNo: empNo ?? this.empNo,
      joinDate: joinDate ?? this.joinDate,
      resignDate: resignDate ?? this.resignDate,
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
      taxDependents: taxDependents ?? this.taxDependents,
      childrenCount: childrenCount ?? this.childrenCount,
      taxFreeMeal: taxFreeMeal ?? this.taxFreeMeal,
      taxFreeCarMaintenance: taxFreeCarMaintenance ?? this.taxFreeCarMaintenance,
      otherTaxFree: otherTaxFree ?? this.otherTaxFree,
      incomeTaxRate: incomeTaxRate ?? this.incomeTaxRate,
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
  final bool isDurunuri; // 두루누리 지원 여부
  
  // 추가 수당/공제 (과세/비과세 구분 가능)
  final int additionalPay1;
  final String additionalPay1Name;
  final bool additionalPay1IsTaxFree; // 비과세 여부
  final int additionalPay2;
  final String additionalPay2Name;
  final bool additionalPay2IsTaxFree;
  final int additionalPay3;
  final String additionalPay3Name;
  final bool additionalPay3IsTaxFree;
  
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
    this.isDurunuri = false,
    this.additionalPay1 = 0,
    this.additionalPay1Name = '',
    this.additionalPay1IsTaxFree = false,
    this.additionalPay2 = 0,
    this.additionalPay2Name = '',
    this.additionalPay2IsTaxFree = false,
    this.additionalPay3 = 0,
    this.additionalPay3Name = '',
    this.additionalPay3IsTaxFree = false,
    this.additionalDeduct1 = 0,
    this.additionalDeduct1Name = '',
    this.additionalDeduct2 = 0,
    this.additionalDeduct2Name = '',
    this.additionalDeduct3 = 0,
    this.additionalDeduct3Name = '',
  });

  int get totalAdditionalPay => additionalPay1 + additionalPay2 + additionalPay3;
  int get totalAdditionalDeduct => additionalDeduct1 + additionalDeduct2 + additionalDeduct3;
  
  // 과세 수당 합계
  int get taxableAdditionalPay {
    int total = 0;
    if (!additionalPay1IsTaxFree) total += additionalPay1;
    if (!additionalPay2IsTaxFree) total += additionalPay2;
    if (!additionalPay3IsTaxFree) total += additionalPay3;
    return total;
  }
  
  // 비과세 수당 합계
  int get taxFreeAdditionalPay {
    int total = 0;
    if (additionalPay1IsTaxFree) total += additionalPay1;
    if (additionalPay2IsTaxFree) total += additionalPay2;
    if (additionalPay3IsTaxFree) total += additionalPay3;
    return total;
  }

  factory MonthlyData.fromJson(Map<String, dynamic> json) {
    return MonthlyData(
      employeeId: json['employeeId'] as int,
      ym: json['ym'] as String,
      normalHours: (json['normalHours'] as num?)?.toDouble() ?? 209,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0,
      nightHours: (json['nightHours'] as num?)?.toDouble() ?? 0,
      holidayHours: (json['holidayHours'] as num?)?.toDouble() ?? 0,
      weeklyHours: (json['weeklyHours'] as num?)?.toDouble() ?? 40,
      weekCount: (json['weekCount'] as num?)?.toInt() ?? 4,
      bonus: (json['bonus'] as num?)?.toInt() ?? 0,
      isDurunuri: json['isDurunuri'] as bool? ?? false,
      additionalPay1: (json['additionalPay1'] as num?)?.toInt() ?? 0,
      additionalPay1Name: json['additionalPay1Name'] as String? ?? '',
      additionalPay1IsTaxFree: json['additionalPay1IsTaxFree'] as bool? ?? false,
      additionalPay2: (json['additionalPay2'] as num?)?.toInt() ?? 0,
      additionalPay2Name: json['additionalPay2Name'] as String? ?? '',
      additionalPay2IsTaxFree: json['additionalPay2IsTaxFree'] as bool? ?? false,
      additionalPay3: (json['additionalPay3'] as num?)?.toInt() ?? 0,
      additionalPay3Name: json['additionalPay3Name'] as String? ?? '',
      additionalPay3IsTaxFree: json['additionalPay3IsTaxFree'] as bool? ?? false,
      additionalDeduct1: (json['additionalDeduct1'] as num?)?.toInt() ?? 0,
      additionalDeduct1Name: json['additionalDeduct1Name'] as String? ?? '',
      additionalDeduct2: (json['additionalDeduct2'] as num?)?.toInt() ?? 0,
      additionalDeduct2Name: json['additionalDeduct2Name'] as String? ?? '',
      additionalDeduct3: (json['additionalDeduct3'] as num?)?.toInt() ?? 0,
      additionalDeduct3Name: json['additionalDeduct3Name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'ym': ym,
      'normalHours': normalHours,
      'overtimeHours': overtimeHours,
      'nightHours': nightHours,
      'holidayHours': holidayHours,
      'weeklyHours': weeklyHours,
      'weekCount': weekCount,
      'bonus': bonus,
      'isDurunuri': isDurunuri,
      'additionalPay1': additionalPay1,
      'additionalPay1Name': additionalPay1Name,
      'additionalPay1IsTaxFree': additionalPay1IsTaxFree,
      'additionalPay2': additionalPay2,
      'additionalPay2Name': additionalPay2Name,
      'additionalPay2IsTaxFree': additionalPay2IsTaxFree,
      'additionalPay3': additionalPay3,
      'additionalPay3Name': additionalPay3Name,
      'additionalPay3IsTaxFree': additionalPay3IsTaxFree,
      'additionalDeduct1': additionalDeduct1,
      'additionalDeduct1Name': additionalDeduct1Name,
      'additionalDeduct2': additionalDeduct2,
      'additionalDeduct2Name': additionalDeduct2Name,
      'additionalDeduct3': additionalDeduct3,
      'additionalDeduct3Name': additionalDeduct3Name,
    };
  }
}


// ============================================================================
// 급여 계산 결과
// ============================================================================
class SalaryResult {
  final String workerName;
  final String birthDate;
  final String? empNo; // 사번 (동명이인 구분용)
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
    this.empNo, // 사번
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
  final String downloadBasePath; // 기본 다운로드 경로
  final bool useClientSubfolders; // 거래처별 하위 폴더 생성 여부

  AppSettings({
    required this.serverUrl,
    this.apiKey = '',
    this.downloadBasePath = '',
    this.useClientSubfolders = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      serverUrl: json['serverUrl'] as String? ?? 'http://localhost:8000',
      apiKey: json['apiKey'] as String? ?? '',
      downloadBasePath: json['downloadBasePath'] as String? ?? '',
      useClientSubfolders: json['useClientSubfolders'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'apiKey': apiKey,
      'downloadBasePath': downloadBasePath,
      'useClientSubfolders': useClientSubfolders,
    };
  }

  AppSettings copyWith({
    String? serverUrl,
    String? apiKey,
    String? downloadBasePath,
    bool? useClientSubfolders,
  }) {
    return AppSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      apiKey: apiKey ?? this.apiKey,
      downloadBasePath: downloadBasePath ?? this.downloadBasePath,
      useClientSubfolders: useClientSubfolders ?? this.useClientSubfolders,
    );
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
// 수당/공제 마스터 모델
// ============================================================================
class AllowanceMaster {
  final int? id;
  final int clientId;
  final String name;
  final bool isTaxFree;
  final int? defaultAmount;

  AllowanceMaster({
    this.id,
    required this.clientId,
    required this.name,
    this.isTaxFree = false,
    this.defaultAmount,
  });

  factory AllowanceMaster.fromJson(Map<String, dynamic> json) {
    return AllowanceMaster(
      id: json['id'] as int?,
      clientId: json['clientId'] as int,
      name: json['name'] as String,
      isTaxFree: json['isTaxFree'] as bool? ?? false,
      defaultAmount: json['defaultAmount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'clientId': clientId,
      'name': name,
      'isTaxFree': isTaxFree,
      if (defaultAmount != null) 'defaultAmount': defaultAmount,
    };
  }
}

class DeductionMaster {
  final int? id;
  final int clientId;
  final String name;
  final int? defaultAmount;

  DeductionMaster({
    this.id,
    required this.clientId,
    required this.name,
    this.defaultAmount,
  });

  factory DeductionMaster.fromJson(Map<String, dynamic> json) {
    return DeductionMaster(
      id: json['id'] as int?,
      clientId: json['clientId'] as int,
      name: json['name'] as String,
      defaultAmount: json['defaultAmount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'clientId': clientId,
      'name': name,
      if (defaultAmount != null) 'defaultAmount': defaultAmount,
    };
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
