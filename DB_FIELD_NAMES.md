# 📋 DB 필드명 정리

## 주휴수당 관련 필드

### 1. 주휴수당 (계산 결과)
- **테이블**: `dbo.PayrollResults`
- **필드명**: `WeeklyHolidayPay`
- **타입**: `DECIMAL(18, 2) NOT NULL`
- **기본값**: `0`
- **용도**: 계산된 주휴수당 금액 저장 (결과값)

### 2. 주소정근로시간 (주간 근로시간)
- **테이블**: `dbo.PayrollMonthlyInput`
- **필드명**: `WeeklyHours`
- **타입**: `DECIMAL(18, 2) NOT NULL`
- **기본값**: `40.0`
- **용도**: 주간 소정근로시간 (예: 14시간, 40시간)
- **설명**: 주휴수당 지급 판단 기준 (15시간 미만이면 주휴수당 미지급)

### 3. 개근주수 (완벽 출근 주 수)
- **테이블**: `dbo.PayrollMonthlyInput`
- **필드명**: `WeekCount`
- **타입**: `INT NOT NULL`
- **기본값**: `4`
- **용도**: 해당 월의 개근 주 수 (주휴수당 계산 시 사용)
- **설명**: 프리랜서의 주휴수당 계산 시 필요

---

## 요약 테이블

| 한글명 | 영문 필드명 | 테이블 | 타입 | 기본값 | 용도 |
|--------|-------------|--------|------|--------|------|
| **주휴수당** | `WeeklyHolidayPay` | `PayrollResults` | DECIMAL(18,2) | 0 | 계산된 주휴수당 금액 |
| **주소정근로시간** | `WeeklyHours` | `PayrollMonthlyInput` | DECIMAL(18,2) | 40.0 | 주간 소정근로시간 |
| **개근주수** | `WeekCount` | `PayrollMonthlyInput` | INT | 4 | 월별 개근 주 수 |

---

## 관련 계산 로직

### 주휴수당 지급 조건
```dart
// 근로기준법: 주 소정근로시간이 15시간 이상이어야 주휴수당 지급
if (weeklyHours >= 15) {
  // 주휴수당 계산
  weeklyHolidayPay = hourlyRate × dailyHours × weekCount;
} else {
  // 15시간 미만이면 주휴수당 미지급
  weeklyHolidayPay = 0;
}
```

### 예시
```
월급제 직원:
- monthlySalary: 2,000,000원
- weeklyHours: 14시간 ← 15시간 미만
- weekCount: 4주

계산:
- 통상시급 = 2,000,000 ÷ (14 × 4.345) = 32,879원
- weeklyHolidayPay = 0원 (14 < 15이므로 미지급)
```

---

## SQL 쿼리 예시

### 주휴수당 관련 데이터 조회
```sql
-- 입력 데이터 (PayrollMonthlyInput)
SELECT 
    EmployeeId,
    Ym,
    WeeklyHours,    -- 주소정근로시간
    WeekCount,      -- 개근주수
    WorkHours,      -- 정상근로시간
    OvertimeHours,  -- 연장근로
    NightHours,     -- 야간근로
    HolidayHours    -- 휴일근로
FROM dbo.PayrollMonthlyInput
WHERE EmployeeId = 123 AND Ym = '2025-12';

-- 계산 결과 (PayrollResults)
SELECT 
    EmployeeId,
    Ym,
    BaseSalary,         -- 기본급
    OvertimePay,        -- 연장수당
    NightPay,           -- 야간수당
    HolidayPay,         -- 휴일수당
    WeeklyHolidayPay,   -- 주휴수당 ← 결과값
    TotalPay            -- 지급총액
FROM dbo.PayrollResults
WHERE EmployeeId = 123 AND Ym = '2025-12';
```

### WeeklyHours 업데이트
```sql
-- 주소정근로시간을 14시간으로 변경
UPDATE dbo.PayrollMonthlyInput
SET WeeklyHours = 14.0,
    UpdatedAt = SYSUTCDATETIME()
WHERE EmployeeId = 123 AND Ym = '2025-12';
```

### WeekCount 업데이트
```sql
-- 개근주수를 4주로 변경
UPDATE dbo.PayrollMonthlyInput
SET WeekCount = 4,
    UpdatedAt = SYSUTCDATETIME()
WHERE EmployeeId = 123 AND Ym = '2025-12';
```

---

## Flutter/Dart 필드명

Flutter 앱의 `MonthlyData` 모델:
```dart
class MonthlyData {
  final double weeklyHours;    // 주소정근로시간
  final int weekCount;         // 개근주수
  // ...
}

class SalaryResult {
  final int weeklyHolidayPay;  // 주휴수당 (계산 결과)
  // ...
}
```

---

## Python API (server.py) 필드명

```python
class MonthlyUpsertIn(BaseModel):
    weeklyHours: float = 40.0  # 주소정근로시간
    weekCount: int = 4         # 개근주수
    # ...

# DB 컬럼명
# WeeklyHours  → weeklyHours (camelCase)
# WeekCount    → weekCount (camelCase)
```

---

## 핵심 정리

1. **주휴수당** = `WeeklyHolidayPay` (결과 테이블에 저장되는 계산값)
2. **주소정근로시간** = `WeeklyHours` (입력 데이터, 판단 기준)
3. **개근주수** = `WeekCount` (입력 데이터, 계산에 사용)

**중요**: 
- `WeeklyHours` ≥ 15 → 주휴수당 지급 ✅
- `WeeklyHours` < 15 → 주휴수당 미지급 ❌
