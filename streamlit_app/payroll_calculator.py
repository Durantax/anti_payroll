"""
급여 계산 로직
Flutter의 lib/services/payroll_calculator.dart를 Python으로 변환
"""
from typing import Dict, Any, Optional
from datetime import datetime
import json


class PayrollCalculator:
    """급여 계산기"""
    
    # 상수
    WEEKS_PER_MONTH = 4.345
    
    def __init__(self, worker: Dict[str, Any], monthly_data: Dict[str, Any], 
                 client_has_5_or_more: bool = True):
        """
        급여 계산기 초기화
        
        Args:
            worker: 직원 정보 (Employees 테이블)
            monthly_data: 월별 근무 데이터 (PayrollMonthlyInput 테이블)
            client_has_5_or_more: 5인 이상 사업장 여부
        """
        self.worker = worker
        self.monthly_data = monthly_data
        self.client_has_5_or_more = client_has_5_or_more
        
        # 직원 기본 정보
        self.salary_type = worker.get('SalaryType', 'MONTHLY')
        self.employment_type = worker.get('EmploymentType', 'REGULAR')
        self.monthly_salary = worker.get('MonthlySalary', 0)
        self.hourly_rate_input = worker.get('HourlyRate', 0)
        
        # 4대보험 가입 여부
        self.has_national_pension = worker.get('HasNationalPension', True)
        self.has_health_insurance = worker.get('HasHealthInsurance', True)
        self.has_employment_insurance = worker.get('HasEmploymentInsurance', True)
        
        # 세금 관련
        self.tax_dependents = worker.get('TaxDependents', 1)
        self.children_count = worker.get('ChildrenCount', 0)
        self.income_tax_rate = worker.get('IncomeTaxRate', None)
        
        # 비과세 항목
        self.food_allowance = worker.get('FoodAllowance', 0)
        self.car_allowance = worker.get('CarAllowance', 0)
        self.tax_free_meal = worker.get('TaxFreeMeal', 0)
        self.tax_free_car_maintenance = worker.get('TaxFreeCarMaintenance', 0)
        self.other_tax_free = worker.get('OtherTaxFree', 0)
        
        # 월별 근무 데이터
        self.normal_hours = monthly_data.get('NormalHours', 0)
        self.overtime_hours = monthly_data.get('OvertimeHours', 0)
        self.night_hours = monthly_data.get('NightHours', 0)
        self.holiday_hours = monthly_data.get('HolidayHours', 0)
        self.weekly_hours = monthly_data.get('WeeklyHours', 40.0)
        self.week_count = monthly_data.get('WeekCount', 4)
        self.bonus = monthly_data.get('Bonus', 0)
        
        # 추가 지급/공제
        self.additional_pay1 = monthly_data.get('AdditionalPay1', 0)
        self.additional_pay2 = monthly_data.get('AdditionalPay2', 0)
        self.additional_pay3 = monthly_data.get('AdditionalPay3', 0)
        self.additional_deduct1 = monthly_data.get('AdditionalDeduct1', 0)
        self.additional_deduct2 = monthly_data.get('AdditionalDeduct2', 0)
        self.additional_deduct3 = monthly_data.get('AdditionalDeduct3', 0)
        
    def calculate(self) -> Dict[str, Any]:
        """급여 계산 실행"""
        
        # 1. 통상시급 계산
        hourly_rate = self._calculate_hourly_rate()
        
        # 2. 기본급 계산
        base_salary = self._calculate_base_salary(hourly_rate)
        
        # 3. 수당 계산
        overtime_pay = self._calculate_overtime_pay(hourly_rate)
        night_pay = self._calculate_night_pay(hourly_rate)
        holiday_pay = self._calculate_holiday_pay(hourly_rate)
        weekly_holiday_pay = self._calculate_weekly_holiday_pay(hourly_rate)
        
        # 4. 지급 총액
        total_payment = (
            base_salary +
            overtime_pay +
            night_pay +
            holiday_pay +
            weekly_holiday_pay +
            self.bonus +
            self.additional_pay1 +
            self.additional_pay2 +
            self.additional_pay3 +
            self.food_allowance +
            self.car_allowance
        )
        
        # 5. 과세 대상 및 비과세 계산
        taxable_allowance = overtime_pay + night_pay + holiday_pay + weekly_holiday_pay
        total_tax_free = (
            self.tax_free_meal +
            self.tax_free_car_maintenance +
            self.other_tax_free
        )
        
        # 6. 4대보험 기준액 (비과세 제외)
        insurance_base = total_payment - total_tax_free
        
        # 7. 공제 계산
        deductions = self._calculate_deductions(insurance_base, total_payment - total_tax_free)
        
        # 8. 실수령액
        total_deduction = sum(deductions.values())
        net_payment = total_payment - total_deduction
        
        return {
            'worker_name': self.worker.get('Name', ''),
            'birth_date': self.worker.get('BirthDate'),
            'employment_type': self.employment_type,
            'hourly_rate': hourly_rate,
            'base_salary': base_salary,
            'overtime_pay': overtime_pay,
            'night_pay': night_pay,
            'holiday_pay': holiday_pay,
            'weekly_holiday_pay': weekly_holiday_pay,
            'bonus': self.bonus,
            'additional_pay1': self.additional_pay1,
            'additional_pay2': self.additional_pay2,
            'additional_pay3': self.additional_pay3,
            'food_allowance': self.food_allowance,
            'car_allowance': self.car_allowance,
            'total_payment': total_payment,
            'taxable_allowance': taxable_allowance,
            'total_tax_free': total_tax_free,
            'insurance_base': insurance_base,
            **deductions,
            'total_deduction': total_deduction,
            'net_payment': net_payment,
        }
    
    def _calculate_hourly_rate(self) -> float:
        """통상시급 계산"""
        # 월급제 자동 인식: hourlyRate == 0 && monthlySalary > 0
        is_monthly_worker = (
            (self.salary_type == 'MONTHLY' and self.monthly_salary > 0) or
            (self.hourly_rate_input == 0 and self.monthly_salary > 0)
        )
        
        if is_monthly_worker:
            # 월급제: 월급여 ÷ (주소정근로시간 × 4.345)
            monthly_hours = self.weekly_hours * self.WEEKS_PER_MONTH
            return round(self.monthly_salary / monthly_hours) if monthly_hours > 0 else 0
        else:
            # 시급제: 입력된 시급
            return self.hourly_rate_input
    
    def _calculate_base_salary(self, hourly_rate: float) -> int:
        """기본급 계산"""
        is_monthly_worker = (
            (self.salary_type == 'MONTHLY' and self.monthly_salary > 0) or
            (self.hourly_rate_input == 0 and self.monthly_salary > 0)
        )
        
        if is_monthly_worker:
            # 월급제: 월급여 그대로
            return self.monthly_salary
        else:
            # 시급제: 통상시급 × 정상근로시간
            return round(hourly_rate * self.normal_hours)
    
    def _calculate_overtime_pay(self, hourly_rate: float) -> int:
        """연장수당 계산"""
        if not self.client_has_5_or_more or self.overtime_hours == 0:
            return 0
        
        # 연장수당 = 통상시급 × 1.5 × 연장시간
        return round(hourly_rate * 1.5 * self.overtime_hours)
    
    def _calculate_night_pay(self, hourly_rate: float) -> int:
        """야간수당 계산"""
        if not self.client_has_5_or_more or self.night_hours == 0:
            return 0
        
        # 야간수당 = 통상시급 × 0.5 × 야간시간
        return round(hourly_rate * 0.5 * self.night_hours)
    
    def _calculate_holiday_pay(self, hourly_rate: float) -> int:
        """휴일수당 계산"""
        if not self.client_has_5_or_more or self.holiday_hours == 0:
            return 0
        
        # 휴일수당: 8시간 이하는 1.5배, 8시간 초과는 8시간까지 1.5배 + 초과분 2.0배
        if self.holiday_hours <= 8:
            # 8시간 이하: 1.5배
            return round(hourly_rate * 1.5 * self.holiday_hours)
        else:
            # 8시간 초과: 8시간까지 1.5배 + 초과분 2.0배
            base_pay = round(hourly_rate * 1.5 * 8)
            overtime_pay = round(hourly_rate * 2.0 * (self.holiday_hours - 8))
            return base_pay + overtime_pay
    
    def _calculate_weekly_holiday_pay(self, hourly_rate: float) -> int:
        """주휴수당 계산"""
        is_monthly_worker = (
            (self.salary_type == 'MONTHLY' and self.monthly_salary > 0) or
            (self.hourly_rate_input == 0 and self.monthly_salary > 0)
        )
        
        # 월급제는 주휴수당 0 (이미 월급에 포함)
        if is_monthly_worker:
            return 0
        
        # 시급제 + 주 15시간 미만 → 주휴수당 없음
        if self.weekly_hours < 15:
            return 0
        
        # 프리랜서인 경우
        if self.employment_type == 'FREELANCE':
            # 주휴수당 = 통상시급 × 주소정근로시간 ÷ 5 × 개근주수
            return round(hourly_rate * self.weekly_hours / 5 * self.week_count)
        else:
            # 일반 직원: 주휴수당 = 통상시급 × 주소정근로시간 ÷ 5 × 4주
            return round(hourly_rate * self.weekly_hours / 5 * 4)
    
    def _calculate_deductions(self, insurance_base: int, taxable_income: int) -> Dict[str, int]:
        """공제 계산"""
        deductions = {}
        
        # 프리랜서 = 3.3% 세금 (3% 소득세 + 0.3% 지방소득세)
        if self.employment_type == 'FREELANCE':
            income_tax = ((taxable_income * 0.03) // 10) * 10
            local_income_tax = ((taxable_income * 0.003) // 10) * 10
            
            deductions['national_pension'] = 0
            deductions['health_insurance'] = 0
            deductions['long_term_care'] = 0
            deductions['employment_insurance'] = 0
            deductions['income_tax'] = income_tax
            deductions['local_income_tax'] = local_income_tax
            
            return deductions
        
        # 일반 직원: 4대보험
        # 1. 국민연금 (4.5%) - 10원 단위 절사
        if self.has_national_pension:
            national_pension = ((insurance_base * 0.045) // 10) * 10
        else:
            national_pension = 0
        
        # 2. 건강보험 (3.545%) - 10원 단위 절사
        if self.has_health_insurance:
            health_insurance = ((insurance_base * 0.03545) // 10) * 10
            # 3. 장기요양보험 (건강보험의 12.95%) - 10원 단위 절사
            long_term_care = ((health_insurance * 0.1295) // 10) * 10
        else:
            health_insurance = 0
            long_term_care = 0
        
        # 4. 고용보험 (0.9%) - 10원 단위 절사
        if self.has_employment_insurance:
            employment_insurance = ((insurance_base * 0.009) // 10) * 10
        else:
            employment_insurance = 0
        
        # 5. 소득세 및 지방소득세
        income_tax, local_income_tax = self._calculate_income_tax(taxable_income)
        
        deductions['national_pension'] = int(national_pension)
        deductions['health_insurance'] = int(health_insurance)
        deductions['long_term_care'] = int(long_term_care)
        deductions['employment_insurance'] = int(employment_insurance)
        deductions['income_tax'] = int(income_tax)
        deductions['local_income_tax'] = int(local_income_tax)
        
        return deductions
    
    def _calculate_income_tax(self, taxable_income: int) -> tuple:
        """소득세 및 지방소득세 계산 (간이세액표)"""
        
        # 사용자 지정 세율이 있으면 사용
        if self.income_tax_rate is not None:
            income_tax = ((taxable_income * self.income_tax_rate / 100) // 10) * 10
            local_income_tax = ((income_tax * 0.1) // 10) * 10
            return income_tax, local_income_tax
        
        # 간이세액표 로직 (2024년 기준)
        # 월 소득, 부양가족수, 자녀수에 따른 세액 계산
        return self._simplified_income_tax(taxable_income, self.tax_dependents, self.children_count)
    
    def _simplified_income_tax(self, monthly_income: int, dependents: int, children: int) -> tuple:
        """
        간이세액표 계산 (2024-02-29 개정)
        
        Args:
            monthly_income: 월 급여 (과세소득)
            dependents: 부양가족수 (본인 포함)
            children: 20세 이하 자녀수
        
        Returns:
            (소득세, 지방소득세) 튜플
        """
        
        # 1. 근로소득 공제
        if monthly_income <= 500000:
            earned_income_deduction = monthly_income * 0.7
        elif monthly_income <= 1500000:
            earned_income_deduction = 350000 + (monthly_income - 500000) * 0.4
        elif monthly_income <= 4500000:
            earned_income_deduction = 750000 + (monthly_income - 1500000) * 0.15
        elif monthly_income <= 10000000:
            earned_income_deduction = 1200000 + (monthly_income - 4500000) * 0.05
        else:
            earned_income_deduction = 1475000 + (monthly_income - 10000000) * 0.02
        
        earned_income_deduction = min(earned_income_deduction, 20000000)
        
        # 2. 근로소득금액
        earned_income_amount = monthly_income - earned_income_deduction
        
        # 3. 기본공제 (1인당 연 1,500,000원 → 월 125,000원)
        basic_deduction = dependents * 125000
        
        # 4. 특별소득공제 간주 (대략 100,000원)
        special_income_deduction = 100000
        
        # 5. 특별세액공제 간주 (대략 50,000원)
        special_tax_deduction = 50000
        
        # 6. 연금보험료공제
        pension_deduction = self.worker.get('NationalPension', 0)
        
        # 7. 종합소득 과세표준
        taxable_base = max(0, earned_income_amount - basic_deduction - 
                          special_income_deduction - pension_deduction)
        
        # 8. 산출세액 (누진세율)
        if taxable_base <= 14000000 / 12:
            tax = taxable_base * 0.06
        elif taxable_base <= 50000000 / 12:
            tax = (14000000 / 12) * 0.06 + (taxable_base - 14000000 / 12) * 0.15
        elif taxable_base <= 88000000 / 12:
            tax = (14000000 / 12) * 0.06 + (36000000 / 12) * 0.15 + \
                  (taxable_base - 50000000 / 12) * 0.24
        elif taxable_base <= 150000000 / 12:
            tax = (14000000 / 12) * 0.06 + (36000000 / 12) * 0.15 + \
                  (38000000 / 12) * 0.24 + (taxable_base - 88000000 / 12) * 0.35
        else:
            tax = (14000000 / 12) * 0.06 + (36000000 / 12) * 0.15 + \
                  (38000000 / 12) * 0.24 + (62000000 / 12) * 0.35 + \
                  (taxable_base - 150000000 / 12) * 0.38
        
        # 9. 근로소득세액공제 (산출세액의 55%, 최대 740,000원/12)
        earned_income_tax_credit = min(tax * 0.55, 740000 / 12)
        
        # 10. 자녀세액공제 (2명 이상일 때: 15만원/12 + (자녀수-2) * 20만원/12)
        if children >= 2:
            child_tax_credit = (150000 + (children - 2) * 200000) / 12
        else:
            child_tax_credit = 0
        
        # 11. 결정세액
        income_tax = max(0, tax - earned_income_tax_credit - child_tax_credit - special_tax_deduction)
        
        # 10원 단위 절사
        income_tax = (income_tax // 10) * 10
        
        # 12. 지방소득세 (소득세의 10%)
        local_income_tax = ((income_tax * 0.1) // 10) * 10
        
        return int(income_tax), int(local_income_tax)
