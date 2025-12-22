"""
급여관리 프로그램 - Streamlit 완전판
Flutter 앱의 모든 기능을 Streamlit으로 구현
"""
import streamlit as st
import pandas as pd
from datetime import datetime
import os
import subprocess
import platform
from pathlib import Path

# 페이지 설정
st.set_page_config(
    page_title="급여관리 프로그램",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="expanded"
)

# 모듈 임포트
from database import get_db_connection, fetch_all, fetch_one, execute_query
from payroll_calculator import PayrollCalculator
from pdf_generator import generate_payslip_pdf, generate_batch_pdfs
from email_service import EmailService

# CSS 스타일 (Flutter UI 스타일)
st.markdown("""
<style>
    /* 전체 레이아웃 */
    .main {
        background-color: #f5f7fa;
    }
    
    /* 헤더 */
    .main-header {
        font-size: 2rem;
        font-weight: 600;
        color: #2c3e50;
        margin-bottom: 1.5rem;
        padding: 1rem 0;
        border-bottom: 2px solid #3498db;
    }
    
    /* 카드 스타일 */
    .metric-card {
        background: white;
        padding: 1.5rem;
        border-radius: 12px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        margin: 1rem 0;
        border-left: 4px solid #3498db;
    }
    
    /* 직원 카드 */
    .employee-card {
        background: white;
        padding: 1.2rem;
        border-radius: 10px;
        box-shadow: 0 1px 4px rgba(0,0,0,0.08);
        margin: 0.8rem 0;
        border-left: 3px solid #2ecc71;
        transition: all 0.2s;
    }
    
    .employee-card:hover {
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        transform: translateY(-2px);
    }
    
    /* 급여 결과 카드 */
    .salary-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 1.5rem;
        border-radius: 12px;
        margin: 0.8rem 0;
        box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
    }
    
    /* 테이블 스타일 */
    .dataframe {
        border-radius: 8px !important;
        overflow: hidden;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    
    .dataframe thead tr {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white !important;
    }
    
    .dataframe tbody tr:nth-child(even) {
        background-color: #f8f9fa;
    }
    
    .dataframe tbody tr:hover {
        background-color: #e3f2fd;
    }
    
    /* 버튼 스타일 */
    .stButton > button {
        border-radius: 8px;
        padding: 0.6rem 1.5rem;
        font-weight: 500;
        transition: all 0.3s;
        border: none;
        box-shadow: 0 2px 6px rgba(0,0,0,0.15);
    }
    
    .stButton > button:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.25);
    }
    
    /* 성공/오류 메시지 */
    .success-message {
        background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        color: white;
        padding: 1rem 1.5rem;
        border-radius: 8px;
        margin: 1rem 0;
        box-shadow: 0 2px 8px rgba(17, 153, 142, 0.3);
    }
    
    .error-message {
        background: linear-gradient(135deg, #ee0979 0%, #ff6a00 100%);
        color: white;
        padding: 1rem 1.5rem;
        border-radius: 8px;
        margin: 1rem 0;
        box-shadow: 0 2px 8px rgba(238, 9, 121, 0.3);
    }
    
    /* 탭 스타일 */
    .stTabs [data-baseweb="tab-list"] {
        gap: 8px;
        background-color: white;
        padding: 0.5rem;
        border-radius: 10px;
        box-shadow: 0 2px 6px rgba(0,0,0,0.08);
    }
    
    .stTabs [data-baseweb="tab"] {
        border-radius: 8px;
        padding: 0.8rem 1.5rem;
        font-weight: 500;
        transition: all 0.2s;
    }
    
    .stTabs [aria-selected="true"] {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
    }
    
    /* 입력 필드 */
    .stTextInput > div > div > input,
    .stNumberInput > div > div > input,
    .stSelectbox > div > div > select {
        border-radius: 8px;
        border: 2px solid #e0e6ed;
        padding: 0.6rem 1rem;
        transition: all 0.2s;
    }
    
    .stTextInput > div > div > input:focus,
    .stNumberInput > div > div > input:focus {
        border-color: #667eea;
        box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
    }
    
    /* 프로그레스 바 */
    .stProgress > div > div > div {
        background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
        border-radius: 10px;
    }
    
    /* 사이드바 */
    .css-1d391kg {
        background-color: #2c3e50;
    }
    
    /* 확장 가능한 섹션 */
    .streamlit-expanderHeader {
        background-color: white;
        border-radius: 8px;
        font-weight: 500;
    }
</style>
""", unsafe_allow_html=True)

# 세션 상태 초기화
if 'selected_client_id' not in st.session_state:
    st.session_state.selected_client_id = None
if 'selected_year' not in st.session_state:
    st.session_state.selected_year = datetime.now().year
if 'selected_month' not in st.session_state:
    st.session_state.selected_month = datetime.now().month
if 'download_base_path' not in st.session_state:
    # 기본 저장 경로
    if os.name == 'nt':  # Windows
        default_path = os.path.join(os.environ.get('USERPROFILE', 'C:\\'), 
                                    'Documents', '급여관리프로그램')
    else:
        default_path = os.path.join(os.environ.get('HOME', '/home/user'), 
                                    'Documents', '급여관리프로그램')
    st.session_state.download_base_path = default_path
if 'use_client_subfolders' not in st.session_state:
    st.session_state.use_client_subfolders = True
if 'smtp_settings' not in st.session_state:
    st.session_state.smtp_settings = {
        'host': '',
        'port': 587,
        'user': '',
        'password': '',
        'use_tls': True,
        'use_ssl': False
    }
if 'email_templates' not in st.session_state:
    st.session_state.email_templates = {
        'subject': '{year}년 {month}월 급여명세서 - {name}님',
        'body': '''안녕하세요, {name}님

{client} 사업장의 {year}년 {month}월 급여명세서를 첨부하여 보내드립니다.

확인 후 문의사항이 있으시면 연락 주시기 바랍니다.

감사합니다.
{client} 드림'''
    }


def format_money(amount):
    """금액 포맷팅"""
    if amount is None:
        return "0"
    return f"{int(amount):,}"


def load_clients():
    """거래처 목록 로드"""
    try:
        sql = """
            SELECT 
                ID as Id, 
                고객명 as Name, 
                사업자등록번호 as BizId,
                1 as Has5OrMoreWorkers
            FROM 거래처 
            WHERE 사용여부 IN ('O', 1)
            ORDER BY 고객명
        """
        clients = fetch_all(sql)
        
        if not clients:
            st.warning("⚠️ 등록된 거래처가 없습니다.")
            st.info("💡 'database_perfect.py' 프로그램에서 거래처를 먼저 등록하세요.")
        
        return clients
        
    except Exception as e:
        error_msg = str(e)
        if "거래처" in error_msg or "개체 이름" in error_msg:
            st.error("❌ '거래처' 테이블을 찾을 수 없습니다.")
            st.info("""
            💡 해결 방법:
            1. 'database_perfect.py' 프로그램이 사용하는 데이터베이스인지 확인
            2. '거래처' 테이블이 생성되어 있는지 확인
            3. 데이터베이스 연결 정보가 올바른지 확인 (서버: 25.2.89.129, DB: 기본정보)
            """)
        else:
            st.error(f"❌ 거래처 목록 로드 실패: {error_msg}")
        
        return []


