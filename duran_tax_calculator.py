import math

class DuranTaxCalculator:
    """
    세무회계 두란 전용 근로소득 간이세액 계산기 (2024.02.29 개정 반영)
    주소: 서울시 양천구 신정동 1014-2, 503호 / 연락처: 010-7704-1536
    """

    def __init__(self):
        # 1,000만 원인 경우의 가족수별 세액 (33페이지 기준점) 
        self.tax_at_10m = {
            1: 1507400, 2: 1431570, 3: 1200840, 4: 1170840, 5: 1140840,
            6: 1110840, 7: 1080840, 8: 1050840, 9: 1020840, 10: 990840, 11: 960840
        }

    def _get_earned_income_deduction(self, annual_salary):
        """근로소득공제 (소득세법 제20조)"""
        if annual_salary <= 5000000:
            return annual_salary * 0.7
        elif annual_salary <= 15000000:
            return 3500000 + (annual_salary - 5000000) * 0.4
        elif annual_salary <= 45000000:
            return 7500000 + (annual_salary - 15000000) * 0.15
        elif annual_salary <= 100000000:
            return 12000000 + (annual_salary - 45000000) * 0.05
        else:
            return 14750000 + (annual_salary - 100000000) * 0.02

    def _get_special_deduction_formula(self, annual_salary, family_count):
        """1페이지: 특별소득공제 및 특별세액공제 중 일부 산식 [cite: 5]"""
        g = annual_salary
        if family_count == 1:
            if g <= 30000000: return 3100000 + g * 0.04
            if g <= 45000000: return 3100000 + g * 0.04 - (g - 30000000) * 0.05
            if g <= 70000000: return 3100000 + g * 0.015
            if g <= 120000000: return 3100000 + g * 0.005
        elif family_count == 2:
            if g <= 30000000: return 3600000 + g * 0.04
            if g <= 45000000: return 3600000 + g * 0.04 - (g - 30000000) * 0.05
            if g <= 70000000: return 3600000 + g * 0.02
            if g <= 120000000: return 3600000 + g * 0.01
        else: # 3명 이상
            if g <= 30000000: return 5000000 + g * 0.07
            if g <= 45000000: return 5000000 + g * 0.07 - (g - 30000000) * 0.05
            if g <= 70000000: return 5000000 + g * 0.05 + (g - 40000000) * 0.04
            if g <= 120000000: return 5000000 + g * 0.03 + (g - 40000000) * 0.04
        return 0

    def _get_standard_tax_credit(self, annual_tax, annual_salary):
        """근로소득세액공제 (소득세법 제59조)"""
        if annual_tax <= 1300000:
            credit = annual_tax * 0.55
        else:
            credit = 715000 + (annual_tax - 1300000) * 0.30
        
        # 급여 구간별 한도 적용
        if annual_salary <= 33000000: limit = 740000
        elif annual_salary <= 70000000: limit = max(660000, 740000 - (annual_salary - 33000000) * 0.008)
        else: limit = max(500000, 660000 - (annual_salary - 70000000) * 0.5 * 0.01)
        
        return min(credit, limit)

    def _apply_tax_rates(self, taxable_income):
        """기본세율 적용 (2024년 기준)"""
        income = max(0, taxable_income)
        if income <= 14000000: return income * 0.06
        if income <= 50000000: return 840000 + (income - 14000000) * 0.15
        if income <= 88000000: return 6240000 + (income - 50000000) * 0.24
        if income <= 150000000: return 15360000 + (income - 88000000) * 0.35
        if income <= 300000000: return 37060000 + (income - 150000000) * 0.38
        if income <= 500000000: return 94060000 + (income - 300000000) * 0.40
        if income <= 1000000000: return 174060000 + (income - 500000000) * 0.42
        return 384060000 + (income - 1000000000) * 0.45

    def _calculate_under_10m(self, monthly_income, family_count):
        """1,000만 원 이하: 1페이지 수식 기반 계산 [cite: 3, 4, 5]"""
        annual_salary = monthly_income * 12
        
        # 1. 근로소득공제
        deduction_earned = self._get_earned_income_deduction(annual_salary)
        
        # 2. 인적공제 (본인 및 부양가족 1인당 150만 원) [cite: 6]
        deduction_basic = family_count * 1500000
        
        # 3. 연금보험료공제 (편의상 월급여의 4.5% 적용, 상한액 265,500원 가정)
        monthly_pension = min(monthly_income * 0.045, 265500)
        deduction_pension = monthly_pension * 12
        
        # 4. 특별소득·세액공제 (1페이지 수식) [cite: 5]
        deduction_special = self._get_special_deduction_formula(annual_salary, family_count)
        
        # 과세표준 산출
        taxable_income = annual_salary - deduction_earned - deduction_basic - deduction_pension - deduction_special
        
        # 5. 산출세액 및 근로소득세액공제
        calculated_annual_tax = self._apply_tax_rates(taxable_income)
        tax_credit = self._get_standard_tax_credit(calculated_annual_tax, annual_salary)
        
        final_annual_tax = max(0, calculated_annual_tax - tax_credit)
        return final_annual_tax / 12

    def _calculate_over_10m(self, monthly_income, family_count):
        """1,000만 원 초과: 33페이지 명시적 수식 """
        eff_family = min(family_count, 11)
        tax_10m = self.tax_at_10m.get(eff_family, 960840)
        excess = monthly_income - 10000000
        
        if monthly_income <= 14000000:
            return tax_10m + (excess * 0.98 * 0.35) + 25000
        elif monthly_income <= 28000000:
            return tax_10m + 1397000 + ((monthly_income - 14000000) * 0.98 * 0.38)
        elif monthly_income <= 30000000:
            return tax_10m + 6610600 + ((monthly_income - 28000000) * 0.98 * 0.40)
        elif monthly_income <= 45000000:
            return tax_10m + 7394600 + ((monthly_income - 30000000) * 0.40)
        elif monthly_income <= 87000000:
            return tax_10m + 13394600 + ((monthly_income - 45000000) * 0.42)
        else:
            return tax_10m + 31034600 + ((monthly_income - 87000000) * 0.45)

    def calculate_tax(self, monthly_income, family_count, child_count):
        """최종 세액 계산 (자녀세액공제 반영) [cite: 10, 11, 12]"""
        # 1. 기본 세액 (1,000만 원 기준 분기)
        if monthly_income <= 10000000:
            base_tax = self._calculate_under_10m(monthly_income, family_count)
        else:
            base_tax = self._calculate_over_10m(monthly_income, family_count)
            
        # 2. 자녀 세액공제 (2페이지) [cite: 10, 11, 12]
        child_deduction = 0
        if child_count == 1: child_deduction = 12500
        elif child_count == 2: child_deduction = 29160
        elif child_count >= 3: child_deduction = 29160 + (child_count - 2) * 25000
        
        # 3. 11명 초과 가족 공제 로직 (필요 시 추가 가능하나 간이세액은 보통 11명까지 표기) [cite: 13, 14, 15]
        
        final_tax = max(0, base_tax - child_deduction)
        return int(math.floor(final_tax / 10) * 10) # 10원 미만 절사

# --- 사용 예시 ---
if __name__ == "__main__":
    calc = DuranTaxCalculator()
    
    print("=" * 80)
    print("두란 세무회계 계산기 vs 현재 Git 구현 비교 테스트")
    print("=" * 80)
    print()
    
    test_cases = [
        # (월급여, 가족수, 자녀수, 설명)
        (3000000, 3, 1, "월급 300만원, 가족 3명, 자녀 1명"),
        (3000000, 3, 0, "월급 300만원, 가족 3명, 자녀 0명"),
        (5000000, 2, 2, "월급 500만원, 가족 2명, 자녀 2명"),
        (10000000, 3, 1, "월급 1,000만원, 가족 3명, 자녀 1명"),
        (12000000, 3, 1, "월급 1,200만원, 가족 3명, 자녀 1명"),
        (15000000, 2, 2, "월급 1,500만원, 가족 2명, 자녀 2명"),
        (20000000, 4, 3, "월급 2,000만원, 가족 4명, 자녀 3명"),
    ]
    
    for monthly_income, family_count, child_count, desc in test_cases:
        result = calc.calculate_tax(monthly_income, family_count, child_count)
        print(f"📊 {desc}")
        print(f"   두란 계산기 결과: {result:,}원")
        print()
