"""
PDF 급여명세서 생성
"""
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, Any


def format_money(amount):
    """금액 포맷팅"""
    if amount is None:
        return "0"
    return f"{int(amount):,}"


def generate_payslip_pdf(
    worker_data: Dict[str, Any],
    salary_result: Dict[str, Any],
    client_name: str,
    client_biz_id: str,
    year: int,
    month: int,
    output_path: str
) -> str:
    """
    급여명세서 PDF 생성
    
    Args:
        worker_data: 직원 정보
        salary_result: 급여 계산 결과
        client_name: 거래처명
        client_biz_id: 사업자번호
        year: 연도
        month: 월
        output_path: 저장 경로 (디렉토리 또는 전체 경로)
    
    Returns:
        생성된 PDF 파일의 전체 경로
    """
    
    # 출력 경로 설정
    if os.path.isdir(output_path):
        # 디렉토리인 경우 파일명 자동 생성
        filename = f"{client_name}_{salary_result['worker_name']}_{year}년{month}월_급여명세서.pdf"
        full_path = os.path.join(output_path, filename)
    else:
        # 전체 경로가 주어진 경우
        full_path = output_path
    
    # 디렉토리 생성
    Path(full_path).parent.mkdir(parents=True, exist_ok=True)
    
    # PDF 문서 생성
    doc = SimpleDocTemplate(
        full_path,
        pagesize=A4,
        rightMargin=15*mm,
        leftMargin=15*mm,
        topMargin=15*mm,
        bottomMargin=15*mm
    )
    
    # 스토리 (내용) 구성
    story = []
    
    # 스타일
    styles = getSampleStyleSheet()
    
    # 타이틀 스타일
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=18,
        textColor=colors.HexColor('#1f77b4'),
        spaceAfter=12,
        alignment=TA_CENTER,
        fontName='Helvetica-Bold'
    )
    
    # 서브타이틀 스타일
    subtitle_style = ParagraphStyle(
        'CustomSubtitle',
        parent=styles['Normal'],
        fontSize=11,
        alignment=TA_CENTER,
        spaceAfter=20
    )
    
    # 1. 제목
    story.append(Paragraph(f"{year}년 {month}월 급여명세서", title_style))
    story.append(Spacer(1, 5*mm))
    
    # 2. 기본 정보
    info_data = [
        ['거래처', client_name, '사업자번호', client_biz_id],
        ['성명', salary_result['worker_name'], '생년월일', salary_result.get('birth_date', '-')],
        ['통상시급', f"{format_money(salary_result['hourly_rate'])}원", '고용형태', salary_result.get('employment_type', 'REGULAR')]
    ]
    
    info_table = Table(info_data, colWidths=[30*mm, 60*mm, 30*mm, 60*mm])
    info_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, -1), colors.HexColor('#e8f4f8')),
        ('BACKGROUND', (2, 0), (2, -1), colors.HexColor('#e8f4f8')),
        ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('ROWHEIGHTS', (0, 0), (-1, -1), 8*mm),
    ]))
    
    story.append(info_table)
    story.append(Spacer(1, 8*mm))
    
    # 3. 지급 내역
    story.append(Paragraph("<b>지급 내역</b>", styles['Heading2']))
    story.append(Spacer(1, 3*mm))
    
    pay_items = [
        ['항목', '금액'],
        ['기본급', f"{format_money(salary_result['base_salary'])}원"],
    ]
    
    # 수당이 있는 경우만 추가
    if salary_result.get('overtime_pay', 0) > 0:
        pay_items.append(['연장수당', f"{format_money(salary_result['overtime_pay'])}원"])
    if salary_result.get('night_pay', 0) > 0:
        pay_items.append(['야간수당', f"{format_money(salary_result['night_pay'])}원"])
    if salary_result.get('holiday_pay', 0) > 0:
        pay_items.append(['휴일수당', f"{format_money(salary_result['holiday_pay'])}원"])
    if salary_result.get('weekly_holiday_pay', 0) > 0:
        pay_items.append(['주휴수당', f"{format_money(salary_result['weekly_holiday_pay'])}원"])
    if salary_result.get('bonus', 0) > 0:
        pay_items.append(['상여금', f"{format_money(salary_result['bonus'])}원"])
    if salary_result.get('food_allowance', 0) > 0:
        pay_items.append(['식대', f"{format_money(salary_result['food_allowance'])}원"])
    if salary_result.get('car_allowance', 0) > 0:
        pay_items.append(['차량유지비', f"{format_money(salary_result['car_allowance'])}원"])
    
    # 추가 지급 항목
    for i in range(1, 4):
        key = f'additional_pay{i}'
        if salary_result.get(key, 0) > 0:
            pay_items.append([f'추가지급{i}', f"{format_money(salary_result[key])}원"])
    
    # 총액
    pay_items.append(['지급총액', f"{format_money(salary_result['total_payment'])}원"])
    
    pay_table = Table(pay_items, colWidths=[60*mm, 60*mm])
    pay_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#4a90e2')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('BACKGROUND', (-1, -1), (-1, -1), colors.HexColor('#e8f4f8')),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('ROWHEIGHTS', (0, 0), (-1, -1), 7*mm),
    ]))
    
    story.append(pay_table)
    story.append(Spacer(1, 8*mm))
    
    # 4. 공제 내역
    story.append(Paragraph("<b>공제 내역</b>", styles['Heading2']))
    story.append(Spacer(1, 3*mm))
    
    deduct_items = [
        ['항목', '금액'],
    ]
    
    # 공제 항목
    if salary_result.get('national_pension', 0) > 0:
        deduct_items.append(['국민연금', f"{format_money(salary_result['national_pension'])}원"])
    if salary_result.get('health_insurance', 0) > 0:
        deduct_items.append(['건강보험', f"{format_money(salary_result['health_insurance'])}원"])
    if salary_result.get('long_term_care', 0) > 0:
        deduct_items.append(['장기요양', f"{format_money(salary_result['long_term_care'])}원"])
    if salary_result.get('employment_insurance', 0) > 0:
        deduct_items.append(['고용보험', f"{format_money(salary_result['employment_insurance'])}원"])
    if salary_result.get('income_tax', 0) > 0:
        deduct_items.append(['소득세', f"{format_money(salary_result['income_tax'])}원"])
    if salary_result.get('local_income_tax', 0) > 0:
        deduct_items.append(['지방소득세', f"{format_money(salary_result['local_income_tax'])}원"])
    
    # 추가 공제 항목
    for i in range(1, 4):
        key = f'additional_deduct{i}'
        if salary_result.get(key, 0) > 0:
            deduct_items.append([f'추가공제{i}', f"{format_money(salary_result[key])}원"])
    
    # 총액
    deduct_items.append(['공제총액', f"{format_money(salary_result['total_deduction'])}원"])
    
    deduct_table = Table(deduct_items, colWidths=[60*mm, 60*mm])
    deduct_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#e74c3c')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('BACKGROUND', (-1, -1), (-1, -1), colors.HexColor('#fce8e6')),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('ROWHEIGHTS', (0, 0), (-1, -1), 7*mm),
    ]))
    
    story.append(deduct_table)
    story.append(Spacer(1, 10*mm))
    
    # 5. 실수령액
    net_data = [
        ['실수령액', f"{format_money(salary_result['net_payment'])}원"]
    ]
    
    net_table = Table(net_data, colWidths=[60*mm, 60*mm])
    net_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#28a745')),
        ('TEXTCOLOR', (0, 0), (-1, -1), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('FONTSIZE', (0, 0), (-1, -1), 12),
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 1, colors.darkgreen),
        ('ROWHEIGHTS', (0, 0), (-1, -1), 12*mm),
    ]))
    
    story.append(net_table)
    
    # 6. 발행 정보
    story.append(Spacer(1, 10*mm))
    issue_date = datetime.now().strftime("%Y년 %m월 %d일")
    story.append(Paragraph(f"발행일: {issue_date}", subtitle_style))
    
    # PDF 생성
    doc.build(story)
    
    return full_path