def load_workers(client_id, year, month):
    """직원 목록 로드 (실제 DB 스키마 완전 반영)"""
    ym = f"{year:04d}-{month:02d}"
    sql = """
        SELECT 
            e.EmployeeId as Id,
            e.ClientId,
            e.Name,
            e.BirthDate,
            e.EmploymentType,
            e.SalaryType,
            e.BaseSalary as MonthlySalary,
            e.HourlyRate,
            e.NormalHours,
            e.FoodAllowance,
            e.CarAllowance,
            e.HasNationalPension,
            e.HasHealthInsurance,
            e.HasEmploymentInsurance,
            e.TaxDependents,
            e.ChildrenCount,
            e.IncomeTaxRate,
            e.TaxFreeMeal,
            e.TaxFreeCarMaintenance,
            e.OtherTaxFree,
            e.EmailTo,
            e.EmailCc,
            e.UseEmail,
            m.WorkHours as NormalWorkHours,
            m.OvertimeHours,
            m.NightHours,
            m.HolidayHours,
            m.WeeklyHours,
            m.WeekCount,
            m.Bonus,
            m.ExtraAllowance,
            m.ExtraDeduction,
            m.Memo
        FROM dbo.Employees e
        LEFT JOIN dbo.PayrollMonthlyInput m 
            ON e.EmployeeId = m.EmployeeId AND m.Ym = ?
        WHERE e.ClientId = ?
        ORDER BY e.Name
    """
    workers = fetch_all(sql, (ym, client_id))
    
    # None 값을 0으로 변환 및 기본값 설정
    for worker in workers:
        # 급여 계산에 필요한 필드
        for key in ['NormalHours', 'NormalWorkHours', 'OvertimeHours', 'NightHours', 
                    'HolidayHours', 'WeeklyHours', 'WeekCount', 'Bonus',
                    'MonthlySalary', 'HourlyRate', 'FoodAllowance', 'CarAllowance',
                    'TaxDependents', 'ChildrenCount', 'IncomeTaxRate',
                    'TaxFreeMeal', 'TaxFreeCarMaintenance', 'OtherTaxFree',
                    'ExtraAllowance', 'ExtraDeduction']:
            if worker.get(key) is None:
                worker[key] = 0
        
        # EmploymentType 기본값 (빈 문자열이면 REGULAR로 설정)
        if not worker.get('EmploymentType') or worker.get('EmploymentType').strip() == '':
            worker['EmploymentType'] = 'REGULAR'
        
        # SalaryType 기본값
        if not worker.get('SalaryType') or worker.get('SalaryType').strip() == '':
            worker['SalaryType'] = 'MONTHLY'
        
        # WeeklyHours 기본값
        if worker.get('WeeklyHours') == 0:
            worker['WeeklyHours'] = 40.0
        
        # 4대보험 기본값 (없으면 True)
        for key in ['HasNationalPension', 'HasHealthInsurance', 'HasEmploymentInsurance']:
            if worker.get(key) is None:
                worker[key] = True
        
        # 이메일 기본값
        if worker.get('UseEmail') is None:
            worker['UseEmail'] = False
        if worker.get('EmailTo') is None:
            worker['EmailTo'] = ''
        if worker.get('EmailCc') is None:
            worker['EmailCc'] = ''
        if worker.get('Memo') is None:
            worker['Memo'] = ''
        
        # Phone 필드는 DB에 없으므로 기본값
        worker.setdefault('Phone', '')
        
        # AdditionalPay/Deduct는 ExtraAllowance/ExtraDeduction으로 매핑
        worker['AdditionalPay1'] = worker.get('ExtraAllowance', 0)
        worker['AdditionalPay2'] = 0
        worker['AdditionalPay3'] = 0
        worker['AdditionalDeduct1'] = worker.get('ExtraDeduction', 0)
        worker['AdditionalDeduct2'] = 0
        worker['AdditionalDeduct3'] = 0
    
    return workers


def calculate_all_salaries(workers, client_has_5_or_more):
    """모든 직원 급여 계산"""
    results = []
    
    for worker in workers:
        try:
            calculator = PayrollCalculator(worker, worker, client_has_5_or_more)
            result = calculator.calculate()
            result['worker_id'] = worker['Id']
            results.append(result)
        except Exception as e:
            st.error(f"❌ {worker.get('Name', '알 수 없음')} 급여 계산 실패: {e}")
    
    return results


def open_folder(path):
    """폴더 열기 (OS별 처리)"""
    if not os.path.exists(path):
        st.error(f"❌ 폴더가 존재하지 않습니다: {path}")
        return False
    
    try:
        if platform.system() == 'Windows':
            os.startfile(path)
        elif platform.system() == 'Darwin':  # macOS
            subprocess.Popen(['open', path])
        else:  # Linux
            subprocess.Popen(['xdg-open', path])
        return True
    except Exception as e:
        st.error(f"❌ 폴더 열기 실패: {e}")
        return False


def main():
    """메인 함수"""
    
    # 타이틀
    st.markdown('<div class="main-header">💰 급여관리 프로그램</div>', unsafe_allow_html=True)
    
    # DB 연결 확인
    conn = get_db_connection()
    if not conn:
        st.error("❌ 데이터베이스에 연결할 수 없습니다. 서버 설정을 확인하세요.")
        st.info("💡 설정 탭에서 '데이터베이스 연결 진단' 기능을 사용하세요.")
        return
    
    # 사이드바: 거래처 선택 및 날짜 설정
    with st.sidebar:
        st.header("📋 설정")
        
        # 거래처 선택
        clients = load_clients()
        if not clients:
            st.warning("⚠️ 등록된 거래처가 없습니다.")
            return
        
        client_names = {c['Name']: c for c in clients}
        selected_client_name = st.selectbox(
            "거래처 선택",
            options=list(client_names.keys()),
            key='client_selector'
        )
        
        if selected_client_name:
            selected_client = client_names[selected_client_name]
            st.session_state.selected_client_id = selected_client['Id']
            
            # 거래처 정보 표시
            st.info(f"📌 사업자번호: {selected_client['BizId']}\n\n"
                   f"👥 5인 이상: {'예' if selected_client['Has5OrMoreWorkers'] else '아니오'}")
        
        st.divider()
        
        # 날짜 선택
        st.subheader("📅 급여 기준월")
        col1, col2 = st.columns(2)
        
        with col1:
            year = st.number_input("연도", 
                                  min_value=2020, 
                                  max_value=2030, 
                                  value=st.session_state.selected_year,
                                  key='year_input')
            st.session_state.selected_year = year
        
        with col2:
            month = st.number_input("월", 
                                   min_value=1, 
                                   max_value=12, 
                                   value=st.session_state.selected_month,
                                   key='month_input')
            st.session_state.selected_month = month
        
        st.divider()
        
        # 새로고침 버튼
        if st.button("🔄 새로고침", use_container_width=True):
            st.rerun()
    
    # 메인 영역
    if not st.session_state.selected_client_id:
        st.info("👈 사이드바에서 거래처를 선택하세요.")
        return
    
    # 직원 데이터 로드
    workers = load_workers(
        st.session_state.selected_client_id,
        st.session_state.selected_year,
        st.session_state.selected_month
    )
    
    if not workers:
        st.warning(f"⚠️ {selected_client_name}에 등록된 직원이 없습니다.")
        
        if st.button("➕ 직원 추가"):
            st.info("직원 추가 기능은 '직원 관리' 탭에서 사용할 수 있습니다.")
        return
    
    # 탭 구성
    tab1, tab2, tab3, tab4, tab5, tab6 = st.tabs([
        "📊 급여 계산",
        "📝 월별 데이터 입력",
        "👥 직원 관리", 
        "📄 문서 생성",
        "📧 이메일 발송",
        "⚙️ 설정"
    ])
    
    # 탭 1: 급여 계산
    with tab1:
        show_payroll_calculation(workers, selected_client)
    
    # 탭 2: 월별 데이터 입력
    with tab2:
        show_monthly_data_input(workers, selected_client)
    
    # 탭 3: 직원 관리
    with tab3:
        show_employee_management(workers, selected_client)
    
    # 탭 4: 문서 생성
    with tab4:
        show_document_generation(workers, selected_client)
    
    # 탭 5: 이메일 발송
    with tab5:
        show_email_sending(workers, selected_client)
    
    # 탭 6: 설정
    with tab6:
        show_settings()


