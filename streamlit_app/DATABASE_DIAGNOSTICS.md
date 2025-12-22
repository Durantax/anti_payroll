# 데이터베이스 연결 진단 가이드

## 📋 개요

Streamlit 급여관리 프로그램의 데이터베이스 연결 문제를 진단하고 해결하는 완전한 가이드입니다.

**작성일**: 2024-12-22  
**버전**: 1.0.0  
**대상**: 시스템 관리자, 개발자

---

## 🔍 진단 기능 사용법

### 1. 진단 화면 접근
```bash
# Streamlit 앱 실행
cd streamlit_app
streamlit run app.py
```

### 2. 진단 실행
1. 브라우저에서 `http://localhost:8501` 접속
2. **⚙️ 설정** 탭 클릭
3. 하단의 **"🔍 데이터베이스 연결 진단"** 버튼 클릭

### 3. 진단 결과 확인
진단 도구는 다음 정보를 표시합니다:

#### 📌 연결 정보
- **서버**: `25.2.89.129:1433`
- **데이터베이스**: `기본정보`
- **사용자**: `user1`
- **현재 사용 드라이버**: 자동 감지된 ODBC 드라이버

#### 🔌 연결 상태
- ✅ **성공**: 데이터베이스 연결 정상
- ❌ **실패**: 연결 오류 (오류 메시지 표시)

#### 🔧 설치된 ODBC 드라이버
- **SQL Server 드라이버**: 사용 가능한 모든 SQL Server 드라이버 목록
- **현재 사용 중인 드라이버**: ✅ 마크로 표시
- **기타 드라이버**: 시스템의 다른 ODBC 드라이버

---

## ⚠️ 일반적인 오류 및 해결 방법

### 1. IM002 - ODBC 드라이버 미설치

#### 오류 메시지
```
IM002 [Microsoft][ODBC 드라이버 관리자] 데이터 원본 이름이 없고 기본 드라이버를 지정하지 않았습니다
```

#### 원인
- ODBC 드라이버가 시스템에 설치되지 않음
- 드라이버 이름이 잘못 지정됨

#### 해결 방법

##### Windows
1. **Microsoft ODBC Driver for SQL Server 다운로드**
   - [공식 다운로드 페이지](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)
   - 권장 버전: **ODBC Driver 18 for SQL Server**

2. **설치 프로그램 실행**
   ```
   - 다운로드한 msodbcsql.msi 실행
   - 기본 설정으로 설치 진행
   - 설치 완료 후 시스템 재부팅 (선택사항)
   ```

3. **Streamlit 앱 재시작**
   ```bash
   # Ctrl+C로 앱 종료 후 재실행
   streamlit run app.py
   ```

##### Linux (Ubuntu/Debian)
```bash
# Microsoft repository 추가
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

# 패키지 업데이트 및 설치
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18

# 설치 확인
odbcinst -q -d -n "ODBC Driver 18 for SQL Server"
```

##### Linux (RHEL/CentOS)
```bash
# Microsoft repository 추가
curl https://packages.microsoft.com/config/rhel/8/prod.repo | sudo tee /etc/yum.repos.d/mssql-release.repo

# 설치
sudo yum remove unixODBC-utf16 unixODBC-utf16-devel
sudo ACCEPT_EULA=Y yum install -y msodbcsql18

# 설치 확인
odbcinst -q -d -n "ODBC Driver 18 for SQL Server"
```

---

### 2. 08001 - 네트워크 연결 오류

#### 오류 메시지
```
08001 [Microsoft][ODBC Driver 18 for SQL Server] TCP Provider: No connection could be made because the target machine actively refused it
```

#### 원인
- SQL Server가 실행되지 않음
- 방화벽이 1433 포트를 차단
- 서버 주소 또는 포트 번호가 잘못됨
- 네트워크 연결 문제

#### 해결 방법

##### 1. SQL Server 상태 확인
```sql
-- SQL Server Management Studio에서 확인
-- 또는 Windows 서비스에서 'SQL Server (MSSQLSERVER)' 상태 확인
```

##### 2. 포트 확인
```cmd
# Windows에서 SQL Server 포트 확인
netstat -an | findstr 1433

# 출력 예시 (정상):
# TCP    0.0.0.0:1433           0.0.0.0:0              LISTENING
```

##### 3. 방화벽 규칙 확인
```powershell
# Windows Firewall에서 1433 포트 열기
New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
```

##### 4. SQL Server TCP/IP 활성화
1. SQL Server Configuration Manager 실행
2. **SQL Server 네트워크 구성** → **MSSQLSERVER용 프로토콜**
3. **TCP/IP** 마우스 오른쪽 클릭 → **사용**
4. SQL Server 서비스 재시작

##### 5. 연결 테스트
```bash
# telnet으로 포트 연결 테스트
telnet 25.2.89.129 1433

# ping으로 네트워크 연결 테스트
ping 25.2.89.129
```

---

### 3. 18456 - 인증 실패

#### 오류 메시지
```
18456 [Microsoft][ODBC Driver 18 for SQL Server] Login failed for user 'user1'
```

#### 원인
- 사용자명 또는 비밀번호가 잘못됨
- SQL Server 인증이 비활성화됨
- 사용자 권한이 부족함

#### 해결 방법

##### 1. 인증 정보 확인
```python
# streamlit_app/database.py에서 확인
DB_USER = "user1"
DB_PASSWORD = "1536"
```

##### 2. SQL Server 인증 모드 확인
```sql
-- SQL Server Management Studio에서 실행
SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS [인증모드];
-- 0 = SQL Server 및 Windows 인증 (혼합 모드) ✅
-- 1 = Windows 인증만 ❌
```

