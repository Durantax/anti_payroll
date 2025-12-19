# 📋 DB 마이그레이션 가이드

## 🔴 직원 목록 조회 실패 문제 해결

### 문제 원인
- `server.py`는 정상이며, DB에 세금 관련 컬럼이 누락되어 발생한 문제
- 서버는 컬럼이 없을 경우 기본값을 제공하도록 설계되었으나, Flutter 앱에서는 해당 필드를 필수로 요구

### 누락된 컬럼 목록 (dbo.Employees 테이블)

| 컬럼명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `TaxDependents` | INT | 1 | 공제대상 가족 수 (본인 포함) |
| `ChildrenCount` | INT | 0 | 8-20세 자녀 수 (세액공제) |
| `TaxFreeMeal` | DECIMAL(18,2) | 0 | 비과세 식대 (최대 20만원) |
| `TaxFreeCarMaintenance` | DECIMAL(18,2) | 0 | 비과세 차량유지비 (최대 20만원) |
| `OtherTaxFree` | DECIMAL(18,2) | 0 | 기타 비과세 항목 |
| `IncomeTaxRate` | INT | 100 | 소득세율 배율 (80/100/120%) |

---

## ✅ 해결 방법

### 방법 1: SQL 스크립트 직접 실행 (권장)

1. **SQL Server Management Studio (SSMS)** 또는 **Azure Data Studio**로 DB 접속
2. `add_tax_columns.sql` 파일 열기
3. 전체 스크립트 실행 (F5)

```sql
-- 스크립트 내용은 add_tax_columns.sql 파일 참조
```

**실행 결과:**
```
✅ TaxDependents 컬럼 추가 완료
✅ ChildrenCount 컬럼 추가 완료
✅ TaxFreeMeal 컬럼 추가 완료
✅ TaxFreeCarMaintenance 컬럼 추가 완료
✅ OtherTaxFree 컬럼 추가 완료
✅ IncomeTaxRate 컬럼 추가 완료
🎉 모든 세금 관련 컬럼 추가 작업 완료!
```

### 방법 2: 서버 환경변수로 자동 마이그레이션

서버 실행 시 `INIT_DB=1` 환경변수를 설정하면 자동으로 DDL이 실행됩니다:

```bash
# Windows (PowerShell)
$env:INIT_DB="1"
python server.py

# Linux / macOS
INIT_DB=1 python server.py
```

⚠️ **주의:** 이 방법은 `server.py`의 `DDL_EMPLOYEES` 섹션에 컬럼 추가 DDL이 포함되어 있을 때만 작동합니다.

---

## 📊 마이그레이션 후 확인

### 1. 컬럼 추가 확인
```sql
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    COLUMN_DEFAULT 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Employees' 
  AND COLUMN_NAME IN (
      'TaxDependents', 
      'ChildrenCount', 
      'TaxFreeMeal', 
      'TaxFreeCarMaintenance', 
      'OtherTaxFree', 
      'IncomeTaxRate'
  )
ORDER BY ORDINAL_POSITION;
```

### 2. 직원 데이터 확인
```sql
SELECT TOP 5
    EmployeeId,
    Name,
    TaxDependents,
    ChildrenCount,
    TaxFreeMeal,
    TaxFreeCarMaintenance,
    OtherTaxFree,
    IncomeTaxRate
FROM dbo.Employees;
```

### 3. Flutter 앱에서 직원 목록 조회 테스트
- 앱 재시작
- 거래처 선택
- 직원 목록 조회
- ✅ 정상 작동 확인

---

## 🔧 추가 마이그레이션 (선택사항)

급여 계산 결과 저장 및 수당/공제 관리 기능을 사용하려면 아래 테이블도 생성해야 합니다:

### 1. PayrollResults (급여 계산 결과 저장)
```sql
-- server.py 라인 580-606 참조
-- DDL은 서버 코드에 포함되어 있음
```

### 2. AllowanceMaster / DeductionMaster (수당/공제 마스터)
```sql
-- server.py 라인 609-641 참조
```

### 3. EmployeeAllowances / EmployeeDeductions (직원별 수당/공제 매핑)
```sql
-- server.py 라인 624-641 참조
```

### 4. PayrollMonthlyAdjustments (월별 일회성 수당/공제)
```sql
-- server.py 라인 644-652 참조
```

**실행 방법:**
```bash
INIT_DB=1 python server.py
```

---

## 🎯 요약

| 작업 | 상태 | 방법 |
|------|------|------|
| **dbo.Employees 세금 컬럼 추가** | ✅ 필수 | `add_tax_columns.sql` 실행 |
| dbo.PayrollResults | 선택 | `INIT_DB=1` 서버 재시작 |
| 수당/공제 마스터 테이블 | 선택 | `INIT_DB=1` 서버 재시작 |
| Flutter 앱 코드 수정 | ✅ 완료 | PR #1 머지 |

---

## 📞 문제 발생 시

1. **컬럼 추가 실패:** DB 접속 권한 확인 (ALTER TABLE 권한 필요)
2. **여전히 조회 실패:** 서버 로그 확인 (`server.py` 실행 중 에러 출력)
3. **Flutter 앱 에러:** 앱 로그 확인 (JSON 파싱 에러 등)

---

## 📌 참고

- 서버 코드: `/home/user/uploaded_files/server.py`
- Flutter 코드: `/home/user/webapp/lib/`
- SQL 스크립트: `/home/user/webapp/add_tax_columns.sql`
- PR: https://github.com/Durantax/payroll/pull/1