def show_payroll_calculation(workers, selected_client):
    """급여 계산 탭 (Flutter UI 스타일)"""
    st.markdown('<div class="main-header">📊 급여 계산 결과</div>', unsafe_allow_html=True)
    
    # 급여 계산
    client_has_5_or_more = selected_client['Has5OrMoreWorkers']
    salary_results = calculate_all_salaries(workers, client_has_5_or_more)
    
    if not salary_results:
        st.warning("⚠️ 계산 가능한 급여 데이터가 없습니다.")
        st.info("💡 '월별 데이터 입력' 탭에서 근무 시간을 입력하세요.")
        return
    
    # 요약 카드 (큰 카드 스타일)
    st.markdown("### 💼 급여 요약")
    total_payment = sum(r['total_payment'] for r in salary_results)
    total_deduction = sum(r['total_deduction'] for r in salary_results)
    total_net = sum(r['net_payment'] for r in salary_results)
    
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.markdown(f"""
        <div class="metric-card">
            <div style="color: #7f8c8d; font-size: 0.9rem; margin-bottom: 0.5rem;">직원 수</div>
            <div style="font-size: 2rem; font-weight: 600; color: #2c3e50;">{len(salary_results)}명</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown(f"""
        <div class="metric-card">
            <div style="color: #7f8c8d; font-size: 0.9rem; margin-bottom: 0.5rem;">💰 지급총액</div>
            <div style="font-size: 1.8rem; font-weight: 600; color: #27ae60;">{format_money(total_payment)}원</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown(f"""
        <div class="metric-card">
            <div style="color: #7f8c8d; font-size: 0.9rem; margin-bottom: 0.5rem;">➖ 공제총액</div>
            <div style="font-size: 1.8rem; font-weight: 600; color: #e74c3c;">-{format_money(total_deduction)}원</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown(f"""
        <div class="metric-card" style="border-left: 4px solid #3498db;">
            <div style="color: #7f8c8d; font-size: 0.9rem; margin-bottom: 0.5rem;">✅ 실수령액</div>
            <div style="font-size: 1.8rem; font-weight: 600; color: #3498db;">{format_money(total_net)}원</div>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # 직원별 카드 리스트
    st.markdown("### 👥 직원별 급여 내역")
    
    for idx, result in enumerate(salary_results):
        # 직원 카드
        st.markdown(f"""
        <div class="employee-card">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div style="flex: 1;">
                    <div style="font-size: 1.2rem; font-weight: 600; color: #2c3e50; margin-bottom: 0.3rem;">
                        👤 {result['worker_name']}
                    </div>
                    <div style="color: #7f8c8d; font-size: 0.9rem;">
                        {result['birth_date']} | {result['employment_type']}
                    </div>
                </div>
                <div style="text-align: right;">
                    <div style="color: #7f8c8d; font-size: 0.85rem;">실수령액</div>
                    <div style="font-size: 1.5rem; font-weight: 600; color: #3498db;">
                        {format_money(result['net_payment'])}원
                    </div>
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)
        
        # 확장 가능한 상세 내역
        with st.expander(f"📋 {result['worker_name']} 상세 내역 보기"):
            
            col1, col2 = st.columns(2)
            
            with col1:
                # 지급 항목
                st.markdown("#### 💰 지급 항목")
                pay_data = {
                    '기본급': result['base_salary'],
                    '연장수당': result['overtime_pay'],
                    '야간수당': result['night_pay'],
                    '휴일수당': result['holiday_pay'],
                    '주휴수당': result['weekly_holiday_pay'],
                    '상여금': result['bonus'],
                    '식대': result['food_allowance'],
                    '차량유지비': result['car_allowance'],
                }
                
                pay_df = pd.DataFrame([
                    {'항목': k, '금액': f"{format_money(v):>12}원"} 
                    for k, v in pay_data.items() if v > 0
                ])
                
                if not pay_df.empty:
                    st.dataframe(pay_df, use_container_width=True, hide_index=True)
                
                st.markdown(f"**총 지급액: `{format_money(result['total_payment'])}원`**")
            
            with col2:
                # 공제 항목
                st.markdown("#### ➖ 공제 항목")
                deduct_data = {
                    '국민연금': result['national_pension'],
                    '건강보험': result['health_insurance'],
                    '장기요양': result['long_term_care'],
                    '고용보험': result['employment_insurance'],
                    '소득세': result['income_tax'],
                    '지방소득세': result['local_income_tax'],
                }
                
                deduct_df = pd.DataFrame([
                    {'항목': k, '금액': f"{format_money(v):>12}원"} 
                    for k, v in deduct_data.items() if v > 0
                ])
                
                if not deduct_df.empty:
                    st.dataframe(deduct_df, use_container_width=True, hide_index=True)
                
                st.markdown(f"**총 공제액: `{format_money(result['total_deduction'])}원`**")
            
            # 실수령액 (강조)
            st.markdown("---")
            st.success(f"### ✅ 실수령액: **{format_money(result['net_payment'])}원**")


def show_monthly_data_input(workers, selected_client):
    """월별 데이터 입력 탭"""
    st.header("📝 월별 근무 데이터 입력")
    
    year = st.session_state.selected_year
    month = st.session_state.selected_month
    ym = f"{year:04d}-{month:02d}"
    
    if not workers:
        st.info("등록된 직원이 없습니다. '직원 관리' 탭에서 먼저 직원을 추가하세요.")
        return
    
    st.info(f"📅 {year}년 {month}월 근무 데이터를 입력하세요.")
    
    # 일괄 저장 버튼
    if st.button("💾 전체 저장", type="primary", use_container_width=True):
        saved_count = 0
        for worker in workers:
            if save_monthly_data_from_session(worker['Id'], ym):
                saved_count += 1
        st.success(f"✅ {saved_count}명의 데이터가 저장되었습니다!")
        st.rerun()
    
    st.divider()
    
    # 직원별 입력 폼
    for idx, worker in enumerate(workers):
        with st.expander(f"👤 {worker['Name']} ({worker['BirthDate']})", expanded=idx==0):
            
            # 세션 키 생성
            key_prefix = f"monthly_{worker['Id']}_"
            
            # 기본 정보 표시
            col1, col2, col3 = st.columns(3)
            with col1:
                st.text(f"급여형태: {worker.get('SalaryType', 'HOURLY')}")
            with col2:
                if worker.get('SalaryType') == 'MONTHLY':
                    st.text(f"월급: {format_money(worker.get('MonthlySalary', 0))}원")
                else:
                    st.text(f"시급: {format_money(worker.get('HourlyRate', 0))}원")
            with col3:
                st.text(f"고용형태: {worker.get('EmploymentType', 'REGULAR')}")
            
            st.divider()
            
            # 근무 시간
            st.write("**⏰ 근무 시간**")
            col1, col2 = st.columns(2)
            
            with col1:
                normal_hours = st.number_input(
                    "정상근로시간",
                    min_value=0.0,
                    value=float(worker.get('NormalHours', 0)),
                    step=0.5,
                    key=key_prefix + "normal_hours",
                    help="월 기본 근무 시간"
                )
                
                overtime_hours = st.number_input(
                    "연장시간 (5인 이상)",
                    min_value=0.0,
                    value=float(worker.get('OvertimeHours', 0)),
                    step=0.5,
                    key=key_prefix + "overtime_hours",
                    help="연장근로 시간 (1.5배)"
                )
                
                night_hours = st.number_input(
                    "야간시간 (5인 이상)",
                    min_value=0.0,
                    value=float(worker.get('NightHours', 0)),
                    step=0.5,
                    key=key_prefix + "night_hours",
                    help="야간근로 시간 (0.5배)"
                )
            
            with col2:
                holiday_hours = st.number_input(
                    "휴일시간 (5인 이상)",
                    min_value=0.0,
                    value=float(worker.get('HolidayHours', 0)),
                    step=0.5,
                    key=key_prefix + "holiday_hours",
                    help="휴일근로 시간 (1.5~2.0배)"
                )
                
                weekly_hours = st.number_input(
                    "주소정근로시간",
                    min_value=0.0,
                    max_value=80.0,
                    value=float(worker.get('WeeklyHours', 40.0)),
                    step=1.0,
                    key=key_prefix + "weekly_hours",
                    help="주당 소정근로시간 (주휴수당 계산 기준)"
                )
                
                week_count = st.number_input(
                    "개근주수",
                    min_value=0,
                    max_value=5,
                    value=int(worker.get('WeekCount', 4)),
                    step=1,
                    key=key_prefix + "week_count",
                    help="실제 근무한 주수 (주휴수당 계산)"
                )
            
            st.divider()
            
            # 입퇴사일
            st.write("**📅 입퇴사 정보**")
            col1, col2 = st.columns(2)
            
            with col1:
                hire_date = st.date_input(
                    "입사일",
                    value=worker.get('HireDate') if worker.get('HireDate') else None,
                    key=key_prefix + "hire_date",
                    help="직원 입사일 (필수)"
                )
            
            with col2:
                termination_date = st.date_input(
                    "퇴사일",
                    value=worker.get('TerminationDate') if worker.get('TerminationDate') else None,
                    key=key_prefix + "termination_date",
                    help="퇴사일 (재직 중이면 비워두세요)"
                )
            
            st.divider()
            
            # 추가 지급/공제
            st.write("**💰 추가 지급/공제**")
            col1, col2 = st.columns(2)
            
            with col1:
                st.write("**지급 항목**")
                
                bonus = st.number_input(
                    "상여금",
                    min_value=0,
                    value=int(worker.get('Bonus', 0)),
                    step=10000,
                    key=key_prefix + "bonus"
                )
                
                additional_pay1 = st.number_input(
                    "추가지급 1",
                    min_value=0,
                    value=int(worker.get('AdditionalPay1', 0)),
                    step=10000,
                    key=key_prefix + "additional_pay1"
                )
                
                additional_pay2 = st.number_input(
                    "추가지급 2",
                    min_value=0,
                    value=int(worker.get('AdditionalPay2', 0)),
                    step=10000,
                    key=key_prefix + "additional_pay2"
                )
                
                additional_pay3 = st.number_input(
                    "추가지급 3",
                    min_value=0,
                    value=int(worker.get('AdditionalPay3', 0)),
                    step=10000,
                    key=key_prefix + "additional_pay3"
                )
            
            with col2:
                st.write("**공제 항목**")
                
                additional_deduct1 = st.number_input(
                    "추가공제 1",
                    min_value=0,
                    value=int(worker.get('AdditionalDeduct1', 0)),
                    step=10000,
                    key=key_prefix + "additional_deduct1"
                )
                
                additional_deduct2 = st.number_input(
                    "추가공제 2",
                    min_value=0,
                    value=int(worker.get('AdditionalDeduct2', 0)),
                    step=10000,
                    key=key_prefix + "additional_deduct2"
                )
                
                additional_deduct3 = st.number_input(
                    "추가공제 3",
                    min_value=0,
                    value=int(worker.get('AdditionalDeduct3', 0)),
                    step=10000,
                    key=key_prefix + "additional_deduct3"
                )
            
            # 개별 저장 버튼
            if st.button(f"💾 {worker['Name']} 저장", key=f"save_{worker['Id']}", use_container_width=True):
                if save_monthly_data_from_session(worker['Id'], ym):
                    st.success(f"✅ {worker['Name']}님의 데이터가 저장되었습니다!")
                    st.rerun()
                else:
                    st.error("❌ 저장 실패")


def save_monthly_data_from_session(employee_id, ym):
    """세션 상태에서 월별 데이터 저장 (실제 DB 스키마)"""
    try:
        key_prefix = f"monthly_{employee_id}_"
        
        # 세션에서 값 가져오기
        work_hours = st.session_state.get(key_prefix + "normal_hours", 0)
        overtime_hours = st.session_state.get(key_prefix + "overtime_hours", 0)
        night_hours = st.session_state.get(key_prefix + "night_hours", 0)
        holiday_hours = st.session_state.get(key_prefix + "holiday_hours", 0)
        weekly_hours = st.session_state.get(key_prefix + "weekly_hours", 40.0)
        week_count = st.session_state.get(key_prefix + "week_count", 4)
        bonus = st.session_state.get(key_prefix + "bonus", 0)
        
        # 추가 지급/공제 (AdditionalPay1 → ExtraAllowance, AdditionalDeduct1 → ExtraDeduction)
        extra_allowance = st.session_state.get(key_prefix + "additional_pay1", 0)
        extra_deduction = st.session_state.get(key_prefix + "additional_deduct1", 0)
        memo = st.session_state.get(key_prefix + "memo", "")
        
        # UPSERT (있으면 업데이트, 없으면 삽입)
        sql_check = "SELECT Id FROM dbo.PayrollMonthlyInput WHERE EmployeeId = ? AND Ym = ?"
        existing = fetch_one(sql_check, (employee_id, ym))
        
        if existing:
            # 업데이트
            sql = """
                UPDATE dbo.PayrollMonthlyInput SET
                    WorkHours = ?, OvertimeHours = ?, NightHours = ?, HolidayHours = ?,
                    WeeklyHours = ?, WeekCount = ?, Bonus = ?,
                    ExtraAllowance = ?, ExtraDeduction = ?, Memo = ?,
                    UpdatedAt = SYSUTCDATETIME()
                WHERE EmployeeId = ? AND Ym = ?
            """
            execute_query(sql, (
                work_hours, overtime_hours, night_hours, holiday_hours,
                weekly_hours, week_count, bonus,
                extra_allowance, extra_deduction, memo,
                employee_id, ym
            ))
        else:
            # 삽입
            sql = """
                INSERT INTO dbo.PayrollMonthlyInput (
                    EmployeeId, Ym, WorkHours, OvertimeHours, NightHours, HolidayHours,
                    WeeklyHours, WeekCount, Bonus,
                    ExtraAllowance, ExtraDeduction, Memo,
                    CreatedAt, UpdatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, SYSUTCDATETIME(), SYSUTCDATETIME())
            """
            execute_query(sql, (
                employee_id, ym, work_hours, overtime_hours, night_hours, holiday_hours,
                weekly_hours, week_count, bonus,
                extra_allowance, extra_deduction, memo
            ))
        
        return True
    except Exception as e:
        st.error(f"데이터베이스 오류: {e}")
        return False


def show_employee_management(workers, selected_client):
    """직원 관리 탭 - Flutter 스타일 (왼쪽 리스트 + 오른쪽 편집)"""
    st.header("👥 직원 관리")
    
    # 직원이 없으면 추가 안내
    if not workers:
        st.info("등록된 직원이 없습니다.")
        if st.button("➕ 직원 추가", type="primary", use_container_width=True):
            st.session_state.selected_employee_id = 'new'
            st.rerun()
        return
    
    # 왼쪽(리스트) + 오른쪽(편집) 레이아웃
    left_col, right_col = st.columns([1, 2])
    
    with left_col:
        st.subheader(f"📋 직원 목록 ({len(workers)}명)")
        
        # 직원 추가 버튼
        if st.button("➕ 직원 추가", type="primary", use_container_width=True):
            st.session_state.selected_employee_id = 'new'
            st.rerun()
        
        st.divider()
        
        # 직원 리스트 (카드 형식)
        for worker in workers:
            # 선택된 직원 표시
            is_selected = st.session_state.get('selected_employee_id') == worker['Id']
            
            # 급여 정보
            salary_info = ""
            if worker.get('SalaryType') == 'MONTHLY':
                salary_info = f"월급 {format_money(worker.get('MonthlySalary', 0))}"
            else:
                salary_info = f"시급 {format_money(worker.get('HourlyRate', 0))}"
            
            employment_display = "정규직" if worker.get('EmploymentType') == 'REGULAR' else "프리랜서"
            
            # 직원 카드를 버튼으로 만들기 (선택 버튼 불필요)
            button_label = f"👤 {worker['Name']} | {worker['BirthDate']} | {employment_display} | 💰 {salary_info}"
            
            # 선택된 상태에 따라 버튼 스타일 적용
            if st.button(
                button_label,
                key=f"select_{worker['Id']}",
                use_container_width=True,
                type="primary" if is_selected else "secondary"
            ):
                st.session_state.selected_employee_id = worker['Id']
                st.rerun()
    
    with right_col:
        # 선택된 직원에 따라 편집 폼 표시
        selected_id = st.session_state.get('selected_employee_id')
        
        if selected_id == 'new':
            show_employee_form(selected_client, None)
        elif selected_id:
            # 선택된 직원 찾기
            selected_worker = next((w for w in workers if w['Id'] == selected_id), None)
            if selected_worker:
                show_employee_edit_form(selected_client, selected_worker)
            else:
                st.warning("선택된 직원을 찾을 수 없습니다.")
        else:
            st.info("👈 왼쪽에서 직원을 선택하거나 '직원 추가'를 클릭하세요.")


def show_employee_edit_form(selected_client, worker):
    """선택된 직원 편집 폼 (오른쪽 패널)"""
    
    # 헤더
    col1, col2 = st.columns([3, 1])
    with col1:
        st.subheader(f"✏️ {worker['Name']} 님")
    with col2:
        if st.button("🗑️ 삭제", type="secondary", use_container_width=True):
            if delete_employee(worker['Id']):
                st.success(f"✅ {worker['Name']}님이 삭제되었습니다.")
                st.session_state.selected_employee_id = None
                st.rerun()
            else:
                st.error("❌ 삭제 실패")
    
    st.divider()
    
    with st.form(f"employee_edit_form_{worker['Id']}"):
        # 기본 정보
        st.write("**📋 기본 정보**")
        col1, col2 = st.columns(2)
        
        with col1:
            name = st.text_input("이름*", value=worker.get('Name', ''))
            birth_date = st.text_input("생년월일 (YYMMDD)*", value=worker.get('BirthDate', ''))
            employment_type = st.selectbox(
                "고용형태*",
                options=['REGULAR', 'FREELANCE'],
                index=0 if worker.get('EmploymentType') == 'REGULAR' else 1,
                format_func=lambda x: '정규직' if x == 'REGULAR' else '프리랜서'
            )
        
        with col2:
            salary_type = st.selectbox(
                "급여형태*",
                options=['MONTHLY', 'HOURLY'],
                index=0 if worker.get('SalaryType') == 'MONTHLY' else 1,
                format_func=lambda x: '월급제' if x == 'MONTHLY' else '시급제'
            )
            
            # 월급여와 시급을 같은 컬럼에 표시
            if salary_type == 'MONTHLY':
                monthly_salary = st.number_input(
                    "월급여*", 
                    min_value=0, 
                    value=int(worker.get('MonthlySalary', 0)),
                    step=10000
                )
                hourly_rate = 0
            else:
                hourly_rate = st.number_input(
                    "시급*", 
                    min_value=0, 
                    value=int(worker.get('HourlyRate', 0)),
                    step=100
                )
                monthly_salary = 0
        
        st.divider()
        
        # 수당 정보
        st.write("**💵 수당 정보**")
        col1, col2 = st.columns(2)
        
        with col1:
            food_allowance = st.number_input(
                "식대 (월)",
                min_value=0,
                value=int(worker.get('FoodAllowance', 0)),
                step=10000
            )
        
        with col2:
            car_allowance = st.number_input(
                "차량유지비 (월)",
                min_value=0,
                value=int(worker.get('CarAllowance', 0)),
                step=10000
            )
        
        st.divider()
        
        # 4대보험
        st.write("**💳 4대보험 가입 여부**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            has_pension = st.checkbox(
                "국민연금", 
                value=bool(worker.get('HasNationalPension', True))
            )
        with col2:
            has_health = st.checkbox(
                "건강보험", 
                value=bool(worker.get('HasHealthInsurance', True))
            )
        with col3:
            has_employment = st.checkbox(
                "고용보험", 
                value=bool(worker.get('HasEmploymentInsurance', True))
            )
        
        st.divider()
        
        # 세금 관련
        st.write("**💰 세금 관련**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            tax_dependents = st.number_input(
                "공제대상 가족수 (본인 포함)",
                min_value=1,
                max_value=20,
                value=int(worker.get('TaxDependents', 1))
            )
        with col2:
            children_count = st.number_input(
                "8~20세 자녀수",
                min_value=0,
                max_value=10,
                value=int(worker.get('ChildrenCount', 0))
            )
        with col3:
            income_tax_rate = st.selectbox(
                "소득세율",
                options=[80, 100, 120],
                index=[80, 100, 120].index(int(worker.get('IncomeTaxRate', 100))),
                format_func=lambda x: f"{x}%"
            )
        
        st.divider()
        
        # 비과세 항목
        st.write("**🎁 비과세 항목 (월 기준)**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            tax_free_meal = st.number_input(
                "식대 (최대 20만원)",
                min_value=0,
                max_value=200000,
                value=int(worker.get('TaxFreeMeal', 0)),
                step=10000
            )
        with col2:
            tax_free_car = st.number_input(
                "차량유지비 (최대 20만원)",
                min_value=0,
                max_value=200000,
                value=int(worker.get('TaxFreeCarMaintenance', 0)),
                step=10000
            )
        with col3:
            other_tax_free = st.number_input(
                "기타 비과세",
                min_value=0,
                value=int(worker.get('OtherTaxFree', 0)),
                step=10000
            )
        
        st.divider()
        
        # 이메일 설정
        st.write("**📧 이메일 설정**")
        col1, col2 = st.columns(2)
        
        with col1:
            use_email = st.checkbox(
                "이메일 사용", 
                value=bool(worker.get('UseEmail', False))
            )
        
        with col2:
            email_to = st.text_input(
                "이메일 주소",
                value=worker.get('EmailTo', ''),
                disabled=not use_email
            )
        
        email_cc = st.text_input(
            "참조 (CC)",
            value=worker.get('EmailCc', ''),
            disabled=not use_email
        )
        
        st.divider()
        
        # 저장 버튼
        col1, col2 = st.columns([1, 1])
        with col1:
            submitted = st.form_submit_button("💾 저장", use_container_width=True, type="primary")
        with col2:
            cancel = st.form_submit_button("❌ 취소", use_container_width=True)
        
        if cancel:
            st.session_state.selected_employee_id = None
            st.rerun()
        
        if submitted:
            # 유효성 검사
            if not name or not birth_date:
                st.error("❌ 이름과 생년월일은 필수입니다.")
            elif len(birth_date) != 6:
                st.error("❌ 생년월일은 6자리(YYMMDD)로 입력하세요.")
            else:
                # 직원 정보 업데이트
                if update_employee(
                    worker['Id'],
                    selected_client['Id'],
                    name,
                    birth_date,
                    employment_type,
                    salary_type,
                    monthly_salary,
                    hourly_rate,
                    food_allowance,
                    car_allowance,
                    has_pension,
                    has_health,
                    has_employment,
                    tax_dependents,
                    children_count,
                    income_tax_rate,
                    tax_free_meal,
                    tax_free_car,
                    other_tax_free,
                    use_email,
                    email_to,
                    email_cc
                ):
                    st.success(f"✅ {name}님의 정보가 수정되었습니다.")
                    st.rerun()
                else:
                    st.error("❌ 수정 실패")


def show_employee_form(selected_client, employee_id=None):
    """직원 추가/수정 폼"""
    
    # 수정 모드인 경우 기존 데이터 로드
    employee = None
    if employee_id:
        sql = "SELECT * FROM dbo.Employees WHERE Id = ?"
        employee = fetch_one(sql, (employee_id,))
        st.subheader(f"✏️ 직원 수정: {employee['Name']}")
    else:
        st.subheader("➕ 신규 직원 추가")
    
    with st.form("employee_form"):
        # 기본 정보
        st.write("**📋 기본 정보**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            name = st.text_input("이름*", value=employee['Name'] if employee else "")
            birth_date = st.text_input("생년월일 (YYMMDD)*", value=employee['BirthDate'] if employee else "")
        
        with col2:
            employment_type = st.selectbox(
                "고용형태*",
                options=['REGULAR', 'FREELANCE'],
                index=0 if not employee else (0 if employee['EmploymentType'] == 'REGULAR' else 1),
                format_func=lambda x: '정규직' if x == 'REGULAR' else '프리랜서'
            )
            
            salary_type = st.selectbox(
                "급여형태*",
                options=['MONTHLY', 'HOURLY'],
                index=0 if not employee else (0 if employee['SalaryType'] == 'MONTHLY' else 1),
                format_func=lambda x: '월급제' if x == 'MONTHLY' else '시급제'
            )
        
        with col3:
            if salary_type == 'MONTHLY':
                monthly_salary = st.number_input(
                    "월급여*", 
                    min_value=0, 
                    value=employee['MonthlySalary'] if employee else 0,
                    step=10000
                )
                hourly_rate = 0
            else:
                hourly_rate = st.number_input(
                    "시급*", 
                    min_value=0, 
                    value=employee['HourlyRate'] if employee else 0,
                    step=100
                )
                monthly_salary = 0
        
        st.divider()
        
        # 4대보험
        st.write("**💳 4대보험 가입 여부**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            has_pension = st.checkbox(
                "국민연금", 
                value=employee['HasNationalPension'] if employee else True
            )
        with col2:
            has_health = st.checkbox(
                "건강보험", 
                value=employee['HasHealthInsurance'] if employee else True
            )
        with col3:
            has_employment = st.checkbox(
                "고용보험", 
                value=employee['HasEmploymentInsurance'] if employee else True
            )
        
        st.divider()
        
        # 세금 관련
        st.write("**💰 세금 관련**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            tax_dependents = st.number_input(
                "공제대상 가족수 (본인 포함)",
                min_value=1,
                max_value=20,
                value=employee['TaxDependents'] if employee else 1
            )
        with col2:
            children_count = st.number_input(
                "8~20세 자녀수",
                min_value=0,
                max_value=10,
                value=employee['ChildrenCount'] if employee else 0
            )
        with col3:
            income_tax_rate = st.selectbox(
                "소득세율",
                options=[80, 100, 120],
                index=1 if not employee else ([80, 100, 120].index(employee['IncomeTaxRate'])),
                format_func=lambda x: f"{x}%"
            )
        
        st.divider()
        
        # 비과세 항목
        st.write("**🎁 비과세 항목 (월 기준)**")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            tax_free_meal = st.number_input(
                "식대 (최대 20만원)",
                min_value=0,
                max_value=200000,
                value=employee['TaxFreeMeal'] if employee else 0,
                step=10000
            )
        with col2:
            tax_free_car = st.number_input(
                "차량유지비 (최대 20만원)",
                min_value=0,
                max_value=200000,
                value=employee['TaxFreeCarMaintenance'] if employee else 0,
                step=10000
            )
        with col3:
            other_tax_free = st.number_input(
                "기타 비과세",
                min_value=0,
                value=employee['OtherTaxFree'] if employee else 0,
                step=10000
            )
        
        st.divider()
        
        # 이메일 설정
        st.write("**📧 이메일 발송 설정**")
        use_email = st.checkbox(
            "이메일 발송 사용", 
            value=employee['UseEmail'] if employee else False
        )
        
        if use_email:
            col1, col2 = st.columns(2)
            with col1:
                email_to = st.text_input(
                    "수신 이메일*",
                    value=employee['EmailTo'] if employee else ""
                )
            with col2:
                email_cc = st.text_input(
                    "참조 이메일",
                    value=employee['EmailCc'] if employee else ""
                )
        else:
            email_to = ""
            email_cc = ""
        
        # 폼 제출
        col1, col2 = st.columns(2)
        with col1:
            submitted = st.form_submit_button("💾 저장", use_container_width=True, type="primary")
        with col2:
            cancelled = st.form_submit_button("❌ 취소", use_container_width=True)
        
        if cancelled:
            st.session_state.show_employee_form = False
            st.rerun()
        
        if submitted:
            # 유효성 검사
            if not name or not birth_date:
                st.error("❌ 이름과 생년월일은 필수입니다.")
            elif use_email and not email_to:
                st.error("❌ 이메일 발송을 사용하려면 수신 이메일을 입력하세요.")
            else:
                # 저장
                if employee_id:
                    # 수정
                    success = update_employee(
                        employee_id, selected_client['Id'], name, birth_date,
                        employment_type, salary_type, monthly_salary, hourly_rate,
                        has_pension, has_health, has_employment,
                        tax_dependents, children_count, income_tax_rate,
                        tax_free_meal, tax_free_car, other_tax_free,
                        use_email, email_to, email_cc
                    )
                    if success:
                        st.success(f"✅ {name}님의 정보가 수정되었습니다.")
                        st.session_state.show_employee_form = False
                        st.rerun()
                    else:
                        st.error("❌ 수정 실패")
                else:
                    # 추가
                    success = add_employee(
                        selected_client['Id'], name, birth_date,
                        employment_type, salary_type, monthly_salary, hourly_rate,
                        has_pension, has_health, has_employment,
                        tax_dependents, children_count, income_tax_rate,
                        tax_free_meal, tax_free_car, other_tax_free,
                        use_email, email_to, email_cc
                    )
                    if success:
                        st.success(f"✅ {name}님이 추가되었습니다.")
                        st.session_state.show_employee_form = False
                        st.rerun()
                    else:
                        st.error("❌ 추가 실패")


def add_employee(client_id, name, birth_date, employment_type, salary_type,
                monthly_salary, hourly_rate, has_pension, has_health, has_employment,
                tax_dependents, children_count, income_tax_rate,
                tax_free_meal, tax_free_car, other_tax_free,
                use_email, email_to, email_cc):
    """직원 추가 (실제 DB 스키마)"""
    try:
        sql = """
            INSERT INTO dbo.Employees (
                ClientId, Name, BirthDate, EmploymentType, SalaryType,
                BaseSalary, HourlyRate, NormalHours,
                FoodAllowance, CarAllowance,
                HasNationalPension, HasHealthInsurance, HasEmploymentInsurance,
                TaxDependents, ChildrenCount, IncomeTaxRate,
                TaxFreeMeal, TaxFreeCarMaintenance, OtherTaxFree,
                UseEmail, EmailTo, EmailCc,
                UpdatedAt, HealthInsuranceBasis
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 209, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, SYSUTCDATETIME(), 'salary')
        """
        execute_query(sql, (
            client_id, name, birth_date, employment_type, salary_type,
            monthly_salary, hourly_rate,
            0, 0,  # FoodAllowance, CarAllowance
            has_pension, has_health, has_employment,
            tax_dependents, children_count, income_tax_rate,
            tax_free_meal, tax_free_car, other_tax_free,
            use_email, email_to, email_cc
        ))
        return True
    except Exception as e:
        st.error(f"데이터베이스 오류: {e}")
        return False


def update_employee(employee_id, client_id, name, birth_date, employment_type, salary_type,
                   monthly_salary, hourly_rate, has_pension, has_health, has_employment,
                   tax_dependents, children_count, income_tax_rate,
                   tax_free_meal, tax_free_car, other_tax_free,
                   use_email, email_to, email_cc):
    """직원 수정 (실제 DB 스키마)"""
    try:
        sql = """
            UPDATE dbo.Employees SET
                ClientId = ?, Name = ?, BirthDate = ?, EmploymentType = ?, SalaryType = ?,
                BaseSalary = ?, HourlyRate = ?,
                HasNationalPension = ?, HasHealthInsurance = ?, HasEmploymentInsurance = ?,
                TaxDependents = ?, ChildrenCount = ?, IncomeTaxRate = ?,
                TaxFreeMeal = ?, TaxFreeCarMaintenance = ?, OtherTaxFree = ?,
                UseEmail = ?, EmailTo = ?, EmailCc = ?,
                UpdatedAt = SYSUTCDATETIME()
            WHERE EmployeeId = ?
        """
        execute_query(sql, (
            client_id, name, birth_date, employment_type, salary_type,
            monthly_salary, hourly_rate,
            has_pension, has_health, has_employment,
            tax_dependents, children_count, income_tax_rate,
            tax_free_meal, tax_free_car, other_tax_free,
            use_email, email_to, email_cc,
            employee_id
        ))
        return True
    except Exception as e:
        st.error(f"데이터베이스 오류: {e}")
        return False


def delete_employee(employee_id):
    """직원 삭제 (실제 DB 스키마)"""
    try:
        sql = "DELETE FROM dbo.Employees WHERE EmployeeId = ?"
        execute_query(sql, (employee_id,))
        return True
    except Exception as e:
        st.error(f"데이터베이스 오류: {e}")
        return False


def show_document_generation(workers, selected_client):
    """문서 생성 탭"""
    st.header("📄 문서 생성")
    
    # 급여 계산
    client_has_5_or_more = selected_client['Has5OrMoreWorkers']
    salary_results = calculate_all_salaries(workers, client_has_5_or_more)
    
    if not salary_results:
        st.warning("⚠️ 생성 가능한 문서가 없습니다.")
        return
    
    # 저장 경로 표시
    base_path = st.session_state.download_base_path
    use_subfolders = st.session_state.use_client_subfolders
    
    if use_subfolders:
        output_path = os.path.join(base_path, selected_client['Name'], 
                                   str(st.session_state.selected_year))
    else:
        output_path = base_path
    
    st.info(f"📁 저장 경로: `{output_path}`")
    
    col1, col2, col3 = st.columns(3)
    
    # 일괄 PDF 생성
    with col1:
        if st.button("📄 명세서 일괄생성", use_container_width=True):
            progress_bar = st.progress(0)
            status_text = st.empty()
            
            def update_progress(current, total):
                progress = current / total
                progress_bar.progress(progress)
                status_text.text(f"생성 중... ({current}/{total})")
            
            try:
                pdf_files = generate_batch_pdfs(
                    workers=workers,
                    salary_results=salary_results,
                    client_name=selected_client['Name'],
                    client_biz_id=selected_client['BizId'],
                    year=st.session_state.selected_year,
                    month=st.session_state.selected_month,
                    base_path=base_path,
                    use_subfolders=use_subfolders,
                    progress_callback=update_progress
                )
                
                progress_bar.empty()
                status_text.empty()
                st.success(f"✅ {len(pdf_files)}개의 명세서가 생성되었습니다!")
                
                # 생성된 파일 목록
                with st.expander("생성된 파일 목록"):
                    for pdf in pdf_files:
                        st.text(os.path.basename(pdf))
            
            except Exception as e:
                st.error(f"❌ 문서 생성 실패: {e}")
    
    # 폴더 열기
    with col2:
        if st.button("📂 폴더 열기", use_container_width=True):
            if open_folder(output_path):
                st.success("✅ 폴더를 열었습니다!")
    
    # CSV 내보내기
    with col3:
        if st.button("📊 CSV 내보내기", use_container_width=True):
            # CSV 데이터 생성
            csv_data = []
            for result in salary_results:
                csv_data.append({
                    '직원명': result['worker_name'],
                    '생년월일': result['birth_date'],
                    '기본급': result['base_salary'],
                    '연장수당': result['overtime_pay'],
                    '야간수당': result['night_pay'],
                    '휴일수당': result['holiday_pay'],
                    '주휴수당': result['weekly_holiday_pay'],
                    '상여금': result['bonus'],
                    '식대': result['food_allowance'],
                    '차량유지비': result['car_allowance'],
                    '지급총액': result['total_payment'],
                    '국민연금': result['national_pension'],
                    '건강보험': result['health_insurance'],
                    '장기요양': result['long_term_care'],
                    '고용보험': result['employment_insurance'],
                    '소득세': result['income_tax'],
                    '지방소득세': result['local_income_tax'],
                    '공제총액': result['total_deduction'],
                    '실수령액': result['net_payment']
                })
            
            df = pd.DataFrame(csv_data)
            csv = df.to_csv(index=False, encoding='utf-8-sig')
            
            st.download_button(
                label="💾 CSV 다운로드",
                data=csv,
                file_name=f"{selected_client['Name']}_{st.session_state.selected_year}년{st.session_state.selected_month}월_급여대장.csv",
                mime="text/csv",
                use_container_width=True
            )


def show_email_sending(workers, selected_client):
    """이메일 발송 탭"""
    st.header("📧 이메일 발송")
    
    # SMTP 설정 확인
    smtp = st.session_state.smtp_settings
    if not smtp['host'] or not smtp['user']:
        st.warning("⚠️ SMTP 설정이 필요합니다. '설정' 탭에서 SMTP 서버를 구성하세요.")
        return
    
    # 급여 계산
    client_has_5_or_more = selected_client['Has5OrMoreWorkers']
    salary_results = calculate_all_salaries(workers, client_has_5_or_more)
    
    if not salary_results:
        st.warning("⚠️ 발송 가능한 데이터가 없습니다.")
        return
    
    # 이메일 서비스 초기화
    email_service = EmailService(
        smtp_host=smtp['host'],
        smtp_port=smtp['port'],
        smtp_user=smtp['user'],
        smtp_pass=smtp['password'],
        use_tls=smtp['use_tls'],
        use_ssl=smtp['use_ssl']
    )
    
    # 발송 대상 필터링
    email_workers = [w for w in workers if w.get('UseEmail', False) and w.get('EmailTo', '').strip()]
    
    st.info(f"📧 이메일 발송 대상: {len(email_workers)}명")
    
    # 일괄 발송
    if st.button("📧 이메일 일괄발송", use_container_width=True, type="primary"):
        if not email_workers:
            st.warning("⚠️ 이메일 발송 대상이 없습니다.")
            return
        
        # PDF 먼저 생성
        with st.spinner("PDF 생성 중..."):
            base_path = st.session_state.download_base_path
            use_subfolders = st.session_state.use_client_subfolders
            
            pdf_files = generate_batch_pdfs(
                workers=workers,
                salary_results=salary_results,
                client_name=selected_client['Name'],
                client_biz_id=selected_client['BizId'],
                year=st.session_state.selected_year,
                month=st.session_state.selected_month,
                base_path=base_path,
                use_subfolders=use_subfolders
            )
        
        # 이메일 발송
        progress_bar = st.progress(0)
        status_text = st.empty()
        
        def update_progress(current, total):
            progress = current / total
            progress_bar.progress(progress)
            status_text.text(f"발송 중... ({current}/{total})")
        
        success_count, fail_count, errors = email_service.send_batch_emails(
            workers=email_workers,
            salary_results=salary_results,
            pdf_files=pdf_files,
            year=st.session_state.selected_year,
            month=st.session_state.selected_month,
            client_name=selected_client['Name'],
            subject_template=st.session_state.email_templates['subject'],
            body_template=st.session_state.email_templates['body'],
            progress_callback=update_progress
        )
        
        progress_bar.empty()
        status_text.empty()
        
        # 결과 표시
        if success_count > 0:
            st.success(f"✅ {success_count}명에게 이메일 발송 완료!")
        if fail_count > 0:
            st.error(f"❌ {fail_count}명 발송 실패")
            with st.expander("오류 내역"):
                for error in errors:
                    st.text(error)


def show_settings():
    """설정 탭"""
    st.header("⚙️ 설정")
    
    # 데이터베이스 정보 표시
    from database import get_database_info
    
    st.subheader("📊 데이터베이스 정보")
    db_info = get_database_info()
    
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("서버", f"{db_info['server']}:{db_info['port']}")
    with col2:
        st.metric("데이터베이스", db_info['database'])
    with col3:
        st.metric("사용자", db_info['user'])
    
    # ODBC 드라이버 정보
    if db_info['odbc_driver']:
        st.success(f"✅ ODBC 드라이버: {db_info['odbc_driver']}")
    else:
        st.error("❌ ODBC 드라이버를 찾을 수 없습니다")
    
    # 연결 상태
    if db_info['connection_status'] == 'Success':
        st.success("🟢 데이터베이스 연결: 정상")
    else:
        st.error("🔴 데이터베이스 연결: 실패")
        if db_info['connection_error']:
            with st.expander("오류 상세"):
                st.error(db_info['connection_error'])
    
    st.divider()
    
    # 파일 저장 경로
    st.subheader("📁 파일 저장 경로")
    
    current_path = st.session_state.download_base_path
    st.info(f"현재 저장 경로: `{current_path}`")
    
    new_path = st.text_input("저장 경로", value=current_path)
    use_subfolders = st.checkbox("거래처별 하위 폴더 생성 (거래처명/연도/)", 
                                 value=st.session_state.use_client_subfolders)
    
    if st.button("💾 저장 경로 업데이트"):
        try:
            Path(new_path).mkdir(parents=True, exist_ok=True)
            st.session_state.download_base_path = new_path
            st.session_state.use_client_subfolders = use_subfolders
            st.success(f"✅ 저장 경로가 업데이트되었습니다: {new_path}")
            st.rerun()
        except Exception as e:
            st.error(f"❌ 폴더 생성 실패: {e}")
    
    st.divider()
    
    # SMTP 설정
    st.subheader("📧 SMTP 설정")
    
    smtp = st.session_state.smtp_settings
    
    col1, col2 = st.columns(2)
    with col1:
        smtp_host = st.text_input("SMTP 서버", value=smtp['host'], 
                                  placeholder="smtp.gmail.com")
        smtp_user = st.text_input("사용자명 (이메일)", value=smtp['user'],
                                  placeholder="your@email.com")
    
    with col2:
        smtp_port = st.number_input("포트", value=smtp['port'], min_value=1, max_value=65535)
        smtp_pass = st.text_input("비밀번호", value=smtp['password'], type="password")
    
    col1, col2 = st.columns(2)
    with col1:
        smtp_tls = st.checkbox("STARTTLS 사용", value=smtp['use_tls'])
    with col2:
        smtp_ssl = st.checkbox("SSL 사용", value=smtp['use_ssl'])
    
    if st.button("💾 SMTP 설정 저장"):
        st.session_state.smtp_settings = {
            'host': smtp_host,
            'port': smtp_port,
            'user': smtp_user,
            'password': smtp_pass,
            'use_tls': smtp_tls,
            'use_ssl': smtp_ssl
        }
        st.success("✅ SMTP 설정이 저장되었습니다!")
        st.rerun()
    
    # 연결 테스트
    if st.button("🔍 SMTP 연결 테스트"):
        if not smtp_host or not smtp_user:
            st.warning("⚠️ SMTP 서버와 사용자명을 입력하세요.")
        else:
            email_service = EmailService(
                smtp_host=smtp_host,
                smtp_port=smtp_port,
                smtp_user=smtp_user,
                smtp_pass=smtp_pass,
                use_tls=smtp_tls,
                use_ssl=smtp_ssl
            )
            success, message = email_service.test_connection()
            if success:
                st.success(message)
            else:
                st.error(message)
    
    st.divider()
    
    # 이메일 템플릿
    st.subheader("✉️ 이메일 템플릿 (모든 거래처 공통)")
    
    st.info("""
    **사용 가능한 변수:**
    - `{year}`: 급여 연도 (예: 2025)
    - `{month}`: 급여 월 (예: 12)
    - `{name}`: 직원 이름 (예: 홍길동)
    - `{client}`: 거래처 이름 (예: 사업1)
    
    💡 **SMTP 설정은 하나로 모든 거래처의 이메일을 발송합니다.**
    """)
    
    templates = st.session_state.email_templates
    
    email_subject = st.text_input("제목 템플릿", value=templates['subject'], 
                                   placeholder="예: {year}년 {month}월 급여명세서 - {name}님")
    email_body = st.text_area("본문 템플릿", value=templates['body'], height=250,
                               placeholder="예: 안녕하세요, {name}님\n\n{client} 사업장의 {year}년 {month}월 급여명세서를 첨부합니다...")
    
    col1, col2 = st.columns([1, 3])
    with col1:
        if st.button("💾 템플릿 저장", use_container_width=True):
            st.session_state.email_templates = {
                'subject': email_subject,
                'body': email_body
            }
            st.success("✅ 이메일 템플릿이 저장되었습니다!")
            st.rerun()
    
    with col2:
        st.caption("💡 템플릿 변경 시 즉시 모든 거래처에 적용됩니다.")
    
    st.divider()
    
    # 데이터베이스 정보 및 진단
    st.subheader("📊 데이터베이스 연결 진단")
    
    from database import get_database_info
    
    if st.button("🔍 데이터베이스 연결 진단"):
        with st.spinner("데이터베이스 연결 확인 중..."):
            db_info = get_database_info()
            
            # 연결 정보
            st.markdown("### 📌 연결 정보")
            col1, col2 = st.columns(2)
            with col1:
                st.metric("서버", f"{db_info['server']}:{db_info['port']}")
                st.metric("데이터베이스", db_info['database'])
            with col2:
                st.metric("사용자", db_info['user'])
                st.metric("현재 사용 드라이버", db_info['odbc_driver'] or "❌ 없음")
            
            # 연결 상태
            st.markdown("### 🔌 연결 상태")
            if db_info['connection_status'] == 'Success':
                st.success("✅ 데이터베이스 연결 성공!")
            else:
                st.error(f"❌ 데이터베이스 연결 실패")
                if db_info['connection_error']:
                    st.error(f"**오류 메시지**: {db_info['connection_error']}")
                    
                    # 오류 해결 가이드
                    st.markdown("### 💡 문제 해결 가이드")
                    if 'IM002' in db_info['connection_error']:
                        st.warning("""
                        **ODBC 드라이버 문제**
                        - ODBC 드라이버가 설치되지 않았거나 시스템에서 찾을 수 없습니다.
                        - 아래에서 사용 가능한 드라이버를 확인하세요.
                        """)
                    elif '08001' in db_info['connection_error'] or 'timeout' in db_info['connection_error'].lower():
                        st.warning("""
                        **네트워크 연결 문제**
                        - 서버 주소와 포트 번호가 올바른지 확인하세요.
                        - 방화벽이 1433 포트를 차단하고 있지 않은지 확인하세요.
                        - SQL Server가 실행 중인지 확인하세요.
                        """)
                    elif '18456' in db_info['connection_error']:
                        st.warning("""
                        **인증 문제**
                        - 사용자명과 비밀번호가 올바른지 확인하세요.
                        - SQL Server 인증이 활성화되어 있는지 확인하세요.
                        """)
            
            # 사용 가능한 드라이버 목록
            st.markdown("### 🔧 시스템에 설치된 ODBC 드라이버")
            if db_info['available_drivers']:
                sql_drivers = [d for d in db_info['available_drivers'] if 'SQL Server' in d or 'sql' in d.lower()]
                other_drivers = [d for d in db_info['available_drivers'] if d not in sql_drivers]
                
                if sql_drivers:
                    st.success(f"**SQL Server 드라이버 ({len(sql_drivers)}개 발견)**")
                    for driver in sql_drivers:
                        icon = "✅" if driver == db_info['odbc_driver'] else "⚪"
                        st.text(f"{icon} {driver}")
                else:
                    st.error("❌ SQL Server 드라이버가 설치되지 않았습니다!")
                    st.markdown("""
                    **드라이버 설치 방법:**
                    1. [Microsoft ODBC Driver for SQL Server 다운로드](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)
                    2. Windows: 설치 프로그램 실행
                    3. Linux: 패키지 매니저로 설치 (`sudo apt-get install msodbcsql18` 또는 유사)
                    4. 설치 후 Streamlit 앱 재시작
                    """)
                
                if other_drivers:
                    with st.expander(f"기타 ODBC 드라이버 ({len(other_drivers)}개)"):
                        for driver in other_drivers:
                            st.text(f"⚪ {driver}")
            else:
                st.error("❌ 시스템에 ODBC 드라이버가 설치되지 않았습니다!")
            
            # 연결 문자열 (디버깅용)
            with st.expander("🔧 연결 문자열 (디버깅용)"):
                # 비밀번호 마스킹
                masked_conn_str = db_info['connection_string'].replace(
                    f"PWD={db_info.get('password', '')}",
                    "PWD=****"
                )
                st.code(masked_conn_str, language="text")


if __name__ == "__main__":
    main()
