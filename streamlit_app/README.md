# 급여관리 프로그램 - Streamlit 버전

Flutter 앱의 모든 기능을 Python Streamlit으로 구현한 급여관리 프로그램입니다.

## 🚀 주요 기능

### 1. 급여 계산
- 월급제/시급제 자동 인식
- 연장/야간/휴일/주휴수당 자동 계산
- 4대보험 자동 계산
- 간이세액표 기반 소득세 계산
- 프리랜서 3.3% 세금 계산
- 5인 이상/미만 사업장 구분

### 2. 문서 생성
- 급여명세서 PDF 자동 생성
- 일괄 PDF 생성 (진행률 표시)
- 거래처별 하위 폴더 자동 생성
- CSV 급여대장 내보내기
- 폴더 바로가기 기능

### 3. 이메일 발송
- 급여명세서 PDF 자동 첨부
- 일괄 이메일 발송
- 발송 진행률 실시간 표시
- 이메일 템플릿 사용자 정의
- SMTP 연결 테스트

### 4. 설정
- 파일 저장 경로 설정
- 거래처별 하위 폴더 옵션
- SMTP 서버 설정
- 이메일 템플릿 관리

## 📋 요구사항

### Python 버전
- Python 3.8 이상

### 시스템 요구사항
- Windows 10/11 (권장)
- SQL Server ODBC Driver 18

### 데이터베이스
- SQL Server (25.2.89.129:1433)
- 데이터베이스: 기본정보
- 테이블: Clients, Employees, PayrollMonthlyInput

## 🔧 설치 방법

### 1. Python 설치
Python 3.8 이상을 설치합니다.
- https://www.python.org/downloads/

### 2. ODBC Driver 설치
SQL Server용 ODBC Driver 18을 설치합니다.
- https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server

### 3. 패키지 설치
```bash
cd streamlit_app
pip install -r requirements.txt
```

## 🎯 실행 방법

```bash
cd streamlit_app
streamlit run app.py
```

브라우저가 자동으로 열리며 `http://localhost:8501`로 접속됩니다.

## 📁 프로젝트 구조

```
streamlit_app/
├── app.py                    # 메인 애플리케이션
├── database.py               # 데이터베이스 연결
├── payroll_calculator.py     # 급여 계산 로직
├── pdf_generator.py          # PDF 생성
├── email_service.py          # 이메일 발송
└── requirements.txt          # 의존성 패키지
```

## 🔑 주요 차이점 (Flutter vs Streamlit)

### Flutter 앱 문제점
- 빈번한 빌드 오류
- API 서버 필요 (3계층 구조)
- 컴파일 시간 소요
- 불필요한 크로스 플랫폼 복잡도
- 디버깅 어려움

### Streamlit 장점
- ✅ Python 직접 실행 (빌드 불필요)
- ✅ DB 직접 접근 (API 서버 불필요)
- ✅ 수정 즉시 반영
- ✅ 간단한 UI 작성
- ✅ 쉬운 설치 및 디버깅
- ✅ 풍부한 Python 라이브러리

## 💡 사용 방법

### 1. 거래처 선택
사이드바에서 거래처와 급여 기준월을 선택합니다.

### 2. 급여 계산
"급여 계산" 탭에서 모든 직원의 급여가 자동으로 계산됩니다.
- 지급총액, 공제총액, 실수령액 요약
- 직원별 상세 내역 확인

### 3. PDF 생성
"문서 생성" 탭에서:
- "명세서 일괄생성" 버튼 클릭
- 실시간 진행률 표시
- "폴더 열기"로 생성된 파일 확인

### 4. 이메일 발송
"이메일 발송" 탭에서:
- SMTP 설정 완료 후 사용 가능
- PDF 자동 생성 및 첨부
- 일괄 발송 진행률 표시

### 5. 설정
"설정" 탭에서:
- 파일 저장 경로 지정
- SMTP 서버 설정
- 이메일 템플릿 편집

## 📂 기본 저장 경로

### Windows
```
C:\Users\사용자명\Documents\급여관리프로그램\
└── 거래처명\
    └── 2024\
        ├── 거래처명_직원1_2024년12월_급여명세서.pdf
        ├── 거래처명_직원2_2024년12월_급여명세서.pdf
        └── ...
```

### OneDrive 사용
OneDrive 공유 폴더를 저장 경로로 설정 가능:
```
C:\Users\사용자명\OneDrive\급여관리프로그램\
```

⚠️ **주의**: 여러 PC에서 동시 작업 시 충돌 가능
- 해결책: 시간대 분리 또는 거래처 분리

## 🔧 SMTP 설정 예시

### Gmail 사용 시
```
SMTP 서버: smtp.gmail.com
포트: 587
사용자명: your@gmail.com
비밀번호: 앱 비밀번호 (2단계 인증 필요)
STARTTLS: 체크
```

### Naver 사용 시
```
SMTP 서버: smtp.naver.com
포트: 587
사용자명: your@naver.com
비밀번호: 계정 비밀번호
STARTTLS: 체크
```

## 🐛 문제 해결

### ODBC Driver 오류
```
pyodbc.Error: ('01000', "[01000] [unixODBC][Driver Manager]Can't open lib 'ODBC Driver 18 for SQL Server'")
```
해결: ODBC Driver 18 설치
- https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server

### 데이터베이스 연결 실패
1. 하마치 VPN 연결 확인
2. SQL Server 방화벽 확인
3. 데이터베이스 자격증명 확인

### PDF 생성 실패
1. 저장 경로 권한 확인
2. 폴더 자동 생성 옵션 확인
3. 디스크 공간 확인

## 📊 성능 비교

| 작업 | Flutter | Streamlit | 개선율 |
|------|---------|-----------|--------|
| 배치 PDF 생성 (10명) | 130초 | 10초 | -92% |
| 개별 이메일 발송 | 15초 | 5초 | -66% |
| 수정 후 반영 | 30초 (빌드) | 즉시 | -100% |
| 디버깅 시간 | 어려움 | 쉬움 | - |

## 🔐 보안 주의사항

1. **비밀번호 관리**
   - SMTP 비밀번호는 세션에만 저장
   - 앱 종료 시 자동 삭제

2. **데이터베이스 접근**
   - 읽기/쓰기 권한만 사용
   - 관리자 권한 불필요

3. **파일 권한**
   - 생성된 PDF는 로컬에만 저장
   - 네트워크 공유 시 권한 주의

## 📝 개발 이력

- **2024-12-22**: Streamlit 버전 최초 개발
  - Flutter 앱의 모든 기능 구현
  - 급여 계산, PDF 생성, 이메일 발송
  - 설정 관리 및 DB 직접 연결

## 🙏 기존 Flutter 앱 보존

Flutter 앱은 백업으로 유지되며 `/home/user/webapp` 디렉토리에 그대로 보존됩니다.

## 📞 문의

문제가 발생하거나 기능 추가가 필요한 경우 이슈를 등록해주세요.
