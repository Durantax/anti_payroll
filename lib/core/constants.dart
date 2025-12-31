class AppConstants {
  // API 설정
  static const String defaultServerUrl = 'http://127.0.0.1:8000';
  static const String defaultApiKey = '';
  
  // 자동 발송 시간
  static const int autoSendHour = 9;  // 오전 9시
  static const int retryHour = 12;    // 오후 12시
  
  // 폴링 간격
  static const Duration statusCheckInterval = Duration(seconds: 5);
  static const Duration autoSendCheckInterval = Duration(minutes: 10);
  
  // 파일 경로
  static const String logFileName = 'app_logs.txt';
  static const String logsFolder = 'Durantax/logs';
  
  // 급여 계산 상수
  static const double pensionRate = 0.045;        // 국민연금 4.5%
  static const double healthRate = 0.03545;       // 건강보험 3.545%
  static const double longTermCareRate = 0.1295;  // 장기요양 12.95%
  static const double employmentRate = 0.009;     // 고용보험 0.9%
  static const double incomeTaxRate = 0.033;      // 소득세 3.3%
  static const double localTaxRate = 0.1;         // 지방소득세 10%
  
  static const double overtimeMultiplier = 1.5;   // 연장수당 1.5배
  static const double nightMultiplier = 0.5;      // 야간수당 0.5배
  static const double holidayMultiplier = 1.5;    // 휴일수당 1.5배
  
  // 기본값
  static const int defaultNormalHours = 209;
  static const double defaultWeeklyHours = 40.0;
  static const double weeksPerMonth = 4.345;  // 월 환산 계수
}
