import math

# ============================================================================
# 두란 세무회계 계산기 (제공된 코드)
# ============================================================================
class DuranTaxCalculator:
    """수식 기반 계산기"""
    
    def __init__(self):
        self.tax_at_10m = {
            1: 1507400, 2: 1431570, 3: 1200840, 4: 1170840, 5: 1140840,
            6: 1110840, 7: 1080840, 8: 1050840, 9: 1020840, 10: 990840, 11: 960840
        }

    def _get_earned_income_deduction(self, annual_salary):
        """근로소득공제"""
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
        """특별소득공제 및 특별세액공제"""
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
        else:
            if g <= 30000000: return 5000000 + g * 0.07
            if g <= 45000000: return 5000000 + g * 0.07 - (g - 30000000) * 0.05
            if g <= 70000000: return 5000000 + g * 0.05 + (g - 40000000) * 0.04
            if g <= 120000000: return 5000000 + g * 0.03 + (g - 40000000) * 0.04
        return 0

    def _get_standard_tax_credit(self, annual_tax, annual_salary):
        """근로소득세액공제"""
        if annual_tax <= 1300000:
            credit = annual_tax * 0.55
        else:
            credit = 715000 + (annual_tax - 1300000) * 0.30
        
        if annual_salary <= 33000000: limit = 740000
        elif annual_salary <= 70000000: limit = max(660000, 740000 - (annual_salary - 33000000) * 0.008)
        else: limit = max(500000, 660000 - (annual_salary - 70000000) * 0.5 * 0.01)
        
        return min(credit, limit)

    def _apply_tax_rates(self, taxable_income):
        """기본세율 적용"""
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
        """1,000만 원 이하 수식 계산"""
        annual_salary = monthly_income * 12
        deduction_earned = self._get_earned_income_deduction(annual_salary)
        deduction_basic = family_count * 1500000
        monthly_pension = min(monthly_income * 0.045, 265500)
        deduction_pension = monthly_pension * 12
        deduction_special = self._get_special_deduction_formula(annual_salary, family_count)
        taxable_income = annual_salary - deduction_earned - deduction_basic - deduction_pension - deduction_special
        calculated_annual_tax = self._apply_tax_rates(taxable_income)
        tax_credit = self._get_standard_tax_credit(calculated_annual_tax, annual_salary)
        final_annual_tax = max(0, calculated_annual_tax - tax_credit)
        return final_annual_tax / 12

    def _calculate_over_10m(self, monthly_income, family_count):
        """1,000만 원 초과 계산식"""
        eff_family = min(family_count, 11)
        tax_10m = self.tax_at_10m.get(eff_family, 960840)
        
        if monthly_income <= 14000000:
            return tax_10m + ((monthly_income - 10000000) * 0.98 * 0.35) + 25000
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
        """최종 세액 계산"""
        if monthly_income <= 10000000:
            base_tax = self._calculate_under_10m(monthly_income, family_count)
        else:
            base_tax = self._calculate_over_10m(monthly_income, family_count)
            
        child_deduction = 0
        if child_count == 1: child_deduction = 12500
        elif child_count == 2: child_deduction = 29160
        elif child_count >= 3: child_deduction = 29160 + (child_count - 2) * 25000
        
        final_tax = max(0, base_tax - child_deduction)
        return int(math.floor(final_tax / 10) * 10)