def generate_batch_pdfs(
    workers: list,
    salary_results: list,
    client_name: str,
    client_biz_id: str,
    year: int,
    month: int,
    base_path: str,
    use_subfolders: bool = True,
    progress_callback=None
) -> list:
    """
    일괄 PDF 생성
    
    Args:
        workers: 직원 목록
        salary_results: 급여 계산 결과 목록
        client_name: 거래처명
        client_biz_id: 사업자번호
        year: 연도
        month: 월
        base_path: 기본 저장 경로
        use_subfolders: 거래처별 하위 폴더 사용 여부
        progress_callback: 진행 상황 콜백 함수 (current, total)
    
    Returns:
        생성된 PDF 파일 경로 리스트
    """
    
    # 저장 경로 결정
    if use_subfolders:
        output_dir = os.path.join(base_path, client_name, str(year))
    else:
        output_dir = base_path
    
    # 디렉토리 생성
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    generated_files = []
    total = len(salary_results)
    
    for idx, result in enumerate(salary_results, 1):
        try:
            # 해당 직원 데이터 찾기
            worker = next((w for w in workers if w['Id'] == result['worker_id']), None)
            if not worker:
                continue
            
            # PDF 생성
            pdf_path = generate_payslip_pdf(
                worker_data=worker,
                salary_result=result,
                client_name=client_name,
                client_biz_id=client_biz_id,
                year=year,
                month=month,
                output_path=output_dir
            )
            
            generated_files.append(pdf_path)
            
            # 진행 상황 콜백
            if progress_callback:
                progress_callback(idx, total)
        
        except Exception as e:
            print(f"❌ {result.get('worker_name', '알 수 없음')} PDF 생성 실패: {e}")
            continue
    
    return generated_files
