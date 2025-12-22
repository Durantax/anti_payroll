# 🔍 실시간 디버깅 가이드: 주소정근로시간/정상근로시간/주휴수당 0원 문제

## ✅ 확인 완료된 사항

### 1. 데이터베이스 구조 ✅
```sql
-- PayrollMonthlyInput 테이블 (script.sql)
[WeeklyHours] [decimal](18, 2) NOT NULL  -- ✅ 존재
[WeekCount] [int] NOT NULL                -- ✅ 존재

-- 기본값 (Default Constraints)
WeeklyHours: 40.0  -- ✅ 정상
WeekCount: 4       -- ✅ 정상
```

### 2. Python API (server.py) ✅
```python
# MonthlyUpsertIn 모델 (Line 487-498)
weeklyHours: float = 40.0  -- ✅ 존재
weekCount: int = 4         -- ✅ 존재

# upsert_monthly() (Line 1194-1240)
- WeeklyHours, WeekCount를 UPDATE/INSERT ✅

# get_monthly() (Line 1243-1266)
- WeeklyHours, WeekCount를 SELECT해서 반환 ✅
```

### 3. Flutter API 호출 (api_service.dart) ✅
```dart
// getMonthlyData() (Line 146-168)
weeklyHours: (data['weeklyHours'] as num?)?.toDouble() ?? 40  -- ✅ 서버에서 받음
weekCount: (data['weekCount'] as int?) ?? 4                   -- ✅ 서버에서 받음

// saveMonthlyData() (Line 180-197)
'weeklyHours': data.weeklyHours.toDouble()  -- ✅ 서버로 전송
'weekCount': data.weekCount                 -- ✅ 서버로 전송
```

---

## 🚨 문제 가능성 분석

### 가능성 1: 기존 데이터가 업데이트되지 않았음 (⭐ 가장 유력!)
**증상**: 이미 입력된 "테스트2" 직원의 데이터가 새 컬럼 추가 전에 저장되어 `WeeklyHours = 40.0` (기본값)으로 저장됨

**해결**:
```sql
-- 1. 해당 직원의 현재 저장된 데이터 확인
SELECT EmployeeId, Ym, WorkHours, WeeklyHours, WeekCount 
FROM dbo.PayrollMonthlyInput 
WHERE EmployeeId = (SELECT EmployeeId FROM dbo.Employees WHERE Name LIKE '%테스트2%')
ORDER BY Ym DESC;

-- 2. 만약 WeeklyHours가 40.0으로 되어 있다면 → Flutter 앱에서 14시간으로 다시 저장!
```

### 가능성 2: Flutter 앱이 리빌드되지 않음
**증상**: 코드 변경 후 앱을 다시 빌드하지 않아서 구버전 사용 중

**해결**:
```bash
flutter clean
flutter pub get
flutter run
```

### 가능성 3: 거래처 "5인 이상 사업장" 설정 누락
**증상**: 
- 월급여: 2,000,000원 입력
- 연장수당/야간수당/휴일수당: 0원 표시

**해결**: 앱 내에서
```
거래처 관리 → 해당 거래처 선택 → "5인 이상 사업장" 체크 ✅
```

### 가능성 4: 직원 정보 자체가 잘못됨
**증상**: 
- `SalaryType`이 '월급제'인데 `BaseSalary`가 0원
- 또는 `SalaryType`이 '시급제'인데 `HourlyRate`가 0원

**해결**:
```sql
-- 직원 정보 확인
SELECT 
    Name, 
    EmploymentType,  -- 정규직/프리랜서
    SalaryType,      -- 월급제/시급제
    BaseSalary,      -- 기본급
    HourlyRate,      -- 시급
    NormalHours      -- 월 소정근로시간 (209시간)
FROM dbo.Employees 
WHERE Name LIKE '%테스트2%';
```

---

## 🔧 단계별 디버깅 절차

### Step 1: 데이터베이스 직접 확인 (가장 중요!)
```sql
-- 1-1. "테스트2" 직원의 EmployeeId 찾기
SELECT EmployeeId, Name, SalaryType, BaseSalary, HourlyRate, NormalHours
FROM dbo.Employees
WHERE Name LIKE '%테스트2%';

-- 예상 출력:
-- EmployeeId | Name   | SalaryType | BaseSalary | HourlyRate | NormalHours
-- 123        | 테스트2 | 월급제     | 2000000    | 0          | 209
-- (만약 BaseSalary가 0이면 이게 문제!)

-- 1-2. 해당 직원의 월별 입력 데이터 확인
SELECT 
    EmployeeId, 
    Ym, 
    WorkHours,        -- 정상근로시간 (50시간 입력했는지)
    WeeklyHours,      -- 주소정근로시간 (14시간이 저장되었는지!)
    WeekCount,        -- 개근주수
    OvertimeHours,    -- 연장근로
    NightHours,       -- 야간근로
    HolidayHours,     -- 휴일근로
    Bonus
FROM dbo.PayrollMonthlyInput
WHERE EmployeeId = 123  -- 위에서 찾은 EmployeeId
  AND Ym = '2025-12';   -- 현재 월

-- ⚠️ 핵심 체크포인트:
-- WeeklyHours = 14.0 ← 이렇게 저장되어 있어야 함!
-- WeeklyHours = 40.0 ← 이렇다면 Flutter 앱에서 다시 저장 필요!
```

