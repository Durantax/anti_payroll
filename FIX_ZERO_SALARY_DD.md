# 🚨 긴급 수정: 월급 20,000,000원인데 0원으로 계산되는 문제

## 📸 스크린샷 분석

```
직원 정보 - DD
├─ 기본정보
│  ├─ 월급여: 20,000,000원 ✅
│  ├─ 시급: 0원 ⚠️ ← 문제!
│  └─ 주소정근로시간: 40.0시간 ✅
└─ 이번 달 근무
   ├─ 정상근로시간: 40.0시간
   ├─ 연장시간: 0.0시간
   ├─ 야간시간: 0.0시간
   ├─ 휴일시간: 0.0시간
   └─ 개근주수: 4주
```

---

## 🔍 문제 원인

### 원인: `salaryType` 필드가 제대로 설정되지 않음!

코드 로직:
```dart
// lib/services/payroll_calculator.dart (Line 44-55)

int hourlyRate = worker.hourlyRate;  // ← 0원을 가져옴

bool isMonthlyWorker = worker.salaryType == 'MONTHLY' 
                    && worker.monthlySalary > 0;

if (isMonthlyWorker) {
  // ✅ 월급제: 통상시급 자동 계산
  final weeklyHours = monthly.weeklyHours > 0 ? monthly.weeklyHours : 40.0;
  final monthlyHours = weeklyHours * AppConstants.weeksPerMonth;
  hourlyRate = (worker.monthlySalary / monthlyHours).round();
} else {
  // ❌ 시급제로 인식됨: hourlyRate = 0원 그대로 사용!
}
```

### 문제:
1. **`worker.salaryType`이 'MONTHLY'가 아님** (아마 'HOURLY' 또는 null)
2. → `isMonthlyWorker = false`
3. → 통상시급 자동 계산 안 함
4. → `hourlyRate = 0`으로 남음
5. → 모든 수당 계산 = 0원!

---

## 🔧 해결 방법

### 방법 1: Flutter 앱에서 급여형태 수정 (⭐ 권장)

1. **"DD" 직원 정보 열기**
2. **"기본정보" 탭에서 "급여형태" 확인**
3. **"월급제" 또는 "MONTHLY" 선택**
4. **저장**

#### 예상되는 UI:
```
급여형태: ○ 시급제  ● 월급제  ← 이걸 "월급제"로 변경!
```

---

### 방법 2: DB에서 직접 수정

```sql
-- DD 직원의 SalaryType을 'MONTHLY'로 변경
UPDATE dbo.Employees
SET SalaryType = 'MONTHLY',
    BaseSalary = 20000000,
    UpdatedAt = SYSUTCDATETIME()
WHERE Name = 'DD';

-- 확인
SELECT Name, SalaryType, BaseSalary, HourlyRate
FROM dbo.Employees
WHERE Name = 'DD';

-- 기대 결과:
-- Name | SalaryType | BaseSalary | HourlyRate
-- DD   | MONTHLY    | 20000000   | 0
```

---

### 방법 3: 코드 수정 (임시 방편, 권장하지 않음)

```dart
// lib/services/payroll_calculator.dart

// 기존 코드 (Line 46)
bool isMonthlyWorker = worker.salaryType == 'MONTHLY' && worker.monthlySalary > 0;

// 수정 제안:
bool isMonthlyWorker = (worker.salaryType == 'MONTHLY' && worker.monthlySalary > 0)
                    || (worker.hourlyRate == 0 && worker.monthlySalary > 0);
                    // ↑ hourlyRate가 0이고 monthlySalary가 있으면 월급제로 간주

// ⚠️ 하지만 이 방법은 근본 원인을 해결하지 못함!
```

---

## 🎯 정확한 진단 방법

### DB 쿼리로 확인:
```sql
-- DD 직원의 정확한 정보 조회
SELECT 
    Name AS 이름,
    EmploymentType AS 고용형태,
    SalaryType AS 급여형태,
    BaseSalary AS 기본급,
    HourlyRate AS 시급,
    NormalHours AS 월소정근로시간
FROM dbo.Employees
WHERE Name = 'DD';

-- 예상 결과 (문제 있는 경우):
-- 이름 | 고용형태 | 급여형태 | 기본급   | 시급 | 월소정근로시간
-- DD   | regular  | HOURLY   | 20000000 | 0    | 209
--                   ↑ 문제!

-- 올바른 결과:
-- 이름 | 고용형태 | 급여형태 | 기본급   | 시급 | 월소정근로시간
-- DD   | regular  | MONTHLY  | 20000000 | 0    | 209
--                   ↑ 정상!
```

