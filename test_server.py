#!/usr/bin/env python3
"""
서버 API 테스트 스크립트
모든 주요 엔드포인트를 테스트하고 결과를 출력
"""
import requests
import json
from datetime import datetime

BASE_URL = "http://25.2.89.129:8000"
API_KEY = ""

def make_headers():
    headers = {"Content-Type": "application/json"}
    if API_KEY:
        headers["X-API-Key"] = API_KEY
    return headers

def test_health():
    """Health check 테스트"""
    print("\n[1] Health Check")
    print("-" * 60)
    try:
        response = requests.get(f"{BASE_URL}/health", headers=make_headers(), timeout=5)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 서버 상태: OK")
            print(f"   DB 연결: {'✅' if data.get('db') else '❌'}")
        else:
            print(f"❌ 실패: {response.text}")
    except Exception as e:
        print(f"❌ 에러: {e}")

def test_app_settings():
    """앱 설정 테스트"""
    print("\n[2] App Settings")
    print("-" * 60)
    try:
        response = requests.get(f"{BASE_URL}/app/settings", headers=make_headers(), timeout=5)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 앱 설정 조회 성공")
            print(f"   ServerUrl: {data.get('serverUrl')}")
            print(f"   ApiKey: {data.get('apiKey', '(없음)')}")
        elif response.status_code == 404:
            print(f"⚠️  설정 없음 - init_db.py 실행 필요")
        else:
            print(f"❌ 실패: {response.text}")
    except Exception as e:
        print(f"❌ 에러: {e}")

def test_smtp_config():
    """SMTP 설정 테스트"""
    print("\n[3] SMTP Config")
    print("-" * 60)
    try:
        response = requests.get(f"{BASE_URL}/smtp/config", headers=make_headers(), timeout=5)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ SMTP 설정 조회 성공")
            print(f"   Host: {data.get('host')}")
            print(f"   Port: {data.get('port')}")
            print(f"   Username: {data.get('username', '(없음)')}")
            print(f"   UseSSL: {data.get('useSSL')}")
        elif response.status_code == 404:
            print(f"⚠️  설정 없음 - init_db.py 실행 필요")
        else:
            print(f"❌ 실패: {response.text}")
    except Exception as e:
        print(f"❌ 에러: {e}")

def test_clients():
    """거래처 목록 테스트"""
    print("\n[4] Clients List")
    print("-" * 60)
    try:
        response = requests.get(f"{BASE_URL}/clients", headers=make_headers(), timeout=5)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 거래처 목록 조회 성공")
            print(f"   총 거래처 수: {len(data)}")
            if data:
                for i, client in enumerate(data[:3], 1):  # 상위 3개만 표시
                    print(f"   [{i}] {client.get('name')} (ID: {client.get('id')})")
        else:
            print(f"❌ 실패: {response.text}")
    except Exception as e:
        print(f"❌ 에러: {e}")

def test_routes():
    """라우트 목록 테스트"""
    print("\n[5] Available Routes")
    print("-" * 60)
    try:
        response = requests.get(f"{BASE_URL}/_routes", headers=make_headers(), timeout=5)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 등록된 엔드포인트: {len(data)}개")
            
            # 카테고리별 분류
            categories = {}
            for route in data:
                path = route['path']
                method = route['method']
                
                if '/clients' in path:
                    cat = 'Clients'
                elif '/employees' in path:
                    cat = 'Employees'
                elif '/payroll' in path:
                    cat = 'Payroll'
                elif '/logs' in path:
                    cat = 'Logs'
                elif '/smtp' in path or '/app' in path:
                    cat = 'Settings'
                elif '/allowance' in path or '/deduction' in path:
                    cat = 'Masters'
                else:
                    cat = 'Others'
                
                if cat not in categories:
                    categories[cat] = []
                categories[cat].append(f"{method:6s} {path}")
            
            for cat, routes in sorted(categories.items()):
                print(f"\n   📁 {cat} ({len(routes)}개)")
                for route in sorted(routes)[:5]:  # 상위 5개만
                    print(f"      {route}")
        else:
            print(f"❌ 실패: {response.text}")
    except Exception as e:
        print(f"❌ 에러: {e}")

def main():
    print("=" * 60)
    print("🧪 서버 API 테스트")
    print(f"   Base URL: {BASE_URL}")
    print(f"   시작 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    test_health()
    test_app_settings()
    test_smtp_config()
    test_clients()
    test_routes()
    
    print("\n" + "=" * 60)
    print("✅ 테스트 완료")
    print("=" * 60)

if __name__ == "__main__":
    main()
