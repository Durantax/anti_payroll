@echo off
echo ================================
echo 급여관리 프로그램 시작
echo ================================
echo.

cd /d "%~dp0"

echo Python 버전 확인...
python --version
echo.

echo 패키지 확인...
pip show streamlit >nul 2>&1
if errorlevel 1 (
    echo Streamlit이 설치되지 않았습니다. 설치를 시작합니다...
    pip install -r requirements.txt
)

echo.
echo 애플리케이션을 시작합니다...
echo 브라우저가 자동으로 열립니다. (http://localhost:8501)
echo.
echo 종료하려면 Ctrl+C를 누르세요.
echo.

streamlit run app.py

pause
