import 'dart:math';

// 테스트 케이스: 스크린샷과 동일한 조건
void main() {
  print('=== 월급제 직원 급여 계산 테스트 ===\n');
  
  // 입력값 (스크린샷)
  final monthlySalary = 2000000;  // 월급 200만원
  final weeklyHours = 14.0;       // 주소정근로시간 14시간
  final normalHours = 50.0;       // 정상근로시간 (월급제는 사용 안 함)
  final overtimeHours = 5.0;      // 연장 5시간
  final nightHours = 5.0;         // 야간 5시간
  final holidayHours = 5.0;       // 휴일 5시간
  final weekCount = 4;            // 개근주수 4주
  
  final salaryType = 'MONTHLY';
  final weeksPerMonth = 4.345;
  
  print('📋 입력값:');
  print('  - 월급: ${formatMoney(monthlySalary)}원');
  print('  - 급여 유형: $salaryType');
  print('  - 주소정근로시간: $weeklyHours시간');
  print('  - 정상근로시간: $normalHours시간 (월급제는 사용 안 함)');
  print('  - 연장시간: $overtimeHours시간');
  print('  - 야간시간: $nightHours시간');
  print('  - 휴일시간: $holidayHours시간');
  print('  - 개근주수: $weekCount주');
  
  // 통상시급 계산
  final monthlyHours = weeklyHours * weeksPerMonth;
  final hourlyRate = (monthlySalary / monthlyHours).round();
  
  print('\n💰 통상시급 계산:');
  print('  - 월 소정근로시간: $weeklyHours × $weeksPerMonth = ${monthlyHours.toStringAsFixed(1)}시간');
  print('  - 통상시급: ${formatMoney(monthlySalary)}원 ÷ ${monthlyHours.toStringAsFixed(1)}시간');
  print('  - 통상시급: ${formatMoney(hourlyRate)}원');
  
  // 기본급 (월급제는 월급 그대로)
  final baseSalary = monthlySalary;
  
  // 연장수당
  final overtimePay = (hourlyRate * overtimeHours * 1.5).round();
  
  // 야간수당
  final nightPay = (hourlyRate * nightHours * 0.5).round();
  
  // 휴일수당
  final holidayPay = holidayHours <= 8 
    ? (hourlyRate * holidayHours * 1.5).round()
    : (hourlyRate * 8 * 1.5).round() + (hourlyRate * (holidayHours - 8) * 2.0).round();
  
  // 주휴수당 (월급제는 월급에 포함)
  final weeklyHolidayPay = 0;
  
  // 지급총액
  final totalPayment = baseSalary + overtimePay + nightPay + holidayPay + weeklyHolidayPay;
  
  print('\n📊 급여 항목:');
  print('  1. 기본급: ${formatMoney(baseSalary)}원 (월급 그대로)');
  print('  2. 연장수당: ${formatMoney(overtimePay)}원 (${formatMoney(hourlyRate)} × $overtimeHours × 1.5)');
  print('  3. 야간수당: ${formatMoney(nightPay)}원 (${formatMoney(hourlyRate)} × $nightHours × 0.5)');
  print('  4. 휴일수당: ${formatMoney(holidayPay)}원 (${formatMoney(hourlyRate)} × $holidayHours × 1.5)');
  print('  5. 주휴수당: 월급에 포함');
  print('\n  💵 지급총액: ${formatMoney(totalPayment)}원');
  
  // 문제 체크
  print('\n🔍 문제 체크:');
  if (hourlyRate == 0) {
    print('  ❌ 통상시급이 0원입니다!');
    print('     원인: 주소정근로시간이 너무 작거나 월급이 0원');
  } else {
    print('  ✅ 통상시급: ${formatMoney(hourlyRate)}원');
  }
  
  if (totalPayment == 0 || totalPayment == monthlySalary) {
    print('  ⚠️  연장/야간/휴일 수당이 계산되지 않았습니다');
    print('     확인사항: "5인 이상 사업장" 설정 확인');
  } else {
    print('  ✅ 연장/야간/휴일 수당 정상 계산');
  }
}

String formatMoney(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}
