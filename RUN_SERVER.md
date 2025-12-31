# 서버 실행 가이드

## 🚀 빠른 시작

### 1. DB 초기화 (최초 1회만)

DB에 AppSettings와 SmtpConfig 초기 데이터를 삽입합니다:

```bash
cd C:\work\payroll
python init_db.py
```

**출력 예시:**
```
============================================================
DB 초기화 시작
============================================================

[1] AppSettings 테이블 확인...
   ⏩ AppSettings 초기 데이터 삽입 중...
   ✅ AppSettings 삽입 완료

[2] SmtpConfig 테이블 확인...
   ⏩ SmtpConfig 초기 데이터 삽입 중...
   ✅ SmtpConfig 삽입 완료

============================================================
✅ DB 초기화 완료!
============================================================
```

### 2. 서버 실행

```bash
cd C:\work\payroll
python server.py
```

**출력 예시:**
```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

### 3. 서버 테스트

새 터미널에서:

```bash
cd C:\work\payroll
python test_server.py
```

**출력 예시:**
```
============================================================
🧪 서버 API 테스트
   Base URL: http://25.2.89.129:8000
   시작 시간: 2025-12-31 14:30:00
============================================================

[1] Health Check
------------------------------------------------------------
Status: 200
✅ 서버 상태: OK
   DB 연결: ✅

[2] App Settings
------------------------------------------------------------
Status: 200
✅ 앱 설정 조회 성공
   ServerUrl: http://25.2.89.129:8000
   ApiKey: (없음)

[3] SMTP Config
------------------------------------------------------------
Status: 200
✅ SMTP 설정 조회 성공
   Host: smtp.gmail.com
   Port: 587
   Username: (없음)
   UseSSL: True

[4] Clients List
------------------------------------------------------------
Status: 200
✅ 거래처 목록 조회 성공
   총 거래처 수: 5
   [1] 삼성전자 (ID: 1)
   [2] LG전자 (ID: 2)
   [3] 현대자동차 (ID: 3)

[5] Available Routes
------------------------------------------------------------
Status: 200
✅ 등록된 엔드포인트: 45개

   📁 Clients (7개)
      GET    /clients
      GET    /clients/{client_id}
      PATCH  /clients/{client_id}
      GET    /clients/{client_id}/allowance-masters
      GET    /clients/{client_id}/deduction-masters

   📁 Employees (5개)
      GET    /clients/{client_id}/employees
      POST   /employees/upsert
      DELETE /employees/{employee_id}
      GET    /employees/{employee_id}/empno

   📁 Payroll (9개)
      POST   /payroll/monthly/upsert
      GET    /payroll/monthly
      POST   /payroll/results/save
      PATCH  /payroll/results/{result_id}/confirm
      GET    /payroll/today/clients

============================================================
✅ 테스트 완료
============================================================
```

## 🔧 문제 해결

### 문제: 500 에러 - AppSettings 테이블이 없습니다

**해결:** DB 초기화 스크립트 실행
```bash
python init_db.py
```

### 문제: DB 연결 실패

**원인:** Hamachi VPN이 연결되지 않았거나 DB 서버가 실행되지 않음

**해결:**
1. Hamachi VPN 연결 확인
2. SQL Server 실행 확인
3. 방화벽 설정 확인 (포트 1433)

### 문제: Flutter 앱에서 404/500 에러

**원인:** 서버가 실행되지 않았거나 DB에 초기 데이터가 없음

**해결:**
1. `python init_db.py` 실행
2. `python server.py` 실행
3. `python test_server.py`로 서버 상태 확인
4. Flutter 앱 재시작

## 📝 체크리스트

서버 실행 전 확인사항:

- [ ] Hamachi VPN 연결됨 (25.2.89.129)
- [ ] SQL Server 실행 중
- [ ] DB 초기화 완료 (`python init_db.py`)
- [ ] 서버 실행 완료 (`python server.py`)
- [ ] 서버 테스트 성공 (`python test_server.py`)
- [ ] Flutter 앱 실행 (`flutter run -d windows`)

## 🎯 API 엔드포인트

총 45개의 API 엔드포인트가 제공됩니다:

### 거래처 관리 (Clients)
- `GET /clients` - 거래처 목록 조회
- `PATCH /clients/{id}` - 거래처 정보 수정
- `GET /clients/{id}/employees` - 거래처별 직원 목록
- `GET /clients/{id}/send-status` - 발송 현황 조회

### 직원 관리 (Employees)
- `POST /employees/upsert` - 직원 추가/수정 (EmpNo 자동 생성)
- `DELETE /employees/{id}` - 직원 삭제
- `GET /employees/{id}/empno` - 사번 조회

### 급여 관리 (Payroll)
- `POST /payroll/monthly/upsert` - 월별 근무 데이터 저장
- `GET /payroll/monthly` - 월별 근무 데이터 조회
- `POST /payroll/results/save` - 급여 계산 결과 저장
- `PATCH /payroll/results/{id}/confirm` - 급여 확정
- `PATCH /payroll/results/{id}/unconfirm` - 급여 확정 취소
- `GET /payroll/results/client/{id}/confirmation-status` - 마감 현황

### 수당/공제 마스터 (Masters)
- `GET /clients/{id}/allowance-masters` - 거래처별 수당 마스터
- `POST /clients/{id}/allowance-masters` - 수당 마스터 추가
- `PATCH /allowance-masters/{id}` - 수당 마스터 수정
- `DELETE /allowance-masters/{id}` - 수당 마스터 삭제
- 동일한 CRUD가 deduction-masters에도 제공

### 로그 관리 (Logs)
- `POST /logs/mail` - 메일 로그 저장
- `GET /logs/mail` - 메일 로그 조회
- `POST /logs/payroll-send` - 급여 발송 로그 저장
- `GET /logs/payroll-send` - 급여 발송 로그 조회

### 설정 (Settings)
- `GET /app/settings` - 앱 설정 조회
- `POST /app/settings` - 앱 설정 저장
- `GET /smtp/config` - SMTP 설정 조회
- `POST /smtp/config` - SMTP 설정 저장

### 기타 (Others)
- `GET /health` - 서버 상태 확인
- `GET /_routes` - 전체 엔드포인트 목록

## 📊 서버 버전

**Version:** 3.0.0  
**Release Date:** 2025-12-31  
**Tech Stack:**
- FastAPI 0.109.0
- MS SQL Server (ODBC Driver 18)
- Python 3.8+
- Hamachi VPN (25.2.89.129)

## 🔗 관련 문서

- [SERVER_API_GUIDE.md](./SERVER_API_GUIDE.md) - 상세 API 문서
- [README.md](./README.md) - 프로젝트 개요
- [script_utf8.sql](./script_utf8.sql) - DB 스키마
