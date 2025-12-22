import 'dart:math';
import '../core/models.dart';
import '../core/constants.dart';
import 'income_tax_calculator.dart';

class PayrollCalculator {
  /// 급여 계산 (정규직 / 프리랜서)
  static SalaryResult calculate({
    required WorkerModel worker,
    required MonthlyData monthly,
    required bool has5OrMoreWorkers,
  }) {
    final isFreelancer = worker.employmentType == 'freelance';

    if (isFreelancer) {
      return _calculateFreelancer(worker: worker, monthly: monthly);
    } else {
      return _calculateRegular(
        worker: worker,
        monthly: monthly,
        has5OrMoreWorkers: has5OrMoreWorkers,
      );
    }
  }

  /// 정규직 급여 계산
  static SalaryResult _calculateRegular({
    required WorkerModel worker,
    required MonthlyData monthly,
    required bool has5OrMoreWorkers,
  }) {
    // ===== 통상시급 계산 =====
    // 📌 근로기준법상 통상시급 정의:
    // - "정기적·일률적·고정적으로 지급되는 임금을 시급으로 환산한 금액"
    // - 연장/야간/휴일수당 계산의 기준이 되는 시급
    //
    // 📌 월급제의 경우:
    // - 통상시급 = 월급 ÷ 월 소정근로시간
    // - 월 소정근로시간 = 주소정근로시간 × 4.345주 (주휴 포함)
    // - 예: 월급 3,000,000원, 주 40시간 → 통상시급 = 3,000,000 ÷ (40 × 4.345) = 17,271원
    //
    // 📌 시급제의 경우:
    // - 입력된 시급을 통상시급으로 사용
    int hourlyRate = worker.hourlyRate;
    String hourlyRateSource = '입력된 시급';
    // 월급제 판정: salaryType이 'MONTHLY'이거나, 시급이 0이고 월급이 있으면 월급제
    bool isMonthlyWorker = (worker.salaryType == 'MONTHLY' && worker.monthlySalary > 0)
                        || (worker.hourlyRate == 0 && worker.monthlySalary > 0);
    
    if (isMonthlyWorker) {
      // 월급제: 통상시급 자동 계산
      // 주휴시간은 별도 계산하지 않음 (월급에 이미 포함되어 있음)
      final weeklyHours = monthly.weeklyHours > 0 ? monthly.weeklyHours : 40.0;
      final monthlyHours = weeklyHours * AppConstants.weeksPerMonth; // 예: 40 × 4.345 = 173.8시간
      hourlyRate = (worker.monthlySalary / monthlyHours).round();
      hourlyRateSource = '${formatMoney(worker.monthlySalary)}원 ÷ ${monthlyHours.toStringAsFixed(1)}시간 = 통상시급 ${formatMoney(hourlyRate)}원';
    }
    
    final normalHours = monthly.normalHours;

    // ===== 지급 항목 =====

    // 1. 기본급
    // 월급제: 월급 그대로 사용 (통상시급 계산식 표시)
    // 시급제: 시급 × 정상근로시간
    int baseSalary;
    String baseSalaryFormula;
    
    if (isMonthlyWorker) {
      baseSalary = worker.monthlySalary;
      // 월급제는 통상시급 계산식 포함
      final weeklyHours = monthly.weeklyHours > 0 ? monthly.weeklyHours : 40.0;
      final monthlyHours = weeklyHours * AppConstants.weeksPerMonth;
      baseSalaryFormula = '월급 ${formatMoney(worker.monthlySalary)}원 (통상시급: ${formatMoney(hourlyRate)}원 = ${formatMoney(worker.monthlySalary)}원 ÷ ${monthlyHours.toStringAsFixed(1)}h)';
    } else {
      baseSalary = (hourlyRate * normalHours).round();
      baseSalaryFormula = '${formatMoney(hourlyRate)}원 × ${normalHours.toStringAsFixed(0)}시간';
    }

    // 2. 연장수당 (5인 이상 사업장만)
    int overtimePay = 0;
    String overtimeFormula = '';
    if (has5OrMoreWorkers && monthly.overtimeHours > 0) {
      overtimePay = (hourlyRate * monthly.overtimeHours * AppConstants.overtimeMultiplier).round();
      overtimeFormula =
          '${formatMoney(hourlyRate)}원 × ${monthly.overtimeHours.toStringAsFixed(0)}시간 × 1.5';
    }

    // 3. 야간수당 (5인 이상 사업장만)
    int nightPay = 0;
    String nightFormula = '';
    if (has5OrMoreWorkers && monthly.nightHours > 0) {
      nightPay = (hourlyRate * monthly.nightHours * AppConstants.nightMultiplier).round();
      nightFormula =
          '${formatMoney(hourlyRate)}원 × ${monthly.nightHours.toStringAsFixed(0)}시간 × 0.5';
    }

    // 4. 휴일수당 (5인 이상 사업장만)
    // 8시간까지는 1.5배, 8시간 초과는 2배
    int holidayPay = 0;
    String holidayFormula = '';
    if (has5OrMoreWorkers && monthly.holidayHours > 0) {
      if (monthly.holidayHours <= 8) {
        // 8시간 이하: 1.5배
        holidayPay = (hourlyRate * monthly.holidayHours * 1.5).round();
        holidayFormula =
            '${formatMoney(hourlyRate)}원 × ${monthly.holidayHours.toStringAsFixed(1)}시간 × 1.5';
      } else {
        // 8시간 초과: 8시간까지는 1.5배, 초과분은 2배
        final baseHours = 8.0;
        final overtimeHours = monthly.holidayHours - 8;
        final basePay = (hourlyRate * baseHours * 1.5).round();
        final overtimePay = (hourlyRate * overtimeHours * 2.0).round();
        holidayPay = basePay + overtimePay;
        holidayFormula =
            '(${formatMoney(hourlyRate)}원 × 8h × 1.5) + (${formatMoney(hourlyRate)}원 × ${overtimeHours.toStringAsFixed(1)}h × 2.0)';
      }
    }

    // 5. 주휴수당 (시급제만 계산, 월급제는 이미 포함되어 있음)
    // 📌 주휴수당 지급 조건: 주 소정근로시간 15시간 이상 (근로기준법 제18조)
    int weeklyHolidayPay = 0;
    String weeklyHolidayFormula = '';
    if (!isMonthlyWorker && monthly.weekCount > 0 && monthly.weeklyHours >= 15) {
      // 시급제만: 시급 × 1일 소정근로시간(최대 8시간) × 개근주수
      // 1일 소정근로시간 = 주 소정근로시간 ÷ 5일 (최대 8시간)
      final dailyHours = min(monthly.weeklyHours / 5, 8.0);
      weeklyHolidayPay = (hourlyRate * dailyHours * monthly.weekCount).round();
      weeklyHolidayFormula =
          '${formatMoney(hourlyRate)}원 × ${dailyHours.toStringAsFixed(1)}시간 × ${monthly.weekCount}주';
    } else if (isMonthlyWorker) {
      weeklyHolidayFormula = '월급에 포함';
    } else if (!isMonthlyWorker && monthly.weeklyHours > 0 && monthly.weeklyHours < 15) {
      weeklyHolidayFormula = '주 15시간 미만 (지급 대상 아님)';
    }

    // 6. 상여금
    final bonus = monthly.bonus;

    // 7. 추가수당
    final additionalPay1 = monthly.additionalPay1;
    final additionalPay1Name = monthly.additionalPay1Name;
    final additionalPay2 = monthly.additionalPay2;
    final additionalPay2Name = monthly.additionalPay2Name;
    final additionalPay3 = monthly.additionalPay3;
    final additionalPay3Name = monthly.additionalPay3Name;

    // ===== 지급총액 =====
    final totalPayment = baseSalary +
        overtimePay +
        nightPay +
        holidayPay +
        weeklyHolidayPay +
        bonus +
        additionalPay1 +
        additionalPay2 +
        additionalPay3 +
        worker.taxFreeMeal +
        worker.taxFreeCarMaintenance +
        worker.otherTaxFree;

    // ===== 4대보험 기준액 계산 =====
    // 과세 대상 수당: 기본급 + 연장 + 야간 + 휴일 + 주휴 + 상여금 + 과세 추가수당
    // 비과세 수당: WorkerModel의 비과세 항목 + MonthlyData의 비과세 추가수당
    final taxableIncome = baseSalary +
        overtimePay +
        nightPay +
        holidayPay +
        weeklyHolidayPay +
        bonus +
        monthly.taxableAdditionalPay; // 과세 추가수당만 포함
    
    // 비과세 합계 (WorkerModel + MonthlyData)
    final totalTaxFree = worker.taxFreeMeal + 
                        worker.taxFreeCarMaintenance + 
                        worker.otherTaxFree +
                        monthly.taxFreeAdditionalPay; // 비과세 추가수당
    
    // 4대보험 기준액 = 과세 소득 (비과세 수당 제외됨)
    final insuranceBase = taxableIncome;

    // ===== 공제 항목 =====

    // 1. 국민연금 (4.5%) - 10원 미만 절사
    int nationalPension = 0;
    String pensionFormula = '';
    if (worker.hasNationalPension) {
      final pensionBase = worker.pensionInsurableWage ?? insuranceBase;
      nationalPension = ((pensionBase * AppConstants.pensionRate) ~/ 10) * 10; // 10원 미만 절사
      pensionFormula = '${formatMoney(pensionBase)}원 × 4.5%';
    }

    // 2. 건강보험 (3.545%) - 10원 미만 절사
    int healthInsurance = 0;
    String healthFormula = '';
    if (worker.hasHealthInsurance) {
      final healthBase = worker.healthInsuranceBasis == 'salary'
          ? insuranceBase
          : (worker.pensionInsurableWage ?? insuranceBase);
      healthInsurance = ((healthBase * AppConstants.healthRate) ~/ 10) * 10; // 10원 미만 절사
      healthFormula = '${formatMoney(healthBase)}원 × 3.545%';
    }

    // 3. 장기요양 (12.95%) - 10원 미만 절사
    int longTermCare = 0;
    String longTermCareFormula = '';
    if (worker.hasHealthInsurance) {
      longTermCare = ((healthInsurance * AppConstants.longTermCareRate) ~/ 10) * 10; // 10원 미만 절사
      longTermCareFormula = '${formatMoney(healthInsurance)}원 × 12.95%';
    }

    // 4. 고용보험 (0.9%) - 10원 미만 절사
    int employmentInsurance = 0;
    String employmentFormula = '';
    if (worker.hasEmploymentInsurance) {
      employmentInsurance = ((insuranceBase * AppConstants.employmentRate) ~/ 10) * 10; // 10원 미만 절사
      employmentFormula = '${formatMoney(insuranceBase)}원 × 0.9%';
    }

    // 5. 소득세 (근로소득 간이세액표 적용)
    // 근로소득자: 간이세액표 / 사업소득자: 3.3% (프리랜서와 동일)
    int incomeTax;
    int localIncomeTax;
    String incomeTaxFormula;
    String localTaxFormula;
    
    // 월 과세소득 계산 (비과세 제외)
    final monthlyTaxableIncome = taxableIncome;
    
    // 공제대상 가족수 (WorkerModel에서 가져옴)
    final taxDependents = worker.taxDependents;
    
    // 간이세액표 적용하여 소득세 계산 (자녀 수 반영)
    final taxes = IncomeTaxCalculator.calculateIncomeTax(
      monthlyIncome: monthlyTaxableIncome,
      familyCount: taxDependents,
      childrenCount: worker.childrenCount, // 8-20세 자녀 수
    );
    
    // 소득세율 적용 (80%, 100%, 120%)
    final taxRateMultiplier = worker.incomeTaxRate / 100.0;
    incomeTax = ((taxes[0] * taxRateMultiplier) ~/ 10) * 10; // 1의 자리 절사
    localIncomeTax = ((taxes[1] * taxRateMultiplier) ~/ 10) * 10; // 1의 자리 절사
    
    String taxRateLabel = '';
    if (worker.incomeTaxRate == 80) {
      taxRateLabel = ' × 80%';
    } else if (worker.incomeTaxRate == 120) {
      taxRateLabel = ' × 120%';
    }
    
    // 소득세 공식 설명 (명세서에는 표시 안 함, 프리랜서만 3.3% 표시)
    incomeTaxFormula = ''; // 근로소득세는 명세서에 계산식 표시 안 함
    localTaxFormula = ''; // 지방소득세도 명세서에 계산식 표시 안 함

    // 7. 추가공제
    final additionalDeduct1 = monthly.additionalDeduct1;
    final additionalDeduct1Name = monthly.additionalDeduct1Name;
    final additionalDeduct2 = monthly.additionalDeduct2;
    final additionalDeduct2Name = monthly.additionalDeduct2Name;
    final additionalDeduct3 = monthly.additionalDeduct3;
    final additionalDeduct3Name = monthly.additionalDeduct3Name;

    return SalaryResult(
      workerName: worker.name,
      birthDate: worker.birthDate,
      employmentType: worker.employmentType,
      baseSalary: baseSalary,
      overtimePay: overtimePay,
      nightPay: nightPay,
      holidayPay: holidayPay,
      weeklyHolidayPay: weeklyHolidayPay,
      bonus: bonus,
      additionalPay1: additionalPay1,
      additionalPay1Name: additionalPay1Name,
      additionalPay2: additionalPay2,
      additionalPay2Name: additionalPay2Name,
      additionalPay3: additionalPay3,
      additionalPay3Name: additionalPay3Name,
      nationalPension: nationalPension,
      healthInsurance: healthInsurance,
      longTermCare: longTermCare,
      employmentInsurance: employmentInsurance,
      incomeTax: incomeTax,
      localIncomeTax: localIncomeTax,
      additionalDeduct1: additionalDeduct1,
      additionalDeduct1Name: additionalDeduct1Name,
      additionalDeduct2: additionalDeduct2,
      additionalDeduct2Name: additionalDeduct2Name,
      additionalDeduct3: additionalDeduct3,
      additionalDeduct3Name: additionalDeduct3Name,
      baseSalaryFormula: baseSalaryFormula,
      overtimeFormula: overtimeFormula,
      nightFormula: nightFormula,
      holidayFormula: holidayFormula,
      weeklyHolidayFormula: weeklyHolidayFormula,
      pensionFormula: pensionFormula,
      healthFormula: healthFormula,
      longTermCareFormula: longTermCareFormula,
      employmentFormula: employmentFormula,
      incomeTaxFormula: incomeTaxFormula,
      localTaxFormula: localTaxFormula,
    );
  }