### Step 2: 거래처 "5인 이상 사업장" 설정 확인
```sql
-- 2-1. "테스트2"가 속한 거래처의 설정 확인
SELECT 
    c.ID,
    c.고객명,
    e.Name AS 직원명,
    e.EmploymentType,
    e.SalaryType
FROM 거래처 c
INNER JOIN dbo.Employees e ON e.ClientId = c.ID
WHERE e.Name LIKE '%테스트2%';

-- 2-2. Flutter 앱에서 확인
-- 거래처 관리 → 해당 거래처 → "5인 이상 사업장" 체크박스 확인 ✅
```

### Step 3: Flutter 앱 재빌드 및 재저장
```bash
# 3-1. Flutter 앱 완전 클린 후 재실행
flutter clean
flutter pub get
flutter run

# 3-2. 앱 실행 후
# - "테스트2" 직원 선택
# - 주소정근로시간: 14시간 입력
# - 정상근로시간: 50시간 입력
# - "저장" 버튼 클릭!
```

### Step 4: API 호출 로그 확인 (고급)
```dart
// lib/services/api_service.dart의 saveMonthlyData() 함수에 로그 추가

Future<void> saveMonthlyData(MonthlyData data) async {
  final body = {
    'employeeId': data.employeeId,
    'ym': data.ym,
    'workHours': data.normalHours.toDouble(),
    'bonus': data.bonus.toDouble(),
    'overtimeHours': data.overtimeHours.toDouble(),
    'nightHours': data.nightHours.toDouble(),
    'holidayHours': data.holidayHours.toDouble(),
    'weeklyHours': data.weeklyHours.toDouble(),  // ← 이 값이 14.0인지 확인!
    'weekCount': data.weekCount,
  };

  // ⭐ 로그 추가
  print('📤 API 전송 데이터: ${json.encode(body)}');
  // 예상 출력: {"employeeId":123,"ym":"2025-12","workHours":50.0,"weeklyHours":14.0,"weekCount":4,...}

  final response = await http.post(...);
  
  // ⭐ 응답 로그 추가
  print('📥 API 응답: ${response.statusCode}');
}
```

### Step 5: 통상시급 계산 로직 확인
```dart
// lib/services/payroll_calculator.dart

// 월급제 직원의 통상시급 계산:
// hourlyRate = monthlySalary / (weeklyHours * 4.345주)

// 예시 계산:
// monthlySalary = 2,000,000원
// weeklyHours = 14시간  ← 중요!

// 기대값:
// hourlyRate = 2,000,000 / (14 * 4.345) = 2,000,000 / 60.83 = 32,879원

// 만약 weeklyHours가 40시간이라면:
// hourlyRate = 2,000,000 / (40 * 4.345) = 2,000,000 / 173.8 = 11,510원 ← 잘못된 값!
```

---

## 🎯 가장 가능성 높은 원인과 해결책

### 원인 A: 기존 데이터가 `WeeklyHours = 40.0` (기본값)으로 저장됨 ⭐⭐⭐
**문제**: DB에 컬럼을 추가한 후, 기존에 입력했던 "테스트2" 데이터는 `WeeklyHours = 40.0` (기본값)으로 자동 설정됨.

**해결**: 
1. Flutter 앱에서 "테스트2" 직원의 데이터를 불러옴
2. **"주소정근로시간"을 14시간으로 다시 입력**
3. **"저장" 버튼 클릭**
4. → DB의 `WeeklyHours`가 14.0으로 업데이트됨!
5. → 통상시급이 32,879원으로 정상 계산됨!

### 원인 B: "5인 이상 사업장" 체크 누락 ⭐⭐
**문제**: 연장/야간/휴일수당은 5인 이상 사업장만 의무

**해결**: 
```
거래처 관리 → 해당 거래처 → "5인 이상 사업장" ✅ 체크
```

---

## 📋 최종 체크리스트

