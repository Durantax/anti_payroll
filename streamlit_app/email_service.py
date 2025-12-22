"""
이메일 발송 서비스
"""
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import os
from typing import Optional, List
from pathlib import Path


class EmailService:
    """이메일 발송 서비스"""
    
    def __init__(self, smtp_host: str, smtp_port: int, smtp_user: str, 
                 smtp_pass: str, use_tls: bool = True, use_ssl: bool = False):
        """
        이메일 서비스 초기화
        
        Args:
            smtp_host: SMTP 서버 주소
            smtp_port: SMTP 포트
            smtp_user: SMTP 사용자명
            smtp_pass: SMTP 비밀번호
            use_tls: STARTTLS 사용 여부
            use_ssl: SSL 사용 여부
        """
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.smtp_user = smtp_user
        self.smtp_pass = smtp_pass
        self.use_tls = use_tls
        self.use_ssl = use_ssl
    
    def send_payslip_email(
        self,
        to_email: str,
        worker_name: str,
        year: int,
        month: int,
        client_name: str,
        pdf_path: Optional[str] = None,
        subject_template: Optional[str] = None,
        body_template: Optional[str] = None,
        cc_email: Optional[str] = None
    ) -> tuple[bool, str]:
        """
        급여명세서 이메일 발송
        
        Args:
            to_email: 수신 이메일
            worker_name: 직원명
            year: 연도
            month: 월
            client_name: 거래처명
            pdf_path: 첨부할 PDF 파일 경로
            subject_template: 제목 템플릿
            body_template: 본문 템플릿
            cc_email: 참조 이메일
        
        Returns:
            (성공 여부, 메시지)
        """
        
        try:
            # 제목 및 본문 생성
            if subject_template:
                subject = subject_template.replace('{year}', str(year))\
                                        .replace('{month}', str(month))\
                                        .replace('{name}', worker_name)\
                                        .replace('{client}', client_name)
            else:
                subject = f"{year}년 {month}월 급여명세서 - {worker_name}"
            
            if body_template:
                body = body_template.replace('{year}', str(year))\
                                   .replace('{month}', str(month))\
                                   .replace('{name}', worker_name)\
                                   .replace('{client}', client_name)
            else:
                body = f"""
안녕하세요, {worker_name}님

{year}년 {month}월 급여명세서를 첨부하여 보내드립니다.
확인 후 문의사항이 있으시면 연락 주시기 바랍니다.

감사합니다.
{client_name} 드림
"""
            
            # 이메일 메시지 생성
            msg = MIMEMultipart()
            msg['From'] = self.smtp_user
            msg['To'] = to_email
            if cc_email:
                msg['Cc'] = cc_email
            msg['Subject'] = subject
            
            # 본문 추가
            msg.attach(MIMEText(body, 'plain', 'utf-8'))
            
            # PDF 첨부
            if pdf_path and os.path.exists(pdf_path):
                filename = os.path.basename(pdf_path)
                
                with open(pdf_path, 'rb') as f:
                    part = MIMEBase('application', 'pdf')
                    part.set_payload(f.read())
                    encoders.encode_base64(part)
                    part.add_header('Content-Disposition', 
                                  f'attachment; filename={filename}')
                    msg.attach(part)
            
            # SMTP 연결 및 발송
            if self.use_ssl:
                server = smtplib.SMTP_SSL(self.smtp_host, self.smtp_port)
            else:
                server = smtplib.SMTP(self.smtp_host, self.smtp_port)
                if self.use_tls:
                    server.starttls()
            
            server.login(self.smtp_user, self.smtp_pass)
            
            # 수신자 리스트 (CC 포함)
            recipients = [to_email]
            if cc_email:
                recipients.append(cc_email)
            
            server.send_message(msg)
            server.quit()
            
            return True, f"✅ {worker_name}님께 이메일 발송 완료"
        
        except Exception as e:
            return False, f"❌ {worker_name}님 이메일 발송 실패: {str(e)}"
    
    def send_batch_emails(
        self,
        workers: list,
        salary_results: list,
        pdf_files: list,
        year: int,
        month: int,
        client_name: str,
        subject_template: Optional[str] = None,
        body_template: Optional[str] = None,
        progress_callback=None
    ) -> tuple[int, int, List[str]]:
        """
        일괄 이메일 발송
        
        Args:
            workers: 직원 목록
            salary_results: 급여 계산 결과
            pdf_files: PDF 파일 경로 리스트
            year: 연도
            month: 월
            client_name: 거래처명
            subject_template: 제목 템플릿
            body_template: 본문 템플릿
            progress_callback: 진행 상황 콜백 (current, total)
        
        Returns:
            (성공 개수, 실패 개수, 오류 메시지 리스트)
        """
        
        success_count = 0
        fail_count = 0
        error_messages = []
        
        # PDF 파일을 worker_id로 매핑
        pdf_map = {}
        for pdf_path in pdf_files:
            filename = os.path.basename(pdf_path)
            # 파일명에서 직원명 추출 시도
            for result in salary_results:
                if result['worker_name'] in filename:
                    pdf_map[result['worker_id']] = pdf_path
                    break
        
        # 이메일 발송 대상 필터링
        email_targets = []
        for worker in workers:
            # 이메일 사용 여부 확인
            if not worker.get('UseEmail', False):
                continue
            
            # 이메일 주소 확인
            to_email = worker.get('EmailTo', '').strip()
            if not to_email:
                continue
            
            # 급여 계산 결과 찾기
            result = next((r for r in salary_results if r['worker_id'] == worker['Id']), None)
            if not result:
                continue
            
            email_targets.append({
                'worker': worker,
                'result': result,
                'pdf_path': pdf_map.get(worker['Id'])
            })
        
        total = len(email_targets)
        
        for idx, target in enumerate(email_targets, 1):
            worker = target['worker']
            result = target['result']
            pdf_path = target['pdf_path']
            
            # 이메일 발송
            success, message = self.send_payslip_email(
                to_email=worker['EmailTo'],
                worker_name=result['worker_name'],
                year=year,
                month=month,
                client_name=client_name,
                pdf_path=pdf_path,
                subject_template=subject_template,
                body_template=body_template,
                cc_email=worker.get('EmailCc')
            )
            
            if success:
                success_count += 1
            else:
                fail_count += 1
                error_messages.append(message)
            
            # 진행 상황 콜백
            if progress_callback:
                progress_callback(idx, total)
        
        return success_count, fail_count, error_messages
    
    def test_connection(self) -> tuple[bool, str]:
        """
        SMTP 연결 테스트
        
        Returns:
            (성공 여부, 메시지)
        """
        try:
            if self.use_ssl:
                server = smtplib.SMTP_SSL(self.smtp_host, self.smtp_port, timeout=10)
            else:
                server = smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=10)
                if self.use_tls:
                    server.starttls()
            
            server.login(self.smtp_user, self.smtp_pass)
            server.quit()
            
            return True, "✅ SMTP 연결 성공"
        
        except Exception as e:
            return False, f"❌ SMTP 연결 실패: {str(e)}"
