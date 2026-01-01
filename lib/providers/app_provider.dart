import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../core/models.dart';
import '../core/constants.dart';
import '../services/api_service.dart';
import '../services/payroll_calculator.dart';
import '../services/file_email_service.dart';
import '../utils/path_helper.dart';

class AppProvider with ChangeNotifier {
  final ApiService _apiService;

  // 상태
  List<ClientModel> _clients = [];
  ClientModel? _selectedClient;
  DateTime _selectedDate = DateTime.now();
  
  Map<int, List<WorkerModel>> _workersByClient = {};
  Map<int, Map<int, MonthlyData>> _monthlyDataByWorker = {};
  Map<int, SalaryResult> _salaryResults = {};
  Map<int, bool> _workerFinalizedStatus = {}; // 직원별 마감 상태 (workerId -> isConfirmed)
  Map<int, int> _payrollResultIds = {}; // 직원별 PayrollResults의 resultId (workerId -> resultId)
  Map<int, bool> _isManualCalculation = {}; // 직원별 수동 계산 여부 (workerId -> isManual)
  
  SmtpConfig? _smtpConfig;
  AppSettings? _appSettings;
  
  ClientSendStatus? _sendStatus;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _statusCheckTimer;
  Timer? _autoSendTimer;
  
  // 자동 발송 기록 (중복 발송 방지)
  String? _lastAutoSendDate; // YYYY-MM-DD 형식
  String? _lastRetryDate; // YYYY-MM-DD 형식

  AppProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService() {
    _init();
  }

  // Getters
  List<ClientModel> get clients => _clients;
  ClientModel? get selectedClient => _selectedClient;
  DateTime get selectedDate => _selectedDate;
  int get selectedYear => _selectedDate.year;
  int get selectedMonth => _selectedDate.month;
  String get selectedYm => formatYm(_selectedDate);
  
  List<WorkerModel> get currentWorkers {
    final client = _selectedClient;
    if (client == null || client.id == null) return [];
    return _workersByClient[client.id!] ?? [];
  }
  
  Map<int, SalaryResult> get salaryResults => _salaryResults;
  
  SmtpConfig? get smtpConfig => _smtpConfig;
  AppSettings? get appSettings => _appSettings;
  AppSettings? get settings => _appSettings;  // Alias for compatibility
  ClientSendStatus? get sendStatus => _sendStatus;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  ApiService get apiService => _apiService;
  String? get error => _errorMessage;  // Alias for compatibility

  // 급여 총액 계산
  int get totalPayment => _salaryResults.values.fold(0, (sum, r) => sum + r.totalPayment);
  int get totalDeduction => _salaryResults.values.fold(0, (sum, r) => sum + r.totalDeduction);
  int get totalNetPayment => _salaryResults.values.fold(0, (sum, r) => sum + r.netPayment);

  // ========== 초기화 ==========

  Future<void> _init() async {
    await loadAppSettings();
    await loadSmtpConfig();
    await syncClients();
    _startAutoSendCheck();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _autoSendTimer?.cancel();
    super.dispose();
  }

  // ========== 에러 처리 ==========

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ========== 설정 ==========
  
  /// 유효한 basePath 반환 (빈 문자열이면 기본 경로 사용)
  String _getValidBasePath() {
    final path = settings?.downloadBasePath ?? '';
    return path.isEmpty ? PathHelper.getDefaultDownloadPath() : path;
  }

  Future<void> loadAppSettings() async {
    try {
      final settings = await _apiService.getAppSettings();
      
      // 서버에서 가져온 설정이 null이거나 downloadBasePath가 비어있으면 기본 경로 설정
      if (settings == null || settings.downloadBasePath.isEmpty) {
        _appSettings = (settings ?? AppSettings(
          serverUrl: 'http://127.0.0.1:8000',
          apiKey: '',
          downloadBasePath: '',
          useClientSubfolders: true,
        )).copyWith(
          downloadBasePath: PathHelper.getDefaultDownloadPath(),
        );
      } else {
        _appSettings = settings;
      }
      
      notifyListeners();
    } catch (e) {
      print('앱 설정 로드 실패: $e - 기본 OneDrive 경로 사용');
      // 서버에서 설정을 가져오지 못하면 항상 OneDrive 기본 경로 사용
      // 사용자 설정 불필요 - 자동으로 OneDrive 우선, 없으면 Documents
      _appSettings = AppSettings(
        serverUrl: 'http://25.2.89.129:8000',
        apiKey: '',
        downloadBasePath: PathHelper.getDefaultDownloadPath(), // OneDrive 자동
        useClientSubfolders: true, // 항상 거래처별 폴더 사용
      );
      notifyListeners();
    }
  }

  // saveAppSettings 제거됨 - 서버 URL이 하드코딩되어 더 이상 필요 없음

  Future<void> loadSmtpConfig() async {
    try {
      _smtpConfig = await _apiService.getSmtpConfig();
      notifyListeners();
    } catch (e) {
      print('SMTP 설정 로드 실패: $e');
    }
  }

