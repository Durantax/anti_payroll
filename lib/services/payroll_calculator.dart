import 'dart:math';
import '../core/models.dart';
import '../core/constants.dart';

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
    // 월급제의 경우: 월급 ÷ (주소정근로시간 × 4.345주)
    // 시급제의 경우: 입력된 시급 사용
    int hourlyRate = worker.hourlyRate;
    String hourlyRateSource = '입력된 시급';
    
    if (worker.salaryType == 'MONTHLY' && worker.monthlySalary > 0) {
      // 월급제: 통상시급 자동 계산
      final weeklyHours = monthly.weeklyHours > 0 ? monthly.weeklyHours : 40.0;
      hourlyRate = (worker.monthlySalary / (weeklyHours * AppConstants.weeksPerMonth)).round();
      hourlyRateSource = '${formatMoney(worker.monthlySalary)}원 ÷ (${weeklyHours}시간 × 4.345주)';
    }
    
    final normalHours = monthly.normalHours;

    // ===== 지급 항목 =====

    // 1. 기본급
    // 월급제: 월급 그대로 사용
    // 시급제: 시급 × 정상근로시간
    int baseSalary;
    String baseSalaryFormula;
    
    if (worker.salaryType == 'MONTHLY' && worker.monthlySalary > 0) {
      baseSalary = worker.monthlySalary;
      baseSalaryFormula = '월급 ${formatMoney(worker.monthlySalary)}원';
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

    // 5. 주휴수당 (시급 × 1일 소정근로시간(최대 8시간) × 개근주수)
    int weeklyHolidayPay = 0;
    String weeklyHolidayFormula = '';
    if (monthly.weekCount > 0 && monthly.weeklyHours > 0) {
      // 1일 소정근로시간 = 주 소정근로시간 ÷ 5일 (최대 8시간)
      final dailyHours = min(monthly.weeklyHours / 5, 8.0);
      weeklyHolidayPay = (hourlyRate * dailyHours * monthly.weekCount).round();
      weeklyHolidayFormula =
          '${formatMoney(hourlyRate)}원 × ${dailyHours.toStringAsFixed(1)}시간 × ${monthly.weekCount}주';
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
        worker.foodAllowance +
        worker.carAllowance;

    // ===== 4대보험 기준액 계산 =====
    // 과세 대상 수당: 기본급 + 연장 + 야간 + 휴일 + 주휴 + 상여금 + 추가수당
    // 비과세 수당: 식대, 차량유지비 제외
    // TODO: 추가수당의 과세 여부는 수당 마스터 연동 후 개선
    final taxableIncome = baseSalary +
        overtimePay +
        nightPay +
        holidayPay +
        weeklyHolidayPay +
        bonus +
        additionalPay1 +
        additionalPay2 +
        additionalPay3;
    
    // 4대보험 기준액 = 과세 소득 (비과세 수당 제외됨)
    final insuranceBase = taxableIncome;

    // ===== 공제 항목 =====

    // 1. 국민연금 (4.5%)
    int nationalPension = 0;
    String pensionFormula = '';
    if (worker.hasNationalPension) {
      final pensionBase = worker.pensionInsurableWage ?? insuranceBase;
      nationalPension = (pensionBase * AppConstants.pensionRate).round();
      pensionFormula = '${formatMoney(pensionBase)}원 × 4.5%';
    }

    // 2. 건강보험 (3.545%)
    int healthInsurance = 0;
    String healthFormula = '';
    if (worker.hasHealthInsurance) {
      final healthBase = worker.healthInsuranceBasis == 'salary'
          ? insuranceBase
          : (worker.pensionInsurableWage ?? insuranceBase);
      healthInsurance = (healthBase * AppConstants.healthRate).round();
      healthFormula = '${formatMoney(healthBase)}원 × 3.545%';
    }

    // 3. 장기요양 (12.95%)
    int longTermCare = 0;
    String longTermCareFormula = '';
    if (worker.hasHealthInsurance) {
      longTermCare = (healthInsurance * AppConstants.longTermCareRate).round();
      longTermCareFormula = '${formatMoney(healthInsurance)}원 × 12.95%';
    }

    // 4. 고용보험 (0.9%)
    int employmentInsurance = 0;
    String employmentFormula = '';
    if (worker.hasEmploymentInsurance) {
      employmentInsurance = (insuranceBase * AppConstants.employmentRate).round();
      employmentFormula = '${formatMoney(insuranceBase)}원 × 0.9%';
    }

    // 5. 소득세 (3.3% - 1의 자리 절사)
    // 과세 소득 기준 (비과세 수당 제외)
    final incomeTaxRaw = (taxableIncome * AppConstants.incomeTaxRate).round();
    final incomeTax = (incomeTaxRaw ~/ 10) * 10; // 1의 자리 절사
    final incomeTaxFormula = '${formatMoney(taxableIncome)}원 × 3.3%';

    // 6. 지방소득세 (소득세의 10% - 1의 자리 절사)
    final localIncomeTaxRaw = (incomeTax * AppConstants.localTaxRate).round();
    final localIncomeTax = (localIncomeTaxRaw ~/ 10) * 10; // 1의 자리 절사
    final localTaxFormula = '${formatMoney(incomeTax)}원 × 10%';

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
    int weeklyHolidayPay = 0;
    String weeklyHolidayFormula = '';
    if (monthly.weekCount > 0) {
      weeklyHolidayPay = (hourlyRate * monthly.weeklyHours * monthly.weekCount).round();
      weeklyHolidayFormula =
          '${formatMoney(hourlyRate)}원 × ${monthly.weeklyHours.toStringAsFixed(0)}시간 × ${monthly.weekCount}주';
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

    // 1. 소득세 (3.3% - 1의 자리 절사)
    final incomeTaxRaw = (totalPayment * AppConstants.incomeTaxRate).round();
    final incomeTax = (incomeTaxRaw ~/ 10) * 10; // 1의 자리 절사
    final incomeTaxFormula = '${formatMoney(totalPayment)}원 × 3.3%';

    // 프리랜서는 지방소득세 없음 (3.3%에 포함)
    final localIncomeTax = 0;
    final localTaxFormula = '';

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
