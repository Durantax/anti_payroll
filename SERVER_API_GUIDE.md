# 🚀 Durantax 급여관리 서버 API 완전 가이드

## 📋 목차
1. [서버 구성](#서버-구성)
2. [설치 및 실행](#설치-및-실행)
3. [API 엔드포인트 전체 목록](#api-엔드포인트-전체-목록)
4. [테스트 방법](#테스트-방법)
5. [주요 변경사항](#주요-변경사항)
6. [문제 해결](#문제-해결)

---

## 서버 구성

### 기술 스택
- **프레임워크**: FastAPI 3.0.0
- **데이터베이스**: MS SQL Server (ODBC Driver 18)
- **Python 버전**: 3.8+
- **네트워크**: Hamachi VPN (25.2.89.129)

### 환경 변수
```bash
DB_SERVER=25.2.89.129
DB_PORT=1433
DB_NAME=기본정보
DB_USER=user1
DB_PASSWORD=1536
API_KEY=                    # 비어있음 (인증 없음)
INIT_DB=0                   # 기존 DB 사용 (1로 설정 시 테이블 생성)
```

---

## 설치 및 실행

### 1. 필수 패키지 설치
```bash
pip install fastapi uvicorn pyodbc requests pydantic
```

### 2. ODBC Driver 설치 확인
```bash
# Windows
odbcad32.exe

# Linux
odbcinst -j
```

필요시 다운로드: [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

### 3. 서버 실행
```bash
cd /path/to/webapp
python server.py
```

또는 uvicorn 직접 실행:
```bash
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
```

### 4. 서버 확인
```bash
curl http://localhost:8000/health
```

---

## API 엔드포인트 전체 목록

### 📊 헬스체크
| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| GET | `/health` | 서버 상태 확인 | `{"ok": true, "db": true, "time": "..."}` |
| GET | `/_routes` | 모든 라우트 목록 | `[{"path": "/...", "methods": ["GET"]}]` |

### 🏢 거래처 (Clients)
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| GET | `/clients` | 거래처 목록 조회 | - |
| PATCH | `/clients/{client_id}` | 거래처 정보 수정 | `{"has5OrMoreWorkers": bool, "emailSubjectTemplate": str, "emailBodyTemplate": str}` |

### 👥 직원 (Employees)
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| GET | `/clients/{client_id}/employees` | 직원 목록 조회 | - |
| POST | `/employees/upsert` | 직원 등록/수정 | `EmployeeUpsertIn` (전체 필드) |
| GET | `/employees/{employee_id}/empno` | 사번 조회 | - |
| DELETE | `/employees/{employee_id}` | 직원 삭제 | - |

**✅ EmpNo (사번) 자동 생성**
- 신규 직원 등록 시 DB 트리거/로직에서 자동 부여
- UPDATE 시 EmpNo는 수정 불가
- 응답에 `empNo` 필드 포함

### 📅 월별 입력 (Monthly Input)
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| GET | `/payroll/monthly?employeeId={id}&ym={ym}` | 월별 데이터 조회 | - |
| POST | `/payroll/monthly/upsert` | 월별 데이터 저장 | `{"employeeId": int, "ym": "YYYY-MM", "workHours": float, "bonus": float, "overtimeHours": float, "nightHours": float, "holidayHours": float, "weeklyHours": float, "weekCount": int, "isDurunuri": bool}` |

**✅ isDurunuri 필드 추가**
- 두루누리 체크박스 상태 저장
- DB 컬럼: `PayrollMonthlyInput.IsDurunuri`

### 💰 급여 계산 결과 (Payroll Results)
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| GET | `/payroll/results/{employee_id}?year={y}&month={m}` | 급여 이력 조회 | - |
| POST | `/payroll/results/save` | 급여 결과 저장 | `{"employeeId": int, "clientId": int, "year": int, "month": int, "baseSalary": float, ..., "duruNuriEmployerContribution": float, "duruNuriEmployeeContribution": float, "duruNuriApplied": bool}` |
| PATCH | `/payroll/results/{result_id}/confirm` | 급여 확정 | `{"confirmedBy": "admin"}` |
| PATCH | `/payroll/results/{result_id}/unconfirm` | 급여 확정 해제 | - |
| PATCH | `/payroll/results/client/{client_id}/confirm-all?year={y}&month={m}` | 전체 확정 | `{"confirmedBy": "admin"}` |
| GET | `/payroll/results/client/{client_id}/confirmation-status?year={y}&month={m}` | 확정 상태 조회 | - |

**✅ 두루누리 지원 (신규 컬럼)**
- `duruNuriEmployerContribution`: 사업주 기여금
- `duruNuriEmployeeContribution`: 근로자 기여금
- `duruNuriApplied`: 두루누리 적용 여부

### 📧 발송 현황 (Send Status)
| Method | Endpoint | Description | Query Params |
|--------|----------|-------------|--------------|
| GET | `/clients/{client_id}/send-status` | 발송 현황 조회 | `?ym=YYYY-MM&docType=slip|register` |
| GET | `/payroll/today/clients` | 오늘 발송 대상 조회 | `?docType=slip|register` |

### 📝 로그 (Logs)
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| POST | `/logs/doc` | 문서 로그 저장 | `{"clientId": int, "ym": str, "docType": str, "fileName": str, ...}` |
| GET | `/logs/doc?clientId={id}&ym={ym}` | 문서 로그 조회 | - |
| POST | `/logs/mail` | 메일 로그 저장 | `{"clientId": int, "ym": str, "docType": str, "toEmail": str, "subject": str, "status": "sent|failed", ...}` |
| POST | `/logs/mail/bulk` | 메일 로그 일괄 저장 | `{"items": [MailLogIn]}` |
| GET | `/logs/mail?clientId={id}&ym={ym}&docType={type}` | 메일 로그 조회 | - |

**✅ 급여발송로그 (신규)**
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| POST | `/logs/payroll-send` | 급여발송로그 저장 | `{"clientId": int, "ym": str, "docType": str, "sendResult": "성공|실패", "retryCount": int, "errorMessage": str, "recipient": str, "ccRecipient": str, "subject": str, "sendMethod": "자동|수동", "sendPath": "SMTP", "executingPC": str, "executor": str}` |
| GET | `/logs/payroll-send?clientId={id}&ym={ym}&docType={type}` | 급여발송로그 조회 | - |

**용도**: 거래처별 일괄 발송 로그 (자동 발송 시스템용)

### ⚙️ 설정 (Settings)
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| GET | `/smtp/config` | SMTP 설정 조회 | - |
| POST | `/smtp/config` | SMTP 설정 저장 | `{"host": str, "port": int, "username": str, "password": str, "useSSL": bool}` |
| GET | `/app/settings` | 앱 설정 조회 | - |
| POST | `/app/settings` | 앱 설정 저장 | `{"serverUrl": str, "apiKey": str}` |

### 📨 메일 발송 (Mail Send)
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| POST | `/mail/send` | SMTP 이메일 발송 | `{"clientId": int, "ym": str, "docType": str, "toEmail": str, "subject": str, "bodyText": str, "ccEmail": str, "employeeId": int, "pcId": str}` |

### 💼 거래처별 수당/공제 항목 관리 (신규)

**수당 항목 (Allowance Masters)**
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| GET | `/clients/{client_id}/allowance-masters` | 수당 항목 조회 | - |
| POST | `/clients/{client_id}/allowance-masters` | 수당 항목 생성 | `{"allowanceName": str, "isActive": bool}` |
| PATCH | `/allowance-masters/{allowance_id}` | 수당 항목 수정 | `{"allowanceName": str, "isActive": bool}` |
| DELETE | `/allowance-masters/{allowance_id}` | 수당 항목 삭제 | - |

**공제 항목 (Deduction Masters)**
| Method | Endpoint | Description | Request Body |
|--------|----------|-------------|--------------|
| GET | `/clients/{client_id}/deduction-masters` | 공제 항목 조회 | - |
| POST | `/clients/{client_id}/deduction-masters` | 공제 항목 생성 | `{"deductionName": str, "isActive": bool}` |
| PATCH | `/deduction-masters/{deduction_id}` | 공제 항목 수정 | `{"deductionName": str, "isActive": bool}` |
| DELETE | `/deduction-masters/{deduction_id}` | 공제 항목 삭제 | - |

---

## 테스트 방법

### 1. 헬스체크 테스트
```bash
curl http://25.2.89.129:8000/health
```

**예상 응답**:
```json
{
  "ok": true,
  "db": true,
  "time": "2025-12-31T12:00:00",
  "holidayCacheYears": [2025],
  "holidayCacheErr": {}
}
```

### 2. 거래처 목록 조회
```bash
curl http://25.2.89.129:8000/clients
```

### 3. 직원 목록 조회
```bash
curl http://25.2.89.129:8000/clients/1/employees
```

### 4. 직원 등록 (사번 자동 생성 확인)
```bash
curl -X POST http://25.2.89.129:8000/employees/upsert \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": 1,
    "name": "홍길동",
    "birthDate": "900101",
    "employmentType": "regular",
    "salaryType": "MONTHLY",
    "baseSalary": 3000000,
    "hourlyRate": 0,
    "normalHours": 209,
    "foodAllowance": 100000,
    "carAllowance": 0,
    "emailTo": "hong@example.com",
    "useEmail": true,
    "hasNationalPension": true,
    "hasHealthInsurance": true,
    "hasEmploymentInsurance": true,
    "taxDependents": 1,
    "childrenCount": 0
  }'
```

**응답 확인**: `empNo` 필드에 자동 생성된 사번(예: "0001") 포함

### 5. 월별 데이터 저장 (두루누리 체크박스)
```bash
curl -X POST http://25.2.89.129:8000/payroll/monthly/upsert \
  -H "Content-Type: application/json" \
  -d '{
    "employeeId": 1,
    "ym": "2025-01",
    "workHours": 209,
    "bonus": 0,
    "overtimeHours": 10,
    "nightHours": 5,
    "holidayHours": 0,
    "weeklyHours": 40,
    "weekCount": 4,
    "isDurunuri": true
  }'
```

### 6. 급여 결과 저장 (두루누리 포함)
```bash
curl -X POST http://25.2.89.129:8000/payroll/results/save \
  -H "Content-Type: application/json" \
  -d '{
    "employeeId": 1,
    "clientId": 1,
    "year": 2025,
    "month": 1,
    "baseSalary": 3000000,
    "overtimeAllowance": 150000,
    "totalPayment": 3150000,
    "nationalPension": 135000,
    "healthInsurance": 106350,
    "longTermCare": 13772,
    "employmentInsurance": 27000,
    "incomeTax": 99000,
    "localIncomeTax": 9900,
    "totalDeduction": 391022,
    "netPay": 2758978,
    "duruNuriEmployerContribution": 60750,
    "duruNuriEmployeeContribution": 40500,
    "duruNuriApplied": true,
    "calculatedBy": "system"
  }'
```

### 7. 급여발송로그 저장
```bash
curl -X POST http://25.2.89.129:8000/logs/payroll-send \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": 1,
    "ym": "2025-01",
    "docType": "slip",
    "sendResult": "성공",
    "retryCount": 0,
    "errorMessage": null,
    "recipient": "10명",
    "ccRecipient": null,
    "subject": "삼성전자 2025년 1월 급여명세서",
    "sendMethod": "자동",
    "sendPath": "SMTP",
    "executingPC": "25.2.89.129",
    "executor": "AUTO_SYSTEM"
  }'
```

### 8. 수당 항목 생성
```bash
curl -X POST http://25.2.89.129:8000/clients/1/allowance-masters \
  -H "Content-Type: application/json" \
  -d '{
    "allowanceName": "성과급",
    "isActive": true
  }'
```

---

## 주요 변경사항

### ✅ 1. 사번(EmpNo) 시스템 구현
- **DB 컬럼**: `Employees.EmpNo` (char(4))
- **자동 생성**: INSERT 시 DB 트리거/로직에서 자동 부여
- **수정 불가**: UPDATE 시 EmpNo 제외
- **API 응답**: `/employees/upsert` 응답에 `empNo` 포함
- **파일명 사용**: PDF/HTML 파일명에 생년월일 대신 사번 사용

### ✅ 2. 두루누리 지원 구현
**월별 입력 (PayrollMonthlyInput)**
- `IsDurunuri` (bit): 두루누리 체크박스 상태

**급여 결과 (PayrollResults)**
- `DuruNuriEmployerContribution` (decimal): 사업주 기여금
- `DuruNuriEmployeeContribution` (decimal): 근로자 기여금
- `DuruNuriApplied` (bit): 두루누리 적용 여부

### ✅ 3. 급여발송로그 API 추가
- **테이블**: `dbo.급여발송로그`
- **용도**: 거래처별 일괄 발송 로그 (자동 발송 시스템용)
- **엔드포인트**: 
  - POST `/logs/payroll-send`: 로그 저장
  - GET `/logs/payroll-send`: 로그 조회
- **MailLog와 차이**: MailLog는 직원별, PayrollSendLog는 거래처별

### ✅ 4. 거래처별 수당/공제 항목 관리
- **테이블**: `dbo.AllowanceMasters`, `dbo.DeductionMasters`
- **용도**: 거래처별 맞춤 수당/공제 항목 설정
- **CRUD API**: 생성, 조회, 수정, 삭제

### ✅ 5. 급여 확정 기능 추가
- **컬럼**: `PayrollResults.IsConfirmed`, `ConfirmedAt`, `ConfirmedBy`
- **API**:
  - PATCH `/payroll/results/{id}/confirm`: 개별 확정
  - PATCH `/payroll/results/{id}/unconfirm`: 확정 해제
  - PATCH `/payroll/results/client/{id}/confirm-all`: 전체 확정
  - GET `/payroll/results/client/{id}/confirmation-status`: 확정 상태 조회

### ✅ 6. 컬럼 존재 여부 동적 체크
모든 API에서 DB 컬럼 존재 여부를 동적으로 확인하여 호환성 보장:
- `column_exists()` 함수로 컬럼 체크
- 컬럼이 없으면 기본값 사용 또는 무시
- 기존 DB 구조와 완벽 호환

---

## 문제 해결

### 문제 1: ODBC Driver 연결 오류
```
pyodbc.Error: ('01000', "[01000] [unixODBC][Driver Manager]Can't open lib 'ODBC Driver 18 for SQL Server'")
```

**해결 방법**:
1. ODBC Driver 18 설치 확인
2. 환경 변수 설정:
   ```bash
   export ODBCSYSINI=/etc
   export ODBCINI=/etc/odbc.ini
   ```

### 문제 2: DB 연결 타임아웃
```
Connection Timeout Expired
```

**해결 방법**:
1. Hamachi VPN 연결 확인
2. 방화벽 설정 확인 (포트 1433 허용)
3. SQL Server 설정에서 TCP/IP 활성화

### 문제 3: 테이블이 없음
```
dbo.Employees 테이블이 없습니다.
```

**해결 방법**:
- DB에 해당 테이블이 실제로 존재하는지 확인
- `script.sql` 실행하여 테이블 생성

### 문제 4: 컬럼이 없음 (EmpNo, IsDurunuri 등)
```
The column 'EmpNo' does not exist
```

**해결 방법**:
- 서버가 자동으로 컬럼 존재 여부를 체크하므로 무시 가능
- 필요하면 `script.sql`의 ALTER TABLE 문으로 컬럼 추가

### 문제 5: 사번 자동 생성 안 됨
**해결 방법**:
1. DB에 EmpNo 자동 생성 트리거/프로시저 확인
2. 없다면 수동으로 생성:
```sql
-- 트리거 예시
CREATE TRIGGER trg_AutoEmpNo
ON dbo.Employees
AFTER INSERT
AS
BEGIN
    UPDATE e
    SET EmpNo = RIGHT('000' + CAST(ROW_NUMBER() OVER (PARTITION BY e.ClientId ORDER BY e.EmployeeId) AS VARCHAR(4)), 4)
    FROM dbo.Employees e
    INNER JOIN inserted i ON e.EmployeeId = i.EmployeeId
    WHERE e.EmpNo IS NULL
END
```

---

## 서버 배포 체크리스트

### 시작 전
- [ ] Python 3.8+ 설치 확인
- [ ] ODBC Driver 18 설치 확인
- [ ] Hamachi VPN 연결 확인 (25.2.89.129)
- [ ] DB 접속 정보 확인 (user1/1536)

### 서버 실행
- [ ] `python server.py` 실행
- [ ] 로그 확인: `[BOOT] Starting Durantax Payroll API v3.0.0`
- [ ] 헬스체크: `curl http://25.2.89.129:8000/health`

### API 테스트
- [ ] 거래처 조회 (`/clients`)
- [ ] 직원 조회 (`/clients/1/employees`)
- [ ] 직원 등록 및 사번 자동 생성 확인
- [ ] 월별 데이터 저장 (두루누리 체크박스)
- [ ] 급여 결과 저장 (두루누리 기여금)
- [ ] 급여발송로그 저장
- [ ] 수당/공제 항목 관리

### Flutter 앱 연동
- [ ] Flutter 앱에서 API 호출 테스트
- [ ] 사번 표시 확인
- [ ] 두루누리 체크박스 저장/로드 확인
- [ ] 자동 발송 시스템 동작 확인

---

## 연락처 및 지원

**문제 발생 시**:
1. 서버 로그 확인: `[REQ]`, `[BOOT]`, `[WARN]` 메시지
2. DB 상태 확인: `/health` 엔드포인트
3. 네트워크 확인: Hamachi VPN 연결 상태

**버전 정보**:
- Server API: v3.0.0
- FastAPI: Latest
- Python: 3.8+
- DB: MS SQL Server 2019+

---

## 부록: Flutter API 호출 예제

### Dart 코드 예제
```dart
// 사번 포함 직원 조회
final response = await http.get(
  Uri.parse('http://25.2.89.129:8000/clients/1/employees'),
  headers: {'Content-Type': 'application/json'},
);

final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
for (var worker in data) {
  print('이름: ${worker['name']}, 사번: ${worker['empNo']}');
}

// 두루누리 체크박스 저장
await http.post(
  Uri.parse('http://25.2.89.129:8000/payroll/monthly/upsert'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'employeeId': 1,
    'ym': '2025-01',
    'workHours': 209,
    'isDurunuri': true,
  }),
);

// 급여발송로그 저장
await http.post(
  Uri.parse('http://25.2.89.129:8000/logs/payroll-send'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'clientId': 1,
    'ym': '2025-01',
    'docType': 'slip',
    'sendResult': '성공',
    'retryCount': 0,
    'sendMethod': '자동',
    'executingPC': hamachiIP,
    'executor': 'AUTO_SYSTEM',
  }),
);
```

---

**업데이트 일자**: 2025-12-31  
**작성자**: AI Senior CTO  
**버전**: 3.0.0 FINAL