- [ ] 1. DB에서 `SELECT * FROM dbo.PayrollMonthlyInput WHERE EmployeeId=?` 확인
  - [ ] `WeeklyHours`가 14.0인지 확인 (40.0이면 문제!)
- [ ] 2. DB에서 `SELECT * FROM dbo.Employees WHERE Name LIKE '%테스트2%'` 확인
  - [ ] `BaseSalary`가 2,000,000인지 확인 (0이면 문제!)
  - [ ] `SalaryType`이 '월급제'인지 확인
- [ ] 3. Flutter 앱에서 "거래처 관리" → "5인 이상 사업장" 체크 확인
- [ ] 4. Flutter 앱 `flutter clean` 후 재실행
- [ ] 5. Flutter 앱에서 "테스트2" 데이터 다시 저장 (주소정근로시간 14시간 입력!)
- [ ] 6. 급여 계산 결과 확인:
  - [ ] 통상시급: 32,879원 (2,000,000 ÷ 60.83)
  - [ ] 기본급: 2,000,000원
  - [ ] 연장수당: 246,592원 (5인 이상 사업장만)
  - [ ] 야간수당: 82,198원 (5인 이상 사업장만)
  - [ ] 휴일수당: 246,592원 (5인 이상 사업장만)
  - [ ] **주휴수당: 0원** (주소정근로시간 14시간 < 15시간 → 정상!)

---

## 🔬 SQL 쿼리 템플릿 (복사해서 사용)

```sql
-- [쿼리 1] 테스트2 직원 정보 확인
SELECT * FROM dbo.Employees WHERE Name LIKE '%테스트2%';

-- [쿼리 2] 테스트2 월별 입력 데이터 확인
SELECT * FROM dbo.PayrollMonthlyInput 
WHERE EmployeeId = (SELECT TOP 1 EmployeeId FROM dbo.Employees WHERE Name LIKE '%테스트2%')
ORDER BY Ym DESC;

-- [쿼리 3] WeeklyHours가 40.0 (기본값)인 데이터 찾기
SELECT e.Name, p.Ym, p.WeeklyHours, p.WorkHours
FROM dbo.PayrollMonthlyInput p
INNER JOIN dbo.Employees e ON e.EmployeeId = p.EmployeeId
WHERE p.WeeklyHours = 40.0
  AND e.Name LIKE '%테스트2%';

-- [쿼리 4] 테스트2의 WeeklyHours를 14.0으로 수동 업데이트 (임시 해결)
UPDATE dbo.PayrollMonthlyInput
SET WeeklyHours = 14.0, UpdatedAt = SYSUTCDATETIME()
WHERE EmployeeId = (SELECT TOP 1 EmployeeId FROM dbo.Employees WHERE Name LIKE '%테스트2%')
  AND Ym = '2025-12';  -- 현재 월로 수정
```

---

## ✅ 정상 동작 예시

### 입력 데이터:
- 월급여: 2,000,000원
- 주소정근로시간: **14시간**
- 정상근로시간: 50시간
- 연장: 5시간, 야간: 5시간, 휴일: 5시간
- 거래처: **5인 이상 사업장 ✅**

### 기대 결과:
| 항목 | 계산식 | 금액 |
|------|--------|------|
| 통상시급 | 2,000,000 ÷ (14 × 4.345) = 2,000,000 ÷ 60.83 | **32,879원** |
| 기본급 | 월급제 → monthlySalary | **2,000,000원** |
| 연장수당 | 32,879 × 1.5 × 5h | **246,592원** |
| 야간수당 | 32,879 × 0.5 × 5h | **82,198원** |
| 휴일수당 | 32,879 × 1.5 × 5h | **246,592원** |
| 주휴수당 | 14h < 15h → 미달 | **0원** ✅ (정상!) |
| **지급총액** | | **2,575,382원** |

---

## 🎯 결론

**모든 코드는 정상입니다!** 문제는:

1. **기존 데이터가 `WeeklyHours = 40.0` (기본값)으로 저장**되어 있어서
2. Flutter 앱에서 **14시간을 다시 입력하고 저장하지 않았음**

### 해결 방법:
**Flutter 앱에서 "테스트2" 데이터를 다시 열어서, "주소정근로시간 14시간" 입력 후 저장하기!**

또는 SQL로 직접 수정:
```sql
UPDATE dbo.PayrollMonthlyInput
SET WeeklyHours = 14.0, UpdatedAt = SYSUTCDATETIME()
WHERE EmployeeId = (SELECT TOP 1 EmployeeId FROM dbo.Employees WHERE Name LIKE '%테스트2%')
  AND Ym = '2025-12';
```
