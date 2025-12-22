# DB 필드 분석: 주소정근로시간 (Weekly Working Hours)

## 📊 현재 상황

### 1. **DB (script.sql)에 있는 필드**
```sql
CREATE TABLE [dbo].[Employees](
    ...
    [NormalHours] [decimal](18, 2) NOT NULL,  -- 기본값: 209 (월 소정근로시간)
    ...
)
```
- ❌ `WeeklyHours` 필드 **없음**
- ✅ `NormalHours` 필드 **있음** (월 소정근로시간, 기본값 209시간)

### 2. **Flutter 앱 (WorkerModel)에 있는 필드**
```dart
class WorkerModel {
  final double normalHours;  // 월 소정근로시간 (기본값: 209)
  ...
}

class MonthlyData {
  final double normalHours;   // 월 근무시간
  final double weeklyHours;   // 주소정근로시간 ✅ (기본값: 40)
  final int weekCount;        // 개근주수 (기본값: 4)
  ...
}
```

### 3. **server.py (Python API)에 있는 필드**
```python
class EmployeeUpsertIn(BaseModel):
    normalHours: float = 209  # 월 소정근로시간
    # ❌ weeklyHours 없음

class MonthlyUpsertIn(BaseModel):
    workHours: float  # 월 실제근무시간
    # ❌ weeklyHours 없음
    # ❌ weekCount 없음
```

---

## 🔴 **문제점**

### 문제 1: `weeklyHours` 필드가 DB/API에 없음
- Flutter 앱의 `MonthlyData.weeklyHours` (주소정근로시간) 필드가 **DB와 API에 없음**
- 현재는 **Flutter 앱에서만** 기본값 40시간으로 하드코딩됨
- 주 15시간 미만 주휴수당 계산 불가능

### 문제 2: `weekCount` 필드가 DB/API에 없음  
- Flutter 앱의 `MonthlyData.weekCount` (개근주수) 필드가 **DB와 API에 없음**
- 프리랜서 주휴수당 계산 불가능

---

## ✅ **해결 방안**

### Option 1: DB에 필드 추가 (권장)
```sql
-- PayrollMonthlyInput 테이블에 추가
ALTER TABLE [dbo].[PayrollMonthlyInput]
ADD [WeeklyHours] DECIMAL(18,2) NOT NULL DEFAULT 40.0;

ALTER TABLE [dbo].[PayrollMonthlyInput]
ADD [WeekCount] INT NOT NULL DEFAULT 4;
```

**장점:**
- ✅ 직원별/월별로 정확한 주소정근로시간 저장/관리 가능
- ✅ 주 15시간 미만 주휴수당 판정 정확
- ✅ 프리랜서 주휴수당 계산 정확
- ✅ 데이터 일관성 보장

**필요 작업:**
1. DB 마이그레이션 SQL 실행
2. `server.py`의 `MonthlyUpsertIn/MonthlyOut` 모델에 필드 추가
3. API 엔드포인트 수정 (필드 저장/조회)
4. Flutter 앱 테스트

---

### Option 2: 클라이언트에서만 처리 (임시 방편)
- Flutter 앱에서 `weeklyHours = 40` 고정값 사용
- 문제점: 주 15시간 근무자 판정 불가능

---

## 🎯 **권장 사항**

**DB에 필드 추가하는 것을 강력히 권장합니다!**

이유:
1. 주소정근로시간은 **직원별/월별로 다를 수 있음** (시간제 근로자)
2. 주 15시간 미만 주휴수당 판정에 **필수**
3. 프리랜서 주휴수당 계산에 **필수**
4. 노동법 준수를 위해 **정확한 데이터 관리 필요**

---

## 📋 **다음 단계**

1. ✅ DB 필드 분석 완료
2. ⏳ DB 마이그레이션 SQL 작성
3. ⏳ server.py 모델 업데이트
4. ⏳ API 엔드포인트 수정
5. ⏳ Flutter 앱 테스트