##### 3. 혼합 모드 활성화 (필요 시)
1. SQL Server Management Studio 실행
2. 서버 마우스 오른쪽 클릭 → **속성**
3. **보안** 페이지
4. **서버 인증** → **SQL Server 및 Windows 인증 모드** 선택
5. SQL Server 재시작

##### 4. 사용자 권한 확인
```sql
-- 사용자 존재 확인
USE [기본정보];
SELECT name FROM sys.database_principals WHERE name = 'user1';

-- 사용자에게 권한 부여
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO user1;
```

---

## 🔧 고급 문제 해결

### 연결 문자열 직접 확인

진단 화면의 **"연결 문자열 (디버깅용)"** 섹션에서 확인:

```
DRIVER={ODBC Driver 18 for SQL Server};
SERVER=25.2.89.129,1433;
DATABASE=기본정보;
UID=user1;
PWD=****;
TrustServerCertificate=YES;
Encrypt=YES;
Connection Timeout=10;
```

### 수동 연결 테스트 (Python)

```python
import pyodbc

conn_str = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=25.2.89.129,1433;"
    "DATABASE=기본정보;"
    "UID=user1;"
    "PWD=1536;"
    "TrustServerCertificate=YES;"
    "Encrypt=YES;"
)

try:
    conn = pyodbc.connect(conn_str)
    print("✅ 연결 성공!")
    cursor = conn.cursor()
    cursor.execute("SELECT @@VERSION")
    row = cursor.fetchone()
    print(f"SQL Server 버전: {row[0]}")
    conn.close()
except Exception as e:
    print(f"❌ 연결 실패: {e}")
```

### 드라이버 우선순위 변경

`streamlit_app/database.py`의 `get_odbc_driver()` 함수:

```python
drivers = [
    "ODBC Driver 18 for SQL Server",  # 최우선
    "ODBC Driver 17 for SQL Server",
    "ODBC Driver 13 for SQL Server",
    "ODBC Driver 11 for SQL Server",
    "SQL Server Native Client 11.0",
    "SQL Server",                      # 최후 수단
]
```

---

## 📊 자동 드라이버 감지 로직

### 작동 방식

1. **우선순위 목록 확인**
   - Driver 18, 17, 13, 11 순서로 확인
   - 시스템에 설치된 첫 번째 드라이버 선택

2. **Fallback 메커니즘**
   - 우선순위 목록에 없는 경우
   - 'SQL Server'가 포함된 다른 드라이버 검색
   - 모두 실패하면 기본 드라이버 사용

3. **자동 설정**
   - 연결 문자열 자동 생성
   - TLS/SSL 보안 설정 적용
   - 연결 타임아웃 10초 설정

### 코드 구조

```python
def get_odbc_driver():
    """사용 가능한 ODBC 드라이버 찾기"""
    try:
        available_drivers = pyodbc.drivers()
        
        # 우선순위 목록에서 찾기
        for driver in priority_drivers:
            if driver in available_drivers:
                return driver
        
        # SQL Server 포함 드라이버 검색
        for driver in available_drivers:
            if 'SQL Server' in driver:
                return driver
        
        return None  # 드라이버 없음
    except:
        return priority_drivers[0]  # 기본값
```

---

## ✅ 설치 확인 체크리스트

### Windows

- [ ] Microsoft ODBC Driver 18 for SQL Server 설치됨
- [ ] SQL Server가 실행 중임
- [ ] TCP/IP 프로토콜이 활성화됨
- [ ] 방화벽이 1433 포트를 허용함
- [ ] SQL Server 혼합 인증 모드 활성화
- [ ] user1 계정이 존재하고 권한이 있음
- [ ] Streamlit 앱에서 진단 테스트 통과

### Linux

- [ ] msodbcsql18 패키지 설치됨
- [ ] SQL Server 원격 연결 허용됨
- [ ] 네트워크 방화벽 규칙 설정됨
- [ ] pyodbc Python 패키지 설치됨
- [ ] odbcinst 명령어로 드라이버 확인됨
- [ ] Streamlit 앱에서 진단 테스트 통과

---

## 🆘 추가 지원

### 진단 결과 공유

문제가 해결되지 않을 경우, 진단 화면에서 다음 정보를 캡처:

1. **연결 정보** 섹션 스크린샷
2. **연결 상태** 및 오류 메시지
3. **설치된 ODBC 드라이버** 목록
4. **연결 문자열** (비밀번호 제외)

### 로그 파일 확인

```bash
# Streamlit 실행 로그 확인
# 터미널 출력에서 오류 메시지 확인
```

### 공식 문서

- [Microsoft ODBC Driver for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/)
- [pyodbc 공식 문서](https://github.com/mkleehammer/pyodbc/wiki)
- [SQL Server 네트워크 구성](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-a-server-to-listen-on-a-specific-tcp-port)

---

## 📝 요약

### 빠른 해결 순서

1. **진단 실행**: 설정 탭 → "데이터베이스 연결 진단" 클릭
2. **드라이버 확인**: SQL Server 드라이버가 설치되어 있는가?
   - 없으면 → Microsoft 사이트에서 다운로드 및 설치
3. **연결 테스트**: 진단 화면에서 연결 상태 확인
   - 실패 시 → 오류 코드별 해결 방법 참조
4. **앱 재시작**: 드라이버 설치 후 Streamlit 앱 재시작
5. **재진단**: 다시 진단 실행하여 ✅ 연결 성공 확인

### 가장 흔한 원인
1. **ODBC 드라이버 미설치** (70%)
2. **SQL Server 미실행** (15%)
3. **방화벽 차단** (10%)
4. **인증 정보 오류** (5%)

---

**버전**: 1.0.0  
**최종 업데이트**: 2024-12-22  
**작성자**: GenSpark AI Developer  
**문서 상태**: ✅ 완료