---

## 📊 수정 후 기대 결과

### 입력:
```
월급여: 20,000,000원
급여형태: MONTHLY ✅
주소정근로시간: 40.0시간
정상근로시간: 40.0시간
연장: 0h, 야간: 0h, 휴일: 0h
```

### 계산:
```
[1] 통상시급 자동 계산
    = 20,000,000 ÷ (40 × 4.345)
    = 20,000,000 ÷ 173.8
    = 115,103원 ✅

[2] 기본급
    = 20,000,000원 (월급 그대로) ✅

[3] 연장/야간/휴일수당
    = 0원 (근무시간 0이므로)

[4] 지급총액
    = 20,000,000원 ✅

[5] 4대보험 공제
    국민연금 = 20,000,000 × 4.5% = 900,000원
    건강보험 = 20,000,000 × 3.545% = 709,000원
    장기요양 = 709,000 × 12.95% = 91,816원
    고용보험 = 20,000,000 × 0.9% = 180,000원

[6] 소득세
    간이세액표 (20,000,000원, 가족 1명)
    → 소득세: 약 890,000원
    → 지방소득세: 약 89,000원

[7] 공제총액
    = 약 2,859,816원

[8] 실수령액
    = 20,000,000 - 2,859,816
    = 약 17,140,184원 ✅
```

---

## 🛠️ 즉시 조치 사항

### 1단계: 급여형태 확인
```
Flutter 앱 → "DD" 직원 → 기본정보 탭
→ "급여형태"가 "월급제" 또는 "MONTHLY"인지 확인!
```

### 2단계: 잘못 설정된 경우 수정
```
급여형태: 시급제 → 월급제로 변경
저장 버튼 클릭
```

### 3단계: 재계산 확인
```
"급여" 탭으로 이동
→ 통상시급이 115,103원으로 표시되는지 확인
→ 기본급이 20,000,000원으로 표시되는지 확인
```

---

## ⚠️ 추가 확인 사항

### 체크리스트:
- [ ] **급여형태가 "월급제" (MONTHLY)로 설정되어 있는가?**
- [ ] **월급여가 20,000,000원으로 입력되어 있는가?**
- [ ] **시급이 0원인 것이 정상인가?** (월급제는 시급 입력 불필요)
- [ ] **주소정근로시간이 40시간으로 설정되어 있는가?**
- [ ] **거래처 "5인 이상 사업장" 설정이 필요한가?** (현재는 연장/야간/휴일 없음)

---

## 🔍 디버깅 정보 수집

만약 위 방법으로도 해결되지 않으면 다음 정보를 확인해주세요:

### SQL 쿼리:
```sql
-- DD 직원의 전체 정보 확인
SELECT *
FROM dbo.Employees
WHERE Name = 'DD';

-- PayrollMonthlyInput 확인
SELECT *
FROM dbo.PayrollMonthlyInput
WHERE EmployeeId = (SELECT EmployeeId FROM dbo.Employees WHERE Name = 'DD')
ORDER BY Ym DESC;
```

### Flutter 로그:
```dart
// lib/services/payroll_calculator.dart에 로그 추가

static SalaryResult _calculateRegular(...) {
  print('===== 급여 계산 시작 =====');
  print('직원명: ${worker.name}');
  print('급여형태: ${worker.salaryType}');
  print('월급여: ${worker.monthlySalary}');
  print('시급: ${worker.hourlyRate}');
  print('주소정근로시간: ${monthly.weeklyHours}');
  
  bool isMonthlyWorker = worker.salaryType == 'MONTHLY' && worker.monthlySalary > 0;
  print('월급제 판정: $isMonthlyWorker');
  
  // ...
}
```

---

## 💡 핵심 요약

**문제**: `salaryType`이 'MONTHLY'가 아니라서 통상시급 자동 계산이 안 됨!

**해결**: Flutter 앱에서 "DD" 직원의 **급여형태를 "월급제"로 변경**하고 저장!

**확인**: 통상시급이 115,103원, 기본급이 20,000,000원으로 계산되는지 확인!

---

## 📁 관련 파일

- `lib/services/payroll_calculator.dart` (Line 44-55) - 통상시급 계산 로직
- `lib/core/models.dart` (Line 76, 109, 140) - WorkerModel.salaryType 필드
- `dbo.Employees` 테이블 - SalaryType 컬럼

---

이 문서를 참고해서 **"급여형태"를 "월급제"로 변경**해보세요!
그래도 안 되면 SQL 쿼리 결과를 알려주세요! 😊
