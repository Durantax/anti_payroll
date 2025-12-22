# 🔍 API 디버깅 가이드

## 문제: 여전히 0원이 나옴

### 1단계: DB 확인

```sql
-- PayrollMonthlyInput 테이블에 컬럼이 있는지 확인
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PayrollMonthlyInput'
  AND COLUMN_NAME IN ('WeeklyHours', 'WeekCount');
```

**예상 결과:**
```
WeeklyHours | decimal | NO | ((40.0))
WeekCount   | int     | NO | ((4))
```

만약 결과가 없으면 → `add_weekly_hours_fields.sql` 실행 필요!

---

### 2단계: 실제 저장된 데이터 확인

```sql
-- 테스트2 직원의 월별 데이터 확인
SELECT 
    EmployeeId,
    Ym,
    WorkHours AS 정상근로시간,
    WeeklyHours AS 주소정근로시간,
    WeekCount AS 개근주수,
    OvertimeHours AS 연장시간,
    NightHours AS 야간시간,
    HolidayHours AS 휴일시간
FROM dbo.PayrollMonthlyInput
WHERE EmployeeId = (SELECT EmployeeId FROM dbo.Employees WHERE Name = '테스트2')
  AND Ym = '2025-12'
ORDER BY UpdatedAt DESC;
```

**확인 사항:**
- WeeklyHours가 14.0으로 저장되어 있나?
- WeekCount가 4로 저장되어 있나?
- 40.0/4 (기본값)으로 되어 있으면 → Flutter 앱이 데이터를 안 보낸 것!

---

### 3단계: API 응답 확인 (Postman/curl)

```bash
# 월별 데이터 조회 API 테스트
curl -X GET "http://your-server:8000/payroll/monthly?employeeId=직원ID&ym=2025-12" \
  -H "X-API-Key: your-api-key"
```

**응답 확인:**
```json
{
  "employeeId": 4,
  "ym": "2025-12",
  "workHours": 50.0,
  "weeklyHours": 14.0,  // ← 이게 있어야 함!
  "weekCount": 4,       // ← 이게 있어야 함!
  "overtimeHours": 5.0,
  "nightHours": 5.0,
  "holidayHours": 5.0,
  "bonus": 0.0
}
```

만약 `weeklyHours`가 40.0으로 나오면 → DB에 제대로 저장 안 된 것!

---

### 4단계: Flutter 앱 재빌드 확인

```bash
# 완전 클린 빌드
flutter clean
flutter pub get
flutter run

# 또는
flutter run --debug
```

**확인 사항:**
- 코드 변경 후 **Hot Reload만 했나요?** → 안 됩니다! 완전 재시작 필요!
- 앱을 완전히 종료하고 다시 실행했나요?

---

### 5단계: Flutter 로그 확인

Flutter 앱 실행 시 콘솔에서:

```dart
// api_service.dart에 디버그 로그 추가 (임시)
Future<void> saveMonthlyData(MonthlyData data) async {
  final body = {
    'employeeId': data.employeeId,
    'ym': data.ym,
    'workHours': data.normalHours.toDouble(),
    'bonus': data.bonus.toDouble(),
    'overtimeHours': data.overtimeHours.toDouble(),
    'nightHours': data.nightHours.toDouble(),
    'holidayHours': data.holidayHours.toDouble(),
    'weeklyHours': data.weeklyHours.toDouble(),
    'weekCount': data.weekCount,
  };
  
  print('🔍 API 전송 데이터: ${json.encode(body)}');  // 추가!
  
  final response = await http.post(...);
}
```

**확인:**
- 콘솔에 `weeklyHours: 14.0`이 찍히나요?
- 만약 `weeklyHours: 40.0`이면 → Flutter UI에서 제대로 입력 안 된 것!

---

### 6단계: 직원 정보 확인

```sql
-- 테스트2 직원의 기본 정보 확인
SELECT 
    EmployeeId,
    Name,
    SalaryType,
    BaseSalary AS 월급,
    HourlyRate AS 시급,
    NormalHours AS 월소정근로시간
FROM dbo.Employees
WHERE Name = '테스트2';
```

**확인:**
- SalaryType이 'MONTHLY'인가?
- BaseSalary가 2000000인가?
- NormalHours는 209 (기본값, 월급제는 안 씀)

---

### 7단계: 5인 이상 사업장 설정 재확인

```sql
-- 거래처 설정 확인
SELECT 
    ClientId,
    Name,
    Has5OrMoreWorkers
FROM dbo.Clients
WHERE ClientId = (SELECT ClientId FROM dbo.Employees WHERE Name = '테스트2');
```

**확인:**
- Has5OrMoreWorkers가 1 (true)인가?
- 0이면 → 연장/야간/휴일 수당이 모두 0원!

---

## 🎯 문제별 해결책

### A. DB에 컬럼이 없음
→ `add_weekly_hours_fields.sql` 실행

### B. Flutter 앱이 구버전
→ `flutter clean && flutter run`

### C. 데이터가 저장 안 됨
→ Flutter UI에서 "저장" 버튼 다시 클릭
→ 주소정근로시간 14시간 다시 입력

### D. 5인 이상 사업장 체크 안 됨
→ 거래처 설정에서 체크박스 확인

### E. 월급여가 0원
→ 직원 정보에서 월급여 2,000,000 입력

---

## 📋 최종 체크리스트

**DB:**
☐ WeeklyHours 컬럼 존재?
☐ WeekCount 컬럼 존재?
☐ 실제 데이터에 14.0 저장됨?

**직원 정보:**
☐ 월급여 2,000,000원?
☐ 급여 유형 "월급제"?

**거래처:**
☐ 5인 이상 사업장 체크?

**Flutter 앱:**
☐ 완전 재빌드 했나?
☐ 월별 데이터 다시 저장했나?
☐ 주소정근로시간 14시간 입력?

---

## 💡 빠른 확인 방법

Python으로 직접 API 호출:

```python
import requests
import json

# 월별 데이터 조회
response = requests.get(
    'http://your-server:8000/payroll/monthly',
    params={'employeeId': 4, 'ym': '2025-12'},
    headers={'X-API-Key': 'your-key'}
)

data = response.json()
print(f"주소정근로시간: {data.get('weeklyHours')}")
print(f"개근주수: {data.get('weekCount')}")
```

