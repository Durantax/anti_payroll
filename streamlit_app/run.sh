#!/bin/bash

echo "================================"
echo "급여관리 프로그램 시작"
echo "================================"
echo ""

cd "$(dirname "$0")"

echo "Python 버전 확인..."
python3 --version
echo ""

echo "패키지 확인..."
if ! python3 -c "import streamlit" 2>/dev/null; then
    echo "Streamlit이 설치되지 않았습니다. 설치를 시작합니다..."
    pip3 install -r requirements.txt
fi

echo ""
echo "애플리케이션을 시작합니다..."
echo "브라우저가 자동으로 열립니다. (http://localhost:8501)"
echo ""
echo "종료하려면 Ctrl+C를 누르세요."
echo ""

streamlit run app.py
