# 📋 DB 마이그레이션 실행 가이드

## 🎯 목적
`PayrollMonthlyInput` 테이블에 다음 필드를 추가합니다:
- **WeeklyHours** (주소정근로시간) - 주 15시간 미만 주휴수당 판정용
- **WeekCount** (개근주수) - 프리랜서 주휴수당 계산용

---

## 📁 제공된 SQL 파일

### 1. **add_weekly_hours_fields.sql** (권장)
- ✅ 안전한 버전 (필드 존재 여부 체크)
- ✅ 기존 데이터 자동 업데이트
- ✅ 실행 결과 확인 쿼리 포함
- 💡 **이미 필드가 있으면 건너뜀 (에러 없음)**

### 2. **add_weekly_hours_SIMPLE.sql** (간단 버전)
- ⚡ 간결한 코드
- ⚠️ 필드가 이미 있으면 에러 발생
- 💡 **처음 실행할 때만 사용**

---

## 🚀 실행 방법

### 방법 1: SQL Server Management Studio (SSMS)

1. **SSMS 열기**
2. **서버 연결**
3. **새 쿼리 창 열기** (Ctrl + N)
4. **SQL 파일 내용 복사/붙여넣기** 또는 **파일 > 열기**
   ```
   add_weekly_hours_fields.sql
   ```
5. **실행** (F5 또는 Execute 버튼)

---

### 방법 2: sqlcmd (명령줄)

```bash
# 윈도우
sqlcmd -S localhost -d payroll -i add_weekly_hours_fields.sql

# 인증 필요한 경우
sqlcmd -S localhost -U sa -P 비밀번호 -d payroll -i add_weekly_hours_fields.sql

# SQL Server 인스턴스 지정
sqlcmd -S localhost\SQLEXPRESS -d payroll -i add_weekly_hours_fields.sql
```

---

### 방법 3: Azure Data Studio

1. **Azure Data Studio 열기**
2. **서버 연결**
3. **New Query** 클릭
4. **SQL 파일 내용 붙여넣기**
5. **Run** 버튼 클릭

---

### 방법 4: Python (pymssql/pyodbc)

```python
import pymssql

# 연결
conn = pymssql.connect(
    server='localhost',
    user='sa',
    password='your_password',
    database='payroll'
)

# SQL 파일 읽기
with open('add_weekly_hours_fields.sql', 'r', encoding='utf-8') as f:
    sql_script = f.read()

# 실행
cursor = conn.cursor()
cursor.execute(sql_script)
conn.commit()

print("마이그레이션 완료!")
conn.close()
```

---

## ✅ 실행 후 확인

실행 후 다음 쿼리로 확인:

```sql
-- 필드 확인
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PayrollMonthlyInput'
  AND COLUMN_NAME IN ('WeeklyHours', 'WeekCount')
ORDER BY ORDINAL_POSITION;
```

**예상 결과:**
```
COLUMN_NAME   DATA_TYPE   IS_NULLABLE   COLUMN_DEFAULT
WeeklyHours   decimal     NO            ((40.0))
WeekCount     int         NO            ((4))
```

---

## 📊 실행 내용 요약

### 추가되는 필드

| 필드명 | 타입 | Nullable | 기본값 | 설명 |
|--------|------|----------|--------|------|
| **WeeklyHours** | DECIMAL(18,2) | NOT NULL | 40.0 | 주소정근로시간 (주 15시간 미만 판정용) |
| **WeekCount** | INT | NOT NULL | 4 | 개근주수 (프리랜서 주휴수당 계산용) |

### 영향받는 테이블
- ✅ `dbo.PayrollMonthlyInput`

### 기존 데이터
- ✅ 기존 모든 레코드에 기본값 자동 설정
  - `WeeklyHours = 40.0`
  - `WeekCount = 4`

---

## 🔧 롤백 (되돌리기)

만약 문제가 생겨서 되돌려야 한다면:

```sql
USE [payroll];
GO

-- WeeklyHours 필드 삭제
ALTER TABLE [dbo].[PayrollMonthlyInput]
DROP COLUMN [WeeklyHours];
GO

-- WeekCount 필드 삭제
ALTER TABLE [dbo].[PayrollMonthlyInput]
DROP COLUMN [WeekCount];
GO
```

---

## ⚠️ 주의사항

1. **백업 권장**: 실행 전 DB 백업 권장 (중요한 프로덕션 환경인 경우)
   ```sql
   BACKUP DATABASE [payroll] TO DISK = 'C:\Backup\payroll_before_migration.bak'
   ```

2. **권한 필요**: `ALTER TABLE` 권한 필요 (보통 db_owner 또는 sysadmin)

3. **트랜잭션**: 안전한 실행을 위해 제공된 SQL은 각 단계마다 `GO`로 분리됨

4. **기존 데이터**: 기존 레코드에는 자동으로 기본값(40.0, 4) 설정됨

---

## 🎯 다음 단계

마이그레이션 완료 후:

1. ✅ **server.py 업데이트**
   - `MonthlyUpsertIn` 모델에 `weeklyHours`, `weekCount` 추가
   - API 엔드포인트에서 저장/조회 로직 추가

2. ✅ **Flutter 앱 테스트**
   - 월별 데이터 입력 시 `weeklyHours`, `weekCount` 입력 확인
   - 주 15시간 미만 주휴수당 판정 확인
   - 프리랜서 주휴수당 계산 확인

---

## 📞 문제 발생 시

에러 메시지를 확인하고:
- `"이미 존재"` 에러: 이미 필드가 추가되어 있음 (정상)
- `"권한 없음"` 에러: db_owner 권한 필요
- 기타 에러: 에러 메시지와 함께 문의

---

## 📝 체크리스트

실행 전:
- [ ] DB 백업 완료 (프로덕션인 경우)
- [ ] `payroll` 데이터베이스 선택 확인
- [ ] 적절한 권한 확인

실행 중:
- [ ] SQL 스크립트 실행
- [ ] 에러 없이 완료 확인

실행 후:
- [ ] 필드 추가 확인 (SELECT 쿼리)
- [ ] 기존 데이터 기본값 설정 확인
- [ ] server.py 업데이트
- [ ] Flutter 앱 테스트

