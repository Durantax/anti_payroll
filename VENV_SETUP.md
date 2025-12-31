# Python 가상환경 설정 가이드

## 🎯 가상환경 사용 이유

- 프로젝트별 독립적인 패키지 관리
- 시스템 Python 환경 보호
- requirements.txt로 패키지 버전 고정
- 다른 개발자와 동일한 환경 공유

---

## 🚀 빠른 시작 (3단계)

### 1단계: 가상환경 생성

```bash
cd C:\work\payroll

# 가상환경 생성 (최초 1회만)
python -m venv venv
```

**예상 출력:**
```
(없음 - 조용히 완료됨)
```

**생성 확인:**
```bash
dir venv
```

**예상 출력:**
```
 디렉터리: C:\work\payroll\venv

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d-----        2025-12-31   오후 2:30                Include
d-----        2025-12-31   오후 2:30                Lib
d-----        2025-12-31   오후 2:30                Scripts
-a----        2025-12-31   오후 2:30            119 pyvenv.cfg
```

---

### 2단계: 가상환경 활성화

```bash
# Windows PowerShell
.\venv\Scripts\Activate.ps1

# Windows CMD
venv\Scripts\activate.bat
```

**성공 시 프롬프트 변경:**
```
(venv) PS C:\work\payroll>
```

**⚠️ PowerShell 실행 정책 에러 발생 시:**
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

그 후 다시:
```bash
.\venv\Scripts\Activate.ps1
```

---

### 3단계: 패키지 설치

```bash
# 가상환경 활성화 상태에서
pip install -r requirements.txt
```

**예상 출력:**
```
Collecting fastapi==0.109.0
  Downloading fastapi-0.109.0-py3-none-any.whl (92 kB)
Collecting uvicorn[standard]==0.27.0
  Downloading uvicorn-0.27.0-py3-none-any.whl (60 kB)
Collecting pyodbc==5.0.1
  Downloading pyodbc-5.0.1-cp311-cp311-win_amd64.whl (66 kB)
...
Successfully installed fastapi-0.109.0 uvicorn-0.27.0 pyodbc-5.0.1 ...
```

---

## 📋 일상적인 사용

### 서버 시작 (매번)

```bash
# 1. 가상환경 활성화
cd C:\work\payroll
.\venv\Scripts\Activate.ps1

# 2. 서버 실행
(venv) python server.py
```

### 가상환경 비활성화

```bash
deactivate
```

---

## 🔧 문제 해결

### 문제 1: "Activate.ps1을 로드할 수 없습니다"

**에러:**
```
.\venv\Scripts\Activate.ps1 : 이 시스템에서 스크립트를 실행할 수 없으므로...
```

**해결:**
```bash
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### 문제 2: pip 업그레이드 경고

**경고:**
```
WARNING: You are using pip version 21.x.x; however, version 24.x.x is available.
```

**해결 (선택사항):**
```bash
python -m pip install --upgrade pip
```

---

### 문제 3: pyodbc 설치 실패

**에러:**
```
ERROR: Could not find a version that satisfies the requirement pyodbc
```

**해결:**

1. **Visual C++ 재배포 패키지 설치**
   - https://aka.ms/vs/17/release/vc_redist.x64.exe
   - 다운로드 후 설치

2. **다시 시도:**
   ```bash
   pip install pyodbc
   ```

---

## 📝 .gitignore 설정

`.gitignore`에 이미 추가되어 있습니다:

```gitignore
# Python virtual environment
venv/
env/
ENV/
.venv/
*.pyc
__pycache__/
*.pyo
*.pyd
.Python
```

**확인:**
```bash
git status
```

**예상 출력 (venv 폴더 없어야 함):**
```
On branch genspark_ai_developer
nothing to commit, working tree clean
```

---

## 🎯 완전한 워크플로우

### 최초 설정 (1회만)

```bash
cd C:\work\payroll

# 1. 가상환경 생성
python -m venv venv

# 2. 활성화
.\venv\Scripts\Activate.ps1

# 3. 패키지 설치
pip install -r requirements.txt

# 4. DB 초기화
python init_db.py
```

### 매일 작업

```bash
cd C:\work\payroll

# 1. 최신 코드 가져오기
git pull origin genspark_ai_developer

# 2. 가상환경 활성화
.\venv\Scripts\Activate.ps1

# 3. 서버 실행
python server.py
```

### 새 터미널에서 (테스트/Flutter)

```bash
cd C:\work\payroll

# 1. 가상환경 활성화
.\venv\Scripts\Activate.ps1

# 2. 테스트
python test_server.py

# 3. Flutter (가상환경 필요 없음)
flutter run -d windows
```

---

## 🌟 Pro Tips

### Tip 1: 가상환경 자동 활성화

**PowerShell 프로필 설정:**

```bash
# 프로필 열기
notepad $PROFILE
```

**추가:**
```powershell
function payroll {
    cd C:\work\payroll
    .\venv\Scripts\Activate.ps1
}
```

**사용:**
```bash
payroll  # 자동으로 이동 + 활성화
```

---

### Tip 2: requirements.txt 업데이트

**새 패키지 설치 후:**
```bash
pip freeze > requirements.txt
```

**⚠️ 주의:** 불필요한 패키지까지 포함될 수 있으므로 수동으로 정리 권장

---

### Tip 3: 가상환경 재생성

**문제가 있을 때:**
```bash
# 1. 가상환경 삭제
deactivate
rmdir /s venv

# 2. 재생성
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

---

## ✅ 체크리스트

설정 완료 확인:

- [ ] `python -m venv venv` 실행
- [ ] `.\venv\Scripts\Activate.ps1` 실행
- [ ] 프롬프트에 `(venv)` 표시됨
- [ ] `pip install -r requirements.txt` 실행
- [ ] `python server.py` 정상 실행
- [ ] `git status`에 venv 폴더 없음

---

## 📊 설치된 패키지 확인

```bash
# 가상환경 활성화 상태에서
pip list
```

**예상 출력:**
```
Package            Version
------------------ -------
fastapi            0.109.0
uvicorn            0.27.0
pyodbc             5.0.1
requests           2.31.0
pydantic           2.5.3
...
```

---

## 🔗 관련 문서

- [RUN_SERVER.md](./RUN_SERVER.md) - 서버 실행 가이드
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - 문제 해결
- [requirements.txt](./requirements.txt) - 패키지 목록

---

**작성일:** 2025-12-31  
**버전:** 1.0