  /// 프리랜서 급여 계산
  static SalaryResult _calculateFreelancer({
    required WorkerModel worker,
    required MonthlyData monthly,
  }) {
    final hourlyRate = worker.hourlyRate;
    final normalHours = monthly.normalHours;

    // ===== 지급 항목 =====

    // 1. 기본급 (시급 × 정상근로시간)
    final baseSalary = (hourlyRate * normalHours).round();
    final baseSalaryFormula = '${formatMoney(hourlyRate)}원 × ${normalHours.toStringAsFixed(0)}시간';

    // 2. 주휴수당 (개근주수 × 시급 × 주소정근로시간)
    // 📌 주휴수당 지급 조건: 주 소정근로시간 15시간 이상 (근로기준법 제18조)
    int weeklyHolidayPay = 0;
    String weeklyHolidayFormula = '';
    if (monthly.weekCount > 0 && monthly.weeklyHours >= 15) {
      weeklyHolidayPay = (hourlyRate * monthly.weeklyHours * monthly.weekCount).round();
      weeklyHolidayFormula =
          '${formatMoney(hourlyRate)}원 × ${monthly.weeklyHours.toStringAsFixed(0)}시간 × ${monthly.weekCount}주';
    } else if (monthly.weeklyHours > 0 && monthly.weeklyHours < 15) {
      weeklyHolidayFormula = '주 15시간 미만 (지급 대상 아님)';
    }

    // 3. 상여금
    final bonus = monthly.bonus;

    // 4. 추가수당
    final additionalPay1 = monthly.additionalPay1;
    final additionalPay1Name = monthly.additionalPay1Name;
    final additionalPay2 = monthly.additionalPay2;
    final additionalPay2Name = monthly.additionalPay2Name;
    final additionalPay3 = monthly.additionalPay3;
    final additionalPay3Name = monthly.additionalPay3Name;

    // ===== 지급총액 =====
    final totalPayment = baseSalary +
        weeklyHolidayPay +
        bonus +
        additionalPay1 +
        additionalPay2 +
        additionalPay3;

    // ===== 공제 항목 =====

    // 1. 소득세 (3.0% - 10원 미만 절사)
    final incomeTaxRaw = (totalPayment * 0.03);
    final incomeTax = (incomeTaxRaw ~/ 10) * 10; // 10원 미만 절사
    final incomeTaxFormula = '${formatMoney(totalPayment)}원 × 3.0%';

    // 2. 지방소득세 (0.3% - 10원 미만 절사)
    final localIncomeTaxRaw = (totalPayment * 0.003);
    final localIncomeTax = (localIncomeTaxRaw ~/ 10) * 10; // 10원 미만 절사
    final localTaxFormula = '${formatMoney(totalPayment)}원 × 0.3%';

    // 2. 추가공제
    final additionalDeduct1 = monthly.additionalDeduct1;
    final additionalDeduct1Name = monthly.additionalDeduct1Name;
    final additionalDeduct2 = monthly.additionalDeduct2;
    final additionalDeduct2Name = monthly.additionalDeduct2Name;
    final additionalDeduct3 = monthly.additionalDeduct3;
    final additionalDeduct3Name = monthly.additionalDeduct3Name;

    return SalaryResult(
      workerName: worker.name,
      birthDate: worker.birthDate,
      employmentType: worker.employmentType,
      baseSalary: baseSalary,
      overtimePay: 0,
      nightPay: 0,
      holidayPay: 0,
      weeklyHolidayPay: weeklyHolidayPay,
      bonus: bonus,
      additionalPay1: additionalPay1,
      additionalPay1Name: additionalPay1Name,
      additionalPay2: additionalPay2,
      additionalPay2Name: additionalPay2Name,
      additionalPay3: additionalPay3,
      additionalPay3Name: additionalPay3Name,
      nationalPension: 0,
      healthInsurance: 0,
      longTermCare: 0,
      employmentInsurance: 0,
      incomeTax: incomeTax,
      localIncomeTax: localIncomeTax,
      additionalDeduct1: additionalDeduct1,
      additionalDeduct1Name: additionalDeduct1Name,
      additionalDeduct2: additionalDeduct2,
      additionalDeduct2Name: additionalDeduct2Name,
      additionalDeduct3: additionalDeduct3,
      additionalDeduct3Name: additionalDeduct3Name,
      baseSalaryFormula: baseSalaryFormula,
      overtimeFormula: '',
      nightFormula: '',
      holidayFormula: '',
      weeklyHolidayFormula: weeklyHolidayFormula,
      pensionFormula: '',
      healthFormula: '',
      longTermCareFormula: '',
      employmentFormula: '',
      incomeTaxFormula: incomeTaxFormula,
      localTaxFormula: localTaxFormula,
    );
  }

  /// 시급 자동 계산 (월급 → 시급)
  static int calculateHourlyRate({
    required int monthlySalary,
    required double weeklyHours,
  }) {
    if (monthlySalary == 0 || weeklyHours == 0) return 0;
    
    // 월급 ÷ (주당시간 × 4.345주)
    final hourlyRate = monthlySalary / (weeklyHours * AppConstants.weeksPerMonth);
    return hourlyRate.round();
  }

  /// 월급 자동 계산 (시급 → 월급)
  static int calculateMonthlySalary({
    required int hourlyRate,
    required double weeklyHours,
  }) {
    if (hourlyRate == 0 || weeklyHours == 0) return 0;
    
    // 시급 × 주당시간 × 4.345주
    final monthlySalary = hourlyRate * weeklyHours * AppConstants.weeksPerMonth;
    return monthlySalary.round();
  }
}