  Future<void> saveSmtpConfig(SmtpConfig config) async {
    try {
      _setLoading(true);
      await _apiService.saveSmtpConfig(config);
      _smtpConfig = config;
      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('SMTP 설정 저장 실패: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // updateDownloadPath 제거됨 - 파일 경로는 항상 OneDrive 자동 사용

  Future<bool> testServerConnection() async {
    try {
      return await _apiService.checkHealth();
    } catch (e) {
      return false;
    }
  }

  // ========== 거래처 ==========

  Future<void> syncClients() async {
    try {
      _setLoading(true);
      _clients = await _apiService.getClients();
      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('거래처 동기화 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  void selectClient(ClientModel? client) {
    _selectedClient = client;
    _salaryResults.clear();
    notifyListeners();
    
    if (client != null) {
      loadWorkers(client.id);
      loadSendStatus();
      loadConfirmationStatus(); // 마감 상태 로드
    }
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    _salaryResults.clear();
    notifyListeners();
    
    if (_selectedClient != null) {
      // 새로운 월의 데이터 로드
      _loadMonthlyDataForAllWorkers();
      loadSendStatus();
      loadConfirmationStatus(); // 마감 상태 로드
    }
  }

  Future<void> _loadMonthlyDataForAllWorkers() async {
    for (var worker in currentWorkers) {
      if (worker.id != null) {
        await _loadMonthlyDataForWorker(worker.id!);
      }
    }
    notifyListeners();
  }

  Future<void> updateClientSettings({
    bool? has5OrMoreWorkers,
    String? emailSubjectTemplate,
    String? emailBodyTemplate,
  }) async {
    if (_selectedClient == null) return;

    try {
      _setLoading(true);
      await _apiService.updateClient(
        clientId: _selectedClient!.id,
        has5OrMoreWorkers: has5OrMoreWorkers,
        emailSubjectTemplate: emailSubjectTemplate,
        emailBodyTemplate: emailBodyTemplate,
      );

      // 로컬 상태 업데이트
      _selectedClient = _selectedClient!.copyWith(
        has5OrMoreWorkers: has5OrMoreWorkers,
        emailSubjectTemplate: emailSubjectTemplate,
        emailBodyTemplate: emailBodyTemplate,
      );

      final index = _clients.indexWhere((c) => c.id == _selectedClient!.id);
      if (index != -1) {
        _clients[index] = _selectedClient!;
      }

      // 급여 재계산
      _recalculateAllSalaries();

      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('거래처 설정 저장 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ========== 직원 ==========

  Future<void> loadWorkers(int clientId) async {
    try {
      _setLoading(true);
      final workers = await _apiService.getEmployees(clientId);
      _workersByClient[clientId] = workers;

      // 각 직원의 월별 데이터 초기화 및 로드
      for (var worker in workers) {
        if (worker.id != null) {
          _monthlyDataByWorker[worker.id!] = {};
          
          // 현재 선택된 월의 데이터 로드
          await _loadMonthlyDataForWorker(worker.id!);
        }
      }

      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('직원 목록 조회 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadMonthlyDataForWorker(int workerId) async {
    try {
      final data = await _apiService.getMonthlyData(
        employeeId: workerId,
        ym: selectedYm,
      );

      if (data != null) {
        if (_monthlyDataByWorker[workerId] == null) {
          _monthlyDataByWorker[workerId] = {};
        }
        _monthlyDataByWorker[workerId]![_selectedDate.month] = data;
        
        // 급여 계산
        _calculateSalary(workerId);
      }
    } catch (e) {
      print('월별 데이터 로드 실패 (직원 $workerId): $e');
    }
  }

  Future<WorkerModel> saveWorker(WorkerModel worker) async {
    try {
      _setLoading(true);
      final saved = await _apiService.upsertEmployee(worker);

      if (_workersByClient[worker.clientId] == null) {
        _workersByClient[worker.clientId] = [];
      }

      final workers = _workersByClient[worker.clientId]!;
      final index = workers.indexWhere((w) => w.id == saved.id);

      if (index != -1) {
        workers[index] = saved;
      } else {
        workers.add(saved);
      }

      _setError(null);
      notifyListeners();
      return saved;
    } catch (e) {
      _setError('직원 저장 실패: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteWorker(int clientId, int workerId) async {
    try {
      _setLoading(true);
      await _apiService.deleteEmployee(workerId);

      _workersByClient[clientId]?.removeWhere((w) => w.id == workerId);
      _monthlyDataByWorker.remove(workerId);
      _salaryResults.remove(workerId);

      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('직원 삭제 실패: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ========== 마감 상태 관리 ==========

  // 서버에서 마감 현황 로드
  Future<void> loadConfirmationStatus() async {
    if (_selectedClient == null) return;

    try {
      final status = await _apiService.getConfirmationStatus(
        clientId: _selectedClient!.id,
        year: selectedYear,
        month: selectedMonth,
      );

      _workerFinalizedStatus.clear();
      _payrollResultIds.clear();
      
      final employees = status['employees'] as List?;
      if (employees != null) {
        for (var emp in employees) {
          final employeeId = emp['employeeId'] as int?;
          final resultId = emp['resultId'] as int?;
          final isConfirmed = emp['isConfirmed'] as bool? ?? false;
          if (employeeId != null) {
            _workerFinalizedStatus[employeeId] = isConfirmed;
            if (resultId != null) {
              _payrollResultIds[employeeId] = resultId;
            }
          }
        }
      }

      notifyListeners();
    } catch (e) {
      print('마감 현황 로드 실패: $e');
      // 에러 시 로컬 상태 유지
    }
  }

  bool isWorkerFinalized(int workerId) {
    return _workerFinalizedStatus[workerId] ?? false;
  }

  Future<void> toggleWorkerFinalized(int workerId) async {
    final currentStatus = _workerFinalizedStatus[workerId] ?? false;
    final newStatus = !currentStatus;
    int? resultId = _payrollResultIds[workerId];

    // resultId가 없으면 급여를 먼저 저장
    if (resultId == null) {
      try {
        // 급여 자동 계산 (서버에도 자동 저장됨)
        _calculateSalary(workerId);
        
        // 계산 후 잠시 대기하여 서버 저장 완료 확인
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 마감 현황 다시 로드하여 resultId 갱신
        await loadConfirmationStatus();
        
        resultId = _payrollResultIds[workerId];
        
        if (resultId == null) {
          _setError('급여 결과 저장 실패. 월별 데이터를 먼저 입력해주세요.');
          return;
        }
      } catch (e) {
        _setError('급여 자동 저장 실패: $e');
        return;
      }
    }

    try {
      // 낙관적 업데이트 (UI 먼저 변경)
      _workerFinalizedStatus[workerId] = newStatus;
      notifyListeners();

      // 서버에 마감/마감취소 API 호출
      if (newStatus) {
        await _apiService.confirmPayrollResult(resultId: resultId);
      } else {
        await _apiService.unconfirmPayrollResult(resultId);
      }

      _setError(null);
    } catch (e) {
      print('마감 상태 변경 실패: $e');
      // 실패 시 원래 상태로 복구
      _workerFinalizedStatus[workerId] = currentStatus;
      notifyListeners();
      _setError('마감 상태 변경 실패: $e');
      rethrow;
    }
  }

  List<int> get finalizedWorkerIds {
    return _workerFinalizedStatus.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  /// 전체 마감
  Future<void> confirmAllWorkers() async {
    if (_selectedClient == null) {
      _setError('거래처를 선택해주세요.');
      return;
    }

    try {
      _setLoading(true);
      
      final result = await _apiService.confirmAllPayrollResults(
        clientId: _selectedClient!.id,
        year: selectedYear,
        month: selectedMonth,
        confirmedBy: 'admin',
      );

      // 마감 현황 다시 로드
      await loadConfirmationStatus();
      
      final confirmedCount = result['confirmed'] as int? ?? 0;
      _setError('✅ ${confirmedCount}명 전체 마감 완료');
      
    } catch (e) {
      print('전체 마감 실패: $e');
      _setError('전체 마감 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ========== 월별 근무 데이터 ==========

  Future<void> updateMonthlyData(int workerId, MonthlyData data) async {
    try {
      // 서버에 저장
      await _apiService.saveMonthlyData(data);

      // 로컬 상태 업데이트
      if (_monthlyDataByWorker[workerId] == null) {
        _monthlyDataByWorker[workerId] = {};
      }
      _monthlyDataByWorker[workerId]![_selectedDate.month] = data;

    // 월별 데이터 수정 시 자동 계산 재활성화
    _isManualCalculation[workerId] = false;
    
    // 급여 재계산
    _calculateSalary(workerId);
      notifyListeners();
    } catch (e) {
      _setError('월별 데이터 저장 실패: $e');
      rethrow;
    }
  }

  MonthlyData? getMonthlyData(int workerId) {
    return _monthlyDataByWorker[workerId]?[_selectedDate.month];
  }

  // 현재 월의 모든 직원 MonthlyData Map
  Map<int, MonthlyData> get currentMonthlyDataMap {
    final result = <int, MonthlyData>{};
    for (var entry in _monthlyDataByWorker.entries) {
      final workerId = entry.key;
      final monthlyData = entry.value[_selectedDate.month];
      if (monthlyData != null) {
        result[workerId] = monthlyData;
      }
    }
    return result;
  }

  // ========== 급여 계산 ==========

  void _calculateSalary(int workerId) {
    if (_selectedClient == null) return;

    // 수동 계산된 급여는 자동 재계산하지 않음
    if (_isManualCalculation[workerId] == true) {
      print('⚠️ 수동 수정된 급여입니다. 자동 재계산을 건너뜁니다: Worker $workerId');
      return;
    }

    final worker = currentWorkers.firstWhere((w) => w.id == workerId);
    final monthlyData = getMonthlyData(workerId);

    if (monthlyData == null) return;

    final result = PayrollCalculator.calculate(
      worker: worker,
      monthly: monthlyData,
      has5OrMoreWorkers: _selectedClient!.has5OrMoreWorkers,
    );

    _salaryResults[workerId] = result;
    
    // 서버에 급여 결과 자동 저장 (백그라운드)
    _savePayrollResultToServer(workerId, result, monthlyData);
  }

  Future<void> _savePayrollResultToServer(int workerId, SalaryResult result, MonthlyData monthlyData) async {
    if (_selectedClient == null) return;

    try {
      await _apiService.savePayrollResult(
        employeeId: workerId,
        clientId: _selectedClient!.id,
        year: selectedYear,
        month: selectedMonth,
        salaryData: {
          'baseSalary': result.baseSalary,
          'overtimePay': result.overtimePay,
          'nightPay': result.nightPay,
          'holidayPay': result.holidayPay,
          'weeklyHolidayPay': result.weeklyHolidayPay,
          'bonus': result.bonus,
          'additionalPay1': result.additionalPay1,
          'additionalPay1Name': result.additionalPay1Name,
          'additionalPay2': result.additionalPay2,
          'additionalPay2Name': result.additionalPay2Name,
          'totalPayment': result.totalPayment,
          'nationalPension': result.nationalPension,
          'healthInsurance': result.healthInsurance,
          'longTermCare': result.longTermCare,
          'employmentInsurance': result.employmentInsurance,
          'incomeTax': result.incomeTax,
          'localIncomeTax': result.localIncomeTax,
          'additionalDeduct1': result.additionalDeduct1,
          'additionalDeduct1Name': result.additionalDeduct1Name,
          'additionalDeduct2': result.additionalDeduct2,
          'additionalDeduct2Name': result.additionalDeduct2Name,
          'totalDeduction': result.totalDeduction,
          'netPayment': result.netPayment,
          'normalHours': monthlyData.normalHours,
          'overtimeHours': monthlyData.overtimeHours,
          'nightHours': monthlyData.nightHours,
          'holidayHours': monthlyData.holidayHours,
          'weekCount': monthlyData.weekCount,
          'paymentFormulas': {},
          'deductionFormulas': {},
        },
      );
      
      // 저장 후 마감 상태 갱신
      await loadConfirmationStatus();
    } catch (e) {
      print('급여 결과 서버 저장 실패: $e');
      // 에러가 나도 로컬 계산은 유지 (사용자에게 에러 표시하지 않음)
    }
  }

  void _recalculateAllSalaries() {
    for (var worker in currentWorkers) {
      if (worker.id != null) {
        final monthlyData = getMonthlyData(worker.id!);
        if (monthlyData != null) {
          _calculateSalary(worker.id!);
        }
      }
    }
    notifyListeners();
  }

  /// 특정 직원의 자동 계산 재활성화 (수동 수정 플래그 제거)
  void enableAutoCalculation(int workerId) {
    _isManualCalculation[workerId] = false;
    print('✅ Worker $workerId: 자동 계산 재활성화');
    
    // 즉시 재계산
    _calculateSalary(workerId);
    notifyListeners();
  }

  /// 전체 직원의 자동 계산 재활성화
  void enableAutoCalculationForAll() {
    _isManualCalculation.clear();
    print('✅ 전체 직원: 자동 계산 재활성화');
    
    _recalculateAllSalaries();
  }

  /// 특정 직원을 수동 계산으로 표시 (외부에서 호출용)
  void setManualCalculation(int workerId, bool isManual) {
    _isManualCalculation[workerId] = isManual;
    if (isManual) {
      print('🔒 Worker $workerId: 수동 계산으로 잠금 (자동 재계산 방지)');
    }
  }

  SalaryResult? getSalaryResult(int workerId) {
    return _salaryResults[workerId];
  }

  // ========== Excel 처리 ==========

  Future<void> importFromExcel(String filePath) async {
    try {
      _setLoading(true);

      final parsed = await FileEmailService.parseExcelFile(filePath);
      final clientName = parsed['clientName'] as String;
      final bizId = parsed['bizId'] as String;
      final workersData = parsed['workers'] as List<Map<String, dynamic>>;

      if (_selectedClient == null) {
        throw Exception('거래처를 먼저 선택하세요');
      }

      // 직원 데이터 처리
      for (var data in workersData) {
        // 기존 직원 찾기
        var existingWorker = currentWorkers.firstWhere(
          (w) => w.name == data['name'] && w.birthDate == data['birthDate'],
          orElse: () => WorkerModel(
            clientId: _selectedClient!.id,
            name: '',
            birthDate: '',
          ),
        );

        int workerId;
        bool needsUpdate = false;

        // 신규 직원이면 서버에 저장
        if (existingWorker.id == null || existingWorker.name.isEmpty) {
          print('신규 직원 생성: ${data['name']} (${data['birthDate']})');
          
          final newWorker = WorkerModel(
            clientId: _selectedClient!.id,
            name: data['name'] as String,
            birthDate: data['birthDate'] as String,
            joinDate: data['joinDate'] as String?, // 입사일 추가
            resignDate: data['resignDate'] as String?, // 퇴사일 추가
            phoneNumber: '',
            email: '', // 추가
            employmentType: 'regular',
            salaryType: (data['hourlyRate'] as int) > 0 ? 'HOURLY' : 'MONTHLY', // 대문자로 수정
            monthlySalary: data['monthlySalary'] as int,
            hourlyRate: data['hourlyRate'] as int,
            normalHours: data['normalHours'] as double,
            foodAllowance: 0,
            carAllowance: 0,
            hasNationalPension: true,
            hasHealthInsurance: true,
            hasEmploymentInsurance: true,
            healthInsuranceBasis: 'salary',
            useEmail: false,
          );

          // 서버에 저장하고 ID 받기
          try {
            print('서버에 직원 저장 중...');
            final savedWorker = await saveWorker(newWorker);
            workerId = savedWorker.id!;
            print('저장 성공! Worker ID: $workerId');
          } catch (e) {
            print('저장 실패: $e');
            final errorMsg = '직원 저장 실패 (${data['name']}): $e';
            _setError(errorMsg);
            rethrow; // 에러를 상위로 전파
          }
        } else {
          workerId = existingWorker.id!;
          print('기존 직원: ${existingWorker.name} (ID: $workerId)');
          
          // 기존 직원의 월급/시급/주소정근로시간이 변경되었는지 확인
          final excelMonthlySalary = data['monthlySalary'] as int;
          final excelHourlyRate = data['hourlyRate'] as int;
          final excelJoinDate = data['joinDate'] as String?;
          final excelResignDate = data['resignDate'] as String?;
          
          if (existingWorker.monthlySalary != excelMonthlySalary ||
              existingWorker.hourlyRate != excelHourlyRate ||
              existingWorker.joinDate != excelJoinDate ||
              existingWorker.resignDate != excelResignDate) {
            needsUpdate = true;
            print('직원 정보 변경 감지: ${existingWorker.name}');
            print('  월급: ${existingWorker.monthlySalary} -> $excelMonthlySalary');
            print('  시급: ${existingWorker.hourlyRate} -> $excelHourlyRate');
            
            // 업데이트된 직원 정보로 서버에 저장
            final updatedWorker = existingWorker.copyWith(
              monthlySalary: excelMonthlySalary,
              hourlyRate: excelHourlyRate,
              joinDate: excelJoinDate,
              resignDate: excelResignDate,
              salaryType: excelHourlyRate > 0 ? 'HOURLY' : 'MONTHLY',
            );
            
            try {
              await saveWorker(updatedWorker);
              print('직원 정보 업데이트 완료');
            } catch (e) {
              print('직원 업데이트 실패: $e');
              _setError('직원 업데이트 실패 (${data['name']}): $e');
            }
          }
        }

        // MonthlyData 생성
        final monthlyData = MonthlyData(
          employeeId: workerId,
          ym: selectedYm,
          normalHours: data['normalHours'] as double,
          overtimeHours: data['overtimeHours'] as double,
          nightHours: data['nightHours'] as double,
          holidayHours: data['holidayHours'] as double,
          weeklyHours: data['weeklyHours'] as double,
          weekCount: data['weekCount'] as int,
          bonus: data['bonus'] as int,
          
          // 고정 마스터: additionalPay1 = 식대, additionalPay2 = 차량
          additionalPay1: data['additionalPay1'] as int,
          additionalPay1Name: '식대',
          additionalPay1IsTaxFree: true,
          
          additionalPay2: data['additionalPay2'] as int,
          additionalPay2Name: '자기차량운전보조금',
          additionalPay2IsTaxFree: true,
          
          // 거래처별 첫 번째 마스터: additionalPay3 (이름은 나중에 마스터에서 가져옴)
          additionalPay3: data['additionalPay3'] as int? ?? 0,
          additionalPay3Name: '',  // TODO: 마스터에서 이름 가져오기
          additionalPay3IsTaxFree: false,
          
          additionalDeduct1: data['additionalDeduct1'] as int,
          additionalDeduct1Name: '',
          additionalDeduct2: data['additionalDeduct2'] as int,
          additionalDeduct2Name: '',
        );

        updateMonthlyData(workerId, monthlyData);
      }

      // 직원 목록 갱신
      await loadWorkers(_selectedClient!.id);
      
      // Excel 업로드 시 모든 직원의 자동 계산 재활성화
      enableAutoCalculationForAll();

      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('Excel 가져오기 실패: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> exportExcelTemplate() async {
    if (_selectedClient == null) return;

    try {
      _setLoading(true);
      
      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;
      
      // 거래처별 수당/공제 마스터 로드
      List<AllowanceMaster> allowanceMasters = [];
      List<DeductionMaster> deductionMasters = [];
      
      try {
        allowanceMasters = await _apiService.getAllowanceMasters(_selectedClient!.id);
        deductionMasters = await _apiService.getDeductionMasters(_selectedClient!.id);
      } catch (e) {
        print('마스터 로드 실패 (무시): $e');
      }
      
      // 직원 기본 정보(이름~주소정근로시간)는 DB에서 자동 입력
      // 정상근로시간부터는 사용자가 매달 직접 입력
      await FileEmailService.generateExcelTemplate(
        _selectedClient!.name,
        bizId: _selectedClient!.bizId,
        workers: currentWorkers,
        monthlyDataMap: currentMonthlyDataMap,
        allowanceMasters: allowanceMasters,
        deductionMasters: deductionMasters,
        basePath: basePath,
        useClientSubfolders: useSubfolders,
        year: selectedYear,
        month: selectedMonth,
      );
      _setError(null);
    } catch (e) {
      _setError('템플릿 생성 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> exportCsv() async {
    if (_selectedClient == null || _salaryResults.isEmpty) return;

    try {
      _setLoading(true);
      final results = _salaryResults.values.toList();
      
      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;
      
      await FileEmailService.exportPayrollCsv(
        clientName: _selectedClient!.name,
        year: selectedYear,
        month: selectedMonth,
        results: results,
        basePath: basePath,
        useClientSubfolders: useSubfolders,
      );
      _setError(null);
    } catch (e) {
      _setError('CSV 내보내기 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> exportPayrollRegisterPdf() async {
    if (_selectedClient == null || _salaryResults.isEmpty) return;

    try {
      _setLoading(true);
      final results = _salaryResults.values.toList();
      
      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;
      
      await FileEmailService.exportPayrollRegisterPdf(
        clientName: _selectedClient!.name,
        bizId: _selectedClient!.bizId,
        year: selectedYear,
        month: selectedMonth,
        results: results,
        basePath: basePath,
        useClientSubfolders: useSubfolders,
      );
      _setError(null);
    } catch (e) {
      _setError('급여대장 PDF 내보내기 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ========== PDF 생성 ==========

  Future<void> generatePdf(int workerId) async {
    if (_selectedClient == null) return;

    final result = _salaryResults[workerId];
    if (result == null) return;

    try {
      _setLoading(true);
      
      // 자동 경로 사용 (기본값: OneDrive)
      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;
      
      await FileEmailService.generatePayslipPdf(
        client: _selectedClient!,
        result: result,
        year: selectedYear,
        month: selectedMonth,
        basePath: basePath,
        useClientSubfolders: useSubfolders,
      );
      _setError(null);
    } catch (e) {
      _setError('PDF 생성 실패: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> generateHtml(int workerId) async {
    if (_selectedClient == null) return;

    final result = _salaryResults[workerId];
    if (result == null) return;

    try {
      _setLoading(true);
      
      // 자동 경로 사용 (기본값: OneDrive)
      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;
      
      await FileEmailService.generatePayslipHtml(
        client: _selectedClient!,
        result: result,
        year: selectedYear,
        month: selectedMonth,
        basePath: basePath,
        useClientSubfolders: useSubfolders,
        requireAuth: true, // 다운로드된 HTML 파일은 생년월일 인증 필요
      );
      _setError(null);
    } catch (e) {
      _setError('HTML 생성 실패: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> generateAllPdfs() async {
    if (_selectedClient == null || _salaryResults.isEmpty) return;

    try {
      _setLoading(true);
      
      // 마감된 직원 목록
      final finalizedWorkers = _salaryResults.entries
          .where((entry) => isWorkerFinalized(entry.key))
          .toList();
      
      if (finalizedWorkers.isEmpty) {
        _setError('마감된 직원이 없습니다.');
        return;
      }
      
      int successCount = 0;
      int totalCount = finalizedWorkers.length;
      
      // 기본 경로 사용 (기본값: OneDrive)
      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;
      
      for (var i = 0; i < finalizedWorkers.length; i++) {
        final entry = finalizedWorkers[i];
        final workerId = entry.key;
        final result = entry.value;
        
        try {
          await FileEmailService.generatePayslipPdf(
            client: _selectedClient!,
            result: result,
            year: selectedYear,
            month: selectedMonth,
            basePath: basePath,
            useClientSubfolders: useSubfolders,
          );
          successCount++;
          
          // 진행 상황 업데이트
          _setError('명세서 생성 중... ($successCount/$totalCount)');
          notifyListeners();
        } catch (e) {
          print('PDF 생성 실패 (${result.workerName}): $e');
        }
      }
      
      _setError('명세서 $successCount개 생성 완료!');
      
      // 폴더 열기 (Windows)
      if (Platform.isWindows) {
        final folderPath = PathHelper.getClientFolderPath(
          basePath: basePath,
          clientName: _selectedClient!.name,
          year: selectedYear,
          month: selectedMonth,
        );
        await Process.run('explorer', [folderPath]);
      }
    } catch (e) {
      _setError('PDF 일괄 생성 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ========== 이메일 발송 ==========

  Future<void> sendEmail(int workerId) async {
    if (_selectedClient == null || _smtpConfig == null) return;

    final worker = currentWorkers.firstWhere((w) => w.id == workerId);
    final result = _salaryResults[workerId];

    if (result == null || worker.emailTo == null || worker.emailTo!.isEmpty) {
      throw Exception('이메일 주소가 없습니다');
    }

    try {
      _setLoading(true);

      // PDF 생성 (기본값: OneDrive)
      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;
      
      final pdfFile = await FileEmailService.generatePayslipPdf(
        client: _selectedClient!,
        result: result,
        year: selectedYear,
        month: selectedMonth,
        basePath: basePath,
        useClientSubfolders: useSubfolders,
      );

      // 이메일 발송
      await FileEmailService.sendPayslipEmail(
        smtpConfig: _smtpConfig!,
        client: _selectedClient!,
        worker: worker,
        year: selectedYear,
        month: selectedMonth,
        pdfFile: pdfFile,
      );

      // 발송 로그 저장
      await _apiService.logMail(
        clientId: _selectedClient!.id,
        ym: selectedYm,
        docType: 'slip',
        toEmail: worker.emailTo!,
        subject: _selectedClient!.emailSubjectTemplate
            .replaceAll('{clientName}', _selectedClient!.name)
            .replaceAll('{year}', selectedYear.toString())
            .replaceAll('{month}', selectedMonth.toString())
            .replaceAll('{workerName}', worker.name),
        status: 'sent',
        ccEmail: worker.emailCc,
        employeeId: worker.id,
      );

      // 발송 상태 갱신
      await loadSendStatus();

      _setError(null);
    } catch (e) {
      // 실패 로그 저장
      await _apiService.logMail(
        clientId: _selectedClient!.id,
        ym: selectedYm,
        docType: 'slip',
        toEmail: worker.emailTo!,
        subject: '',
        status: 'failed',
        errorMessage: e.toString(),
        employeeId: worker.id,
      );

      _setError('이메일 발송 실패: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendAllEmails() async {
    if (_selectedClient == null || _smtpConfig == null) return;

    // 마감된 직원 중에서 이메일 발송 조건에 맞는 직원만 선택
    final targetWorkers = currentWorkers.where((w) =>
        w.useEmail && 
        w.emailTo != null && 
        w.emailTo!.isNotEmpty && 
        w.id != null && 
        isWorkerFinalized(w.id!)).toList();

    if (targetWorkers.isEmpty) {
      _setError('발송 대상이 없습니다');
      return;
    }

    try {
      _setLoading(true);
      int successCount = 0;
      int failCount = 0;

      for (var worker in targetWorkers) {
        try {
          await sendEmail(worker.id!);
          successCount++;
        } catch (e) {
          failCount++;
          print('${worker.name} 발송 실패: $e');
        }
      }

      _setError(null);
      notifyListeners();

      // 결과 메시지
      if (failCount == 0) {
        _setError('✅ 전체 발송 완료: $successCount명');
      } else {
        _setError('발송 완료: 성공 $successCount명, 실패 $failCount명');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// HTML 명세서 일괄생성
  Future<void> generateAllHtmlPayslips() async {
    if (_selectedClient == null || _salaryResults.isEmpty) return;

    try {
      _setLoading(true);
      
      // 마감된 직원 목록
      final finalizedWorkers = _salaryResults.entries
          .where((entry) => isWorkerFinalized(entry.key))
          .toList();
      
      if (finalizedWorkers.isEmpty) {
        _setError('마감된 직원이 없습니다.');
        return;
      }
      
      int successCount = 0;
      int totalCount = finalizedWorkers.length;
      
      // 기본 경로 사용 (기본값: OneDrive)
      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;
      
      for (var i = 0; i < finalizedWorkers.length; i++) {
        final entry = finalizedWorkers[i];
        final workerId = entry.key;
        final result = entry.value;
        
        try {
          await FileEmailService.generatePayslipHtml(
            client: _selectedClient!,
            result: result,
            year: selectedYear,
            month: selectedMonth,
            basePath: basePath,
            useClientSubfolders: useSubfolders,
          );
          successCount++;
          
          // 진행 상황 업데이트
          _setError('HTML 명세서 생성 중... ($successCount/$totalCount)');
          notifyListeners();
        } catch (e) {
          print('HTML 생성 실패 (${result.workerName}): $e');
        }
      }
      
      _setError('HTML 명세서 $successCount개 생성 완료!');
      
    } finally {
      _setLoading(false);
    }
  }

  /// HTML 형식으로 이메일 일괄발송
  Future<void> sendAllEmailsAsHtml() async {
    if (_selectedClient == null || _smtpConfig == null) return;

    // 마감된 직원 중에서 이메일 발송 조건에 맞는 직원만 선택
    final targetWorkers = currentWorkers.where((w) =>
        w.useEmail && 
        w.emailTo != null && 
        w.emailTo!.isNotEmpty && 
        w.id != null && 
        isWorkerFinalized(w.id!)).toList();

    if (targetWorkers.isEmpty) {
      _setError('발송 대상이 없습니다');
      return;
    }

    try {
      _setLoading(true);
      int successCount = 0;
      int failCount = 0;

      final basePath = _getValidBasePath();
      final useSubfolders = settings?.useClientSubfolders ?? true;

      for (var worker in targetWorkers) {
        try {
          final result = _salaryResults[worker.id!];
          if (result == null) continue;

          await FileEmailService.sendPayslipEmailAsHtml(
            client: _selectedClient!,
            worker: worker,
            result: result,
            year: selectedYear,
            month: selectedMonth,
            smtpConfig: _smtpConfig!,
            basePath: basePath,
            useClientSubfolders: useSubfolders,
          );
          successCount++;
        } catch (e) {
          failCount++;
          print('${worker.name} HTML 발송 실패: $e');
        }
      }

      _setError(null);
      notifyListeners();

      // 결과 메시지
      if (failCount == 0) {
        _setError('✅ HTML 전체 발송 완료: $successCount명');
      } else {
        _setError('HTML 발송 완료: 성공 $successCount명, 실패 $failCount명');
      }
    } finally {
      _setLoading(false);
    }
  }

  // ========== 발송 상태 ==========

  Future<void> loadSendStatus() async {
    if (_selectedClient == null) return;

    try {
      _sendStatus = await _apiService.getClientSendStatus(
        clientId: _selectedClient!.id,
        ym: selectedYm,
        docType: 'slip',
      );
      notifyListeners();
    } catch (e) {
      print('발송 상태 조회 실패: $e');
    }
  }

  void startStatusPolling() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(AppConstants.statusCheckInterval, (timer) {
      loadSendStatus();
    });
  }

  void stopStatusPolling() {
    _statusCheckTimer?.cancel();
  }

  // ========== 자동 발송 ==========

  void _startAutoSendCheck() {
    _autoSendTimer?.cancel();
    _autoSendTimer = Timer.periodic(AppConstants.autoSendCheckInterval, (timer) {
      _checkAutoSend();
    });
  }

  /// 하마치 IP 가져오기 (25.x.x.x 대역)
  Future<String?> _getHamachiIP() async {
    if (kIsWeb) return null;
    try {
      final interfaces = await NetworkInterface.list();
      
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          // 하마치 IP는 25.x.x.x 대역
          if (addr.address.startsWith('25.')) {
            print('[NETWORK] Hamachi IP found: ${addr.address}');
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('[ERROR] Failed to get Hamachi IP: $e');
    }
    
    return null;
  }

  /// 서버 PC인지 확인 (하마치 IP 체크)
  Future<bool> _isServerPC() async {
    final myHamachiIP = await _getHamachiIP();
    final serverIP = AppConstants.defaultServerUrl.replaceAll('http://', '').split(':')[0];
    
    if (myHamachiIP == null) {
      print('[AUTO] ❌ Hamachi IP not found. Auto send disabled.');
      return false;
    }
    
    final isServer = myHamachiIP == serverIP;
    
    if (isServer) {
      print('[AUTO] ✅ This is SERVER PC (IP: $myHamachiIP)');
    } else {
      print('[AUTO] ❌ This is CLIENT PC (IP: $myHamachiIP, Server: $serverIP)');
    }
    
    return isServer;
  }

  Future<void> _checkAutoSend() async {
    // 서버 PC인지 확인
    if (!await _isServerPC()) {
      return; // 서버 PC가 아니면 자동 발송 안함
    }

    final now = DateTime.now();

    // 오전 9시 체크 (9:00 ~ 9:10)
    if (now.hour == AppConstants.autoSendHour && now.minute < 10) {
      await _autoSendPending();
    }

    // 오후 12시 재시도 (12:00 ~ 12:10)
    if (now.hour == AppConstants.retryHour && now.minute < 10) {
      await _retryFailed();
    }
  }

  Future<void> _autoSendPending() async {
    print('[AUTO] ========================================');
    print('[AUTO] 오전 ${AppConstants.autoSendHour}시 자동 발송 체크 시작');
    print('[AUTO] ========================================');
    
    // 서버 PC인지 재확인
    if (!await _isServerPC()) {
      print('[AUTO] 서버 PC가 아니므로 자동 발송 건너뜀');
      return;
    }

    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // 오늘 이미 발송했는지 체크 (중복 발송 방지)
      if (_lastAutoSendDate == todayStr) {
        print('[AUTO] ⚠️  오늘 이미 자동 발송을 완료했습니다. 건너뜀.');
        return;
      }
      
      // 모든 거래처 조회
      if (_clients.isEmpty) {
        await syncClients();
      }
      
      // 오늘이 발송일인 거래처 필터링
      final targetClients = _clients.where((client) {
        return client.slipSendDay == today.day;
      }).toList();
      
      if (targetClients.isEmpty) {
        print('[AUTO] 오늘(${today.day}일) 발송할 거래처가 없습니다.');
        return;
      }
      
      print('[AUTO] 📧 발송 대상 거래처: ${targetClients.length}개');
      
      int successCount = 0;
      int failCount = 0;
      
      for (var client in targetClients) {
        try {
          print('[AUTO] ---------------------------------------');
          print('[AUTO] 거래처: "${client.name}" 자동 발송 시작...');
          
          // 거래처 선택
          _selectedClient = client;
          
          // 직원 목록 로드
          await loadWorkers(client.id);
          
          if (currentWorkers.isEmpty) {
            print('[AUTO] ⚠️  "${client.name}": 직원이 없습니다. 건너뜀.');
            continue;
          }
          
          // 월별 데이터 로드
          await _loadMonthlyDataForAllWorkers();
          
          // 급여 계산
          _recalculateAllSalaries();
          
          // 이메일 사용 설정된 직원 확인
          final emailWorkers = currentWorkers.where((w) => w.useEmail && w.emailTo != null && w.emailTo!.isNotEmpty).toList();
          
          if (emailWorkers.isEmpty) {
            print('[AUTO] ⚠️  "${client.name}": 이메일 설정된 직원이 없습니다. 건너뜀.');
            continue;
          }
          
          print('[AUTO] 📨 이메일 발송 시작... (${emailWorkers.length}명)');
          
          // 이메일 일괄 발송
          await sendAllEmails();
          
          // 급여발송로그 저장 (거래처 단위, 자동 발송 성공)
          try {
            final hamachiIP = await _getHamachiIP();
            await _apiService.logPayrollSend(
              clientId: client.id,
              ym: selectedYm,
              docType: 'slip',
              sendResult: '성공',
              retryCount: 0,
              recipient: '${emailWorkers.length}명',
              subject: '${client.name} ${selectedYear}년 ${selectedMonth}월 급여명세서',
              sendMethod: '자동',
              sendPath: 'SMTP',
              executingPC: hamachiIP ?? 'Unknown',
              executor: 'AUTO_SYSTEM',
            );
          } catch (e) {
            print('[AUTO] ⚠️  급여발송로그 저장 실패: $e');
          }
          
          print('[AUTO] ✅ "${client.name}" 발송 완료 (${emailWorkers.length}명)');
          successCount++;
          
        } catch (e) {
          print('[AUTO] ❌ "${client.name}" 발송 실패: $e');
          
          // 급여발송로그 저장 (거래처 단위, 자동 발송 실패)
          try {
            final hamachiIP = await _getHamachiIP();
            await _apiService.logPayrollSend(
              clientId: client.id,
              ym: selectedYm,
              docType: 'slip',
              sendResult: '실패',
              retryCount: 0,
              errorMessage: e.toString(),
              subject: '${client.name} ${selectedYear}년 ${selectedMonth}월 급여명세서',
              sendMethod: '자동',
              sendPath: 'SMTP',
              executingPC: hamachiIP ?? 'Unknown',
              executor: 'AUTO_SYSTEM',
            );
          } catch (logError) {
            print('[AUTO] ⚠️  급여발송로그 저장 실패: $logError');
          }
          
          failCount++;
        }
      }
      
      print('[AUTO] ========================================');
      print('[AUTO] 자동 발송 완료!');
      print('[AUTO] 성공: $successCount개 거래처');
      print('[AUTO] 실패: $failCount개 거래처');
      print('[AUTO] ========================================');
      
      // 발송 기록 저장 (중복 방지)
      _lastAutoSendDate = todayStr;
      
    } catch (e) {
      print('[AUTO ERROR] 자동 발송 중 오류 발생: $e');
    }
  }

  Future<void> _retryFailed() async {
    print('[AUTO] ========================================');
    print('[AUTO] 오후 ${AppConstants.retryHour}시 실패건 재시도 시작');
    print('[AUTO] ========================================');
    
    // 서버 PC인지 재확인
    if (!await _isServerPC()) {
      print('[AUTO] 서버 PC가 아니므로 재시도 건너뜀');
      return;
    }

    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // 오늘 이미 재시도했는지 체크 (중복 방지)
      if (_lastRetryDate == todayStr) {
        print('[AUTO] ⚠️  오늘 이미 재시도를 완료했습니다. 건너뜀.');
        return;
      }
      
      // 발송 상태 로드
      await loadSendStatus();
      
      final sendStatus = _sendStatus;
      if (sendStatus == null) {
        print('[AUTO] 발송 상태 정보가 없습니다.');
        return;
      }
      
      // 실패건이 있는지 확인 (isSent가 false인 직원)
      final failedEmployees = sendStatus.employees.where((e) => !e.isSent).toList();
      final failedCount = failedEmployees.length;
      
      if (failedCount == 0) {
        print('[AUTO] 재시도할 실패건이 없습니다.');
        return;
      }
      
      print('[AUTO] 🔄 실패건 재시도 시작... ($failedCount건)');
      
      // 실패건 재발송
      await retryFailedEmails();
      
      print('[AUTO] ========================================');
      print('[AUTO] 실패건 재시도 완료!');
      print('[AUTO] ========================================');
      
      // 재시도 기록 저장 (중복 방지)
      _lastRetryDate = todayStr;
      
    } catch (e) {
      print('[AUTO ERROR] 실패건 재시도 중 오류 발생: $e');
    }
  }

  Future<void> retryFailedEmails() async {
    final sendStatus = _sendStatus;
    if (sendStatus == null) return;

    final failedEmployees = sendStatus.employees
        .where((e) => e.useEmail && e.lastStatus == 'failed' && e.emailTo != null)
        .toList();

    if (failedEmployees.isEmpty) {
      _setError('재발송 대상이 없습니다');
      return;
    }

    try {
      _setLoading(true);
      int successCount = 0;
      int failCount = 0;

      for (var employee in failedEmployees) {
        try {
          await sendEmail(employee.employeeId);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      _setError(null);
      notifyListeners();

      if (failCount == 0) {
        _setError('✅ 재발송 완료: $successCount명');
      } else {
        _setError('재발송 완료: 성공 $successCount명, 실패 $failCount명');
      }
    } finally {
      _setLoading(false);
    }
  }
}
