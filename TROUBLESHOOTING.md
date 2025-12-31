# 문제 해결 가이드 (Troubleshooting)

## 🚨 현재 발생한 문제

### 증상 1: 서버 500 에러
```
[2] App Settings
Status: 500
❌ 실패: Internal Server Error

[3] SMTP Config
Status: 500
❌ 실패: Internal Server Error
```

### 증상 2: Flutter null check 에러
```
Null check operator used on a null value
```

---

## ✅ 해결 방법

### 1단계: 서버 중지

**Ctrl+C를 눌러서 실행 중인 server.py를 중지하세요.**

```
INFO:     Shutting down
INFO:     Finished server process
```

---

### 2단계: 최신 코드 확인

```bash
cd C:\work\payroll
git status
git log --oneline -5
```

**예상 출력:**
```
On branch genspark_ai_developer
Your branch is up to date with 'origin/genspark_ai_developer'.

6a3d42d docs: Add final completion report
b8343f5 fix: Improve error handling and null safety
3679126 docs: Add comprehensive testing and status documentation
c13e661 fix(server): Fix MERGE statements for AppSettings and SmtpConfig
b638800 feat: Complete server.py v3.0.0 with all Flutter API endpoints
```

**최신 커밋이 `6a3d42d`여야 합니다!**

만약 다르다면:
```bash
git pull origin genspark_ai_developer
```

---

### 3단계: DB 초기화 (최초 1회만)

```bash
python init_db.py
```

**예상 출력:**
```
============================================================
DB 초기화 시작
============================================================

[1] AppSettings 테이블 확인...
   ✅ AppSettings 삽입 완료
   (또는)
   ℹ️  AppSettings 데이터가 이미 존재합니다.

[2] SmtpConfig 테이블 확인...
   ✅ SmtpConfig 삽입 완료
   (또는)
   ℹ️  SmtpConfig 데이터가 이미 존재합니다.

============================================================
✅ DB 초기화 완료!
============================================================
```

**만약 에러 발생 시:**
```
❌ DB 연결 실패: [에러 메시지]
```

→ Hamachi VPN 연결 확인
→ SQL Server 실행 확인

---

### 4단계: 서버 재시작

```bash
python server.py
```

**예상 출력:**
```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

---

### 5단계: 서버 테스트

**새 터미널(PowerShell)을 열어서:**

```bash
cd C:\work\payroll
python test_server.py
```

**예상 출력 (모든 항목 ✅):**
```
============================================================
🧪 서버 API 테스트
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
   총 거래처 수: 16

[5] Available Routes
------------------------------------------------------------
Status: 200
✅ 등록된 엔드포인트: 45개
```

---

### 6단계: Flutter 앱 실행

```bash
flutter run -d windows
```

**예상 결과:**
- ✅ 빌드 성공
- ✅ 앱 시작 (에러 없음)
- ✅ 거래처 목록 표시
- ✅ null check 에러 없음

---

## 🔍 여전히 문제가 있다면?

### 문제 A: init_db.py 에러

**증상:**
```
❌ DB 연결 실패
```

**원인 및 해결:**

1. **Hamachi VPN 연결 확인**
   ```bash
   ping 25.2.89.129
   ```
   - 타임아웃 발생 → Hamachi 재연결

2. **SQL Server 실행 확인**
   - Windows 서비스에서 "SQL Server (SQLEXPRESS)" 확인
   - 중지됨 → 시작

3. **방화벽 확인**
   - 포트 1433 허용 확인

---

### 문제 B: 서버 500 에러 계속 발생

**증상:**
```
[2] App Settings
Status: 500
```

**원인:**
- 서버가 최신 코드를 반영하지 않음

**해결:**
```bash
# 1. 서버 중지 (Ctrl+C)
# 2. Python 프로세스 강제 종료 (필요 시)
taskkill /F /IM python.exe

# 3. 서버 재시작
python server.py
```

---

### 문제 C: Flutter null check 에러

**증상:**
```
Null check operator used on a null value
```

**원인:**
- Flutter 앱이 최신 코드를 반영하지 않음

**해결:**
```bash
# 1. 앱 중지 (Ctrl+C 또는 창 닫기)

# 2. 클린 빌드
flutter clean
flutter pub get

# 3. 재실행
flutter run -d windows
```

---

### 문제 D: 404 에러 - 발송 상태

**증상:**
```
발송 상태 조회 실패: 404
```

**원인:**
- 해당 거래처/연월에 발송 로그가 없음

**해결:**
- **정상 동작입니다!**
- 발송 이력이 없으면 404 반환
- Flutter 앱에서 빈 상태로 표시됨

---

## 📋 체크리스트

서버 재시작 전:

- [ ] `git pull origin genspark_ai_developer` 실행
- [ ] 최신 커밋 확인 (6a3d42d)
- [ ] server.py 중지 (Ctrl+C)
- [ ] `python init_db.py` 실행
- [ ] 출력에서 ✅ 또는 ℹ️ 확인

서버 재시작 후:

- [ ] `python server.py` 실행
- [ ] "Uvicorn running" 메시지 확인
- [ ] 새 터미널에서 `python test_server.py` 실행
- [ ] 모든 항목 ✅ 확인

Flutter 앱:

- [ ] `flutter clean && flutter pub get` 실행
- [ ] `flutter run -d windows` 실행
- [ ] 에러 없이 시작 확인
- [ ] 거래처 선택 시 정상 작동 확인

---

## 🆘 긴급 문제 해결

### 모든 방법이 실패했다면?

1. **Python 프로세스 모두 종료**
   ```bash
   taskkill /F /IM python.exe
   ```

2. **Git 상태 확인**
   ```bash
   git status
   git log --oneline -1
   ```

3. **강제로 최신 코드 가져오기**
   ```bash
   git fetch origin genspark_ai_developer
   git reset --hard origin/genspark_ai_developer
   ```

4. **다시 시작**
   ```bash
   python init_db.py
   python server.py
   ```

---

## 📞 추가 지원

### 로그 확인

**서버 로그:**
- server.py 실행 중인 터미널 확인
- 에러 메시지 복사

**Flutter 로그:**
- Debug Console 확인
- 빨간색 에러 메시지 복사

### 문서 참조

- [RUN_SERVER.md](./RUN_SERVER.md) - 서버 실행 가이드
- [TESTING_GUIDE.md](./TESTING_GUIDE.md) - 테스트 절차
- [FINAL_STATUS.md](./FINAL_STATUS.md) - 최종 상태

---

## ✅ 성공 확인

모든 것이 정상이면:

```bash
# 서버 테스트
python test_server.py
→ 모든 항목 ✅

# Flutter 앱
flutter run -d windows
→ 에러 없이 시작
→ 거래처 목록 표시
→ 직원 목록 표시
```

**완료!** 🎉

---

**작성일:** 2025-12-31  
**버전:** 1.0