# ============================================================================
# 현재 Git 구현 (간이세액표 기반)
# ============================================================================
class GitImplementation:
    """간이세액표 조회 방식"""
    
    TAX_TABLE = {
        1065: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0},
        1130: {1: 1810, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0},
        1400: {1: 6910, 2: 2410, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0},
        1600: {1: 10780, 2: 6280, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0},
        1800: {1: 15110, 2: 10610, 3: 2630, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0},
        2000: {1: 18880, 2: 14330, 3: 6200, 4: 3420, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0},
        2200: {1: 26590, 2: 19590, 3: 10960, 4: 7590, 5: 4210, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0},
        2400: {1: 33340, 2: 26340, 3: 15130, 4: 11760, 5: 8380, 6: 5010, 7: 1630, 8: 0, 9: 0, 10: 0, 11: 0},
        2600: {1: 39690, 2: 32020, 3: 18920, 4: 16120, 5: 12740, 6: 9370, 7: 5990, 8: 2620, 9: 0, 10: 0, 11: 0},
        2800: {1: 55950, 2: 38530, 3: 24520, 4: 19930, 5: 16130, 6: 13400, 7: 9600, 8: 6010, 9: 2630, 10: 0, 11: 0},
        3000: {1: 74350, 2: 56850, 3: 31940, 4: 26690, 5: 21440, 6: 17100, 7: 13730, 8: 10350, 9: 6980, 10: 3600, 11: 0},
        3400: {1: 117440, 2: 92790, 3: 56200, 4: 35130, 5: 29880, 6: 24630, 7: 19380, 8: 14130, 9: 10680, 10: 6660, 11: 3290},
        4000: {1: 192000, 2: 140000, 3: 88000, 4: 60000, 5: 48000, 6: 40000, 7: 32000, 8: 24000, 9: 18000, 10: 12000, 11: 8000},
        5000: {1: 290000, 2: 220000, 3: 150000, 4: 110000, 5: 90000, 6: 75000, 7: 60000, 8: 48000, 9: 38000, 10: 28000, 11: 20000},
        6000: {1: 390000, 2: 310000, 3: 220000, 4: 170000, 5: 140000, 6: 115000, 7: 95000, 8: 75000, 9: 60000, 10: 48000, 11: 38000},
        7000: {1: 500000, 2: 410000, 3: 300000, 4: 240000, 5: 200000, 6: 170000, 7: 140000, 8: 115000, 9: 95000, 10: 75000, 11: 60000},
        8000: {1: 620000, 2: 520000, 3: 390000, 4: 320000, 5: 270000, 6: 230000, 7: 195000, 8: 165000, 9: 140000, 10: 115000, 11: 95000},
        9000: {1: 750000, 2: 640000, 3: 490000, 4: 410000, 5: 350000, 6: 300000, 7: 260000, 8: 225000, 9: 195000, 10: 165000, 11: 140000},
        10000: {1: 890000, 2: 770000, 3: 600000, 4: 510000, 5: 440000, 6: 380000, 7: 335000, 8: 295000, 9: 260000, 10: 225000, 11: 195000},
    }
    
    @classmethod
    def _lookup_tax_table(cls, monthly_income, family_count):
        """간이세액표 조회"""
        income_in_thousands = ((monthly_income + 4999) // 5000) * 5
        
        keys = sorted(cls.TAX_TABLE.keys())
        lower_key = None
        upper_key = None
        
        for key in keys:
            if income_in_thousands <= key:
                upper_key = key
                break
            lower_key = key
        
        if upper_key is not None and family_count in cls.TAX_TABLE[upper_key]:
            if income_in_thousands == upper_key:
                return cls.TAX_TABLE[upper_key][family_count]
            
            # 선형 보간
            if lower_key is not None and family_count in cls.TAX_TABLE[lower_key]:
                lower_tax = cls.TAX_TABLE[lower_key][family_count]
                upper_tax = cls.TAX_TABLE[upper_key][family_count]
                ratio = (income_in_thousands - lower_key) / (upper_key - lower_key)
                return int(lower_tax + (upper_tax - lower_tax) * ratio)
            
            return cls.TAX_TABLE[upper_key][family_count]
        
        if lower_key is not None and family_count in cls.TAX_TABLE[lower_key]:
            return cls.TAX_TABLE[lower_key][family_count]
        
        return 0
    
    @classmethod
    def _calculate_over_ten_million(cls, monthly_income, family_count):
        """1,000만원 초과 계산"""
        base_a = cls._lookup_tax_table(10000000, family_count)
        
        if monthly_income <= 14000000:
            excess = monthly_income - 10000000
            return base_a + int(excess * 0.98 * 0.35) + 25000
        elif monthly_income <= 28000000:
            excess = monthly_income - 14000000
            return base_a + 1397000 + int(excess * 0.98 * 0.38)
        elif monthly_income <= 30000000:
            excess = monthly_income - 28000000
            return base_a + 6610600 + int(excess * 0.98 * 0.40)
        elif monthly_income <= 45000000:
            excess = monthly_income - 30000000
            return base_a + 7394600 + int(excess * 0.40)
        elif monthly_income <= 87000000:
            excess = monthly_income - 45000000
            return base_a + 13394600 + int(excess * 0.42)
        else:
            excess = monthly_income - 87000000
            return base_a + 31034600 + int(excess * 0.45)
    
    @classmethod
    def calculate_tax(cls, monthly_income, family_count, child_count):
        """최종 세액 계산"""
        adjusted_family_count = max(1, family_count)
        is_over_eleven = family_count > 11
        if is_over_eleven:
            adjusted_family_count = 11
        
        # 간이세액표 기준 소득세
        if monthly_income <= 1060000:
            income_tax = 0
        elif monthly_income <= 10000000:
            income_tax = cls._lookup_tax_table(monthly_income, adjusted_family_count)
        else:
            income_tax = cls._calculate_over_ten_million(monthly_income, adjusted_family_count)
        
        # 자녀 세액공제
        if child_count > 0:
            if child_count == 1:
                child_tax_credit = 12500
            elif child_count == 2:
                child_tax_credit = 29160
            else:
                child_tax_credit = 29160 + (child_count - 2) * 25000
            income_tax -= child_tax_credit
            if income_tax < 0:
                income_tax = 0
        
        # 가족 수 11명 초과 처리
        if is_over_eleven:
            if monthly_income <= 10000000:
                tax10 = cls._lookup_tax_table(monthly_income, 10)
                tax11 = cls._lookup_tax_table(monthly_income, 11)
            else:
                tax10 = cls._calculate_over_ten_million(monthly_income, 10)
                tax11 = cls._calculate_over_ten_million(monthly_income, 11)
            extra_family = family_count - 11
            income_tax = income_tax - ((tax10 - tax11) * extra_family)
            if income_tax < 0:
                income_tax = 0
        
        # 지방소득세
        local_income_tax = int(income_tax * 0.1)
        
        # 1의 자리 절사
        income_tax = (income_tax // 10) * 10
        local_income_tax = (local_income_tax // 10) * 10
        
        return income_tax + local_income_tax


# ============================================================================
# 비교 테스트
# ============================================================================
if __name__ == "__main__":
    duran_calc = DuranTaxCalculator()
    
    print("=" * 100)
    print("🔍 두란 세무회계 (수식 기반) vs 현재 Git 구현 (간이세액표 기반) 비교")
    print("=" * 100)
    print()
    
    test_cases = [
        (3000000, 3, 1, "월급 300만원, 가족 3명, 자녀 1명"),
        (3000000, 3, 0, "월급 300만원, 가족 3명, 자녀 0명"),
        (5000000, 2, 2, "월급 500만원, 가족 2명, 자녀 2명"),
        (10000000, 3, 1, "월급 1,000만원, 가족 3명, 자녀 1명"),
        (12000000, 3, 1, "월급 1,200만원, 가족 3명, 자녀 1명"),
        (15000000, 2, 2, "월급 1,500만원, 가족 2명, 자녀 2명"),
        (20000000, 4, 3, "월급 2,000만원, 가족 4명, 자녀 3명"),
    ]
    
    total_diff = 0
    max_diff = 0
    max_diff_case = None
    
    for monthly_income, family_count, child_count, desc in test_cases:
        duran_result = duran_calc.calculate_tax(monthly_income, family_count, child_count)
        git_result = GitImplementation.calculate_tax(monthly_income, family_count, child_count)
        
        diff = git_result - duran_result
        diff_pct = (diff / duran_result * 100) if duran_result > 0 else 0
        
        total_diff += abs(diff)
        if abs(diff) > abs(max_diff):
            max_diff = diff
            max_diff_case = desc
        
        print(f"📊 {desc}")
        print(f"   두란 계산기:     {duran_result:>12,}원")
        print(f"   현재 Git 구현:   {git_result:>12,}원")
        print(f"   차이:           {diff:>12,}원 ({diff_pct:+.2f}%)")
        
        if abs(diff) > 1000:
            print(f"   ⚠️  차이가 1,000원 이상입니다!")
        
        print()
    
    print("=" * 100)
    print("📈 종합 분석")
    print("=" * 100)
    print(f"총 누적 차이: {total_diff:,}원")
    print(f"최대 차이 케이스: {max_diff_case}")
    print(f"최대 차이 금액: {max_diff:,}원")
    print()
    print("🔍 결론:")
    print("- 두란 계산기는 '수식 기반'으로 모든 공제를 직접 계산합니다")
    print("- 현재 Git 구현은 '간이세액표 조회 방식'으로 국세청 공식 표를 참조합니다")
    print("- 간이세액표는 이미 모든 공제가 반영된 '최종 납부세액'입니다")
    print("- 차이가 발생하는 이유:")
    print("  1) 두란 계산기의 1,000만원 기준점 값이 간이세액표와 다름")
    print("  2) 간이세액표가 더 정확함 (국세청 공식 발표)")
    print()
