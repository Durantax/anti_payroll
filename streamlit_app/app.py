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

# CSS 스타일
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        margin-bottom: 1rem;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        margin: 0.5rem 0;
    }
    .success-message {
        padding: 1rem;
        background-color: #d4edda;
        border-left: 4px solid #28a745;
        margin: 1rem 0;
    }
    .error-message {
        padding: 1rem;
        background-color: #f8d7da;
        border-left: 4px solid #dc3545;
        margin: 1rem 0;
    }
    .stProgress .st-bo {
        background-color: #1f77b4;
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
        'subject': '{year}년 {month}월 급여명세서 - {name}',
        'body': '''안녕하세요, {name}님

{year}년 {month}월 급여명세서를 첨부하여 보내드립니다.
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
    sql = "SELECT Id, Name, BizId, Has5OrMoreWorkers FROM dbo.Clients ORDER BY Name"
    return fetch_all(sql)


def load_workers(client_id, year, month):
    """직원 목록 로드"""
    ym = f"{year:04d}-{month:02d}"
    sql = """
        SELECT 
            e.*,
            m.NormalHours, m.OvertimeHours, m.NightHours, m.HolidayHours,
            m.WeeklyHours, m.WeekCount, m.Bonus,
            m.AdditionalPay1, m.AdditionalPay2, m.AdditionalPay3,
            m.AdditionalDeduct1, m.AdditionalDeduct2, m.AdditionalDeduct3
        FROM dbo.Employees e
        LEFT JOIN dbo.PayrollMonthlyInput m 
            ON e.Id = m.EmployeeId AND m.Ym = ?
        WHERE e.ClientId = ?
        ORDER BY e.Name
    """
    workers = fetch_all(sql, (ym, client_id))
    
    # None 값을 0으로 변환
    for worker in workers:
        for key in ['NormalHours', 'OvertimeHours', 'NightHours', 'HolidayHours',
                    'WeeklyHours', 'WeekCount', 'Bonus', 
                    'AdditionalPay1', 'AdditionalPay2', 'AdditionalPay3',
                    'AdditionalDeduct1', 'AdditionalDeduct2', 'AdditionalDeduct3']:
            if worker.get(key) is None:
                worker[key] = 0
        
        # WeeklyHours 기본값
        if worker.get('WeeklyHours') == 0:
            worker['WeeklyHours'] = 40.0
    
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
    tab1, tab2, tab3, tab4, tab5 = st.tabs([
        "📊 급여 계산", 
        "👥 직원 관리", 
        "📄 문서 생성",
        "📧 이메일 발송",
        "⚙️ 설정"
    ])
    
    # 탭 1: 급여 계산
    with tab1:
        show_payroll_calculation(workers, selected_client)
    
    # 탭 2: 직원 관리
    with tab2:
        show_employee_management(workers, selected_client)
    
    # 탭 3: 문서 생성
    with tab3:
        show_document_generation(workers, selected_client)
    
    # 탭 4: 이메일 발송
    with tab4:
        show_email_sending(workers, selected_client)
    
    # 탭 5: 설정
    with tab5:
        show_settings()


def show_payroll_calculation(workers, selected_client):
    """급여 계산 탭"""
    st.header("📊 급여 계산 결과")
    
    # 급여 계산
    client_has_5_or_more = selected_client['Has5OrMoreWorkers']
    salary_results = calculate_all_salaries(workers, client_has_5_or_more)
    
    if not salary_results:
        st.warning("⚠️ 계산 가능한 급여 데이터가 없습니다.")
        return
    
    # 요약 정보
    total_payment = sum(r['total_payment'] for r in salary_results)
    total_deduction = sum(r['total_deduction'] for r in salary_results)
    total_net = sum(r['net_payment'] for r in salary_results)
    
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("지급총액", f"{format_money(total_payment)}원")
    with col2:
        st.metric("공제총액", f"{format_money(total_deduction)}원", 
                 delta=f"-{format_money(total_deduction)}원", delta_color="inverse")
    with col3:
        st.metric("실수령액", f"{format_money(total_net)}원")
    
    st.divider()
    
    # 직원별 상세 결과
    for idx, result in enumerate(salary_results):
        with st.expander(f"👤 {result['worker_name']} - 실수령액: {format_money(result['net_payment'])}원"):
            
            # 기본 정보
            col1, col2, col3 = st.columns(3)
            with col1:
                st.write(f"**통상시급:** {format_money(result['hourly_rate'])}원")
            with col2:
                st.write(f"**고용형태:** {result['employment_type']}")
            with col3:
                st.write(f"**생년월일:** {result['birth_date']}")
            
            # 지급 항목
            st.subheader("💰 지급 항목")
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
                {'항목': k, '금액': f"{format_money(v)}원"} 
                for k, v in pay_data.items() if v > 0
            ])
            
            if not pay_df.empty:
                st.dataframe(pay_df, use_container_width=True, hide_index=True)
            
            st.write(f"**지급총액:** {format_money(result['total_payment'])}원")
            
            # 공제 항목
            st.subheader("➖ 공제 항목")
            deduct_data = {
                '국민연금': result['national_pension'],
                '건강보험': result['health_insurance'],
                '장기요양': result['long_term_care'],
                '고용보험': result['employment_insurance'],
                '소득세': result['income_tax'],
                '지방소득세': result['local_income_tax'],
            }
            
            deduct_df = pd.DataFrame([
                {'항목': k, '금액': f"{format_money(v)}원"} 
                for k, v in deduct_data.items() if v > 0
            ])
            
            if not deduct_df.empty:
                st.dataframe(deduct_df, use_container_width=True, hide_index=True)
            
            st.write(f"**공제총액:** {format_money(result['total_deduction'])}원")
            
            # 실수령액
            st.subheader("✅ 실수령액")
            st.success(f"### {format_money(result['net_payment'])}원")


def show_employee_management(workers, selected_client):
    """직원 관리 탭"""
    st.header("👥 직원 관리")
    st.info("🚧 직원 추가/수정/삭제 기능은 개발 중입니다.")
    
    # 직원 목록 표시
    if workers:
        df = pd.DataFrame(workers)
        display_columns = ['Name', 'BirthDate', 'SalaryType', 'MonthlySalary', 
                          'HourlyRate', 'EmploymentType']
        available_columns = [col for col in display_columns if col in df.columns]
        
        st.dataframe(df[available_columns], use_container_width=True)


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
    st.subheader("✉️ 이메일 템플릿")
    
    st.info("사용 가능한 변수: {year}, {month}, {name}, {client}")
    
    templates = st.session_state.email_templates
    
    email_subject = st.text_input("제목 템플릿", value=templates['subject'])
    email_body = st.text_area("본문 템플릿", value=templates['body'], height=200)
    
    if st.button("💾 템플릿 저장"):
        st.session_state.email_templates = {
            'subject': email_subject,
            'body': email_body
        }
        st.success("✅ 이메일 템플릿이 저장되었습니다!")
        st.rerun()
    
    st.divider()
    
    # 데이터베이스 정보
    st.subheader("📊 데이터베이스 정보")
    st.code(f"""
서버: 25.2.89.129:1433
데이터베이스: 기본정보
사용자: user1
""")


if __name__ == "__main__":
    main()
